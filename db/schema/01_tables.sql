CREATE TABLE chub_food.client (
    client_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    login varchar(64) NOT NULL,
    password varchar(32) NOT NULL,
    phone_number varchar(16) NOT NULL,
    CONSTRAINT client_login_unique UNIQUE (login),
    CONSTRAINT client_phone_unique UNIQUE (phone_number),
    CONSTRAINT client_login_present CHECK (btrim(login) <> ''),
    CONSTRAINT client_password_md5 CHECK (password ~ '^[0-9a-f]{32}$'),
    CONSTRAINT client_phone_present CHECK (btrim(phone_number) <> '')
);

CREATE TABLE chub_food.address (
    address_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    street varchar(160) NOT NULL,
    house_number varchar(20) NOT NULL,
    apartment_office varchar(20),
    CONSTRAINT address_location_unique UNIQUE NULLS NOT DISTINCT (street, house_number, apartment_office),
    CONSTRAINT address_street_present CHECK (btrim(street) <> ''),
    CONSTRAINT address_house_present CHECK (btrim(house_number) <> ''),
    CONSTRAINT address_apartment_present CHECK (btrim(apartment_office) <> '')
);

CREATE TABLE chub_food.client_address (
    client_id uuid NOT NULL REFERENCES chub_food.client (client_id),
    address_id uuid NOT NULL REFERENCES chub_food.address (address_id),
    PRIMARY KEY (client_id, address_id)
);

CREATE TABLE chub_food.restaurant (
    restaurant_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    restaurant_name varchar(160) NOT NULL,
    address_id uuid NOT NULL REFERENCES chub_food.address (address_id),
    description text NOT NULL,
    work_start time NOT NULL,
    work_end time NOT NULL,
    company_details text NOT NULL,
    rating numeric(3,2),
    status chub_food.restaurant_status NOT NULL DEFAULT 'активен',
    CONSTRAINT restaurant_address_unique UNIQUE (address_id),
    CONSTRAINT restaurant_name_present CHECK (btrim(restaurant_name) <> ''),
    CONSTRAINT restaurant_description_present CHECK (btrim(description) <> ''),
    CONSTRAINT restaurant_details_present CHECK (btrim(company_details) <> ''),
    CONSTRAINT restaurant_work_hours CHECK (work_end > work_start),
    CONSTRAINT restaurant_rating_range CHECK (rating BETWEEN 0 AND 5)
);

CREATE TABLE chub_food.courier (
    courier_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    fio varchar(160) NOT NULL,
    phone_number varchar(16) NOT NULL,
    status chub_food.courier_status NOT NULL DEFAULT 'свободен',
    hire_date date NOT NULL,
    dismissal_date date,
    coefficient numeric(3,2) NOT NULL DEFAULT 0.1,
    CONSTRAINT courier_name_present CHECK (btrim(fio) <> ''),
    CONSTRAINT courier_phone_present CHECK (btrim(phone_number) <> ''),
    CONSTRAINT courier_dismissal_required CHECK (status <> 'уволен' OR dismissal_date IS NOT NULL),
    CONSTRAINT courier_dates_ordered CHECK (dismissal_date >= hire_date),
    CONSTRAINT courier_coefficient_range CHECK (coefficient BETWEEN 0.1 AND 0.5)
);

CREATE TABLE chub_food.courier_pay (
    year integer NOT NULL,
    month integer NOT NULL,
    courier_id uuid NOT NULL REFERENCES chub_food.courier (courier_id),
    amount numeric(16,2) NOT NULL,
    coefficient_used numeric(3,2) NOT NULL,
    PRIMARY KEY (year, month, courier_id),
    CONSTRAINT courier_pay_year_range CHECK (year BETWEEN 1 AND 9999),
    CONSTRAINT courier_pay_month_range CHECK (month BETWEEN 1 AND 12),
    CONSTRAINT courier_pay_amount_nonnegative CHECK (amount >= 0 AND amount <> 'NaN'::numeric),
    CONSTRAINT courier_pay_coefficient_range CHECK (coefficient_used BETWEEN 0.1 AND 0.5)
);

CREATE TABLE chub_food.product_category (
    product_category_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_category_name varchar(100) NOT NULL,
    CONSTRAINT product_category_name_present CHECK (btrim(product_category_name) <> '')
);

CREATE TABLE chub_food.product (
    product_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    product_name varchar(160) NOT NULL,
    product_category_id uuid NOT NULL REFERENCES chub_food.product_category (product_category_id),
    price numeric(12,2) NOT NULL,
    restaurant_id uuid NOT NULL REFERENCES chub_food.restaurant (restaurant_id),
    photo_url text,
    rating numeric(3,2),
    status chub_food.product_status NOT NULL DEFAULT 'доступно',
    description text NOT NULL,
    CONSTRAINT product_name_present CHECK (btrim(product_name) <> ''),
    CONSTRAINT product_price_nonnegative CHECK (price >= 0 AND price <> 'NaN'::numeric),
    CONSTRAINT product_photo_url CHECK (photo_url ~ '^https?://[^[:space:]]+$'),
    CONSTRAINT product_rating_range CHECK (rating BETWEEN 0 AND 5),
    CONSTRAINT product_description_present CHECK (btrim(description) <> '')
);

