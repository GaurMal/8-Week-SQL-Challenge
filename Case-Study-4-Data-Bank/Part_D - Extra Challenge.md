# Part D: Non-Compounding Interest-Based Allocation

This section explores an additional data-allocation model in which customers receive extra data based on daily interest earned on their account balances.

The initial calculation uses a 6% annual interest rate without compounding, meaning previously earned interest is not added to the balance used for future interest calculations.

---

# Requirement

Data Bank wants to try another option which is a bit more difficult to implement - they want to calculate data growth using an interest calculation, just like in a traditional savings account you might have with a bank.

If the annual interest rate is set at 6% and the Data Bank team wants to reward its customers by increasing their data allocation based off the interest calculated on a daily basis at the end of each day, how much data would be required for this option on a monthly basis?

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
    daily_interest AS (
        SELECT
            customer_id,
            balance_date,
            account_balance,
            account_balance * 0.06 / 365 AS interest_amount
        FROM
            daily_account_balance
    )
SELECT
    DATE_TRUNC ('month', balance_date)::DATE AS allocation_month,
    ROUND(SUM(interest_amount), 2) AS interest_data_required
FROM
    daily_interest
GROUP BY
    allocation_month
ORDER BY
    allocation_month;
```

## Output 

| allocation_month | interest_data_required |
| ---------------- | ---------------------- |
| 2020-01-01       | 478.61                 |
| 2020-02-01       | 311.93                 |
| 2020-03-01       | -468.89                |
| 2020-04-01       | -1054.53               |

## Answer

Under the non-compounding interest option, each customer's daily interest is calculated using their end-of-day account balance and an annual interest rate of 6%.

The annual rate is divided by 365 to obtain the daily interest rate. This rate is applied independently to each day's account balance, and the resulting daily interest amounts are summed for each month. Since the calculation is non-compounding, previously earned interest is not added to the balance used for future interest calculations.

Based on this approach, Data Bank would require **478.61 additional data units** in January, **311.93 units** in February, **-468.89 units** in March and **-1,054.53 units** in April.

> **Note:** The challenge does not specify how negative account balances should affect interest-based data allocation. This solution retains the raw balances, which can produce negative interest amounts. In practice, an additional business rule would likely be required to prevent negative data allocation.

> **Note:** The April result may represent a partial month if the dataset ends before 30 April 2020.