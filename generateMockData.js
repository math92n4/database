import { Client } from "pg";
import { faker } from "@faker-js/faker";
import dotenv from "dotenv";

dotenv.config();

const client = new Client({
  user: process.env.POSTGRES_USER,
  host: process.env.HOST,
  database: process.env.POSTGRES_DB,
  password: process.env.POSTGRES_PASSWORD,
  port: process.env.PORT,
});

async function generateMockData() {
  try {
    await client.connect();

    // ------------------------
    // 1. Brand
    // ------------------------
    const brands = [];
    for (let i = 0; i < 5; i++) {
      const res = await client.query(
        `INSERT INTO brand (name, description)
         VALUES ($1,$2) RETURNING brand_id`,
        [faker.company.name(), faker.company.catchPhrase()]
      );
      brands.push(res.rows[0].brand_id);
    }

    // ------------------------
    // 2. Category
    // ------------------------
    const categories = [];
    for (let i = 0; i < 5; i++) {
      const res = await client.query(
        `INSERT INTO category (name, description)
         VALUES ($1,$2) RETURNING category_id`,
        [faker.commerce.department(), faker.commerce.productDescription()]
      );
      categories.push(res.rows[0].category_id);
    }

    // ------------------------
    // 3. Customer
    // ------------------------
    const customers = [];
    for (let i = 0; i < 10; i++) {
      const res = await client.query(
        `INSERT INTO customer (email, password, first_name, last_name, phone_number, date_of_birth)
         VALUES ($1,$2,$3,$4,$5,$6) RETURNING customer_id`,
        [
          faker.internet.email(),
          faker.internet.password(),
          faker.person.firstName(),
          faker.person.lastName(),
          faker.phone.number(),
          faker.date.birthdate({ min: 18, max: 70, mode: "age" }),
        ]
      );
      customers.push(res.rows[0].customer_id);
    }

    // ------------------------
    // 4. Warehouse
    // ------------------------
    const warehouses = [];
    for (let i = 0; i < 3; i++) {
      const res = await client.query(
        `INSERT INTO warehouse (name, address, city, postal_code, country, phone)
         VALUES ($1,$2,$3,$4,$5,$6) RETURNING warehouse_id`,
        [
          faker.company.name(),
          faker.location.streetAddress(),
          faker.location.city(),
          faker.location.zipCode(),
          faker.location.country(),
          faker.phone.number(),
        ]
      );
      warehouses.push(res.rows[0].warehouse_id);
    }

    // ------------------------
    // 5. Coupon
    // ------------------------
    const coupons = [];
    for (let i = 0; i < 5; i++) {
      const res = await client.query(
        `INSERT INTO coupon (code, discount_type, discount_value, minimum_order_value, expiry_date, usage_limit, times_used, is_active)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING coupon_id`,
        [
          faker.string.alphanumeric(6).toUpperCase(),
          faker.helpers.arrayElement(["percentage", "fixed_amount"]),
          faker.number.float({ min: 5, max: 50 }),
          faker.number.float({ min: 50, max: 300 }),
          faker.date.future(),
          faker.number.int({ min: 10, max: 100 }),
          0,
          true,
        ]
      );
      coupons.push(res.rows[0].coupon_id);
    }

    // ------------------------
    // 6. Warranty
    // ------------------------
    const warranties = [];
    for (let i = 0; i < 5; i++) {
      const start_date = faker.date.past();
      const end_date = faker.date.future({ years: 2 });
      const res = await client.query(
        `INSERT INTO warranty (start_date, end_date, description)
         VALUES ($1,$2,$3) RETURNING warranty_id`,
        [start_date, end_date, faker.lorem.sentence()]
      );
      warranties.push(res.rows[0].warranty_id);
    }

    // ------------------------
    // 7. Product
    // ------------------------
    const products = [];
    for (let i = 0; i < 10; i++) {
      const res = await client.query(
        `INSERT INTO product (product_id, brand_id, category_id, sku, name, description, stock_quantity, price, weight)
         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7,$8) RETURNING product_id`,
        [
          faker.helpers.arrayElement(brands),
          faker.helpers.arrayElement(categories),
          faker.string.alphanumeric(8).toUpperCase(),
          faker.commerce.productName(),
          faker.commerce.productDescription(),
          faker.number.int({ min: 10, max: 500 }),
          faker.number.float({ min: 10, max: 500 }),
          faker.number.float({ min: 0.5, max: 5 }),
        ]
      );
      products.push(res.rows[0].product_id);
    }

    // ------------------------
    // 8. Product Variants
    // ------------------------
    const variants = [];
    for (const product_id of products) {
      const variantCount = faker.number.int({ min: 1, max: 3 });
      for (let j = 0; j < variantCount; j++) {
        const res = await client.query(
          `INSERT INTO productvariant (product_id, name, description, stock_quantity, price, weight, sku)
           VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING variant_id`,
          [
            product_id,
            faker.commerce.productMaterial(),
            faker.lorem.sentence(),
            faker.number.int({ min: 0, max: 100 }),
            faker.number.float({ min: 5, max: 50 }),
            faker.number.float({ min: 0.2, max: 3 }),
            faker.string.alphanumeric(8).toUpperCase(),
          ]
        );
        variants.push(res.rows[0].variant_id);
      }
    }

    // ------------------------
    // 9. Orders
    // ------------------------
    const orders = [];
    for (const customer_id of customers) {
      const orderCount = faker.number.int({ min: 1, max: 3 });
      for (let i = 0; i < orderCount; i++) {
        const order_date = faker.date.recent({ days: 30 });
        const subtotal = faker.number.float({ min: 50, max: 500 });
        const tax = subtotal * 0.1;
        const shipping = faker.number.float({ min: 5, max: 25 });
        const discount = faker.number.float({ min: 0, max: 50 });
        const total = subtotal + tax + shipping - discount;

        const resOrder = await client.query(
          `INSERT INTO "order" (customer_id, payment_method_id, shipping_address_id, order_date, status, subtotal, tax_amount, shipping_cost, discount_amount, total_amount)
           VALUES ($1, NULL, NULL, $2, $3, $4, $5, $6, $7, $8) RETURNING order_id`,
          [
            customer_id,
            order_date,
            faker.helpers.arrayElement([
              "pending",
              "confirmed",
              "processing",
              "shipped",
              "delivered",
              "cancelled",
              "returned",
            ]),
            subtotal,
            tax,
            shipping,
            discount,
            total,
          ]
        );
        orders.push(resOrder.rows[0].order_id);
      }
    }

    // ------------------------
    // 10. Payments
    // ------------------------
    for (const order_id of orders) {
      await client.query(
        `INSERT INTO payment (order_id, payment_method, amount, currency, status, payment_date)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [
          order_id,
          faker.helpers.arrayElement([
            "credit_card",
            "paypal",
            "bank_transfer",
            "invoice",
          ]),
          faker.number.float({ min: 50, max: 1000 }),
          "USD",
          faker.helpers.arrayElement([
            "pending",
            "completed",
            "failed",
            "refunded",
          ]),
          faker.date.recent(),
        ]
      );
    }

    // ------------------------
    // 11. Reviews
    // ------------------------
    for (let i = 0; i < 15; i++) {
      const res = await client.query(
        `INSERT INTO review (product_id, customer_id, order_item_id, review_value, title, comment, is_verified_purchase, created_at)
         VALUES ($1,$2,NULL,$3,$4,$5,$6,$7)`,
        [
          faker.helpers.arrayElement(products),
          faker.helpers.arrayElement(customers),
          faker.number.int({ min: 1, max: 5 }),
          faker.lorem.sentence(),
          faker.lorem.paragraph(),
          faker.datatype.boolean(),
          faker.date.recent(),
        ]
      );
    }

    // ------------------------
    // 12. Wishlist
    // ------------------------
    for (const customer_id of customers) {
      const wishlist_product_id = faker.helpers.arrayElement(products);
      await client.query(
        `INSERT INTO wishlist (wishlist_id, customer_id, wishlist_product_id, name)
         VALUES (gen_random_uuid(),$1,$2,$3)`,
        [customer_id, wishlist_product_id, faker.commerce.productName()]
      );
    }

    // ------------------------
    // 13. ProductRelated
    // ------------------------
    for (const product_id of products) {
      const related_id = faker.helpers.arrayElement(
        products.filter((p) => p !== product_id)
      );
      await client.query(
        `INSERT INTO productrelated (product_id, related_product_id, relation_type)
         VALUES ($1,$2,$3)`,
        [
          product_id,
          related_id,
          faker.helpers.arrayElement(["accessory", "alternative", "bundle"]),
        ]
      );
    }

    // ------------------------
    // 14. CustomerCoupon
    // ------------------------
    for (const customer_id of customers) {
      const coupon_id = faker.helpers.arrayElement(coupons);
      await client.query(
        `INSERT INTO customercoupon (customer_id, coupon_id, used_date, order_id)
         VALUES ($1,$2,$3,NULL)`,
        [customer_id, coupon_id, faker.date.recent()]
      );
    }

    console.log("✅ All mock data generated successfully!");
  } catch (err) {
    console.error("❌ Error generating mock data:", err);
  } finally {
    await client.end();
  }
}

generateMockData();
