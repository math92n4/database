-- ======================
-- Core reference tables
-- ======================

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