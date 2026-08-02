# Part C: Data Allocation Challenge

Data Bank links its cloud data-storage offering to the financial activity and balances of its customers.

This section explores different methods for determining how much data should be allocated to each customer based on their account balance.

The analysis compares several allocation models, including running balances, monthly closing balances, and monthly average balances, to understand how each approach affects the total amount of data that Data Bank would need to provision.

---

## Index

| Section | Description |
|---------|-------------|
| [Section 1](#1-running-customer-balance) | Running customer balance after each transaction |
| [Section 2](#2-customer-balance-at-the-end-of-each-month) | Customer closing balance at month-end |
| [Section 3](#3-minimum-average-and-maximum-values-of-the-running-customer-balance) | Minimum, average and maximum running balances |
| [Section 4](#4-option-1-previous-month-end-balance-allocation) | Allocation based on previous month-end balance |
| [Section 5](#5-option-2-previous-30-day-average-balance-allocation) | Allocation based on previous 30-day average balance |
| [Section 6](#6-option-3-real-time-data-allocation) | Allocation based on real-time balances |

---

# Requirement

To test out a few different hypotheses, the Data Bank team wants to run an experiment where different groups of customers would be allocated data using three different options:

- **Option 1:** Data is allocated based on the amount of money at the end of the previous month.
- **Option 2:** Data is allocated based on the average amount of money kept in the account during the previous 30 days.
- **Option 3:** Data is updated in real time.

To estimate how much data needs to be provisioned for each option, generate the following:

- Running customer balance after every transaction
- Customer balance at the end of each month
- Minimum, average and maximum running balance for each customer
- Monthly data required under each allocation option

---

# 1. Running Customer Balance

## Question

Calculate the running customer balance after applying the impact of each transaction.

## Solution

```sql
WITH
    transaction_change AS (
        SELECT
            customer_id,
            txn_date,
            txn_type,
            txn_amount,
            CASE
                WHEN txn_type = 'deposit' THEN txn_amount
                WHEN txn_type IN ('purchase', 'withdrawal') THEN - txn_amount
                ELSE 0
            END AS txn_change
        FROM
            data_bank.customer_transactions
    )
SELECT
    *,
    SUM(txn_change) OVER (
        PARTITION BY
            customer_id
        ORDER BY
            txn_date
    ) AS running_balance
FROM
    transaction_change
ORDER BY
    customer_id,
    txn_date
LIMIT
    10;
```

## Output

| customer_id | txn_date   | txn_type   | txn_amount | txn_change | running_balance |
| ----------- | ---------- | ---------- | ---------- | ---------- | --------------- |
| 1           | 2020-01-02 | deposit    | 312        | 312        | 312             |
| 1           | 2020-03-05 | purchase   | 612        | -612       | -300            |
| 1           | 2020-03-17 | deposit    | 324        | 324        | 24              |
| 1           | 2020-03-19 | purchase   | 664        | -664       | -640            |
| 2           | 2020-01-03 | deposit    | 549        | 549        | 549             |
| 2           | 2020-03-24 | deposit    | 61         | 61         | 610             |
| 3           | 2020-01-27 | deposit    | 144        | 144        | 144             |
| 3           | 2020-02-22 | purchase   | 965        | -965       | -821            |
| 3           | 2020-03-05 | withdrawal | 213        | -213       | -1034           |
| 3           | 2020-03-19 | withdrawal | 188        | -188       | -1222           |

## Answer
Deposits increase the customer balance, while purchases and withdrawals reduce it. The running balance shows the customer's account balance after each transaction.

---

# 2. Customer Balance at the End of Each Month

## Question

Calculate the customer balance at the end of each month.

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

## Answer
The monthly net change is calculated by adding deposits and subtracting purchases and withdrawals for each customer. The closing balance is then derived as the cumulative monthly balance.

Months without any transactions are included with a monthly net change of **0**, allowing the previous month's closing balance to be carried forward correctly.

---

# 3. Minimum, average and maximum values of the running customer balance

## Question

Calculate the minimum, average and maximum values of the running balance for each customer.

## Solution

```sql
WITH
    transaction_change AS (
        SELECT
            customer_id,
            txn_date,
            txn_type,
            txn_amount,
            CASE
                WHEN txn_type = 'deposit' THEN txn_amount
                WHEN txn_type IN ('purchase', 'withdrawal') THEN - txn_amount
                ELSE 0
            END AS txn_change
        FROM
            data_bank.customer_transactions
    ),
    running_balance AS (
        SELECT
            *,
            SUM(txn_change) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    txn_date
            ) AS running_balance
        FROM
            transaction_change
    )
SELECT
    customer_id,
    MIN(running_balance) AS min_running_bal,
    ROUND(AVG(running_balance), 2) AS avg_running_bal,
    MAX(running_balance) AS max_running_bal
FROM
    running_balance
GROUP BY
    customer_id
ORDER BY
    customer_id
LIMIT
    10;
```

## Output

| customer_id | min_running_bal | avg_running_bal | max_running_bal |
| ----------- | --------------- | --------------- | --------------- |
| 1           | -640            | -151.00         | 312             |
| 2           | 549             | 579.50          | 610             |
| 3           | -1222           | -732.40         | 144             |
| 4           | 458             | 653.67          | 848             |
| 5           | -2413           | -135.45         | 1780            |
| 6           | -552            | 624.00          | 2197            |
| 7           | 887             | 2268.69         | 3539            |
| 8           | -1029           | 173.70          | 1363            |
| 9           | -91             | 1021.70         | 2030            |
| 10          | -5090           | -2229.83        | 556             |

## Answer
The minimum, average and maximum running balances were calculated for each customer using their balance after every transaction.

For example, Customer 1 had a minimum running balance of **-640**, an average running balance of **-151.00**, and a maximum running balance of **312**.

---

# 4. Option 1: Previous Month-End Balance Allocation

## Question

Calculate the total amount of data that would be allocated each month based on each customer's closing balance from the previous month.

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
    prev_month_bal AS (
        SELECT
            customer_id,
            month,
            LAG (closing_balance) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    month
            ) AS prev_month_balance
        FROM
            closing_balance
    )
SELECT
    month,
    SUM(prev_month_balance) AS allocated_data
FROM
    prev_month_bal
WHERE
    prev_month_balance IS NOT NULL
GROUP BY
    month
ORDER BY
    month;
```

## Output

| month      | allocated_data |
| ---------- | -------------- |
| 2020-02-01 | 126091         |
| 2020-03-01 | -13708         |
| 2020-04-01 | -184592        |

> **Note:** The challenge does not specify how negative account balances should affect data allocation. The solution uses the raw previous-month closing balances. In a production system, a business rule such as allocating zero data to customers with negative balances would likely be required.

## Answer
Under Option 1, each customer's monthly data allocation is based on their closing balance from the previous month.

Using the raw previous-month closing balances, Data Bank would allocate **126,091 units** in February, **-13,708 units** in March, and **-184,592 units** in April.

January is excluded because no previous-month balance is available within the dataset. The negative totals occur because the combined closing balances across customers were below zero.

---

# 5. Option 2: Previous 30-Day Average Balance Allocation

## Question

Calculate the total amount of data that would be allocated each month based on average amount of money kept in the account in the previous 30 days.

## Solution

```sql
WITH
    customers AS (
        SELECT DISTINCT
            customer_id
        FROM
            data_bank.customer_transactions
    ),
    dates AS (
        SELECT
            GENERATE_SERIES (MIN(txn_date), MAX(txn_date), INTERVAL '1 day')::DATE AS balance_date
        FROM
            data_bank.customer_transactions
    ),
    customer_dates AS (
        SELECT
            c.customer_id,
            d.balance_date
        FROM
            customers AS c
            CROSS JOIN dates AS d
    ),
    daily_transaction AS (
        SELECT
            customer_id,
            txn_date,
            SUM(
                CASE
                    WHEN txn_type = 'deposit' THEN txn_amount
                    WHEN txn_type in ('purchase', 'withdrawal') THEN - txn_amount
                    ELSE 0
                END
            ) AS daily_net_change
        FROM
            data_bank.customer_transactions
        GROUP BY
            customer_id,
            txn_date
    ),
    complete_daily_transaction AS (
        SELECT
            cd.customer_id,
            cd.balance_date,
            COALESCE(dt.daily_net_change, 0) AS daily_net_change
        FROM
            customer_dates AS cd
            LEFT JOIN daily_transaction AS dt 
                ON cd.customer_id = dt.customer_id
            AND cd.balance_date = dt.txn_date
    ),
    daily_account_balance AS (
        SELECT
            customer_id,
            balance_date,
            SUM(daily_net_change) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    balance_date
            ) AS account_balance
        FROM
            complete_daily_transaction
    ),
    rolling_30_day_balance AS (
        SELECT
            customer_id,
            balance_date,
            account_balance,
            AVG(account_balance) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    balance_date ROWS BETWEEN 29 PRECEDING
                    AND CURRENT ROW
            ) AS avg_30_day_balance,
            COUNT(*) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    balance_date ROWS BETWEEN 29 PRECEDING
                    AND CURRENT ROW
            ) AS days_in_window
        FROM
            daily_account_balance
    ),
    month_end_customer_avg AS (
        SELECT
            customer_id,
            balance_date,
            avg_30_day_balance
        FROM
            rolling_30_day_balance
        WHERE
            days_in_window = 30
            AND balance_date = DATE_TRUNC ('month', balance_date) + INTERVAL '1 month' - INTERVAL '1 day'
    )
SELECT
    (balance_date + INTERVAL '1 day')::DATE AS allocation_month,
    ROUND(SUM(avg_30_day_balance), 2) AS allocated_data
FROM
    month_end_customer_avg
GROUP BY
    balance_date
ORDER BY
    balance_date;
```

## Output

| allocation_month | allocated_data |
| ---------------- | -------------- |
| 2020-02-01       | 96655.20       |
| 2020-03-01       | 67455.70       |
| 2020-04-01       | -94313.43      |

## Answer
Under Option 2, each customer's monthly data allocation is based on their average account balance over the previous 30 days.

The daily transaction changes are first converted into cumulative daily account balances. A rolling 30-day average is then calculated for each customer using the current day and the previous 29 days. Only complete 30-day windows are included, and each month-end average is used to calculate the following month's allocation.

Based on this approach, Data Bank would allocate **96,655.20 units** in February, **67,455.70 units** in March and **-94,313.43 units** in April.

> **Note:** The challenge does not specify how negative average balances should affect data allocation. This solution retains the raw calculated balances. In practice, an additional business rule would be required to handle negative allocations.

---

# 6. Option 3: Real-Time Data Allocation

## Question
Calculate the total amount of data that would be allocated each month based on data updated real-time.

## Solution

```sql
WITH
    customers AS (
        SELECT DISTINCT
            customer_id
        FROM
            data_bank.customer_transactions
    ),
    dates AS (
        SELECT
            GENERATE_SERIES (MIN(txn_date), MAX(txn_date), INTERVAL '1 day')::DATE AS balance_date
        FROM
            data_bank.customer_transactions
    ),
    customer_dates AS (
        SELECT
            c.customer_id,
            d.balance_date
        FROM
            customers AS c
            CROSS JOIN dates AS d
    ),
    daily_transaction AS (
        SELECT
            customer_id,
            txn_date,
            SUM(
                CASE
                    WHEN txn_type = 'deposit' THEN txn_amount
                    WHEN txn_type in ('purchase', 'withdrawal') THEN - txn_amount
                    ELSE 0
                END
            ) AS daily_net_change
        FROM
            data_bank.customer_transactions
        GROUP BY
            customer_id,
            txn_date
    ),
    complete_daily_transaction AS (
        SELECT
            cd.customer_id,
            cd.balance_date,
            COALESCE(dt.daily_net_change, 0) AS daily_net_change
        FROM
            customer_dates AS cd
            LEFT JOIN daily_transaction AS dt ON cd.customer_id = dt.customer_id
            AND cd.balance_date = dt.txn_date
    ),
    daily_account_balance AS (
        SELECT
            customer_id,
            balance_date,
            SUM(daily_net_change) OVER (
                PARTITION BY
                    customer_id
                ORDER BY
                    balance_date
            ) AS account_balance
        FROM
            complete_daily_transaction
    ),
    month_end_balance AS (
        SELECT
            customer_id,
            balance_date,
            account_balance
        FROM
            daily_account_balance
        WHERE
            balance_date = DATE_TRUNC ('month', balance_date) + INTERVAL '1 month' - INTERVAL '1 day'
    )
SELECT
    balance_date AS allocation_month,
    SUM(account_balance) AS allocated_data
FROM
    month_end_balance
GROUP BY
    balance_date
ORDER BY
    balance_date;
```

## Output

| allocation_month | allocated_data |
| ---------------- | -------------- |
| 2020-01-31       | 126091         |
| 2020-02-29       | -13708         |
| 2020-03-31       | -184592        |

## Answer
Under Option 3, each customer’s data allocation is updated in real time based on their current account balance.

The daily transaction amounts are first converted into net balance changes, where deposits increase the balance and purchases or withdrawals decrease it. These daily changes are then accumulated to calculate each customer’s account balance on every date. The month-end balances are summed to represent the total real-time data allocation for each month.

Based on this approach, Data Bank would allocate 126,091 units at the end of January, -13,708 units at the end of February and -184,592 units at the end of March.

> **Note:** The challenge does not specify how negative account balances should affect real-time data allocation. This solution retains the raw calculated balances. In practice, an additional business rule would likely be required to prevent negative data allocations.