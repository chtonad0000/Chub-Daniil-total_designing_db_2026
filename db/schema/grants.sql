DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'inspector') THEN
        CREATE ROLE inspector LOGIN PASSWORD 'NetoSQL2025';
    ELSE
        ALTER ROLE inspector LOGIN PASSWORD 'NetoSQL2025';
    END IF;
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO inspector', current_database());
    EXECUTE format('ALTER ROLE inspector IN DATABASE %I SET search_path TO chub_food, exts, public', current_database());
END;
$$;

GRANT ALL PRIVILEGES ON SCHEMA chub_food TO inspector;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA chub_food TO inspector;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA chub_food TO inspector;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA chub_food TO inspector;
GRANT USAGE ON SCHEMA exts, information_schema, pg_catalog TO inspector;
GRANT EXECUTE ON FUNCTION exts.uuid_generate_v4() TO inspector;
GRANT USAGE ON TYPE chub_food.restaurant_status, chub_food.product_status,
    chub_food.courier_status, chub_food.order_status, chub_food.order_pay_status,
    chub_food.payment_status, chub_food.payment_type, chub_food.review_entity_type TO inspector;

ALTER DEFAULT PRIVILEGES IN SCHEMA chub_food GRANT ALL PRIVILEGES ON TABLES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA chub_food GRANT ALL PRIVILEGES ON SEQUENCES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA chub_food GRANT ALL PRIVILEGES ON ROUTINES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA chub_food GRANT USAGE ON TYPES TO inspector;
