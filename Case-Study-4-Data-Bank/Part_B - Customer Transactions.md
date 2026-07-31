# Part B: Customer Transactions

This section analyses the banking transactions performed by Data Bank customers.

The dataset contains deposits, purchases, and withdrawals. The analysis examines transaction frequency, transaction amounts, customer deposit behaviour, monthly activity, and changes in customer balances.

The purpose of this section is to understand how customers use their Data Bank accounts and identify broader transaction patterns across the customer base.

---

# Question 1

## Question
What is the unique count and total amount for each transaction type?

## Solution

```sql
SELECT
    txn_type,
    COUNT(*) AS txn_count,
    SUM(txn_amount) AS total_txn_amount
FROM
    data_bank.customer_transactions
GROUP BY
    txn_type;
```

## Output

| txn_type   | txn_count | total_txn_amount |
| ---------- | --------- | ---------------- |
| purchase   | 1617      | 806537           |
| withdrawal | 1580      | 793003           |
| deposit    | 2671      | 1359168          |

## Answer
Deposits are the most frequent transaction type, with **2,671 transactions** totaling **1,359,168**.

Purchases account for **1,617 transactions** totaling **806,537**, while withdrawals account for **1,580 transactions** totaling **793,003**.

---

# Question 2

## Question
What is the average total historical deposit counts and amounts for all customers?

## Solution

```sql
WITH
    deposit_txn_history AS (
        SELECT
            customer_id,
            COUNT(*) AS txn_count,
            SUM(txn_amount) AS total_txn_amount
        FROM
            data_bank.customer_transactions
        WHERE
            txn_type = 'deposit'
        GROUP BY
            customer_id
    )
SELECT
    ROUND(AVG(txn_count), 2) AS avg_count,
    ROUND(AVG(total_txn_amount), 2) AS avg_total
FROM
    deposit_txn_history;
```

## Output

| avg_count | avg_total |
| --------- | --------- |
| 5.34      | 2718.34   |

## Answer
On average, each customer made **5.34 deposit transactions**, with an average total historical deposit amount of **2,718.34** per customer.

---

# Question 3

## Question
For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

## Solution

```sql
WITH
    deposit_count AS (
        SELECT
            customer_id,
            TO_CHAR (txn_date, 'Mon') AS month,
            COUNT(
                CASE
                    WHEN txn_type = 'deposit' THEN 1
                END
            ) AS deposit_count,
            COUNT(
                CASE
                    WHEN txn_type = 'purchase' THEN 1
                END
            ) AS purchased_count,
            COUNT(
                CASE
                    WHEN txn_type = 'withdrawal' THEN 1
                END
            ) AS withdrawal_count
        FROM
            data_bank.customer_transactions
        GROUP BY
            customer_id,
            month
    )
SELECT
    month,
    COUNT(customer_id) AS customers_count
FROM
    deposit_count
WHERE
    deposit_count > 1
    AND (
        purchased_count >= 1
        OR withdrawal_count >= 1
    )
GROUP BY
    month
ORDER BY
    customers_count DESC;
```

## Output

| month | customers_count |
| ----- | --------------- |
| Mar   | 192             |
| Feb   | 181             |
| Jan   | 168             |
| Apr   | 70              |

## Approach 
1. Group transactions by customer and month.
2. Calculate the number of deposits, purchases, and withdrawals for each customer-month.
3. Filter customers who made more than one deposit and at least one purchase or withdrawal.
4. Count the qualifying customers for each month.

## Answer
March had the highest number of qualifying customers, with **192 customers** making more than one deposit and at least one purchase or withdrawal during the month.

This was followed by February with **181 customers**, January with **168 customers**, and April with the lowest count of **70 customers**.

---

# Question 4

## Question
What is the closing balance for each customer at the end of the month?

## Solution

```sql
WITH
    customers AS (
        SELECT DISTINCT
            customer_id
        FROM
            data_bank.customer_transactions
    ),
    months AS (
        SELECT
            GENERATE_SERIES (
                DATE_TRUNC ('month', MIN(txn_date)),
                DATE_TRUNC ('month', MAX(txn_date)),
                INTERVAL '1 month'
            )::DATE AS month
        FROM
            data_bank.customer_transactions
    ),
    customer_months AS (
        SELECT
            c.customer_id,
            m.month
        FROM
            customers AS c
            CROSS JOIN months AS m
    ),
    monthly_transactions AS (
        SELECT
            customer_id,
            DATE_TRUNC ('month', txn_date)::DATE AS month,
            SUM(
                CASE
                    WHEN txn_type = 'deposit' THEN txn_amount
                    WHEN txn_type in ('purchase', 'withdrawal') THEN - txn_amount
                    ELSE 0
                END
            ) AS monthly_net_change
        FROM
            data_bank.customer_transactions
        GROUP BY
            customer_id,
            month
    ),
    complete_monthly_transaction AS (
        SELECT
            cm.customer_id,
            cm.month,
            COALESCE(mt.monthly_net_change, 0) AS monthly_net_change
        FROM
            customer_months AS cm
            LEFT JOIN monthly_transactions AS mt 
                ON cm.customer_id = mt.customer_id
            AND cm.month = mt.month
    )
SELECT
    customer_id,
    month,
    monthly_net_change,
    SUM(monthly_net_change) OVER (
        PARTITION BY
            customer_id
        ORDER BY
            month
    ) AS closing_balance
FROM
    complete_monthly_transaction
ORDER BY
    customer_id,
    month
LIMIT
    10;
```

