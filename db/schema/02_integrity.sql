CREATE FUNCTION chub_food.lock_order_rows() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
BEGIN
    PERFORM o.order_id
    FROM chub_food."order" o
    WHERE o.order_id IN (
        CASE WHEN TG_OP <> 'INSERT' THEN OLD.order_id END,
        CASE WHEN TG_OP <> 'DELETE' THEN NEW.order_id END
    )
    ORDER BY o.order_id
    FOR NO KEY UPDATE;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER lock_order_rows BEFORE INSERT OR UPDATE OR DELETE ON chub_food.order_structure
FOR EACH ROW EXECUTE FUNCTION chub_food.lock_order_rows();
CREATE TRIGGER lock_order_rows BEFORE INSERT OR UPDATE OR DELETE ON chub_food.payment
FOR EACH ROW EXECUTE FUNCTION chub_food.lock_order_rows();
CREATE TRIGGER lock_order_rows BEFORE INSERT OR UPDATE OR DELETE ON chub_food.review
FOR EACH ROW EXECUTE FUNCTION chub_food.lock_order_rows();

CREATE FUNCTION chub_food.capture_unit_price() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
DECLARE
    v_price numeric;
BEGIN
    SELECT price INTO v_price FROM chub_food.product
    WHERE product_id = NEW.product_id FOR SHARE;
    IF NEW.unit_price IS NULL THEN
        NEW.unit_price := v_price;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER capture_unit_price BEFORE INSERT OR UPDATE ON chub_food.order_structure
FOR EACH ROW EXECUTE FUNCTION chub_food.capture_unit_price();

CREATE FUNCTION chub_food.protect_product_restaurant() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
BEGIN
    IF NEW.restaurant_id IS DISTINCT FROM OLD.restaurant_id
       AND EXISTS (SELECT 1 FROM chub_food.order_structure WHERE product_id = OLD.product_id) THEN
        RAISE EXCEPTION 'An ordered product cannot be moved to another restaurant'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER protect_product_restaurant BEFORE UPDATE OF restaurant_id ON chub_food.product
FOR EACH ROW EXECUTE FUNCTION chub_food.protect_product_restaurant();

CREATE FUNCTION chub_food.derive_pay_status() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
BEGIN
    SELECT CASE
        WHEN coalesce(bool_or(p.status = 'успех'), false) THEN 'оплачен'
        WHEN coalesce(bool_and(p.status = 'ошибка'), false) THEN 'ошибка'
        ELSE 'ожидает'
    END::chub_food.order_pay_status
    INTO NEW.pay_status
    FROM chub_food.payment p WHERE p.order_id = NEW.order_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER derive_pay_status BEFORE INSERT OR UPDATE OF pay_status ON chub_food."order"
FOR EACH ROW EXECUTE FUNCTION chub_food.derive_pay_status();

CREATE FUNCTION chub_food.payment_change() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
BEGIN
    UPDATE chub_food."order" o SET pay_status = o.pay_status
    WHERE o.order_id IN (
        CASE WHEN TG_OP <> 'INSERT' THEN OLD.order_id END,
        CASE WHEN TG_OP <> 'DELETE' THEN NEW.order_id END
    );
    RETURN NULL;
END;
$$;

CREATE TRIGGER payment_change AFTER INSERT OR UPDATE OR DELETE ON chub_food.payment
FOR EACH ROW EXECUTE FUNCTION chub_food.payment_change();

CREATE FUNCTION chub_food.check_order_integrity() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
DECLARE
    v_order chub_food."order"%ROWTYPE;
    v_amount numeric;
    v_count bigint;
    v_mixed_restaurants boolean;
