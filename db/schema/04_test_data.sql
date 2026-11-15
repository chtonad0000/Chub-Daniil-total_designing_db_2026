CREATE PROCEDURE chub_food.insert_test_data(value integer)
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
DECLARE
    v_client uuid;
    v_courier uuid;
    v_category uuid;
    v_restaurant uuid;
    v_order uuid;
    v_address uuid;
    v_product uuid;
    v_addresses uuid[];
    v_products uuid[];
    v_prices numeric[];
    v_couriers uuid[] := ARRAY[]::uuid[];
    v_courier_status chub_food.courier_status;
    v_order_status chub_food.order_status;
    v_entity_type chub_food.review_entity_type;
    v_entity_id uuid;
    v_first_month date := (date_trunc('month', current_date) - interval '5 months')::date;
    v_month timestamp;
    v_end timestamp;
    v_created timestamp;
    v_delivered timestamp;
    v_amount numeric;
    v_next integer;
    v_phone varchar(16);
    v_names text[] := ARRAY['Борщ', 'Плов', 'Паста', 'Салат', 'Пирог'];
BEGIN
    IF value IS NULL OR value <= 0 THEN
        RAISE EXCEPTION 'value must be a positive integer' USING ERRCODE = '22023';
    END IF;

    FOR i IN 1..value LOOP
        v_client := exts.uuid_generate_v4();
        v_courier := exts.uuid_generate_v4();
        v_category := exts.uuid_generate_v4();
        v_restaurant := exts.uuid_generate_v4();
        v_couriers := array_append(v_couriers, v_courier);
        v_addresses := ARRAY[]::uuid[];
        v_products := ARRAY[]::uuid[];
        v_prices := ARRAY[]::numeric[];

        LOOP
            v_phone := '+7' || lpad(nextval('chub_food.test_phone_sequence')::text, 10, '0');
            EXIT WHEN NOT EXISTS (SELECT 1 FROM chub_food.client WHERE phone_number = v_phone);
        END LOOP;
        INSERT INTO chub_food.client (client_id, login, password, phone_number)
        VALUES (v_client, 'client_' || replace(v_client::text, '-', ''), md5(random()::text), v_phone);

        v_courier_status := (enum_range(NULL::chub_food.courier_status))[
            CASE WHEN i = 1 THEN 1 ELSE 1 + floor(random() * 4)::integer END
        ];
        INSERT INTO chub_food.courier (courier_id, fio, phone_number, status, hire_date, dismissal_date)
        VALUES (v_courier, 'Иван Петров ' || i,
                '+7' || lpad(nextval('chub_food.test_phone_sequence')::text, 10, '0'),
                v_courier_status, v_first_month,
                CASE WHEN v_courier_status = 'уволен' THEN current_date END);

        INSERT INTO chub_food.product_category (product_category_id, product_category_name)
        VALUES (v_category, 'Категория ' || i);

        FOR j IN 1..5 LOOP
            v_address := exts.uuid_generate_v4();
            v_addresses := array_append(v_addresses, v_address);
            INSERT INTO chub_food.address (address_id, street, house_number, apartment_office)
            VALUES (v_address, 'Учебная улица ' || replace(v_address::text, '-', ''),
                    (1 + floor(random() * 150)::integer)::text,
                    CASE WHEN j > 1 AND random() > 0.25 THEN (1 + floor(random() * 100)::integer)::text END);
            IF j > 1 THEN
                INSERT INTO chub_food.client_address (client_id, address_id) VALUES (v_client, v_address);
            END IF;
        END LOOP;

        INSERT INTO chub_food.restaurant (
            restaurant_id, restaurant_name, address_id, description, work_start, work_end, company_details, status
        ) VALUES (
            v_restaurant, 'Кухня ' || i || ' ' || left(v_restaurant::text, 8), v_addresses[1],
            'Учебный ресторан доставки еды', '09:00', '23:00',
            'Тестовые реквизиты ' || v_restaurant::text,
            (enum_range(NULL::chub_food.restaurant_status))[1 + floor(random() * 2)::integer]
        );

        FOR j IN 1..5 LOOP
            v_product := exts.uuid_generate_v4();
            v_products := array_append(v_products, v_product);
            v_prices := array_append(v_prices, round((500 + random() * 1000)::numeric, 2));
            INSERT INTO chub_food.product (
                product_id, product_name, product_category_id, price, restaurant_id, photo_url, status, description
            ) VALUES (
                v_product, v_names[j], v_category, v_prices[j], v_restaurant,
                CASE WHEN j % 2 = 0 THEN 'https://example.com/food/' || v_product::text || '.jpg' END,
                (enum_range(NULL::chub_food.product_status))[1 + floor(random() * 3)::integer],
                'Описание блюда ' || v_names[j]
            );
        END LOOP;

        FOR j IN 1..5 LOOP
            v_order := exts.uuid_generate_v4();
            v_next := j % 5 + 1;
            v_month := v_first_month + (((i::bigint - 1) * 5 + j - 1) % 6)::integer * interval '1 month';
            v_end := least(v_month + interval '1 month', localtimestamp);
            v_created := v_month + (v_end - v_month) * (random() * 0.8);
            v_order_status := (enum_range(NULL::chub_food.order_status))[
                CASE WHEN j IN (1, 5) THEN 4 ELSE 1 + floor(random() * 5)::integer END
            ];
            v_delivered := CASE WHEN v_order_status = 'доставлен'
                THEN v_created + (v_end - v_created) * (0.1 + random() * 0.8) END;
            v_amount := round(v_prices[j] * 2 + v_prices[v_next] * 0.5, 2);

            INSERT INTO chub_food."order" (
                order_id, courier_id, client_id, address_id, restaurant_id, order_timestamp,
                delivery_timestamp, order_amount, status, description
            ) VALUES (
                v_order, v_courier, v_client, v_addresses[2 + (j - 1) % 4], v_restaurant,
                v_created, v_delivered, v_amount, v_order_status, 'Учебный заказ ' || j
            );

            INSERT INTO chub_food.order_structure (order_id, product_id, quantity, unit_price)
            VALUES (v_order, v_products[j], 2, v_prices[j]), (v_order, v_products[v_next], 0.5, v_prices[v_next]);

            INSERT INTO chub_food.payment (
                order_id, payment_type, amount, transaction_reference, transaction_timestamp, status
            ) VALUES (
                v_order, (enum_range(NULL::chub_food.payment_type))[1 + floor(random() * 3)::integer],
                v_amount + round(v_amount * 0.1, 2), 'demo-' || exts.uuid_generate_v4()::text,
                v_created, (enum_range(NULL::chub_food.payment_status))[1]
            );

            v_entity_type := (enum_range(NULL::chub_food.review_entity_type))[1 + (i + j) % 3];
            v_entity_id := CASE v_entity_type
                WHEN 'блюдо' THEN v_products[j]
                WHEN 'ресторан' THEN v_restaurant
                ELSE v_order
            END;
            INSERT INTO chub_food.review (
                client_id, review_timestamp, entity_id, entity_type, order_id, description, photo_url, rating
            ) VALUES (
                v_client, coalesce(v_delivered, v_created), v_entity_id, v_entity_type, v_order,
                'Отзыв о заказе ' || j,
                CASE WHEN j % 2 = 0 THEN 'https://example.com/review/' || v_order::text || '.jpg' END,
                1 + floor(random() * 5)::integer
            );
        END LOOP;
    END LOOP;

    FOR m IN 0..5 LOOP
        v_month := v_first_month + m * interval '1 month';
        WITH deliveries AS (
            SELECT o.courier_id, count(*) AS delivery_count, sum(o.commission) AS commission
            FROM chub_food."order" o
            WHERE o.courier_id = ANY(v_couriers) AND o.status = 'доставлен'
              AND o.order_timestamp >= v_month AND o.order_timestamp < v_month + interval '1 month'
            GROUP BY o.courier_id
        ), monthly AS (
            SELECT c.courier_id, c.coefficient,
                   coalesce(d.delivery_count, 0) AS delivery_count, coalesce(d.commission, 0) AS commission
            FROM chub_food.courier c LEFT JOIN deliveries d USING (courier_id)
            WHERE c.courier_id = ANY(v_couriers)
        ), paid AS (
            INSERT INTO chub_food.courier_pay (year, month, courier_id, amount, coefficient_used)
            SELECT extract(year FROM v_month)::integer, extract(month FROM v_month)::integer,
                   courier_id, round(coefficient * commission, 2), coefficient
            FROM monthly RETURNING courier_id
        )
        UPDATE chub_food.courier c
        SET coefficient = CASE
            WHEN s.delivery_count <= 150 THEN 0.1
            WHEN s.delivery_count <= 250 THEN 0.2
            WHEN s.delivery_count <= 500 THEN 0.3
            ELSE 0.5
        END
        FROM monthly s JOIN paid p USING (courier_id)
        WHERE c.courier_id = s.courier_id
          AND (c.dismissal_date IS NULL OR c.dismissal_date >= (v_month + interval '1 month')::date);
    END LOOP;
END;
$$;
