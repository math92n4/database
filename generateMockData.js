const { Client } = require("pg");
const { faker } = require("@faker-js/faker");

const client = new Client({
  user: "your_username",
  host: "localhost",
  database: "your_database",
  password: "your_password",
  port: 5432,
});

async function generateMockData() {
  try {
    await client.connect();

    // ------------------------
    // 1. Brands
    // ------------------------
    const brands = [];
    for (let i = 0; i < 5; i++) {
      const res = await client.query(
        `INSERT INTO brand (name, description, logo_url, website, is_active)
         VALUES ($1,$2,$3,$4,$5) RETURNING brand_id`,
        [
          faker.company.name(),
          faker.company.catchPhrase(),
          faker.image.url(),
          faker.internet.url(),
          true,
        ]
      );
      brands.push(res.rows[0].brand_id);
    }

    // ------------------------
    // 2. Categories
    // ------------------------
    const categories = [];
    for (let i = 0; i < 5; i++) {
      const res = await client.query(
        `INSERT INTO category (name, description, display_order, is_active)
         VALUES ($1,$2,$3,$4) RETURNING category_id`,
        [
          faker.commerce.department(),
          faker.commerce.productDescription(),
          i + 1,
          true,
        ]
      );
      categories.push(res.rows[0].category_id);
    }

    // ------------------------
    // 3. Suppliers
    // ------------------------
    const suppliers = [];
    for (let i = 0; i < 5; i++) {
      const res = await client.query(
        `INSERT INTO supplier (company_name, contact_name, email, phone, address, city, postal_code, country, payment_terms, is_active)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING supplier_id`,
        [
          faker.company.name(),
          faker.person.fullName(),
          faker.internet.email(),
          faker.phone.number(),
          faker.location.streetAddress(),
          faker.location.city(),
          faker.location.zipCode(),
          faker.location.country(),
          "Net 30",
          true,
        ]
      );
      suppliers.push(res.rows[0].supplier_id);
    }

    // ------------------------
    // 4. Warehouses
    // ------------------------
    const warehouses = [];
    for (let i = 0; i < 3; i++) {
      const res = await client.query(
        `INSERT INTO warehouse (name, code, address, city, postal_code, country, manager_name, phone, is_active)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING warehouse_id`,
        [
          faker.company.name(),
          faker.string.alphanumeric(5).toUpperCase(),
          faker.location.streetAddress(),
          faker.location.city(),
          faker.location.zipCode(),
          faker.location.country(),
          faker.person.fullName(),
          faker.phone.number(),
          true,
        ]
      );
      warehouses.push(res.rows[0].warehouse_id);
    }

    // ------------------------
    // 5. Warranties
    // ------------------------
    const warranties = [];
    for (let i = 0; i < 5; i++) {
      const res = await client.query(
        `INSERT INTO warranty (warranty_type, duration_months, terms_conditions, price)
         VALUES ($1,$2,$3,$4) RETURNING warranty_id`,
        [
          faker.commerce.productMaterial(),
          faker.number.int({ min: 6, max: 36 }),
          faker.lorem.sentence(),
          faker.number.int({ min: 10, max: 100 }),
        ]
      );
      warranties.push(res.rows[0].warranty_id);
    }

    // ------------------------
    // 6. Coupons
    // ------------------------
    const coupons = [];
    for (let i = 0; i < 5; i++) {
      const res = await client.query(
        `INSERT INTO coupon (code, description, discount_type, discount_value, minimum_purchase, valid_from, valid_until, usage_limit, times_used, is_active)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING coupon_id`,
        [
          faker.string.alphanumeric(6).toUpperCase(),
          faker.lorem.sentence(),
          faker.helpers.arrayElement(["percentage", "fixed_amount"]),
          faker.number.int({ min: 5, max: 50 }),
          faker.number.int({ min: 20, max: 200 }),
          faker.date.past(),
          faker.date.future(),
          faker.number.int({ min: 10, max: 100 }),
          0,
          true,
        ]
      );
      coupons.push(res.rows[0].coupon_id);
    }

    // ------------------------
    // 7. Customers
    // ------------------------
    const customers = [];
    for (let i = 0; i < 10; i++) {
      const res = await client.query(
        `INSERT INTO customer (email, password, first_name, last_name, phone_number, date_o)
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
    // 8. Addresses
    // ------------------------
    const addresses = [];
    for (const customer_id of customers) {
      const addressCount = faker.number.int({ min: 1, max: 2 });
      for (let i = 0; i < addressCount; i++) {
        const res = await client.query(
          `INSERT INTO address (customer_id, address_type, recipient_name, street_address, city, state_province, postal_code, country, phone, is_default)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING address_id`,
          [
            customer_id,
            faker.helpers.arrayElement(["billing", "shipping", "both"]),
            faker.person.fullName(),
            faker.location.streetAddress(),
            faker.location.city(),
            faker.location.state(),
            faker.location.zipCode(),
            faker.location.country(),
            faker.phone.number(),
            true,
          ]
        );
        addresses.push(res.rows[0].address_id);
      }
    }

    // ------------------------
    // 9. Products and Variants
    // ------------------------
    const products = [];
    const productVariants = [];
    for (let i = 0; i < 10; i++) {
      const res = await client.query(
        `INSERT INTO product (sku, name, description, brand_id, category_id, base_price, weight, dimensions_length, dimensions_width, dimensions_height, is_active, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,NOW(),NOW()) RETURNING product_id`,
        [
          faker.string.alphanumeric(8).toUpperCase(),
          faker.commerce.productName(),
          faker.commerce.productDescription(),
          faker.helpers.arrayElement(brands),
          faker.helpers.arrayElement(categories),
          faker.commerce.price({ min: 10, max: 500 }),
          faker.number.int({ min: 1, max: 20 }),
          faker.number.int({ min: 10, max: 100 }),
          faker.number.int({ min: 10, max: 100 }),
          faker.number.int({ min: 10, max: 100 }),
          true,
        ]
      );
      const product_id = res.rows[0].product_id;
      products.push(product_id);

      const variantCount = faker.number.int({ min: 1, max: 3 });
      for (let j = 0; j < variantCount; j++) {
        const resVar = await client.query(
          `INSERT INTO productvariant (product_id, sku_variant, variant_name, additional_price, stock_quantity, reserved_quantity, color, size, other_attributes)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING variant_id`,
          [
            product_id,
            `VAR-${faker.string.alphanumeric(5).toUpperCase()}`,
            faker.commerce.productMaterial(),
            faker.commerce.price({ min: 5, max: 50 }),
            faker.number.int({ min: 0, max: 100 }),
            faker.number.int({ min: 0, max: 20 }),
            faker.color.human(),
            faker.helpers.arrayElement(["S", "M", "L", "XL"]),
            JSON.stringify({
              warranty: faker.number.int({ min: 6, max: 24 }) + " months",
            }),
          ]
        );
        productVariants.push(resVar.rows[0].variant_id);
      }
    }

    // ------------------------
    // 10. Inventory
    // ------------------------
    for (const variant_id of productVariants) {
      for (const warehouse_id of warehouses) {
        await client.query(
          `INSERT INTO inventory (product_variant_id, warehouse_id, quantity_available, quantity_reserved, reorder_level, reorder_quantity, last_restock_date)
           VALUES ($1,$2,$3,$4,$5,$6,$7)`,
          [
            variant_id,
            warehouse_id,
            faker.number.int({ min: 0, max: 100 }),
            faker.number.int({ min: 0, max: 20 }),
            faker.number.int({ min: 5, max: 20 }),
            faker.number.int({ min: 10, max: 50 }),
            faker.date.past(),
          ]
        );
      }
    }

    // ------------------------
    // 11. ProductSupplier (junction)
    // ------------------------
    for (const product_id of products) {
      const supplier_id = faker.helpers.arrayElement(suppliers);
      await client.query(
        `INSERT INTO productsupplier (product_id, supplier_id, supplier_sku, cost_price, lead_time_days, minimum_order_quantity)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [
          product_id,
          supplier_id,
          faker.string.alphanumeric(6).toUpperCase(),
          faker.number.int({ min: 10, max: 100 }),
          faker.number.int({ min: 3, max: 20 }),
          faker.number.int({ min: 1, max: 50 }),
        ]
      );
    }

    // ------------------------
    // 12. CustomerCoupon (junction)
    // ------------------------
    for (const customer_id of customers) {
      const coupon_id = faker.helpers.arrayElement(coupons);
      await client.query(
        `INSERT INTO customercoupon (customer_id, coupon_id, used_date, order_id)
         VALUES ($1,$2,$3,$4)`,
        [customer_id, coupon_id, faker.date.past(), null]
      );
    }

    // ------------------------
    // 13. Orders, OrderItems, Payments
    // ------------------------
    const orders = [];
    for (const customer_id of customers) {
      const orderCount = faker.number.int({ min: 1, max: 3 });
      for (let i = 0; i < orderCount; i++) {
        const order_number = faker.string.alphanumeric(8).toUpperCase();
        const order_date = faker.date.recent({ days: 30 });
        const order_status = faker.helpers.arrayElement([
          "pending",
          "confirmed",
          "processing",
          "shipped",
          "delivered",
          "cancelled",
          "returned",
        ]);
        const payment_method_id = null; // Will generate payment later
        const shipping_address_id = faker.helpers.arrayElement(addresses);
        const billing_address_id = faker.helpers.arrayElement(addresses);
        const subtotal = faker.number.int({ min: 50, max: 500 });
        const tax_amount = Math.floor(subtotal * 0.1);
        const shipping_cost = faker.number.int({ min: 5, max: 20 });
        const discount_amount = faker.number.int({ min: 0, max: 50 });
        const total_amount =
          subtotal + tax_amount + shipping_cost - discount_amount;
        const notes = faker.lorem.sentence();

        const resOrder = await client.query(
          `INSERT INTO "order" (customer_id, order_number, order_date, status, payment_method_id, shipping_address_id, billing_address_id, subtotal, tax_amount, shipping_cost, discount_amount, total_amount, notes)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING order_id`,
          [
            customer_id,
            order_number,
            order_date,
            order_status,
            payment_method_id,
            shipping_address_id,
            billing_address_id,
            subtotal,
            tax_amount,
            shipping_cost,
            discount_amount,
            total_amount,
            notes,
          ]
        );
        const order_id = resOrder.rows[0].order_id;
        orders.push(order_id);

        // Generate 1-3 order items
        const itemsCount = faker.number.int({ min: 1, max: 3 });
        for (let j = 0; j < itemsCount; j++) {
          const product_variant_id =
            faker.helpers.arrayElement(productVariants);
          const quantity = faker.number.int({ min: 1, max: 5 });
          const unit_price = faker.number.int({ min: 10, max: 200 });
          const discount_amount_item = faker.number.int({ min: 0, max: 20 });
          const tax_amount_item = Math.floor(unit_price * 0.1);
          const total_price =
            unit_price * quantity + tax_amount_item - discount_amount_item;
          const warranty_id = faker.helpers.arrayElement([...warranties, null]);

          await client.query(
            `INSERT INTO orderitem (order_id, product_variant_id, quantity, unit_price, discount_amount, tax_amount, total_price, warranty_id)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
            [
              order_id,
              product_variant_id,
              quantity,
              unit_price,
              discount_amount_item,
              tax_amount_item,
              total_price,
              warranty_id,
            ]
          );
        }

        // Generate Payment
        const payment_method = faker.helpers.arrayElement([
          "credit_card",
          "paypal",
          "bank_transfer",
          "invoice",
        ]);
        const transaction_id = faker.string.alphanumeric(10).toUpperCase();
        const amount = total_amount;
        const currency = "USD";
        const payment_status = faker.helpers.arrayElement([
          "pending",
          "completed",
          "failed",
          "refunded",
        ]);
        const payment_date = order_date;
        const gateway_response = JSON.stringify({ success: true });

        await client.query(
          `INSERT INTO payment (order_id, payment_method, transaction_id, amount, currency, status, payment_date, gateway_response)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [
            order_id,
            payment_method,
            transaction_id,
            amount,
            currency,
            payment_status,
            payment_date,
            gateway_response,
          ]
        );
      }
    }

    // ------------------------
    // 14. Reviews
    // ------------------------
    for (let i = 0; i < 20; i++) {
      const product_id = faker.helpers.arrayElement(products);
      const customer_id = faker.helpers.arrayElement(customers);
      const rating = faker.number.int({ min: 1, max: 5 });
      const title = faker.lorem.sentence();
      const comment = faker.lorem.paragraph();
      const is_verified_purchase = faker.datatype.boolean();
      const helpful_count = faker.number.int({ min: 0, max: 50 });

      await client.query(
        `INSERT INTO review (product_id, customer_id, order_item_id, rating, title, comment, is_verified_purchase, helpful_count, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW(),NOW())`,
        [
          product_id,
          customer_id,
          null,
          rating,
          title,
          comment,
          is_verified_purchase,
          helpful_count,
        ]
      );
    }

    // ------------------------
    // 15. CartItem
    // ------------------------
    for (const customer_id of customers) {
      const variant_id = faker.helpers.arrayElement(productVariants);
      await client.query(
        `INSERT INTO cartitem (customer_id, product_variant_id, quantity, added_date)
         VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING`,
        [
          customer_id,
          variant_id,
          faker.number.int({ min: 1, max: 5 }),
          faker.date.recent(),
        ]
      );
    }

    // ------------------------
    // 16. Wishlist
    // ------------------------
    for (const customer_id of customers) {
      const product_id = faker.helpers.arrayElement(products);
      await client.query(
        `INSERT INTO wishlist (customer_id, product_id, added_date)
         VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
        [customer_id, product_id, faker.date.recent()]
      );
    }

    // ------------------------
    // 17. ProductRelated
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

    console.log("All mock data generated successfully!");
  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}

generateMockData();
