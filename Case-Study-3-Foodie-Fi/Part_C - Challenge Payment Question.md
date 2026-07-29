# Part C - Challenge Payment Question

This section focuses on generating customer payment records by applying Foodie-Fi's billing rules, including trials, upgrades, downgrades, annual plans, and churn events.

---

# REQUIREMENT

## Question
The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

- Monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
- Upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
- Upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
- Once a customer churns they will no longer make payments

## Solution

```sql
WITH
    timeline_with_plan_details AS (
        SELECT
            s.customer_id,
            s.plan_id AS current_plan,
            p.plan_name AS current_plan_name,
            s.start_date AS current_start,
            p.price AS current_price,
            LAG (s.plan_id) OVER (
                PARTITION BY
                    s.customer_id
                ORDER BY
                    s.start_date
            ) AS previous_plan,
            LEAD (s.plan_id) OVER (
                PARTITION BY
                    s.customer_id
                ORDER BY
                    s.start_date
            ) AS next_plan,
            LEAD (s.start_date) OVER (
                PARTITION BY
                    s.customer_id
                ORDER BY
                    s.start_date
            ) AS next_start
        FROM
            foodie_fi.subscriptions AS s
            JOIN foodie_fi.plans AS p ON s.plan_id = p.plan_id
    ),
    paid_plan_details AS (
        SELECT
            *,
            COALESCE(next_start, DATE '2021-01-01') AS effective_end,
            CASE
                WHEN current_plan = 1
                AND next_plan = 2 THEN 'basic_to_pro_monthly'
                WHEN current_plan = 1
                AND next_plan = 3 THEN 'basic_to_pro_annual'
                WHEN current_plan = 2
                AND next_plan = 3 THEN 'pro_monthly_to_pro_annual'
            END AS transition_plan
        FROM
            timeline_with_plan_details
        WHERE
            current_plan IN (1, 2, 3)
    ),
    monthly_payment_periods AS (
        SELECT
            customer_id,
            current_plan,
            current_plan_name,
            current_price,
            transition_plan,
            current_start,
            GENERATE_SERIES (
                current_start,
                effective_end - INTERVAL '1 day',
                INTERVAL '1 month'
            )::DATE AS payment_date
        FROM
            paid_plan_details
        WHERE
            current_plan IN (1, 2)
    ),
    payment_history AS (
        SELECT
            *,
            LAG (current_plan) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    payment_date
            ) AS prev_payment_plan,
            LAG (current_price) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    payment_date
            ) AS prev_payment_amount,
            LAG (payment_date) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    payment_date
            ) AS prev_payment_date
        FROM
            monthly_payment_periods
    ),
    pro_monthly_transition AS (
        SELECT
            *,
            CASE
                WHEN current_plan = 2
                AND prev_payment_plan = 1
                AND payment_date = current_start
                AND payment_date < prev_payment_date + INTERVAL '1 month' THEN current_price - prev_payment_amount
                ELSE current_price
            END AS amount
        FROM
            payment_history
    ),
    basic_to_pro_annual AS (
        SELECT
            ppd.customer_id,
            ppd.next_plan as plan_id,
            p.plan_name,
            ppd.next_start AS payment_date,
            CASE
                WHEN ppd.next_start < MAX(ph.payment_date) + INTERVAL '1 month' THEN p.price - ppd.current_price
                ELSE p.price
            END AS amount
        FROM
            paid_plan_details AS ppd
            JOIN foodie_fi.plans AS p ON ppd.next_plan = p.plan_id
            JOIN payment_history AS ph ON ppd.customer_id = ph.customer_id
            AND ph.current_plan = 1
            AND ph.payment_date < ppd.next_start
        WHERE
            ppd.transition_plan = 'basic_to_pro_annual'
        GROUP BY
            ppd.customer_id,
            ppd.next_plan,
            p.plan_name,
            ppd.next_start,
            p.price,
            ppd.current_price
    ),
    pro_monthly_to_annual_payments AS (
        SELECT
            ppd.customer_id,
            ppd.next_plan AS plan_id,
            p.plan_name,
            (MAX(pmt.payment_date) + INTERVAL '1 month')::DATE AS payment_date,
            p.price AS amount
        FROM
            paid_plan_details AS ppd
            JOIN foodie_fi.plans AS p ON ppd.next_plan = p.plan_id
            JOIN pro_monthly_transition AS pmt ON ppd.customer_id = pmt.customer_id
            AND pmt.current_plan = 2
            AND pmt.payment_date < ppd.next_start
        WHERE
            ppd.transition_plan = 'pro_monthly_to_pro_annual'
        GROUP BY
            ppd.customer_id,
            ppd.next_plan,
            p.plan_name,
            ppd.next_start,
            p.price
    ),
    direct_pro_annual_payments AS (
        SELECT
            customer_id,
            current_plan AS plan_id,
            current_plan_name AS plan_name,
            current_start AS payment_date,
            current_price AS amount
        FROM
            timeline_with_plan_details
        WHERE
            current_plan = 3
            AND previous_plan = 0
    ),
    all_payments AS (
        SELECT
            customer_id,
            current_plan AS plan_id,
            current_plan_name AS plan_name,
            payment_date,
            amount
        FROM
            pro_monthly_transition
        UNION ALL
        SELECT
            *
        FROM
            basic_to_pro_annual
        UNION ALL
        SELECT
            *
        FROM
            pro_monthly_to_annual_payments
        UNION ALL
        SELECT
            *
        FROM
            direct_pro_annual_payments
    )
SELECT
    *,
    ROW_NUMBER() OVER (
        PARTITION BY
            customer_id
        ORDER BY
            payment_date,
            plan_id
    ) AS payment_order
FROM
    all_payments
WHERE
    payment_date >= DATE '2020-01-01'
    AND payment_date < DATE '2021-01-01'
    AND customer_id in (1, 2, 11, 13, 15, 16, 18, 19)
ORDER BY
    customer_id,
    payment_date;
```

