CREATE PROCEDURE chub_food.add_product(
    p_restaurant_id uuid,
    p_product_category_id uuid,
    p_name varchar,
    p_price numeric,
    p_rating numeric,
    p_status chub_food.product_status,
    p_description text,
    p_photo_url text DEFAULT NULL
)
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM chub_food.restaurant WHERE restaurant_id = p_restaurant_id) THEN
        RAISE EXCEPTION 'Restaurant % does not exist', p_restaurant_id USING ERRCODE = '23503';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM chub_food.product_category WHERE product_category_id = p_product_category_id) THEN
        RAISE EXCEPTION 'Product category % does not exist', p_product_category_id USING ERRCODE = '23503';
    END IF;
    IF p_price IS NULL OR p_price < 0 OR p_price = 'NaN'::numeric THEN
        RAISE EXCEPTION 'Product price must be a nonnegative number' USING ERRCODE = '23514';
    END IF;
    IF p_rating IS NOT NULL AND NOT (p_rating BETWEEN 0 AND 5) THEN
        RAISE EXCEPTION 'Product rating must be between 0 and 5' USING ERRCODE = '23514';
    END IF;

    INSERT INTO chub_food.product (
        restaurant_id, product_category_id, product_name, price, rating, status, description, photo_url
    ) VALUES (
        p_restaurant_id, p_product_category_id, p_name, p_price, NULL, p_status, p_description, p_photo_url
    );
END;
$$;

CREATE FUNCTION chub_food.get_statistic()
RETURNS TABLE (
    restaurant_name varchar,
    best_product_name varchar,
    total_amount numeric,
    avg_amount numeric,
    best_user varchar
)
LANGUAGE sql VOLATILE SET search_path = pg_catalog, chub_food AS $$
    WITH delivered AS MATERIALIZED (
        SELECT o.order_id, o.restaurant_id, o.client_id, o.total_amount
        FROM chub_food."order" o WHERE o.status = 'доставлен'
    ), totals AS (
        SELECT d.restaurant_id, sum(d.total_amount) AS total_amount, avg(d.total_amount) AS avg_amount
        FROM delivered d GROUP BY d.restaurant_id
    ), product_sales AS (
        SELECT d.restaurant_id, os.product_id, sum(os.quantity) AS quantity
        FROM delivered d
        JOIN chub_food.order_structure os USING (order_id)
        GROUP BY d.restaurant_id, os.product_id
    ), best_products AS (
        SELECT DISTINCT ON (s.restaurant_id) s.restaurant_id, s.product_id
        FROM product_sales s ORDER BY s.restaurant_id, s.quantity DESC, random()
    ), client_orders AS (
        SELECT d.restaurant_id, d.client_id, count(*) AS order_count
        FROM delivered d GROUP BY d.restaurant_id, d.client_id
    ), best_clients AS (
        SELECT DISTINCT ON (c.restaurant_id) c.restaurant_id, c.client_id
        FROM client_orders c ORDER BY c.restaurant_id, c.order_count DESC, random()
    )
    SELECT r.restaurant_name, p.product_name,
           coalesce(t.total_amount, 0::numeric), coalesce(t.avg_amount, 0::numeric), c.login
    FROM chub_food.restaurant r
    LEFT JOIN totals t USING (restaurant_id)
    LEFT JOIN best_products bp USING (restaurant_id)
    LEFT JOIN chub_food.product p ON p.product_id = bp.product_id
    LEFT JOIN best_clients bc ON bc.restaurant_id = r.restaurant_id
    LEFT JOIN chub_food.client c ON c.client_id = bc.client_id;
$$;

CREATE PROCEDURE chub_food.courier_salary()
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
DECLARE
    v_month date := date_trunc('month', current_date)::date;
