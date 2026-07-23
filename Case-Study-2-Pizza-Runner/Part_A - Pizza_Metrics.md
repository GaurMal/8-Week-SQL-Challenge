# Question 1

## Question
How many customer orders were made?

## Solution

```sql 
SELECT
    COUNT(*) AS total_pizzas_ordered
FROM
    pizza_runner.cleaned_customer_orders;
``` 

## Output

| total_pizzas_ordered |
| -------------------- |
| 14                   |

## Answer
A total of 14 pizzas were ordered.

---

# Question 2

## Question
How many unique customer orders were made?

## Solution

```sql
SELECT
    COUNT(DISTINCT order_id) AS total_unique_orders
FROM
    pizza_runner.cleaned_customer_orders;
```

## Output

| total_unique_orders |
| ------------------- |
| 10                  |

## Answer
There were 10 unique customer orders made.

---

# Question 3

## Question
How many successful orders were delivered by each runner?

## Solution

```sql
SELECT
    runner_id,
    COUNT(*) AS successfully_delivered_orders
FROM
    pizza_runner.cleaned_runner_orders
WHERE
    cancellation IS NULL
GROUP BY
    runner_id
```

## Output

| runner_id | successfully_delivered_orders |
| --------- | ----------------------------- |
| 1         | 4                             |
| 2         | 3                             |
| 3         | 1                             |

## Answer
Runner 1 successfully delivered 4 orders, Runner 2 delivered 3 orders, and Runner 3 delivered 1 order.

---

# Question 4

## Question
How many of each type of pizza was delivered?

## Solution

```sql
SELECT
    p.pizza_name,
    COUNT(*) AS pizzas_delivered
FROM
    pizza_runner.cleaned_customer_orders AS c
    JOIN pizza_runner.cleaned_runner_orders AS r 
        ON c.order_id = r.order_id
    JOIN pizza_runner.pizza_names AS p 
        ON c.pizza_id = p.pizza_id
WHERE
    r.cancellation IS NULL
GROUP BY
    p.pizza_name
```

## Output

| pizza_name | pizzas_delivered |
| ---------- | ---------------- |
| Meatlovers | 9                |
| Vegetarian | 3                |

## Answer
9 Meatlovers pizzas and 3 Vegetarian pizzas were successfully delivered.

---

# Question 5

## Question
How many Vegetarian and Meatlovers were ordered by each customer?

## Solution

```sql
SELECT
    customer_id,
    SUM(
        CASE
            WHEN pizza_id = 1 THEN 1
            ELSE 0
        END
    ) AS meatlovers_pizza_count,
    SUM(
        CASE
            WHEN pizza_id = 2 THEN 1
            ELSE 0
        END
    ) AS vegetarian_pizza_count
FROM
    pizza_runner.cleaned_customer_orders
GROUP BY
    customer_id
ORDER BY
    customer_id
```

## Output

| customer_id | meatlovers_pizza_count | vegetarian_pizza_count |
| ----------- | ---------------------- | ---------------------- |
| 101         | 2                      | 1                      |
| 102         | 2                      | 1                      |
| 103         | 3                      | 1                      |
| 104         | 3                      | 0                      |
| 105         | 0                      | 1                      |

## Answer
Customer 103 and 104 ordered the most Meatlovers pizzas (3 each), while Vegetarian orders were distributed among customers 101, 102, 103, and 105 with 1 order each.

---

# Question 6

## Question
What was the maximum number of pizzas delivered in a single order?

## Solution

```sql
WITH
    pizza_count AS (
        SELECT
            c.order_id,
            COUNT(c.pizza_id) AS total_pizza_ordered
        FROM
            pizza_runner.cleaned_customer_orders AS c
            JOIN pizza_runner.cleaned_runner_orders AS r 
                ON c.order_id = r.order_id
        WHERE
            r.cancellation IS NULL
        GROUP BY
            c.order_id
    )
SELECT
    MAX(total_pizza_ordered) AS max_pizzas_delivered
FROM
    pizza_count
``` 