## Output

| customer_id | plan_id | plan_name     | payment_date | amount | payment_order |
| ----------- | ------- | ------------- | ------------ | ------ | ------------- |
| 1           | 1       | basic monthly | 2020-08-08   | 9.90   | 1             |
| 1           | 1       | basic monthly | 2020-09-08   | 9.90   | 2             |
| 1           | 1       | basic monthly | 2020-10-08   | 9.90   | 3             |
| 1           | 1       | basic monthly | 2020-11-08   | 9.90   | 4             |
| 1           | 1       | basic monthly | 2020-12-08   | 9.90   | 5             |
| 2           | 3       | pro annual    | 2020-09-27   | 199.00 | 1             |
| 13          | 1       | basic monthly | 2020-12-22   | 9.90   | 1             |
| 15          | 2       | pro monthly   | 2020-03-24   | 19.90  | 1             |
| 15          | 2       | pro monthly   | 2020-04-24   | 19.90  | 2             |
| 16          | 1       | basic monthly | 2020-06-07   | 9.90   | 1             |
| 16          | 1       | basic monthly | 2020-07-07   | 9.90   | 2             |
| 16          | 1       | basic monthly | 2020-08-07   | 9.90   | 3             |
| 16          | 1       | basic monthly | 2020-09-07   | 9.90   | 4             |
| 16          | 1       | basic monthly | 2020-10-07   | 9.90   | 5             |
| 16          | 3       | pro annual    | 2020-10-21   | 189.10 | 6             |
| 18          | 2       | pro monthly   | 2020-07-13   | 19.90  | 1             |
| 18          | 2       | pro monthly   | 2020-08-13   | 19.90  | 2             |
| 18          | 2       | pro monthly   | 2020-09-13   | 19.90  | 3             |
| 18          | 2       | pro monthly   | 2020-10-13   | 19.90  | 4             |
| 18          | 2       | pro monthly   | 2020-11-13   | 19.90  | 5             |
| 18          | 2       | pro monthly   | 2020-12-13   | 19.90  | 6             |
| 19          | 2       | pro monthly   | 2020-06-29   | 19.90  | 1             |
| 19          | 2       | pro monthly   | 2020-07-29   | 19.90  | 2             |
| 19          | 3       | pro annual    | 2020-08-29   | 199.00 | 3             |

> **Note:** The final `WHERE customer_id IN (...)` condition was added only to display the same customer sample shown in the expected output. It can be removed to generate the complete 2020 payments table for all customers.

## Approach 

1. Created a subscription timeline for each customer using `LEAD()` to identify their next plan and next subscription start date.

2. Joined the subscription records with the plans table to retrieve the corresponding plan names and prices.

3. Filtered the timeline to paid plans only and classified the relevant upgrade transitions:
   - Basic Monthly to Pro Monthly
   - Basic Monthly to Pro Annual
   - Pro Monthly to Pro Annual

4. Generated recurring monthly payment dates for Basic Monthly and Pro Monthly plans using `GENERATE_SERIES()`. The next subscription start date was treated as an exclusive boundary so that payments from the previous plan were not generated after an upgrade or churn.

5. Used `LAG()` over the generated payment rows to retrieve each customer's previous payment plan, amount and date.

6. Adjusted Basic Monthly to Pro Monthly upgrades:
   - If the upgrade occurred during an already-paid Basic billing period, the Basic payment was deducted from the first Pro Monthly payment.
   - If the upgrade occurred on the next billing date, the full Pro Monthly amount was charged.

7. Created a separate payment stream for Basic Monthly to Pro Annual upgrades. These upgrades started immediately, with the Basic payment deducted only when the upgrade occurred during the active monthly billing period.

8. Created another payment stream for Pro Monthly to Pro Annual upgrades. The annual payment was moved to the end of the customer's current Pro Monthly billing period and charged at the full annual price.

9. Created a separate payment stream for customers who moved directly from the free trial to Pro Annual. The annual fee was charged on the Pro Annual plan's start date.

10. Combined the monthly and annual payment streams using `UNION ALL`.

11. Filtered the combined results to payments occurring during 2020 and assigned a sequential payment order to each customer using `ROW_NUMBER()`.

## Answer

The query generates a simulated payments table for 2020 containing:

- The customer ID
- The plan associated with each payment
- The payment date
- The amount charged
- The chronological payment order for each customer

Monthly payments follow the billing day established by the plan's original start date. Immediate upgrades from Basic Monthly to either Pro Monthly or Pro Annual receive credit for the Basic payment already made during the active billing period.

Upgrades from Pro Monthly to Pro Annual are instead charged at the end of the current monthly billing period. Payments stop when the customer's next subscription event is churn, because the churn date acts as the exclusive end boundary for generating monthly payments.