CREATE TABLE chub_food."order" (
    order_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    courier_id uuid NOT NULL REFERENCES chub_food.courier (courier_id),
    client_id uuid NOT NULL REFERENCES chub_food.client (client_id),
    address_id uuid NOT NULL REFERENCES chub_food.address (address_id),
    restaurant_id uuid NOT NULL REFERENCES chub_food.restaurant (restaurant_id),
    order_timestamp timestamp NOT NULL DEFAULT localtimestamp,
    delivery_timestamp timestamp,
    order_amount numeric(14,2) NOT NULL,
    commission numeric(14,2) GENERATED ALWAYS AS (round(order_amount * 0.1, 2)) STORED NOT NULL,
    total_amount numeric(14,2) GENERATED ALWAYS AS (order_amount + round(order_amount * 0.1, 2)) STORED NOT NULL,
    status chub_food.order_status NOT NULL DEFAULT 'создан',
    pay_status chub_food.order_pay_status NOT NULL DEFAULT 'ожидает',
    description text NOT NULL,
    CONSTRAINT order_client_address_fk FOREIGN KEY (client_id, address_id)
        REFERENCES chub_food.client_address (client_id, address_id),
    CONSTRAINT order_amount_nonnegative CHECK (order_amount >= 0 AND order_amount <> 'NaN'::numeric),
    CONSTRAINT order_total_minimum CHECK (total_amount >= 1000),
    CONSTRAINT order_delivery_required CHECK (status <> 'доставлен' OR delivery_timestamp IS NOT NULL),
    CONSTRAINT order_delivery_ordered CHECK (delivery_timestamp >= order_timestamp),
    CONSTRAINT order_description_present CHECK (btrim(description) <> '')
);

CREATE TABLE chub_food.order_structure (
    order_id uuid NOT NULL REFERENCES chub_food."order" (order_id),
    product_id uuid NOT NULL REFERENCES chub_food.product (product_id),
    quantity numeric(12,3) NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT order_structure_quantity_positive CHECK (quantity > 0 AND quantity <> 'NaN'::numeric),
    CONSTRAINT order_structure_price_nonnegative CHECK (unit_price >= 0 AND unit_price <> 'NaN'::numeric)
);

CREATE TABLE chub_food.payment (
    payment_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    order_id uuid NOT NULL REFERENCES chub_food."order" (order_id),
    payment_type chub_food.payment_type NOT NULL,
    amount numeric(14,2) NOT NULL,
    transaction_reference varchar(100) NOT NULL,
    transaction_timestamp timestamp NOT NULL DEFAULT localtimestamp,
    status chub_food.payment_status NOT NULL,
    CONSTRAINT payment_transaction_unique UNIQUE (transaction_reference),
    CONSTRAINT payment_transaction_present CHECK (btrim(transaction_reference) <> ''),
    CONSTRAINT payment_amount_nonnegative CHECK (amount >= 0 AND amount <> 'NaN'::numeric)
);

CREATE UNIQUE INDEX payment_one_success ON chub_food.payment (order_id) WHERE status = 'успех';

CREATE TABLE chub_food.review (
    review_id uuid PRIMARY KEY DEFAULT exts.uuid_generate_v4(),
    client_id uuid NOT NULL REFERENCES chub_food.client (client_id),
    review_timestamp timestamp NOT NULL DEFAULT localtimestamp,
    entity_id uuid NOT NULL,
    entity_type chub_food.review_entity_type NOT NULL,
    order_id uuid NOT NULL REFERENCES chub_food."order" (order_id),
    description text NOT NULL,
    photo_url text,
    rating numeric(3,2) NOT NULL,
    CONSTRAINT review_target_unique UNIQUE (order_id, entity_type, entity_id),
    CONSTRAINT review_description_present CHECK (btrim(description) <> ''),
    CONSTRAINT review_photo_url CHECK (photo_url ~ '^https?://[^[:space:]]+$'),
    CONSTRAINT review_rating_range CHECK (rating BETWEEN 1 AND 5)
);

CREATE INDEX product_restaurant_idx ON chub_food.product (restaurant_id);
CREATE INDEX order_client_address_idx ON chub_food."order" (client_id, address_id);
CREATE INDEX order_restaurant_idx ON chub_food."order" (restaurant_id);
CREATE INDEX order_courier_month_idx ON chub_food."order" (courier_id, order_timestamp) WHERE status = 'доставлен';
CREATE INDEX order_structure_product_idx ON chub_food.order_structure (product_id);
CREATE INDEX payment_order_idx ON chub_food.payment (order_id);
CREATE INDEX review_entity_idx ON chub_food.review (entity_type, entity_id);