BEGIN
    PERFORM courier_id FROM chub_food.courier ORDER BY courier_id FOR UPDATE;

    WITH deliveries AS (
        SELECT o.courier_id, count(*) AS delivery_count, sum(o.commission) AS commission
        FROM chub_food."order" o
        WHERE o.status = 'доставлен'
          AND o.order_timestamp >= v_month
          AND o.order_timestamp < v_month + interval '1 month'
        GROUP BY o.courier_id
    ), salary AS (
        SELECT c.courier_id, coalesce(d.delivery_count, 0) AS delivery_count,
               coalesce(d.commission, 0) AS commission,
               coalesce(cp.coefficient_used, c.coefficient) AS coefficient_used
        FROM chub_food.courier c
        LEFT JOIN deliveries d USING (courier_id)
        LEFT JOIN chub_food.courier_pay cp ON cp.courier_id = c.courier_id
            AND cp.year = extract(year FROM v_month)::integer
            AND cp.month = extract(month FROM v_month)::integer
    ), paid AS (
        INSERT INTO chub_food.courier_pay (year, month, courier_id, amount, coefficient_used)
        SELECT extract(year FROM v_month)::integer, extract(month FROM v_month)::integer,
               s.courier_id, round(s.commission * s.coefficient_used, 2), s.coefficient_used
        FROM salary s
        ON CONFLICT (year, month, courier_id) DO UPDATE
            SET amount = EXCLUDED.amount
        RETURNING courier_id
    )
    UPDATE chub_food.courier c
    SET coefficient = CASE
        WHEN s.delivery_count <= 150 THEN 0.1
        WHEN s.delivery_count <= 250 THEN 0.2
        WHEN s.delivery_count <= 500 THEN 0.3
        ELSE 0.5
    END
    FROM salary s JOIN paid p USING (courier_id)
    WHERE c.courier_id = s.courier_id AND c.status <> 'уволен';
END;
$$;

CREATE VIEW chub_food.how_much_money AS
WITH RECURSIVE monthly_orders AS MATERIALIZED (
    SELECT date_trunc('month', o.order_timestamp)::date AS month_start,
           sum(o.order_amount) AS sum_no_commission,
           sum(o.total_amount) AS sum_with_commission
    FROM chub_food."order" o WHERE o.status = 'доставлен'
    GROUP BY date_trunc('month', o.order_timestamp)::date
), bounds AS (
    SELECT min(month_start) AS first_month, max(month_start) AS last_month FROM monthly_orders
), months (month_start, last_month) AS (
    SELECT first_month, last_month FROM bounds WHERE first_month IS NOT NULL
    UNION ALL
    SELECT (month_start + interval '1 month')::date, last_month
    FROM months WHERE month_start < last_month
), salaries AS (
    SELECT make_date(cp.year, cp.month, 1) AS month_start, sum(cp.amount) AS amount
    FROM chub_food.courier_pay cp GROUP BY cp.year, cp.month
), monthly AS (
    SELECT m.month_start, coalesce(o.sum_no_commission, 0::numeric) AS sum_no_commission,
           coalesce(o.sum_with_commission, 0::numeric) AS sum_with_commission,
           coalesce(o.sum_with_commission - o.sum_no_commission, 0::numeric) AS commission,
           coalesce(s.amount, 0::numeric) AS courier_pay
    FROM months m
    LEFT JOIN monthly_orders o USING (month_start)
    LEFT JOIN salaries s USING (month_start)
), previous AS (
    SELECT monthly.*, lag(commission) OVER (ORDER BY month_start) AS prev_commission FROM monthly
)
SELECT to_char(month_start, 'YYYY-MM') AS year_month,
       sum_no_commission, sum_with_commission, commission, prev_commission,
       commission - prev_commission AS commission_diff,
       courier_pay, commission - courier_pay AS net_profit
FROM previous;

CREATE PROCEDURE chub_food.erase_test_data()
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
BEGIN
    TRUNCATE TABLE chub_food.review, chub_food.payment, chub_food.order_structure,
        chub_food."order", chub_food.courier_pay, chub_food.product,
        chub_food.client_address, chub_food.restaurant, chub_food.product_category,
        chub_food.courier, chub_food.client, chub_food.address;
END;
$$;
