# Ограничения

[Бизнес-правила](../docs/company-rules.md), [тикеты](../docs/backlog.md), [DDL](schema/01_tables.sql).

## Схема (FOOD-101)

12 таблиц в `chub_food`. UUID создаются через `exts.uuid_generate_v4()` — BR-11.1. Схема `exts` и расширение подготовлены заранее — BR-13.3. Имя таблицы `"order"` сохранено — BR-13.1.

| Данные | Тип | Причина |
|---|---|---|
| Цена / сумма заказа и оплаты / выплата | `numeric(12,2)` / `numeric(14,2)` / `numeric(16,2)` | Денежные суммы без потери точности |
| Количество | `numeric(12,3)` | Дробные порции, BR-7.15 |
| Рейтинг и коэффициент | `numeric(3,2)` | Диапазоны BR-4.2, BR-5.4, BR-6.4, BR-9.4 |
| Даты и время | `date`, `time`, `timestamp` без часового пояса | Время сервера, BR-11.2 |
| Логин / телефон / ФИО и названия / категория | `varchar(64)` / `varchar(16)` / `varchar(160)` / `varchar(100)` | Ограничения длины, BR-11.6 |
| Улица / дом и квартира | `varchar(160)` / `varchar(20)` | Допускаются буквы и дроби, BR-3.1, BR-11.6 |
| Описания, реквизиты, URL | `text` | Переменная длина, BR-11.6 |
| Номер транзакции | `varchar(100)` | Внешний номер провайдера, BR-8.3 |

## Enum

| Тип | Значения | BR |
|---|---|---|
| `restaurant_status` | `активен`, `неактивен` | BR-4.3 |
| `product_status` | `доступно`, `нет_в_наличии`, `архив` | BR-5.5 |
| `courier_status` | `свободен`, `занят`, `на_доставке`, `уволен` | BR-6.2 |
| `order_status` | `создан`, `готовится`, `в_доставке`, `доставлен`, `отменён` | BR-7.7 |
| `order_pay_status` | `ожидает`, `оплачен`, `ошибка` | BR-7.9 |
| `payment_status` | `успех`, `ошибка`, `в_обработке` | BR-8.2 |
| `payment_type` | `карта`, `наличные`, `безнал` | BR-8.2, BR-8.6 |
| `review_entity_type` | `блюдо`, `ресторан`, `заказ` | BR-9.1 |

Все 8 типов — PostgreSQL enum, BR-11.5.

## CHECK

`btrim(...) <> ''` запрещает пустые строки и строки из пробелов.

