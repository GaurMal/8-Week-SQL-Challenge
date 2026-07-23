-- ==================================================
-- Cleaning customer_orders table
-- ==================================================
-- Added line_item_id to uniquely identify each pizza record.
-- Required to distinguish duplicate pizzas within the same order
-- (e.g., Order 10 contains two Meatlovers with different modifications)
CREATE
OR REPLACE VIEW pizza_runner.cleaned_customer_orders AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            order_id,
            order_time,
            pizza_id,
            exclusions,
            extras
    ) AS line_item_id,
    order_id,
    customer_id,
    pizza_id,
    CASE
        WHEN exclusions IS NULL
        OR TRIM(exclusions) = ''
        OR LOWER(TRIM(exclusions)) = 'null' THEN NULL
        ELSE exclusions
    END AS exclusions,
    CASE
        WHEN extras IS NULL
        OR TRIM(extras) = ''
        OR LOWER(TRIM(extras)) = 'null' THEN NULL
        ELSE extras
    END as extras,
    order_time
FROM
    pizza_runner.customer_orders;

-- ==================================================
-- Cleaning runner_orders table
-- ==================================================
CREATE
OR REPLACE VIEW pizza_runner.cleaned_runner_orders AS
SELECT
    order_id,
    runner_id,
    CASE
        WHEN pickup_time IS NULL
        OR TRIM(pickup_time) = ''
        OR LOWER(TRIM(pickup_time)) = 'null' THEN NULL
        ELSE pickup_time::TIMESTAMP
    END AS pickup_time,
    CASE
        WHEN distance IS NULL
        OR TRIM(distance) = ''
        OR LOWER(TRIM(distance)) = 'null' THEN NULL
        ELSE TRIM(REPLACE (LOWER(distance), 'km', ''))::NUMERIC
    END AS distance_km,
    CASE
        WHEN duration is NULL
        OR TRIM(duration) = ''
        OR LOWER(TRIM(duration)) = 'null' THEN NULL
        ELSE REGEXP_REPLACE (duration, '[^0-9]', '', 'g')::INTEGER
    END AS duration_minutes,
    CASE
        WHEN cancellation is NULL
        OR TRIM(cancellation) = ''
        OR LOWER(TRIM(cancellation)) = 'null' THEN NULL
        ELSE cancellation
    END as cancellation
FROM
    pizza_runner.runner_orders;

-- ==================================================
-- Normalizing pizza_recipes table
-- ==================================================
    CREATE
    OR REPLACE VIEW pizza_runner.normalized_pizza_recipes AS
SELECT
    pizza_id,
    TRIM(UNNEST (STRING_TO_ARRAY (toppings, ',')))::INTEGER AS toppings_id
FROM
    pizza_runner.pizza_recipes;

-- ==================================================
-- Normalizing cleaned_customer_orders table
-- ==================================================
    CREATE
    OR REPLACE VIEW pizza_runner.normalized_customer_modification AS
SELECT
    line_item_id,
    order_id,
    customer_id,
    pizza_id,
    'exclusions' AS modification_type,
    TRIM(UNNEST (STRING_TO_ARRAY (exclusions, ',')))::INTEGER AS toppings_id
FROM
    pizza_runner.cleaned_customer_orders
UNION ALL
SELECT
    line_item_id,
    order_id,
    customer_id,
    pizza_id,
    'extras' AS modification_type,
    TRIM(UNNEST (STRING_TO_ARRAY (extras, ',')))::INTEGER AS toppings_id
FROM
    pizza_runner.cleaned_customer_orders;