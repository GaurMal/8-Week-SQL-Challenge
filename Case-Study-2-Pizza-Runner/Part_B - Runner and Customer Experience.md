# Question 1

## Question
How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

## Solution

```sql
SELECT
    FLOOR((registration_date - DATE '2021-01-01') / 7) + 1 AS week_number,
    COUNT(*) AS runners_signed_up
FROM
    pizza_runner.runners
GROUP BY
    week_number
ORDER BY
    week_number
```

## Output

| week_number | runners_signed_up |
| ----------- | ----------------- |
| 1           | 2                 |
| 2           | 1                 |
| 3           | 1                 |

## Approach
Calculated the number of days between each runner's' registration date and the starting date (2021-01-01), grouped them into 7-day periods, and counted runner signups for each week.

## Answer
2 runners signed up in the first week, while 1 runner signed up in both the second and third weeks.

---

# Question 2

## Question
What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

## Solution

```sql
WITH
    placing_time AS (
        SELECT DISTINCT
            order_id,
            order_time
        FROM
            pizza_runner.cleaned_customer_orders
    )
SELECT
    r.runner_id,
    ROUND(
        AVG(
            EXTRACT(
                EPOCH
                FROM
                    (r.pickup_time - p.order_time)
            ) / 60
        ),
        2
    ) AS avg_time_taken
FROM
    pizza_runner.cleaned_runner_orders AS r
    JOIN placing_time AS p 
        ON r.order_id = p.order_id
WHERE
    r.cancellation IS NULL
GROUP BY
    r.runner_id
```

## Output

| runner_id | avg_time_taken |
| --------- | -------------- |
| 1         | 14.33          |
| 2         | 20.01          |
| 3         | 10.47          |

## Approach
Created a CTE containing one row per order to avoid duplicate pickup-time calculations for multi-pizza orders. Then calculated the time difference between order and pickup timestamps, converted it to minutes, and averaged it for each runner.

## Answer
Runner 1 took an average of 14.33 minutes, Runner 2 took 20.01 minutes, and Runner 3 took 10.47 minutes to arrive for pickup.

---

# Question 3

## Question
Is there any relationship between the number of pizzas and how long the order takes to prepare?

## Solution

```sql
WITH
    order_summary AS (
        SELECT
            order_id,
            COUNT(order_id) AS pizza_count,
            order_time
        FROM
            pizza_runner.cleaned_customer_orders
        GROUP BY
            order_id,
            order_time
    )
SELECT
    pizza_count,
    ROUND(
        AVG(
            EXTRACT(
                EPOCH
                FROM
                    (r.pickup_time - o.order_time)
            ) / 60
        ),
        2
    ) AS avg_prep_time
FROM
    pizza_runner.cleaned_runner_orders AS r
    JOIN order_summary AS o 
        ON r.order_id = o.order_id
WHERE
    r.cancellation IS NULL
GROUP BY
    o.pizza_count
ORDER BY
    o.pizza_count
```

## Output

| pizza_count | avg_prep_time |
| ----------- | ------------- |
| 1           | 12.36         |
| 2           | 18.38         |
| 3           | 29.28         |

## Approach
Created an order-level summary using a CTE to count the number of pizzas in each order while retaining the order timestamp. Then joined it with successful runner orders, calculated the time between order placement and pickup in minutes, and averaged that duration for each pizza quantity.

## Answer
Orders with more pizzas generally took longer to prepare. Single-pizza orders averaged 12.36 minutes, two-pizza orders averaged 18.38 minutes, and three-pizza orders averaged 29.28 minutes.

---


# Question 4

## Question
What was the average distance travelled for each customer?

## Solution

```sql
WITH
    order_summary AS (
        SELECT DISTINCT
            order_id,
            customer_id
        FROM
            pizza_runner.cleaned_customer_orders
    )
SELECT
    o.customer_id,
    Round(Avg(r.distance_km), 2) as avg_distance_travelled_in_km
FROM
    pizza_runner.cleaned_runner_orders AS r
    JOIN order_summary AS o 
        ON o.order_id = r.order_id
WHERE
    r.cancellation is null
GROUP BY
    o.customer_id
ORDER BY
    o.customer_id
```

## Output

| customer_id | avg_distance_travelled_in_km |
| ----------- | ---------------------------- |
| 101         | 20.00                        |
| 102         | 18.40                        |
| 103         | 23.40                        |
| 104         | 10.00                        |
| 105         | 25.00                        |

## Approach
Created a CTE to retain one row per order by selecting distinct order_id and customer_id combinations from cleaned_customer_orders. Then joined it with successful deliveries and calculated the average distance travelled for each customer.

## Answer
The average delivery distance for Customer 101 was 20.00 km, for Customer 102 was 18.40 km, for Customer 103 was 23.40 km, for Customer 104 was 10.00 km, and for Customer 105 was 25.00 km.

---

# Question 5

## Question
What was the difference between the longest and shortest delivery times for all orders?

## Solution

```sql
SELECT
    MAX(duration_minutes) - MIN(duration_minutes) AS delivery_time_difference
FROM
    pizza_runner.cleaned_runner_orders
WHERE
    cancellation is null
``` 

## Output

| delivery_time_difference |
| ------------------------ |
| 30                       |

## Answer
The difference between the longest and shortest delivery times among all successful orders was 30 minutes.

---

# Question 6

## Question
What was the average speed for each runner for each delivery and do you notice any trend for these values?

## Solution

```sql
SELECT
    runner_id,
    order_id,
    distance_km,
    ROUND((distance_km * 60) / duration_minutes, 2) AS speed_in_km_per_hr
FROM
    pizza_runner.cleaned_runner_orders
WHERE
    cancellation IS NULL
ORDER BY
    runner_id,
    order_id
```

## Output

| runner_id | order_id | distance_km | speed_in_km_per_hr |
| --------- | -------- | ----------- | ------------------ |
| 1         | 1        | 20          | 37.50              |
| 1         | 2        | 20          | 44.44              |
| 1         | 3        | 13.4        | 40.20              |
| 1         | 10       | 10          | 60.00              |
| 2         | 4        | 23.4        | 35.10              |
| 2         | 7        | 25          | 60.00              |
| 2         | 8        | 23.4        | 93.60              |
| 3         | 5        | 10          | 40.00              |

## Approach
Calculated delivery speed for each successful order using the formula distance ÷ time, converting delivery duration from minutes to hours.

## Answer
Runner 2 showed the greatest variation in delivery speed, ranging from 35.10 km/hr to 93.60 km/hr. Even for two deliveries covering the same distance of 23.4 km, the calculated speeds differed substantially, suggesting that delivery duration varied significantly or may have been rounded.

--- 

# Question 7

## Question
What is the successful delivery percentage for each runner?

## Solution

```sql
SELECT
    runner_id,
    ROUND(
        SUM(
            CASE
                WHEN cancellation IS NULL THEN 1
                ELSE 0
            END
        ) * 100 / COUNT(*),
        2
    ) AS successful_delivery_percentage
FROM
    pizza_runner.cleaned_runner_orders
GROUP BY
    runner_id
ORDER BY
    runner_id
```

## Output

| runner_id | successful_delivery_percentage |
| --------- | ------------------------------ |
| 1         | 100.00                         |
| 2         | 75.00                          |
| 3         | 50.00                          |

## Approach
Used conditional aggregation to count successful deliveries for each runner and divided it by the total number of assigned orders to calculate the delivery success percentage.

## Answer
Runner 1 successfully delivered 100% of assigned orders, Runner 2 delivered 75%, and Runner 3 delivered 50%.