| Ограничение | Условие / причина | BR |
|---|---|---|
| `client_login_present`, `client_phone_present` | Непустые логин и телефон | BR-2.1, BR-11.3–11.4 |
| `client_password_md5` | 32 hex-символа MD5 | BR-2.3 |
| `address_street_present`, `address_house_present` | Непустые улица и дом | BR-3.1, BR-11.3 |
| `address_apartment_present` | Квартира непустая либо `NULL` | BR-3.2, BR-11.3 |
| `restaurant_name_present`, `restaurant_description_present`, `restaurant_details_present` | Непустые название, описание и реквизиты | BR-4.1, BR-4.5, BR-11.3 |
| `restaurant_work_hours` | `work_end > work_start`; без перехода через полночь | BR-4.4 |
| `restaurant_rating_range` | Рейтинг 0–5 | BR-4.2 |
| `courier_name_present`, `courier_phone_present` | Непустые ФИО и телефон | BR-6.1, BR-11.3 |
| `courier_dismissal_required` | При увольнении нужна дата | BR-6.3 |
| `courier_dates_ordered` | Увольнение не раньше найма | BR-6.1–6.3 |
| `courier_coefficient_range` | Коэффициент 0.1–0.5 | BR-6.4 |
| `courier_pay_year_range`, `courier_pay_month_range` | Год 1–9999, месяц 1–12; календарный месяц выплаты | BR-10.1–10.3 |
| `courier_pay_amount_nonnegative` | Выплата ≥ 0, без `NaN` | BR-10.4 |
| `courier_pay_coefficient_range` | Применённая ставка 0.1–0.5 | BR-6.4, BR-10.2 |
| `product_category_name_present` | Непустое название категории | BR-5.7, BR-11.3 |
| `product_name_present`, `product_description_present` | Непустые название и описание блюда | BR-5.2, BR-11.3 |
| `product_price_nonnegative` | Цена ≥ 0, без `NaN` | BR-5.3 |
| `product_photo_url`, `review_photo_url` | HTTP(S)-ссылка без пробелов либо `NULL` | BR-5.6, BR-9.3 |
| `product_rating_range` | Рейтинг 0–5 | BR-5.4 |
| `order_amount_nonnegative` | Стоимость блюд ≥ 0, без `NaN` | BR-5.3, BR-7.10 |
| `order_total_minimum` | `total_amount >= 1000` | BR-1.8, BR-7.11 |
| `order_delivery_required` | У доставленного заказа заполнено время доставки | BR-7.12 |
| `order_delivery_ordered` | Доставка не раньше создания | BR-7.13 |
| `order_description_present` | Непустое описание заказа | BR-11.3 |
| `order_structure_quantity_positive` | Количество > 0, без `NaN` | BR-7.15 |
| `order_structure_price_nonnegative` | Историческая цена ≥ 0, без `NaN` | BR-5.3, BR-7.10 |
| `payment_transaction_present` | Непустой номер попытки оплаты | BR-8.2–8.3, BR-11.3 |
| `payment_amount_nonnegative` | Сумма оплаты ≥ 0, без `NaN` | BR-8.4, BR-7.11 |
| `review_description_present` | Непустой текст отзыва | BR-9.3, BR-11.3 |
| `review_rating_range` | Оценка 1–5 | BR-9.4 |

## UNIQUE и PK

| Ключ / индекс | Причина | BR |
|---|---|---|
| UUID PK сущностей | Уникальный ID записи | BR-11.1 |
| `client_login_unique`, `client_phone_unique` | Логин и телефон клиента не повторяются | BR-2.2 |
| `address_location_unique` | Одна запись на `(street, house_number, apartment_office)`, включая `NULL` квартиры (`NULLS NOT DISTINCT`) | BR-3.3–3.4 |
| `client_address_pkey`: `(client_id, address_id)` | Без повторной привязки адреса | BR-2.5 |
| `restaurant_address_unique`: `address_id` | Один ресторан на адрес | BR-3.3 |
| `order_structure_pkey`: `(order_id, product_id)` | Блюдо не повторяется в заказе | BR-7.16 |
| `courier_pay_pkey`: `(year, month, courier_id)` | Одна выплата курьеру за месяц | BR-10.3 |
| `payment_transaction_unique`: `transaction_reference` | Номер транзакции не повторяется | BR-8.3 |
| `payment_one_success`: `order_id WHERE status = 'успех'` | Не более одной успешной оплаты | BR-8.1 |
| `review_target_unique`: `(order_id, entity_type, entity_id)` | Один отзыв на объект в заказе | BR-9.5 |

Адреса сравниваются по введённым строкам. Названия ресторанов, блюд и категорий могут повторяться.

## FK

Все FK — `NO ACTION`. Связанная история не удаляется каскадно. Удаление клиента или ресторана не удаляет адрес — BR-3.5.