## Output

| max_pizzas_delivered |
| -------------------- |
| 3                    |

## Approach 
Calculated the total number of pizzas delivered in each order and then used MAX() to find the highest number of pizzas delivered within a single order.

## Answer
Maximum of 3 pizzas were delivered in a single order.

---

# Question 7

## Question
For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

## Solution

```sql
SELECT
    c.customer_id,
    SUM(
        CASE
            WHEN c.extras IS NOT NULL
            OR c.exclusions is NOT NULL THEN 1
            ELSE 0
        END
    ) AS with_change,
    SUM(
        CASE
            WHEN c.extras IS NULL
            AND c.exclusions IS NULL THEN 1
            ELSE 0
        END
    ) AS with_no_change
FROM
    pizza_runner.cleaned_customer_orders AS c
    JOIN pizza_runner.cleaned_runner_orders AS r 
        ON c.order_id = r.order_id
WHERE
    r.cancellation IS NULL
GROUP BY
    c.customer_id
```

## Output

| customer_id | with_change | with_no_change |
| ----------- | ----------- | -------------- |
| 101         | 0           | 2              |
| 102         | 0           | 3              |
| 103         | 3           | 0              |
| 104         | 2           | 1              |
| 105         | 1           | 0              |

## Approach
Filtered successful deliveries and used conditional aggregation to classify pizzas as changed when either extras or exclusions were present.

## Answer
Customer 101 had 2 delivered pizzas with no changes, while Customer 102 had 3. Customer 103 had 3 pizzas with changes, Customer 104 had 2 with changes and 1 without, and Customer 105 had 1 pizza with a change.

---

# Question 8

## Question
How many pizzas were delivered that had both exclusions and extras?

## Solution

```sql
SELECT
    SUM(
        CASE
            WHEN c.extras IS NOT NULL
            AND c.exclusions is NOT NULL THEN 1
            ELSE 0
        END
    ) AS delivered_with_exclusions_extras
FROM
    pizza_runner.cleaned_customer_orders AS c
    JOIN pizza_runner.cleaned_runner_orders AS r 
        ON c.order_id = r.order_id
WHERE
    r.cancellation IS NULL
```

## Output

| delivered_with_exclusions_extras |
| -------------------------------- |
| 1                                |

## Approach
Filtered successful deliveries and used conditional aggregation to count pizzas where both extras and exclusions were present.

## Answer
Only 1 delivered pizza had both exclusions and extras.

---

# Question 9

## Question
What was the total volume of pizzas ordered for each hour of the day?

## Solution

```sql
SELECT
    EXTRACT(
        HOUR
        FROM
            order_time
    ) AS hour,
    count(*) AS total_pizzas_volume
FROM
    pizza_runner.cleaned_customer_orders
GROUP BY
    hour
ORDER BY
    hour
```

## Output

| hour | total_pizzas_volume |
| ---- | ------------------- |
| 11   | 1                   |
| 13   | 3                   |
| 18   | 3                   |
| 19   | 1                   |
| 21   | 3                   |
| 23   | 3                   |

## Answer 
The highest pizza order volume was recorded during 13:00, 18:00, 21:00 and 23:00 hours with 3 pizzas ordered in each hour.

---

# Question 10

## Question
What was the volume of orders for each day of the week?

## Solution

```sql
SELECT
    TO_CHAR (order_time, 'DAY') AS day,
    count(*) AS total_pizzas_volume
FROM
    pizza_runner.cleaned_customer_orders
GROUP BY
    day
ORDER BY
    total_pizzas_volume DESC
```

## Output

| day       | total_pizzas_volume |
| --------- | ------------------- |
| WEDNESDAY | 5                   |
| SATURDAY  | 5                   |
| THURSDAY  | 3                   |
| FRIDAY    | 1                   |

## Answer 
The highest pizza order volume was recorded on Wednesday and Saturday with 5 pizzas ordered on each day.