BEGIN
    FOR v_order IN
        SELECT o.* FROM chub_food."order" o
        WHERE o.order_id IN (
            CASE WHEN TG_OP <> 'INSERT' THEN OLD.order_id END,
            CASE WHEN TG_OP <> 'DELETE' THEN NEW.order_id END
        )
        ORDER BY o.order_id
        FOR NO KEY UPDATE
    LOOP
        SELECT count(*), round(sum(os.quantity * os.unit_price), 2),
               bool_or(p.restaurant_id <> v_order.restaurant_id)
        INTO v_count, v_amount, v_mixed_restaurants
        FROM chub_food.order_structure os
        JOIN chub_food.product p USING (product_id)
        WHERE os.order_id = v_order.order_id;

        IF v_count = 0 THEN
            RAISE EXCEPTION 'Order % must contain at least one product', v_order.order_id
                USING ERRCODE = '23514';
        END IF;
        IF v_mixed_restaurants THEN
            RAISE EXCEPTION 'All products in order % must belong to its restaurant', v_order.order_id
                USING ERRCODE = '23514';
        END IF;
        IF v_amount <> v_order.order_amount THEN
            RAISE EXCEPTION 'Order % amount must equal its line total (%)', v_order.order_id, v_amount
                USING ERRCODE = '23514';
        END IF;
        IF EXISTS (
            SELECT 1 FROM chub_food.payment p
            WHERE p.order_id = v_order.order_id AND p.amount <> v_order.total_amount
        ) THEN
            RAISE EXCEPTION 'Payment amount must equal the total of order %', v_order.order_id
                USING ERRCODE = '23514';
        END IF;
        IF v_order.status = 'доставлен' AND v_order.pay_status <> 'оплачен' THEN
            RAISE EXCEPTION 'Delivered order % must have one successful payment', v_order.order_id
                USING ERRCODE = '23514';
        END IF;
        IF EXISTS (
            SELECT 1 FROM chub_food.review r
            WHERE r.order_id = v_order.order_id AND (
                r.client_id <> v_order.client_id
                OR (r.entity_type = 'ресторан' AND r.entity_id <> v_order.restaurant_id)
                OR (r.entity_type = 'заказ' AND r.entity_id <> v_order.order_id)
                OR (r.entity_type = 'блюдо' AND NOT EXISTS (
                    SELECT 1 FROM chub_food.order_structure os
                    WHERE os.order_id = r.order_id AND os.product_id = r.entity_id
                ))
            )
        ) THEN
            RAISE EXCEPTION 'A review must refer to its author''s order and an object in that order'
                USING ERRCODE = '23514';
        END IF;
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER order_integrity
AFTER INSERT OR UPDATE ON chub_food."order"
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION chub_food.check_order_integrity();
CREATE CONSTRAINT TRIGGER order_structure_integrity
AFTER INSERT OR UPDATE OR DELETE ON chub_food.order_structure
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION chub_food.check_order_integrity();
CREATE CONSTRAINT TRIGGER payment_integrity
AFTER INSERT OR UPDATE OR DELETE ON chub_food.payment
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION chub_food.check_order_integrity();
CREATE CONSTRAINT TRIGGER review_integrity
AFTER INSERT OR UPDATE OR DELETE ON chub_food.review
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION chub_food.check_order_integrity();

CREATE FUNCTION chub_food.rating_change() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog, chub_food AS $$
DECLARE
    v_target record;
BEGIN
    FOR v_target IN
        SELECT OLD.entity_type AS entity_type, OLD.entity_id AS entity_id WHERE TG_OP <> 'INSERT'
        UNION
        SELECT NEW.entity_type, NEW.entity_id WHERE TG_OP <> 'DELETE'
        ORDER BY entity_type, entity_id
    LOOP
        IF v_target.entity_type = 'блюдо' THEN
            PERFORM 1 FROM chub_food.product WHERE product_id = v_target.entity_id FOR NO KEY UPDATE;
            UPDATE chub_food.product SET rating = (
                SELECT round(avg(r.rating), 2) FROM chub_food.review r
                WHERE r.entity_type = 'блюдо' AND r.entity_id = v_target.entity_id
            ) WHERE product_id = v_target.entity_id;
        ELSIF v_target.entity_type = 'ресторан' THEN
            PERFORM 1 FROM chub_food.restaurant WHERE restaurant_id = v_target.entity_id FOR NO KEY UPDATE;
            UPDATE chub_food.restaurant SET rating = (
                SELECT round(avg(r.rating), 2) FROM chub_food.review r
                WHERE r.entity_type = 'ресторан' AND r.entity_id = v_target.entity_id
            ) WHERE restaurant_id = v_target.entity_id;
        END IF;
    END LOOP;
    RETURN NULL;
END;
$$;

CREATE TRIGGER rating_change AFTER INSERT OR UPDATE OR DELETE ON chub_food.review
FOR EACH ROW EXECUTE FUNCTION chub_food.rating_change();
