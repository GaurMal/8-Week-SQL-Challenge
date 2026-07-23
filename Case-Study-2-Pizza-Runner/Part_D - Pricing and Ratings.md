# Part D - Pricing and Ratings

This section examines Pizza Runner's revenue, delivery costs, customer ratings, and overall business profitability.

---

# Question 1

## Question
If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

## Solution

```sql
WITH
    order_summary AS (
        SELECT
            c.order_id,
            c.pizza_id
        FROM
            pizza_runner.cleaned_customer_orders AS c
            JOIN pizza_runner.cleaned_runner_orders AS r 
                ON c.order_id = r.order_id
        WHERE
            r.cancellation IS NULL
    )
SELECT
    CONCAT (
        '$ ',
        SUM(
            CASE
                WHEN pizza_id = 1 THEN 12
                ELSE 10
            END
        )
    ) AS total
FROM
    order_summary
```

## Output

| total |
| ----- |
| $ 138 |

## Answer
Pizza Runner has generated $138 in revenue so far, assuming no delivery fees and no additional charges for extras or exclusions.

---

# Question 2

## Question
What if there was an additional $1 charge for any pizza extras?
- Add cheese is $1 extra

## Solution

```sql
WITH
    order_summary AS (
        SELECT
            c.order_id,
            c.pizza_id
        FROM
            pizza_runner.cleaned_customer_orders AS c
            JOIN pizza_runner.cleaned_runner_orders AS r 
                ON c.order_id = r.order_id
        WHERE
            r.cancellation IS NULL
    ),
    base_revenue AS (
        SELECT
            order_id,
            SUM(
                CASE
                    WHEN pizza_id = 1 THEN 12
                    ELSE 10
                END
            ) AS money_made_in_USD
        FROM
            order_summary
        GROUP BY
            order_id
    ),
    extra_count AS (
        SELECT
            order_id,
            COUNT(*) AS extra_charge
        FROM
            pizza_runner.normalized_customer_modification
        WHERE
            modification_type = 'extras'
        GROUP BY
            order_id
    )
SELECT
    Concat ('$ ', SUM(money_made_in_USD) + Sum(total)) AS grand_total
FROM
    base_revenue AS b
    LEFT JOIN extra_count AS e 
        ON b.order_id = e.order_id
```

## Output

| grand_total |
| ----------- |
| $ 142       |

## Approach
Calculated the base revenue for each successfully delivered order, counted its extra toppings at $1 each, then joined both results by order_id and summed them to calculate total revenue.

## Answer
Pizza Runner would have made a total of $142 after charging an additional $1 for every extra topping.

--- 

# Question 3

## Question
The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

## Solution

```sql
CREATE TABLE
    pizza_runner.runner_ratings (
        rating_id SERIAL PRIMARY KEY,
        order_id INTEGER UNIQUE NOT NULL,
        customer_id INTEGER NOT NULL,
        runner_id INTEGER NOT NULL,
        rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
        rating_date DATE NOT NULL DEFAULT CURRENT_DATE
    );

SELECT
    c.order_id,
    c.customer_id,
    r.runner_id
FROM
    pizza_runner.cleaned_customer_orders AS c
    JOIN pizza_runner.cleaned_runner_orders AS r 
        ON c.order_id = r.order_id
WHERE
    r.cancellation IS NULL
GROUP BY
    c.order_id,
    c.customer_id,
    r.runner_id
ORDER BY
    c.order_id;

INSERT INTO
    pizza_runner.runner_ratings (
        order_id,
        customer_id,
        runner_id,
        rating,
        rating_date
    )
VALUES
    (1, 101, 1, 4, DATE '2021-01-01'),
    (2, 101, 1, 5, DATE '2021-01-01'),
    (3, 102, 1, 4, DATE '2021-01-03'),
    (4, 103, 2, 3, DATE '2021-01-04'),
    (5, 104, 3, 5, DATE '2021-01-08'),
    (7, 105, 2, 4, DATE '2021-01-08'),
    (8, 102, 2, 4, DATE '2021-01-09'),
    (10, 104, 1, 5, DATE '2021-01-11');

Select
    *
FROM
    pizza_runner.runner_ratings
```

## Output

| rating_id | order_id | customer_id | runner_id | rating | rating_date |
| --------- | -------- | ----------- | --------- | ------ | ----------- |
| 1         | 1        | 101         | 1         | 4      | 2021-01-01  |
| 2         | 2        | 101         | 1         | 5      | 2021-01-01  |
| 3         | 3        | 102         | 1         | 4      | 2021-01-03  |
| 4         | 4        | 103         | 2         | 3      | 2021-01-04  |
| 5         | 5        | 104         | 3         | 5      | 2021-01-08  |
| 6         | 7        | 105         | 2         | 4      | 2021-01-08  |
| 7         | 8        | 102         | 2         | 4      | 2021-01-09  |
| 8         | 10       | 104         | 1         | 5      | 2021-01-11  |

## Approach
Created a new runner_ratings table with a unique rating ID, one rating per order, and a CHECK constraint to restrict ratings between 1 and 5. Then identified all successfully delivered orders and inserted one sample rating for each of them.