| FK | Причина | BR |
|---|---|---|
| `client_address.client_id → client.client_id` | Владелец адреса | BR-2.4 |
| `client_address.address_id → address.address_id` | Адрес связи | BR-2.4, BR-3.4 |
| `restaurant.address_id → address.address_id` | Адрес ресторана | BR-3.3 |
| `courier_pay.courier_id → courier.courier_id` | Получатель выплаты | BR-10.2–10.3 |
| `product.restaurant_id → restaurant.restaurant_id` | Ресторан блюда | BR-5.1 |
| `product.product_category_id → product_category.product_category_id` | Категория блюда | BR-5.1 |
| `order.courier_id → courier.courier_id` | Курьер заказа | BR-7.5 |
| `order.client_id → client.client_id` | Клиент заказа | BR-7.1–7.2 |
| `order.address_id → address.address_id` | Адрес доставки | BR-7.4 |
| `order.restaurant_id → restaurant.restaurant_id` | Ресторан заказа | BR-7.2 |
| `order.(client_id, address_id) → client_address.(client_id, address_id)` | Адрес принадлежит клиенту | BR-7.4 |
| `order_structure.order_id → order.order_id` | Заказ позиции | BR-7.14 |
| `order_structure.product_id → product.product_id` | Блюдо позиции | BR-7.14 |
| `payment.order_id → order.order_id` | Заказ попытки оплаты | BR-8.1–8.2 |
| `review.client_id → client.client_id` | Автор отзыва | BR-9.2 |
| `review.order_id → order.order_id` | Заказ отзыва | BR-9.2 |

## Межтабличные проверки

`check_order_integrity()` проверяет конечное состояние при `COMMIT`. При переносе записи проверяются старый и новый заказы.

| Условие | Реализация | BR |
|---|---|---|
| Все блюда из ресторана заказа | Сравнение ресторанов; перенос заказанного блюда в другой ресторан запрещён | BR-7.3 |
| Заказ содержит позиции | Не менее одной к `COMMIT` | BR-7.14 |
| Сумма заказа соответствует позициям | `order_amount = round(sum(quantity * unit_price), 2)` | BR-7.10 |
| Сумма оплаты соответствует заказу | Каждая попытка равна `order.total_amount` | BR-8.4 |
| Доставленный заказ оплачен | Есть успешная попытка; вторую запрещает UNIQUE | BR-8.1 |
| Отзыв относится к покупке автора | Автор — клиент заказа; блюдо входит в состав, ресторан совпадает, объект-заказ равен `order_id` | BR-9.1–9.2 |

`review.entity_id` полиморфный: обычный FK в три таблицы невозможен. Объект проверяется триггером по `entity_type`, заказу и позициям.

В `payment` добавлены `payment_type`, `amount`, `transaction_reference`, `transaction_timestamp`, `status` — атрибуты попытки, BR-8.2. Тип оплаты хранится в `payment`, поскольку попытки могут иметь разные типы — BR-8.6.

Изменения зависимостей блокируют заказ. Пересчёт рейтинга блокирует объект, обрабатывает старый и новый объекты и не изменяет `review`.

## NULL и значения по умолчанию

Остальные атрибуты обязательны (`NOT NULL`) — BR-11.3.

| Допускается NULL | Причина | BR |
|---|---|---|
| `address.apartment_office` | Дом без квартиры | BR-3.2 |
| `product.photo_url`, `review.photo_url` | Фото необязательно | BR-5.6, BR-9.3 |
| `courier.dismissal_date` | Курьер работает | BR-6.3 |
| `order.delivery_timestamp` | Заказ ещё не доставлен | BR-7.12 |
| `product.rating`, `restaurant.rating` | Нет отзывов | BR-9.7 |

| Поле | Значение / причина | BR |
|---|---|---|
| Даты событий | `localtimestamp`, время создания записи | BR-11.2 |
| `courier.coefficient` | `0.1`, начальная ставка | BR-6.5 |
| Начальные статусы | Ресторан активен, блюдо доступно, курьер свободен, заказ создан, оплата ожидается | BR-4.3, BR-5.5, BR-6.2, BR-7.7, BR-7.9 |
| `order.pay_status` | Пересчёт по попыткам при INSERT/UPDATE/DELETE | BR-8.7 |
| `order.commission` | GENERATED: `round(order_amount * 0.1, 2)` | BR-1.4 |
| `order.total_amount` | GENERATED: `order_amount + round(order_amount * 0.1, 2)` | BR-7.11 |
| `order_structure.unit_price` | Цена на момент добавления позиции; изменения меню её не меняют | BR-7.10 |

