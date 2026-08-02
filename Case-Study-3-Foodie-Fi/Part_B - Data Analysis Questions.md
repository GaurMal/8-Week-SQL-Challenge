# Part B - Data Analysis Questions

This section analyzes customer behavior and subscription trends, including plan popularity, churn rates, upgrades, downgrades, and customer retention metrics.

---

## Index

| Question | Description |
|----------|-------------|
| [Question 1](#question-1) | Total number of customers |
| [Question 2](#question-2) | Monthly distribution of trial starts |
| [Question 3](#question-3) | Subscription events after 2020 |
| [Question 4](#question-4) | Customer churn count and percentage |
| [Question 5](#question-5) | Customers who churned after trial |
| [Question 6](#question-6) | Plan selection after the trial |
| [Question 7](#question-7) | Plan distribution at the end of 2020 |
| [Question 8](#question-8) | Annual-plan upgrades in 2020 |
| [Question 9](#question-9) | Average time to upgrade to annual |
| [Question 10](#question-10) | Annual upgrades by 30-day periods |
| [Question 11](#question-11) | Downgrades from Pro Monthly to Basic Monthly |

---

# Question 1

## Question
How many customers has Foodie-Fi ever had?

## Solution

```sql
SELECT
    COUNT(DISTINCT customer_id) AS total_customers
FROM
    foodie_fi.subscriptions;
```

## Output

| total_customers |
| --------------- |
| 1000            |

## Answer
Foodie-Fi had 1000 customers in total.

---

# Question 2

## Question
What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value

## Solution

```sql
SELECT
    DATE_TRUNC ('month', start_date) AS month_start,
    COUNT(*) AS total_count
FROM
    foodie_fi.subscriptions
WHERE
    plan_id = 0
GROUP BY
    month_start
ORDER BY
    month_start;
```

## Output

| month_start            | total_count |
| ---------------------- | ----------- |
| 2020-01-01 00:00:00+00 | 88          |
| 2020-02-01 00:00:00+00 | 68          |
| 2020-03-01 00:00:00+00 | 94          |
| 2020-04-01 00:00:00+00 | 81          |
| 2020-05-01 00:00:00+00 | 88          |
| 2020-06-01 00:00:00+00 | 79          |
| 2020-07-01 00:00:00+00 | 89          |
| 2020-08-01 00:00:00+00 | 88          |
| 2020-09-01 00:00:00+00 | 87          |
| 2020-10-01 00:00:00+00 | 79          |
| 2020-11-01 00:00:00+00 | 75          |
| 2020-12-01 00:00:00+00 | 84          |

## Approach 
- Filtered the dataset to include only trial plans (`plan_id = 0`).
- Used `DATE_TRUNC('month', start_date)` to convert all trial dates to the first day of their respective month.
- Counted the number of trial subscriptions for each month and sorted the results chronologically.

## Answer
Trial plan sign-ups were fairly consistent throughout 2020, ranging from 68 to 94 customers per month. March recorded the highest number of trial starts (94), while February had the lowest (68).

---

# Question 3

## Question
What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name

## Solution

```sql
SELECT
    p.plan_name,
    COUNT(*) AS event_count
FROM
    foodie_fi.subscriptions AS s
    JOIN foodie_fi.plans AS p   
        ON s.plan_id = p.plan_id
WHERE
    s.start_date > '2020-12-31'
GROUP BY
    p.plan_name
ORDER BY
    event_count DESC;
```

## Output

| plan_name     | event_count |
| ------------- | ----------- |
| churn         | 71          |
| pro annual    | 63          |
| pro monthly   | 60          |
| basic monthly | 8           |

## Approach 
- Filtered the subscriptions table to include only plan events that occurred after 31 December 2020.
- Joined the subscriptions table with the plans table to retrieve the corresponding plan names.
- Grouped the results by `plan_name` and counted the number of occurrences for each plan.
- Sorted the results in descending order of event count.

## Answer
A total of 202 subscription events occurred after 2020. Churn was the most common event with 71 occurrences, followed by Pro Annual with 63 and Pro Monthly with 60. Basic Monthly had the fewest events, with 8 occurrences.

---

# Question 4

## Question
What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

## Solution

```sql
WITH
    total_customers AS (
        SELECT
            COUNT(DISTINCT customer_id) AS total_count
        FROM
            foodie_fi.subscriptions
    )
SELECT
    COUNT(DISTINCT s.customer_id) AS total_churned_customers,
    CONCAT (
        ROUND(
            COUNT(DISTINCT s.customer_id) * 100.0 / t.total_count,
            1
        ),
        ' %'
    ) AS percentage_of_churned_customers
FROM
    foodie_fi.subscriptions AS s
    CROSS JOIN total_customers AS t
WHERE
    s.plan_id = 4
GROUP BY
    t.total_count;
```

## Output

| total_churned_customers | percentage_of_churned_customers |
| ----------------------- | ------------------------------- |
| 307                     | 30.7 %                          |


## Approach
Filtered the subscriptions table to include only churn events (plan_id = 4). A CTE was used to calculate the total number of unique customers, and the churn percentage was then calculated by dividing the number of churned customers by the total customer count and multiplying by 100.

## Answer
A total of 307 customers churned, representing 30.7% of all Foodie-Fi customers.

---

# Question 5

## Question
How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?

## Solution

```sql
WITH
    total_customers AS (
        SELECT
            COUNT(DISTINCT customer_id) AS total_count
        FROM
            foodie_fi.subscriptions
    ),
    subscription_summary AS (
        SELECT
            customer_id,
            plan_id AS current_plan,
            LEAD (plan_id) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    start_date
            ) AS next_plan
        FROM
            foodie_fi.subscriptions
    )
SELECT
    COUNT(DISTINCT s.customer_id) AS total_churned_cust,
    CONCAT(
        ROUND(
            COUNT(DISTINCT s.customer_id) * 100.0 / t.total_count
        ),
        ' %'
    ) AS pct_of_churned_cust
FROM
    subscription_summary AS s
    CROSS JOIN total_customers AS t
WHERE
    s.current_plan = 0
    AND s.next_plan = 4
GROUP BY
    t.total_count;
```

## Output

| total_churned_cust | pct_of_churned_cust |
| ------------------ | ------------------- |
| 92                 | 9 %                 |

## Approach 
Used `LEAD()` to identify the next subscription plan for each customer based on the chronological order of their plan start dates. Customers whose current plan was the trial plan and whose next plan was churn were counted. The result was divided by the total number of unique customers to calculate the percentage.

## Answer
A total of 92 customers have churned straight after their initial free trial, representing 9% of all Foodie-Fi customers.

---

# Question 6

## Question
What is the number and percentage of customer plans after their initial free trial?

## Solution

```sql
WITH
    total_customers AS (
        SELECT
            COUNT(DISTINCT customer_id) AS total_count
        FROM
            foodie_fi.subscriptions
    ),
    subscription_summary AS (
        SELECT
            customer_id,
            plan_id AS current_plan,
            LAG (plan_id) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    start_date
            ) AS prev_plan
        FROM
            foodie_fi.subscriptions
    )
SELECT
    p.plan_name,
    COUNT(DISTINCT s.customer_id) AS customer_count,
    CONCAT (
        ROUND(
            COUNT(DISTINCT s.customer_id) * 100.0 / t.total_count,
            1
        ),
        ' %'
    ) AS customer_percentage
FROM
    subscription_summary AS s
    JOIN foodie_fi.plans AS p 
        ON s.current_plan = p.plan_id
    CROSS JOIN total_customers AS t
WHERE
    s.current_plan IN (1, 2, 3, 4)
    AND s.prev_plan = 0
GROUP BY
    p.plan_name,
    t.total_count;
```

## Output

| plan_name     | customer_count | customer_percentage |
| ------------- | -------------- | ------------------- |
| basic monthly | 546            | 54.6 %              |
| churn         | 92             | 9.2 %               |
| pro annual    | 37             | 3.7 %               |
| pro monthly   | 325            | 32.5 %              |

## Approach 
Used LAG() to identify the plan immediately preceding each subscription event. Rows where the previous plan was the free trial were selected, then grouped by the current plan name to calculate the number and percentage of customers choosing each plan after the trial.

## Answer
After the free trial, 54.6% of customers selected Basic Monthly, 32.5% selected Pro Monthly, 3.7% selected Pro Annual, and 9.2% churned immediately.

---

# Question 7

## Question
What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

## Solution

```sql
WITH
    total_customers AS (
        SELECT
            COUNT(DISTINCT customer_id) AS total_count
        FROM
            foodie_fi.subscriptions
    ),
    customer_plan_status AS (
        SELECT
            s.customer_id,
            p.plan_name,
            ROW_NUMBER() OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    start_date DESC
            ) AS rn
        FROM
            foodie_fi.subscriptions AS s
            JOIN foodie_fi.plans AS p 
                ON s.plan_id = p.plan_id
        WHERE
            s.start_date <= '2020-12-31'
    )
SELECT
    c.plan_name,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    CONCAT (
        ROUND(
            COUNT(DISTINCT c.customer_id) * 100.0 / t.total_count,
            2
        ),
        ' %'
    ) AS customer_percentage
FROM
    customer_plan_status AS c
    CROSS JOIN total_customers AS t
WHERE
    rn = 1
GROUP BY
    c.plan_name,
    t.total_count;
```

## Output

| plan_name     | customer_count | customer_percentage |
| ------------- | -------------- | ------------------- |
| basic monthly | 224            | 22.40 %             |
| churn         | 236            | 23.60 %             |
| pro annual    | 195            | 19.50 %             |
| pro monthly   | 326            | 32.60 %             |
| trial         | 19             | 1.90 %              |

## Approach 
Filtered subscription records to include only events on or before 31 December 2020. Then used ROW_NUMBER() to rank each customer’s plans by most recent start date and selected the latest plan for each customer. Finally, grouped customers by plan name and calculated the percentage of the total customer base.

## Answer
As of 31 December 2020, Pro Monthly was the most common plan with 326 customers (32.6%), followed by Churn with 236 customers (23.6%), Basic Monthly with 224 customers (22.4%), Pro Annual with 195 customers (19.5%), and Trial with 19 customers (1.9%).

---

# Question 8

## Question
How many customers have upgraded to an annual plan in 2020?

## Solution

```sql
SELECT
    COUNT(DISTINCT customer_id) AS total_customers
FROM
    foodie_fi.subscriptions
WHERE
    plan_id = 3
    AND EXTRACT(
        YEAR
        FROM
            start_date
    ) = 2020;
```

## Output

| total_customers |
| --------------- |
| 195             | 

## Answer
A total of 195 customers upgraded to the Pro Annual plan in 2020.

---

# Question 9

## Question
How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

## Solution

```sql
WITH
    starting_plan AS (
        SELECT
            customer_id,
            start_date AS trial_start_date
        FROM
            foodie_fi.subscriptions
        WHERE
            plan_id = 0
    ),
    annual_plan AS (
        SELECT
            customer_id,
            start_date AS annual_start_date
        FROM
            foodie_fi.subscriptions
        WHERE
            plan_id = 3
    )
SELECT
    ROUND(AVG(a.annual_start_date - s.trial_start_date), 2) AS time_taken_from_trial_to_annual
FROM
    annual_plan AS a
    JOIN starting_plan AS s 
        ON a.customer_id = s.customer_id;
```

## Output

| time_taken_from_trial_to_annual |
| ------------------------------- |
| 104.62                          |

## Approach 
Created separate CTEs for the trial start date and Pro Annual start date. Joined both datasets using `customer_id`, calculated the number of days taken to upgrade for each customer, and then computed the average across all customers.

## Answer
It took customers an average of 104.62 days to upgrade to the Pro Annual plan from the day they joined Foodie-Fi.

---

# Question 10

## Question
Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)

## Solution

```sql
WITH
    trial_plan AS (
        SELECT
            customer_id,
            start_date AS trial_start_date
        FROM
            foodie_fi.subscriptions
        WHERE
            plan_id = 0
    ),
    annual_plan AS (
        SELECT
            customer_id,
            start_date AS annual_start_date
        FROM
            foodie_fi.subscriptions
        WHERE
            plan_id = 3
    ),
    customer_days AS (
        SELECT
            (a.annual_start_date - t.trial_start_date) AS days_to_annual
        FROM
            annual_plan AS a
            JOIN trial_plan AS t 
                ON a.customer_id = t.customer_id
    ),
    bucket_count AS (
        SELECT
            GREATEST (1, CEIL(days_to_annual / 30.0)) AS bucket_number,
            COUNT(*) AS customer_count
        FROM
            customer_days
        GROUP BY
            bucket_number
    )
SELECT
    CONCAT (
        CASE
            WHEN bucket_number = 1 THEN 0
            ELSE (bucket_number - 1) * 30 + 1
        END,
        '-',
        bucket_number * 30,
        ' days'
    ) AS buckets,
    customer_count
FROM
    bucket_count
ORDER BY
    bucket_number;
```

## Output

| buckets      | customer_count |
| ------------ | -------------- |
| 0-30 days    | 49             |
| 31-60 days   | 24             |
| 61-90 days   | 34             |
| 91-120 days  | 35             |
| 121-150 days | 42             |
| 151-180 days | 36             |
| 181-210 days | 26             |
| 211-240 days | 4              |
| 241-270 days | 5              |
| 271-300 days | 1              |
| 301-330 days | 1              |
| 331-360 days | 1              |

## Approach 
Created separate CTEs to identify each customer's trial start date and Pro Annual start date. These CTEs were joined using `customer_id` to calculate the number of days each customer took to upgrade.

The calculated days were then divided into 30-day intervals using `CEIL()`. Each customer was assigned a bucket number, customers within the same bucket were counted, and the bucket numbers were converted into readable ranges such as `0-30 days`, `31-60 days`, and so on.

## Answer
The upgrade times were successfully grouped into 30-day periods.

The largest group was the `0-30 days` range, with 49 customers upgrading to the Pro Annual plan within their first 30 days. The smallest groups were `271-300 days`, `301-330 days`, and `331-360 days`, with only 1 customer in each range.

Overall, most customers upgraded within the first 210 days, while only a small number took more than 240 days to move to the Pro Annual plan.

---

# Question 11

## Question
How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

## Solution

```sql
WITH
    downgrade_summary AS (
        SELECT
            customer_id,
            plan_id AS current_plan,
            LEAD (plan_id) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    start_date
            ) AS next_plan,
            LEAD (start_date) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    start_date
            ) AS transition_date
        FROM
            foodie_fi.subscriptions
    )
SELECT
    COUNT(customer_id) AS total_customers
FROM
    downgrade_summary
WHERE
    current_plan = 2
    AND next_plan = 1
    AND EXTRACT(
        YEAR
        FROM
            transition_date
    ) = 2020;
```

## Output

| total_customers |
| --------------- |
| 0               |

## Approach 
Used `LEAD()` to compare each customer's current plan with their next plan in chronological order. The query then filtered for direct transitions from Pro Monthly to Basic Monthly where the downgrade date occurred in 2020, and counted the matching customers.

## Answer
There were no customers who directly downgraded from the Pro Monthly plan to the Basic Monthly plan in 2020.