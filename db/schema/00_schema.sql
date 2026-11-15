DO $$
BEGIN
    IF to_regprocedure('exts.uuid_generate_v4()') IS NULL THEN
        RAISE EXCEPTION 'Required extension uuid-ossp is missing from schema exts';
    END IF;
END;
$$;

CREATE SCHEMA chub_food;

CREATE TYPE chub_food.restaurant_status AS ENUM ('активен', 'неактивен');
CREATE TYPE chub_food.product_status AS ENUM ('доступно', 'нет_в_наличии', 'архив');
CREATE TYPE chub_food.courier_status AS ENUM ('свободен', 'занят', 'на_доставке', 'уволен');
CREATE TYPE chub_food.order_status AS ENUM ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменён');
CREATE TYPE chub_food.order_pay_status AS ENUM ('ожидает', 'оплачен', 'ошибка');
CREATE TYPE chub_food.payment_status AS ENUM ('успех', 'ошибка', 'в_обработке');
CREATE TYPE chub_food.payment_type AS ENUM ('карта', 'наличные', 'безнал');
CREATE TYPE chub_food.review_entity_type AS ENUM ('блюдо', 'ресторан', 'заказ');

CREATE SEQUENCE chub_food.test_phone_sequence
    AS bigint MINVALUE 0 MAXVALUE 9999999999 START WITH 0 NO CYCLE;
