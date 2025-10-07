-- ======================
-- Core reference tables
-- ======================
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE brand (
  brand_id    UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  name        TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE TABLE category (
  category_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  name        TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE TABLE warehouse (
  warehouse_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  name         TEXT NOT NULL,
  address      TEXT NOT NULL,
  city         TEXT NOT NULL,
  postal_code  TEXT NOT NULL, 
  country      TEXT NOT NULL,
  phone        TEXT NOT NULL
);

-- ======================
-- Customer
-- ======================

CREATE TABLE customer (
  customer_id   UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  email         TEXT NOT NULL UNIQUE,
  password      TEXT NOT NULL,
  first_name    TEXT NOT NULL,
  last_name     TEXT NOT NULL,
  phone_number  TEXT NOT NULL,
  date_of_birth DATE NOT NULL
);

-- ======================
-- Coupons
-- ======================

CREATE TYPE discount_type_enum AS ENUM ('percentage', 'fixed_amount');

CREATE TABLE coupon (
  coupon_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  code                TEXT NOT NULL UNIQUE,
  discount_type       discount_type_enum NOT NULL,
  discount_value      NUMERIC(12,2) NOT NULL,
  minimum_order_value NUMERIC(12,2) NOT NULL,
  expiry_date         DATE,
  usage_limit         INTEGER NOT NULL,
  times_used          INTEGER DEFAULT 0,
  is_active           BOOLEAN DEFAULT TRUE
);

-- ======================
-- Warranty
-- ======================

CREATE TABLE warranty (
  warranty_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  start_date  DATE NOT NULL,
  end_date    DATE NOT NULL,
  description TEXT NOT NULL
);

-- ======================
-- Products
-- ======================

CREATE TABLE product (
  product_id     UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  brand_id       UUID NOT NULL REFERENCES brand(brand_id),
  category_id    UUID NOT NULL REFERENCES category(category_id),
  sku            TEXT UNIQUE NOT NULL,
  name           TEXT NOT NULL,
  description    TEXT NOT NULL,
  stock_quantity INTEGER DEFAULT 0,
  price          NUMERIC(12,2) NOT NULL,
  weight         NUMERIC(8,2)
);

CREATE TABLE productvariant (
  variant_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  product_id     UUID NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  description    TEXT,
  stock_quantity INTEGER DEFAULT 0,
  price          NUMERIC(12,2),
  weight         NUMERIC(8,2),
  sku            TEXT UNIQUE NOT NULL
);

-- ======================
-- Orders
-- ======================

CREATE TYPE order_type_enum AS ENUM ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'returned');

CREATE TABLE "order" (
  order_id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  customer_id      UUID NOT NULL REFERENCES customer(customer_id),
  payment_method_id UUID,
  shipping_address_id UUID,
  order_date       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status           order_type_enum DEFAULT 'pending',
  subtotal         NUMERIC(12,2) NOT NULL,
  tax_amount       NUMERIC(12,2) NOT NULL,
  shipping_cost    NUMERIC(12,2) NOT NULL,
  discount_amount  NUMERIC(12,2),
  total_amount     NUMERIC(12,2) NOT NULL
);

-- ======================
-- Payments
-- ======================

CREATE TYPE payment_type_enum AS ENUM('credit_card', 'paypal', 'bank', 'klarna', 'cash');
CREATE TYPE status_type_enum AS ENUM('pending', 'completed', 'failed', 'refunded');

CREATE TABLE payment (
  payment_id     UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  order_id       UUID NOT NULL REFERENCES "order"(order_id),
  payment_method payment_type_enum NOT NULL,
  amount         NUMERIC(12,2) NOT NULL,
  status         status_type_enum DEFAULT 'pending',
  payment_date   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ======================
-- Reviews
-- ======================

CREATE TABLE review (
  review_id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
  product_id          UUID NOT NULL REFERENCES product(product_id),
  customer_id         UUID NOT NULL REFERENCES customer(customer_id),
  order_item_id       UUID,
  review_value        INTEGER CHECK (review_value >= 1 AND review_value <= 5),
  title               TEXT,
  comment             TEXT,
  is_verified_purchase BOOLEAN DEFAULT FALSE,
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ======================
-- Wishlists
-- ======================

CREATE TABLE wishlist (
  wishlist_id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id         UUID NOT NULL REFERENCES customer(customer_id),
  wishlist_product_id UUID NOT NULL REFERENCES product(product_id),
  name                TEXT NOT NULL
);

-- ======================
-- Join Tables
-- ======================

-- Order-Coupon many-to-many relationship
CREATE TABLE ordercoupon (
  order_id    UUID NOT NULL REFERENCES "order"(order_id) ON DELETE CASCADE,
  coupon_id   UUID NOT NULL REFERENCES coupon(coupon_id) ON DELETE CASCADE,
  applied_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (order_id, coupon_id)
);

-- Order-Product many-to-many relationship (order line items)
CREATE TABLE orderproduct (
  order_id    UUID NOT NULL REFERENCES "order"(order_id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES product(product_id) ON DELETE RESTRICT,
  quantity    INTEGER NOT NULL CHECK (quantity > 0),
  unit_price  NUMERIC(12,2) NOT NULL,
  total_price NUMERIC(12,2) NOT NULL,
  PRIMARY KEY (order_id, product_id)
);

-- Wishlist-Product many-to-many relationship
CREATE TABLE wishlistproduct (
  wishlist_id UUID NOT NULL REFERENCES wishlist(wishlist_id) ON DELETE CASCADE,
  product_id  UUID NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
  added_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (wishlist_id, product_id)
);

-- Warehouse-Product many-to-many relationship with stock tracking
CREATE TABLE warehouseproduct (
  warehouse_id   UUID NOT NULL REFERENCES warehouse(warehouse_id) ON DELETE CASCADE,
  product_id     UUID NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
  stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
  last_updated   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (warehouse_id, product_id)
);

-- =========================================
-- PROCEDURES
-- =========================================

-- 1. Process an order: confirm, update stock, and mark payment
CREATE OR REPLACE PROCEDURE sp_ProcessOrder(p_order_id UUID)
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    stock_qty INT;
BEGIN
    -- Loop through each product in the order
    FOR rec IN
        SELECT product_id, quantity
        FROM orderproduct
        WHERE order_id = p_order_id
    LOOP
        -- Check stock
        SELECT stock_quantity INTO stock_qty
        FROM product
        WHERE product_id = rec.product_id;

        IF stock_qty < rec.quantity THEN
            RAISE EXCEPTION 'Not enough stock for product %', rec.product_id;
        END IF;

        -- Update stock
        UPDATE product
        SET stock_quantity = stock_quantity - rec.quantity
        WHERE product_id = rec.product_id;
    END LOOP;

    -- Update order status
    UPDATE "order"
    SET status = 'confirmed'
    WHERE order_id = p_order_id;

    -- Process payment: mark as completed (simplified)
    UPDATE payment
    SET status = 'completed', payment_date = CURRENT_TIMESTAMP
    WHERE order_id = p_order_id;

    RAISE NOTICE 'Order % processed successfully', p_order_id;
END;
$$;

-- 2. Calculate shipping cost
CREATE OR REPLACE PROCEDURE sp_CalculateShipping(
    p_order_id UUID,
    OUT shipping_cost NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    total_weight NUMERIC := 0;
BEGIN
    SELECT COALESCE(SUM(p.weight * op.quantity),0) INTO total_weight
    FROM orderproduct op
    JOIN product p ON op.product_id = p.product_id
    WHERE op.order_id = p_order_id;

    -- Simple formula: $5 per kg
    shipping_cost := total_weight * 5;

    -- Update order total_amount to include shipping
    UPDATE "order"
    SET shipping_cost = shipping_cost,
        total_amount = subtotal + tax_amount + shipping_cost - COALESCE(discount_amount,0)
    WHERE order_id = p_order_id;

    RAISE NOTICE 'Shipping cost for order %: %', p_order_id, shipping_cost;
END;
$$;

-- 3. Update inventory in warehouse and global stock
CREATE OR REPLACE PROCEDURE sp_UpdateInventory(
    p_product_id UUID,
    p_warehouse_id UUID,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update warehouse stock
    IF EXISTS (
        SELECT 1 FROM warehouseproduct
        WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id
    ) THEN
        UPDATE warehouseproduct
        SET stock_quantity = stock_quantity + p_quantity,
            last_updated = CURRENT_TIMESTAMP
        WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    ELSE
        INSERT INTO warehouseproduct(warehouse_id, product_id, stock_quantity)
        VALUES (p_warehouse_id, p_product_id, p_quantity);
    END IF;

    -- Update global product stock
    UPDATE product
    SET stock_quantity = stock_quantity + p_quantity
    WHERE product_id = p_product_id;

    RAISE NOTICE 'Inventory updated for product % in warehouse %', p_product_id, p_warehouse_id;
END;
$$;


-- 5. Generate monthly sales report (example procedure)
CREATE OR REPLACE PROCEDURE evt_GenerateMonthlyReports(p_month DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    total_orders INT;
    total_revenue NUMERIC(12,2);
BEGIN
    SELECT COUNT(*), COALESCE(SUM(total_amount),0)
    INTO total_orders, total_revenue
    FROM "order"
    WHERE date_trunc('month', order_date) = date_trunc('month', p_month);

    -- You could insert into a report table, or just raise notice
    RAISE NOTICE 'Month: %, Total Orders: %, Total Revenue: %', p_month, total_orders, total_revenue;
END;
$$;



CREATE OR REPLACE VIEW vw_LowStockProducts AS
SELECT
    p.product_id,
    p.name AS product_name,
    p.stock_quantity,
    b.name AS brand_name,
    c.name AS category_name
FROM product p
JOIN brand b ON p.brand_id = b.brand_id
JOIN category c ON p.category_id = c.category_id
WHERE p.stock_quantity <= 10
ORDER BY p.stock_quantity ASC;


CREATE OR REPLACE VIEW vw_BestSellingProducts AS
SELECT
    p.product_id,
    p.name AS product_name,
    COUNT(op.order_id) AS total_orders,
    COALESCE(SUM(p.price), 0) AS total_revenue,
    b.name AS brand_name,
    c.name AS category_name
FROM product p
JOIN orderproduct op ON p.product_id = op.product_id
JOIN brand b ON p.brand_id = b.brand_id
JOIN category c ON p.category_id = c.category_id
GROUP BY p.product_id, p.name, b.name, c.name
ORDER BY total_orders DESC;

-- 6. Update product rankings based on total orders
CREATE OR REPLACE PROCEDURE evt_UpdateProductRankings()
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE product p
    SET stock_quantity = p.stock_quantity -- just placeholder, you could add popularity_score column
    FROM (
        SELECT op.product_id, SUM(op.quantity) AS total_sold
        FROM orderproduct op
        GROUP BY op.product_id
    ) AS sub
    WHERE p.product_id = sub.product_id;

    RAISE NOTICE 'Product rankings updated';
END;
$$;



CREATE OR REPLACE FUNCTION fn_GetProductRating(p_product_id UUID)
RETURNS NUMERIC(3,2)
LANGUAGE plpgsql
AS $$
DECLARE
    avg_rating NUMERIC;
BEGIN
    SELECT ROUND(AVG(review_value), 2)
    INTO avg_rating
    FROM review
    WHERE product_id = p_product_id;

    RETURN COALESCE(avg_rating, 0);
END;
$$;


CREATE OR REPLACE FUNCTION fn_CalculateCustomerLifetimeValue(p_customer_id UUID)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
AS $$
DECLARE
    total_spent NUMERIC;
BEGIN
    SELECT COALESCE(SUM(total_amount), 0)
    INTO total_spent
    FROM "order"
    WHERE customer_id = p_customer_id;

    RETURN total_spent;
END;
$$;

-- ======================
-- TRIGGERS
-- ======================

-- 1. Automatically increment coupon usage when applied to an order
CREATE OR REPLACE FUNCTION increment_coupon_usage()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE coupon
  SET times_used = times_used + 1
  WHERE coupon_id = NEW.coupon_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_increment_coupon_usage
AFTER INSERT ON ordercoupon
FOR EACH ROW
EXECUTE FUNCTION increment_coupon_usage();

-- 2. Validate coupon before applying to order
CREATE OR REPLACE FUNCTION validate_coupon()
RETURNS TRIGGER AS $$
DECLARE
  v_coupon RECORD;
  v_order_total NUMERIC(12,2);
BEGIN
  -- Get coupon details
  SELECT * INTO v_coupon
  FROM coupon
  WHERE coupon_id = NEW.coupon_id;
  
  -- Get order total
  SELECT total_amount INTO v_order_total
  FROM "order"
  WHERE order_id = NEW.order_id;
  
  -- Check if coupon is active
  IF NOT v_coupon.is_active THEN
    RAISE EXCEPTION 'Coupon is not active';
  END IF;
  
  -- Check if coupon has expired
  IF v_coupon.expiry_date IS NOT NULL AND v_coupon.expiry_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Coupon has expired';
  END IF;
  
  -- Check usage limit
  IF v_coupon.times_used >= v_coupon.usage_limit THEN
    RAISE EXCEPTION 'Coupon usage limit exceeded';
  END IF;
  
  -- Check minimum order value
  IF v_order_total < v_coupon.minimum_order_value THEN
    RAISE EXCEPTION 'Order total does not meet minimum order value for this coupon';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_coupon
BEFORE INSERT ON ordercoupon
FOR EACH ROW
EXECUTE FUNCTION validate_coupon();

-- 3. Update product stock when order is placed
CREATE OR REPLACE FUNCTION update_product_stock()
RETURNS TRIGGER AS $$
BEGIN
  -- Decrease product stock quantity
  UPDATE product
  SET stock_quantity = stock_quantity - NEW.quantity
  WHERE product_id = NEW.product_id;
  
  -- Check if stock went negative
  IF (SELECT stock_quantity FROM product WHERE product_id = NEW.product_id) < 0 THEN
    RAISE EXCEPTION 'Insufficient stock for product';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_product_stock
AFTER INSERT ON orderproduct
FOR EACH ROW
EXECUTE FUNCTION update_product_stock();

-- 4. Restore product stock when order is cancelled
CREATE OR REPLACE FUNCTION restore_product_stock()
RETURNS TRIGGER AS $$
BEGIN
  -- Only restore stock if order status changed to cancelled or returned
  IF NEW.status IN ('cancelled', 'returned') AND OLD.status NOT IN ('cancelled', 'returned') THEN
    UPDATE product p
    SET stock_quantity = stock_quantity + op.quantity
    FROM orderproduct op
    WHERE op.order_id = NEW.order_id
    AND p.product_id = op.product_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_restore_product_stock
AFTER UPDATE ON "order"
FOR EACH ROW
EXECUTE FUNCTION restore_product_stock();


SELECT cron.schedule('deactivate-expired-coupons', '0 0 * * *', $$
  UPDATE coupon 
  SET is_active = FALSE 
  WHERE expiry_date < CURRENT_DATE AND is_active = TRUE
$$);

SELECT cron.schedule('cancel-old-pending-orders', '0 2 * * *', $$
  UPDATE "order" 
  SET status = 'cancelled' 
  WHERE status = 'pending' 
  AND order_date < CURRENT_TIMESTAMP - INTERVAL '7 days'
$$);