## Answer
A runner ratings table was successfully created and populated with one rating for each successful customer order. All ratings were restricted to valid values between 1 and 5.

---

# Question 4

## Question
Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
- customer_id
- order_id
- runner_id
- rating
- order_time
- pickup_time
- Time between order and pickup
- Delivery duration
- Average speed
- Total number of pizzas

## Solution

```sql
WITH
    order_summary AS (
        SELECT
            customer_id,
            order_id,
            order_time,
            COUNT(order_id) AS total_pizzas
        FROM
            pizza_runner.cleaned_customer_orders
        GROUP BY
            order_id,
            customer_id,
            order_time
        ORDER BY
            order_id
    )
SELECT
    o.customer_id,
    o.order_id,
    r.runner_id,
    ra.rating,
    o.order_time,
    r.pickup_time,
    ROUND(
        EXTRACT(
            EPOCH
            FROM
                (r.pickup_time - o.order_time)
        ) / 60,
        2
    ) AS time_between_order_and_pickup_mins,
    r.duration_minutes,
    ROUND((r.distance_km * 60) / r.duration_minutes, 2) AS speed_in_km_per_hr,
    total_pizzas
FROM
    order_summary AS o
    JOIN pizza_runner.cleaned_runner_orders AS r 
        ON o.order_id = r.order_id
    JOIN pizza_runner.runner_ratings AS ra 
        ON ra.order_id = o.order_id
WHERE
    r.cancellation IS NULL
```

## Output

| customer_id | order_id | runner_id | rating | order_time          | pickup_time         | time_between_order_and_pickup_mins | duration_minutes | speed_in_km_per_hr | total_pizzas |
| ----------- | -------- | --------- | ------ | ------------------- | ------------------- | ---------------------------------- | ---------------- | ------------------ | ------------ |
| 101         | 1        | 1         | 4      | 2020-01-01 18:05:02 | 2020-01-01 18:15:34 | 10.53                              | 32               | 37.50              | 1            |
| 101         | 2        | 1         | 5      | 2020-01-01 19:00:52 | 2020-01-01 19:10:54 | 10.03                              | 27               | 44.44              | 1            |
| 102         | 3        | 1         | 4      | 2020-01-02 23:51:23 | 2020-01-03 00:12:37 | 21.23                              | 20               | 40.20              | 2            |
| 103         | 4        | 2         | 3      | 2020-01-04 13:23:46 | 2020-01-04 13:53:03 | 29.28                              | 40               | 35.10              | 3            |
| 104         | 5        | 3         | 5      | 2020-01-08 21:00:29 | 2020-01-08 21:10:57 | 10.47                              | 15               | 40.00              | 1            |
| 105         | 7        | 2         | 4      | 2020-01-08 21:20:29 | 2020-01-08 21:30:45 | 10.27                              | 25               | 60.00              | 1            |
| 102         | 8        | 2         | 4      | 2020-01-09 23:54:33 | 2020-01-10 00:15:02 | 20.48                              | 15               | 93.60              | 1            |
| 104         | 10       | 1         | 5      | 2020-01-11 18:34:49 | 2020-01-11 18:50:20 | 15.52                              | 10               | 60.00              | 2            |

## Approach
Created an order-level summary from cleaned_customer_orders to retain one row per order and calculate the total number of pizzas. Then joined it with runner delivery details and the ratings table, and calculated pickup delay and delivery speed using the order, pickup, distance, and duration fields.

## Answer
The final table successfully combines customer, order, runner, rating, timing, delivery, speed, and pizza-count information for all successful deliveries.

---

# Question 5

## Question
If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?

## Solution

```sql
WITH
    order_summary AS (
        SELECT
            c.order_id,
            SUM(
                CASE
                    WHEN c.pizza_id = 1 THEN 12
                    ELSE 10
                END
            ) AS order_revenue
        FROM
            pizza_runner.cleaned_customer_orders AS c
            JOIN pizza_runner.cleaned_runner_orders AS r 
                ON c.order_id = r.order_id
        WHERE
            r.cancellation IS NULL
        GROUP BY
            c.order_id
    ),
    runner_payment AS (
        SELECT
            order_id,
            0.30 * distance_km AS runners_payment
        FROM
            pizza_runner.cleaned_runner_orders
        WHERE
            cancellation IS NULL
    )
SELECT
    CONCAT (
        '$ ',
        Round(SUM(order_revenue) - SUM(runners_payment), 2)
    ) AS remaining_amount
FROM
    order_summary AS os
    JOIN runner_payment AS r 
        ON os.order_id = r.order_id
```

## Output

| remaining_amount |
| ---------------- |
| $ 94.44          |

## Approach
Calculated revenue for each successfully delivered order using the fixed pizza prices, calculated runner payment at $0.30 per kilometre for each delivery, then joined both values by order_id and subtracted total runner payments from total revenue.

## Answer
Pizza Runner had $94.44 remaining after paying runners $0.30 per kilometre for all successful deliveries.