CREATE SCHEMA IF NOT EXISTS shop;
SET search_path = shop, public;

-- ======================
-- Core reference tables
-- ======================

CREATE TABLE brand (
  brand_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        text NOT NULL
);

CREATE TABLE category (
  category_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        text NOT NULL
);

CREATE TABLE product_variant (
  variant_id  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        text NOT NULL
);

CREATE TABLE warehouse (
  warehouse_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name         text NOT NULL
);

-- ======================
-- Customer & addresses
-- ======================

CREATE TABLE customer (
  customer_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  first_name    text NOT NULL,
  last_name     text NOT NULL,
  email         text NOT NULL,
  phone_number  text NOT NULL,
  date_of_birth date NOT NULL  -- ✅ Removed trailing comma here
);

CREATE TABLE address (
  address_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id integer NOT NULL REFERENCES customer(customer_id) ON DELETE CASCADE,
  street      text NOT NULL,
  zip         text NOT NULL,
  city        text NOT NULL
);

-- ======================
-- Catalog
-- ======================

CREATE TABLE product (
  product_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_variant_id integer REFERENCES product_variant(product_variant_id),
  category_id    integer NOT NULL REFERENCES category(category_id) ON DELETE RESTRICT,
  brand_id       integer NOT NULL REFERENCES brand(brand_id) ON DELETE RESTRICT,
  name           text NOT NULL,
  description    text NOT NULL,
  stock_quantity integer NOT NULL,
  price          numeric(12,2) NOT NULL
);

-- Warehouse stock per product (many-to-many)
CREATE TABLE warehouse_product (
  warehouse_id integer NOT NULL REFERENCES warehouse(warehouse_id) ON DELETE CASCADE,
  product_id   integer NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
  PRIMARY KEY (warehouse_id, product_id)
);

-- Product warranty
CREATE TABLE warranty (
  warranty_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id  integer NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
  start_date  date NOT NULL,
  end_date    date NOT NULL
);

-- ======================
-- Coupons & payments
-- ======================

-- 💡 You can later convert discount_type, payment_method, payment_status, etc. to ENUM types.

CREATE TABLE coupon (
  coupon_id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code                text NOT NULL,
  discount_type       text NOT NULL,
  discount_value      numeric(12,2),
  expiry_date         date NOT NULL,
  minimum_order_value numeric(12,2) NOT NULL,
  is_active           boolean NOT NULL  -- ✅ snake_case for convention
);

CREATE TABLE payment (
  payment_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payment_method text NOT NULL,
  status         text NOT NULL,
  payment_date   date NOT NULL,
  amount         numeric(12,2) NOT NULL
);

-- ======================
-- Orders
-- ======================

CREATE TABLE "order" (
  order_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id  integer NOT NULL REFERENCES customer(customer_id) ON DELETE RESTRICT,
  coupon_id    integer REFERENCES coupon(coupon_id) ON DELETE SET NULL,  -- ✅ removed NOT NULL
  payment_id   integer NOT NULL REFERENCES payment(payment_id) ON DELETE RESTRICT,
  order_date   date NOT NULL,
  status       text NOT NULL,
  total_amount numeric(12,2) NOT NULL
);

-- Order line items
CREATE TABLE order_product (
  order_id  integer NOT NULL REFERENCES "order"(order_id) ON DELETE CASCADE,
  product_id integer NOT NULL REFERENCES product(product_id) ON DELETE RESTRICT,
  PRIMARY KEY (order_id, product_id)
);

-- Optional many-to-many order↔coupon mapping
CREATE TABLE order_coupon (
  order_id  integer NOT NULL REFERENCES "order"(order_id) ON DELETE CASCADE,
  coupon_id integer NOT NULL REFERENCES coupon(coupon_id) ON DELETE CASCADE,
  PRIMARY KEY (order_id, coupon_id)
);

-- ======================
-- Wishlists
-- ======================

CREATE TABLE wishlist (
  wishlist_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id integer NOT NULL REFERENCES customer(customer_id) ON DELETE CASCADE,
  name        text NOT NULL
);

