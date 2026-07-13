# Question 1

## Question
Join All The Things

## Solution

```sql
Select
    s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE
        WHEN mem.join_date IS NOT NULL
        AND s.order_date >= mem.join_date THEN 'Y'
        ELSE 'N'
    END AS member
FROM
    dannys_diner.sales AS s
    JOIN dannys_diner.menu AS m ON s.product_id = m.product_id
LEFT JOIN dannys_diner.members AS mem 
    ON s.customer_id = mem.customer_id
ORDER BY
    s.customer_id,
    s.order_date,
    m.product_name
```

## Output

| customer_id | order_date | product_name | price | member |
| ----------- | ---------- | ------------ | ----- | ------ |
| A           | 2021-01-01 | curry        | 15    | N      |
| A           | 2021-01-01 | sushi        | 10    | N      |
| A           | 2021-01-07 | curry        | 15    | Y      |
| A           | 2021-01-10 | ramen        | 12    | Y      |
| A           | 2021-01-11 | ramen        | 12    | Y      |
| A           | 2021-01-11 | ramen        | 12    | Y      |
| B           | 2021-01-01 | curry        | 15    | N      |
| B           | 2021-01-02 | curry        | 15    | N      |
| B           | 2021-01-04 | sushi        | 10    | N      |
| B           | 2021-01-11 | sushi        | 10    | Y      |
| B           | 2021-01-16 | ramen        | 12    | Y      |
| B           | 2021-02-01 | ramen        | 12    | Y      |
| C           | 2021-01-01 | ramen        | 12    | N      |
| C           | 2021-01-01 | ramen        | 12    | N      |
| C           | 2021-01-07 | ramen        | 12    | N      |

## Approach
Joined sales with menu to get product names and prices, then left joined members to keep all customers including non-members. Used CASE to mark each purchase as member = Y if the order date was on or after the customer's join date, otherwise member = N.

## Answer
The final table shows each customer's purchases with product details and a membership flag showing whether the customer was a member at the time of purchase.


# Question 2

## Question
Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases so he expects null ranking values for the records when customers are not yet part of the loyalty program.

## Solution

```sql
WITH
    combined_data AS (
        Select
            s.customer_id,
            s.order_date,
            m.product_name,
            m.price,
            CASE
                WHEN mem.join_date IS NOT NULL
                AND s.order_date >= mem.join_date THEN 'Y'
                ELSE 'N'
            END AS member
        FROM
            dannys_diner.sales AS s
            JOIN dannys_diner.menu AS m ON s.product_id = m.product_id
            LEFT JOIN dannys_diner.members AS mem ON s.customer_id = mem.customer_id
    )
    
SELECT
    *,
    CASE
        WHEN member = 'N' THEN NULL
        ELSE RANK() OVER (
            PARTITION BY
                customer_id,
                member
            ORDER BY
                order_date
        )
    END AS ranking
FROM
    combined_data
ORDER BY
    s.customer_id,
    s.order_date,
    m.product_name
``` 

## Output

| customer_id | order_date | product_name | price | member | ranking |
| ----------- | ---------- | ------------ | ----- | ------ | ------- |
| A           | 2021-01-01 | curry        | 15    | N      | null    |
| A           | 2021-01-01 | sushi        | 10    | N      | null    |
| A           | 2021-01-07 | curry        | 15    | Y      | 1       |
| A           | 2021-01-10 | ramen        | 12    | Y      | 2       |
| A           | 2021-01-11 | ramen        | 12    | Y      | 3       |
| A           | 2021-01-11 | ramen        | 12    | Y      | 3       |
| B           | 2021-01-01 | curry        | 15    | N      | null    |
| B           | 2021-01-02 | curry        | 15    | N      | null    |
| B           | 2021-01-04 | sushi        | 10    | N      | null    |
| B           | 2021-01-11 | sushi        | 10    | Y      | 1       |
| B           | 2021-01-16 | ramen        | 12    | Y      | 2       |
| B           | 2021-02-01 | ramen        | 12    | Y      | 3       |
| C           | 2021-01-01 | ramen        | 12    | N      | null    |
| C           | 2021-01-01 | ramen        | 12    | N      | null    |
| C           | 2021-01-07 | ramen        | 12    | N      | null    |

## Approach
Created a CTE to combine sales, menu, and membership data with a member flag. Then used a CASE statement with RANK() to assign rankings only to member purchases, while keeping non-member purchases as NULL.

## Answer
Member purchases are ranked in order of purchase date for each customer, while all non-member purchases are shown with NULL ranking values.