## Output

| customer_id | month      | monthly_net_change | closing_balance |
| ----------- | ---------- | ------------------ | --------------- |
| 1           | 2020-01-01 | 312                | 312             |
| 1           | 2020-02-01 | 0                  | 312             |
| 1           | 2020-03-01 | -952               | -640            |
| 1           | 2020-04-01 | 0                  | -640            |
| 2           | 2020-01-01 | 549                | 549             |
| 2           | 2020-02-01 | 0                  | 549             |
| 2           | 2020-03-01 | 61                 | 610             |
| 2           | 2020-04-01 | 0                  | 610             |
| 3           | 2020-01-01 | 144                | 144             |
| 3           | 2020-02-01 | -965               | -821            |

## Approach 
1. Extract all unique customers from the transaction table.
2. Generate a continuous list of months between the earliest and latest transaction dates.
3. Cross join the customers and months to create every possible customer-month combination.
4. Calculate each customer's monthly net change by adding deposits and subtracting purchases and withdrawals.
5. Left join the monthly transaction totals to the complete customer-month grid and replace missing monthly values with `0`.
6. Apply a cumulative sum for each customer in chronological order to calculate the closing balance at the end of each month.

## Answer
The closing balance for each customer was calculated by first determining the net transaction change for every month and then applying a cumulative sum across the months.

Months with no customer transactions were assigned a net change of `0`, allowing the previous month's closing balance to be carried forward.

A positive closing balance indicates that cumulative deposits exceeded purchases and withdrawals, while a negative closing balance indicates that cumulative outgoing transactions exceeded deposits.

---

# Question 5

## Question
What is the percentage of customers who increase their closing balance by more than 5%?

## Solution

```sql
WITH
    customers AS (
        SELECT DISTINCT
            customer_id
        FROM
            data_bank.customer_transactions
    ),
    months AS (
        SELECT
            GENERATE_SERIES (
                DATE_TRUNC ('month', MIN(txn_date)),
                DATE_TRUNC ('month', MAX(txn_date)),
                INTERVAL '1 month'
            )::DATE AS month
        FROM
            data_bank.customer_transactions
    ),
    customer_months AS (
        SELECT
            c.customer_id,
            m.month
        FROM
            customers AS c
            CROSS JOIN months AS m
    ),
    monthly_transactions AS (
        SELECT
            customer_id,
            DATE_TRUNC ('month', txn_date)::DATE AS month,
            SUM(
                CASE
                    WHEN txn_type = 'deposit' THEN txn_amount
                    WHEN txn_type in ('purchase', 'withdrawal') THEN - txn_amount
                    ELSE 0
                END
            ) AS monthly_net_change
        FROM
            data_bank.customer_transactions
        GROUP BY
            customer_id,
            month
    ),
    complete_monthly_transaction AS (
        SELECT
            cm.customer_id,
            cm.month,
            COALESCE(mt.monthly_net_change, 0) AS monthly_net_change
        FROM
            customer_months AS cm
            LEFT JOIN monthly_transactions AS mt 
                ON cm.customer_id = mt.customer_id
            AND cm.month = mt.month
    ),
    closing_balance AS (
        SELECT
            customer_id,
            month,
            monthly_net_change,
            SUM(monthly_net_change) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    month
            ) AS closing_balance
        FROM
            complete_monthly_transaction
    ),
    balance_growth AS (
        SELECT
            *,
            LAG (closing_balance) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    month
            ) AS prev_closing_balance
        FROM
            closing_balance
    )
SELECT
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN prev_closing_balance > 0
                AND closing_balance > prev_closing_balance * 1.05 THEN customer_id
            END
        ) / COUNT(DISTINCT customer_id),
        2
    ) AS customer_percentage
FROM
    balance_growth;
```

## Output

| customer_percentage |
| ------------------- |
| 37.00               |

## Approach 
1. Generate a complete customer-month grid so that months without transactions are still included.
2. Calculate each customer's monthly net change by adding deposits and subtracting purchases and withdrawals.
3. Apply a cumulative sum to determine the closing balance for each customer at the end of every month.
4. Use `LAG()` to retrieve the previous month's closing balance.
5. Identify customers whose closing balance increased by more than 5% compared with the previous month.
6. Count each qualifying customer once and divide by the total number of customers to calculate the percentage.

## Answer
37.00% of customers increased their closing balance by more than 5% compared with at least one previous month.

Only comparisons where the previous closing balance was positive were considered valid for the growth test. Each qualifying customer was counted once, and the result was divided by the total number of customers.