GENERATED запрещает ручное изменение комиссии и итога. Обе формулы используют `order_amount`: ссылка на другой generated-столбец в PostgreSQL запрещена.

## Нормализация

- Клиенты, адреса, рестораны, курьеры, категории, блюда и оплаты разделены. Связи M:N — `client_address` и `order_structure`.
- Количество и цена позиции зависят от полного `(order_id, product_id)`. Выплата и применённая ставка — от `(year, month, courier_id)`.
- `commission`, `total_amount`, `pay_status` и рейтинги — производные поля по контракту. Согласованность поддерживают GENERATED и триггеры. Рейтинги хранятся для чтения без повторного расчёта.
- В `review` сохранён `client_id` из ERD. Зависимость `review_id → order_id → client_id` нарушает строгую 3НФ. Триггер проверяет совпадение автора с клиентом заказа.

## Процедуры и отчёты

| Тикет | Решение |
|---|---|
| FOOD-102 | `insert_test_data(n)` добавляет данные без очистки. По `n` клиентов, курьеров, категорий и ресторанов; по `5n` адресов, блюд, заказов, оплат и отзывов. Связей адресов `4n`, позиций `10n`, выплат `6n`. |
| FOOD-103 | `erase_test_data()` удаляет данные всех 12 таблиц с учётом FK. Объекты схемы сохраняются. |
| FOOD-104 | `add_product(...)` проверяет ресторан, категорию и значения полей. Новый рейтинг — `NULL`, отзывов нет (BR-9.7). |
| FOOD-105 | `rating_change()` пересчитывает средний рейтинг при INSERT/UPDATE/DELETE, включая смену объекта. Без отзывов — `NULL`; у заказа агрегата нет. |
| FOOD-106 | `get_statistic()`: доставленные заказы материализуются один раз. Суммы, продажи и частота заказов клиентов агрегируются отдельно. Лучшее блюдо — по `SUM(quantity)`, клиент — по числу заказов; равенство разрешается случайно. `best_user = client.login`. |
| FOOD-107 | `courier_salary()`: комиссия доставок × текущий коэффициент. Ставка сохраняется в `coefficient_used`; следующая определяется по BR-10.2. Повторный вызов обновляет выплату с сохранённой ставкой. Уволенным коэффициент не меняется. |
| FOOD-108 | `how_much_money`: календарь месяцев через рекурсивный CTE, месячные суммы и `LAG` предыдущей комиссии. Прибыль = комиссия − выплаты. |
| FOOD-109 | `grants.sql`: роль `inspector`, права на схему, таблицы, процедуры, функции и `exts`. |
| FOOD-110 | `foodexpress_chub.backup`: `pg_dump -Fc --schema-only`, только `chub_food`. Роль создаётся через `grants.sql`. |

Генератор: UUID, `enum_range()`, `md5(random()::text)`, последние 6 календарных месяцев, минимум один работающий курьер. Логины и номера платежей включают UUID, телефоны используют отдельную последовательность. В заказе две позиции с количествами `2` и `0.5`. Выплаты считаются по месяцам, с сохранением применённой ставки.

## Принятые трактовки

| Вопрос | Решение |
|---|---|
| BR-8.1 и BR-8.7 | Не более одной успешной оплаты; у доставленного заказа — ровно одна. Без попыток статус `ожидает`. Генератор создаёт одну успешную оплату на заказ. |
| Месяц зарплаты и отчёта | По `order_timestamp`, как в проверке C.8 шаблона. Учитываются доставленные заказы. |
| Месяц без доставок | Выручка 0. Вручную внесённая выплата уменьшает прибыль. Если доставок нет вообще, отчёт пустой. |
| Ресторан без доставок | Суммы 0, лучшее блюдо и клиент — `NULL`. |
| Email из примеров | Поле отсутствует в BR-2 и ERD; не добавлено. |