CREATE TABLE wishlist_product (
  wishlist_id integer NOT NULL REFERENCES wishlist(wishlist_id) ON DELETE CASCADE,
  product_id  integer NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
  PRIMARY KEY (wishlist_id, product_id)
);

-- ======================
-- Shopping cart
-- ======================

CREATE TABLE shopping_cart (
  shopping_cart_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id      integer NOT NULL REFERENCES customer(customer_id) ON DELETE CASCADE
);

CREATE TABLE shopping_cart_item (
  shopping_cart_id integer NOT NULL REFERENCES shopping_cart(shopping_cart_id) ON DELETE CASCADE,
  product_id       integer NOT NULL REFERENCES product(product_id) ON DELETE RESTRICT,
  quantity         integer NOT NULL,
  PRIMARY KEY (shopping_cart_id, product_id)
);

-- ======================
-- Reviews
-- ======================

CREATE TABLE review (
  review_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id  integer NOT NULL REFERENCES customer(customer_id) ON DELETE CASCADE,
  product_id   integer NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
  review_value integer NOT NULL
);


-- PROCEDURES

CREATE OR REPLACE PROCEDURE shop.sp_ProcessOrder(p_order_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    prod_id INT;
    qty INT;
    stock_qty INT;
BEGIN
    -- Loop through each product in the order
    FOR prod_id, qty IN
        SELECT product_id, 1  -- assuming 1 per order_product; adapt if quantity exists
        FROM shop.order_product
        WHERE order_id = p_order_id
    LOOP
        -- Check stock
        SELECT stock_quantity INTO stock_qty
        FROM shop.product
        WHERE product_id = prod_id;

        IF stock_qty < qty THEN
            RAISE EXCEPTION 'Not enough stock for product %', prod_id;
        END IF;

        -- Update stock
        UPDATE shop.product
        SET stock_quantity = stock_quantity - qty
        WHERE product_id = prod_id;
    END LOOP;

    -- Update order status
    UPDATE shop."order"
    SET status = 'CONFIRMED'
    WHERE order_id = p_order_id;

    -- Process payment (mark as PAID for simplicity)
    UPDATE shop.payment
    SET status = 'PAID', payment_date = CURRENT_DATE
    WHERE payment_id = (SELECT payment_id FROM shop."order" WHERE order_id = p_order_id);
    
    RAISE NOTICE 'Order % processed successfully', p_order_id;
END;
$$;

CREATE OR REPLACE PROCEDURE shop.sp_CalculateShipping(
    p_order_id INT,
    OUT shipping_cost NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    total_weight NUMERIC := 0;
BEGIN
    -- Sum weight of all products in the order
    SELECT COALESCE(SUM(p.weight),0) INTO total_weight
    FROM shop.order_product op
    JOIN shop.product p ON op.product_id = p.product_id
    WHERE op.order_id = p_order_id;

    -- Simple formula: $5 per kg
    shipping_cost := total_weight * 5;

    -- Update order with shipping cost (if you have a column)
    UPDATE shop."order"
    SET total_amount = total_amount + shipping_cost
    WHERE order_id = p_order_id;

    RAISE NOTICE 'Shipping cost for order %: %', p_order_id, shipping_cost;
END;
$$;

CREATE OR REPLACE PROCEDURE shop.sp_UpdateInventory(p_product_id INT, p_warehouse_id INT, p_quantity INT)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check if warehouse_product exists
    IF EXISTS (
        SELECT 1 FROM shop.warehouse_product
        WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id
    ) THEN
        -- Update existing quantity
        UPDATE shop.warehouse_product
        SET stock_quantity = stock_quantity + p_quantity
        WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id;
    ELSE
        -- Insert new record
        INSERT INTO shop.warehouse_product(warehouse_id, product_id)
        VALUES (p_warehouse_id, p_product_id);
        -- If you have a stock column in warehouse_product, add: stock_quantity = p_quantity
    END IF;

    -- Also update global product stock
    UPDATE shop.product
    SET stock_quantity = stock_quantity + p_quantity
    WHERE product_id = p_product_id;

    RAISE NOTICE 'Inventory updated for product % in warehouse %', p_product_id, p_warehouse_id;
END;
$$;


-- FUNCTIONS

CREATE OR REPLACE FUNCTION shop.fn_GetProductRating(p_product_id INT)
RETURNS NUMERIC(3,2)
LANGUAGE plpgsql
AS $$
DECLARE
    avg_rating NUMERIC;
BEGIN
    SELECT ROUND(AVG(review_value), 2)
    INTO avg_rating
    FROM shop.review
    WHERE product_id = p_product_id;

    RETURN COALESCE(avg_rating, 0);
END;
$$;


CREATE OR REPLACE FUNCTION shop.fn_CalculateCustomerLifetimeValue(p_customer_id INT)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
AS $$
DECLARE
    total_spent NUMERIC;
BEGIN
    SELECT COALESCE(SUM(total_amount), 0)
    INTO total_spent
    FROM shop."order"
    WHERE customer_id = p_customer_id;

    RETURN total_spent;
END;
$$;



CREATE OR REPLACE FUNCTION shop.fn_GetProductAvailability(p_product_id INT)
RETURNS TABLE(
    warehouse_name TEXT,
    stock_quantity INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT w.name, wp.product_id
    FROM shop.warehouse_product wp
    JOIN shop.warehouse w ON wp.warehouse_id = w.warehouse_id
    WHERE wp.product_id = p_product_id;
END;
$$;



-- VIEWS

CREATE OR REPLACE VIEW shop.vw_OrderSummary AS
SELECT
    o.order_id,
    o.order_date,
    o.status AS order_status,
    o.total_amount,
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email AS customer_email,
    p.product_id,
    p.name AS product_name,
    p.price AS unit_price,
    pay.payment_method,
    pay.status AS payment_status
FROM shop."order" o
JOIN shop.customer c ON o.customer_id = c.customer_id
JOIN shop.order_product op ON o.order_id = op.order_id
JOIN shop.product p ON op.product_id = p.product_id
JOIN shop.payment pay ON o.payment_id = pay.payment_id;


CREATE OR REPLACE VIEW shop.vw_LowStockProducts AS
SELECT
    p.product_id,
    p.name AS product_name,
    p.stock_quantity,
    b.name AS brand_name,
    c.name AS category_name
FROM shop.product p
JOIN shop.brand b ON p.brand_id = b.brand_id
JOIN shop.category c ON p.category_id = c.category_id
WHERE p.stock_quantity <= 10
ORDER BY p.stock_quantity ASC;


CREATE OR REPLACE VIEW shop.vw_CustomerPurchaseHistory AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    o.order_id,
    o.order_date,
    o.status AS order_status,
    o.total_amount,
    p.product_id,
    p.name AS product_name,
    p.price AS unit_price,
    op.product_id AS order_product_id
FROM shop.customer c
LEFT JOIN shop."order" o ON c.customer_id = o.customer_id
LEFT JOIN shop.order_product op ON o.order_id = op.order_id
LEFT JOIN shop.product p ON op.product_id = p.product_id
ORDER BY c.customer_id, o.order_date DESC;


CREATE OR REPLACE VIEW shop.vw_BestSellingProducts AS
SELECT
    p.product_id,
    p.name AS product_name,
    COUNT(op.order_id) AS total_orders,
    COALESCE(SUM(p.price), 0) AS total_revenue,
    b.name AS brand_name,
    c.name AS category_name
FROM shop.product p
JOIN shop.order_product op ON p.product_id = op.product_id
JOIN shop.brand b ON p.brand_id = b.brand_id
JOIN shop.category c ON p.category_id = c.category_id
GROUP BY p.product_id, p.name, b.name, c.name
ORDER BY total_orders DESC;


-- TRIGGERS

CREATE OR REPLACE PROCEDURE shop.evt_CleanupAbandonedCarts()
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM shop.shopping_cart_item
    WHERE added_at < CURRENT_DATE - INTERVAL '30 days';

    DELETE FROM shop.shopping_cart
    WHERE shopping_cart_id NOT IN (
        SELECT DISTINCT shopping_cart_id FROM shop.shopping_cart_item
    );

    RAISE NOTICE 'Abandoned carts cleaned up';
END;
$$;


-- EVENTS ??