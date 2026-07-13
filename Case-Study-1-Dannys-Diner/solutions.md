# Question 1

## Question
What is the total amount each customer spent at the restaurant?

## Solution

```sql
SELECT
    s.customer_id,
    SUM(m.price) AS total_amount_spent
FROM
    dannys_diner.sales AS s
JOIN dannys_diner.menu AS m 
    ON s.product_id = m.product_id
GROUP BY
    s.customer_id
ORDER BY
    s.customer_id;
```

## Output

| customer_id | total_amount_spent |
| ----------- | ------------------ |
| A           | 76                 |
| B           | 74                 |
| C           | 36                 |

## Answer

- **Customer A:** $76
- **Customer B:** $74
- **Customer C:** $36


# Question 2

## Question
How many days has each customer visited the restaurant?

## Solution

```sql
SELECT
    customer_id,
    COUNT(DISTINCT order_date) AS number_of_days
FROM
    dannys_diner.sales
GROUP BY
    customer_id
ORDER BY
    customer_id;
```

## Output

| customer_id | number_of_days |
| ----------- | -------------- |
| A           | 4              |
| B           | 6              |
| C           | 2              |

## Answer
- **Customer A:** 4
- **Customer B:** 6
- **Customer C:** 2


# Question 3

## Question
What was the first item from the menu purchased by each customer?

## Solution

```sql
WITH
    ranked_sales AS (
        SELECT
            s.customer_id,
            m.product_name,
            DENSE_RANK() OVER (
                PARTITION BY
                    s.customer_id
                ORDER BY
                    s.order_date ASC
            ) AS purchased_rank
        FROM
            dannys_diner.sales AS s
        JOIN dannys_diner.menu AS m 
            ON s.product_id = m.product_id
    )
SELECT DISTINCT
    customer_id,
    product_name
FROM
    ranked_sales
WHERE
    purchased_rank = 1;
```

## Output

| customer_id | product_name |
| ----------- | ------------ |
| A           | curry        |
| A           | sushi        |
| B           | curry        |
| C           | ramen        |

## Approach 
"Created a Common Table Expression (CTE) to store ranked customer purchases based on order date. Used DENSE_RANK() to identify each customer's earliest purchase date and filtered rank 1 records to get their first purchased item(s)."

## Answer
- **Customer A:** curry and sushi
- **Customer B:** curry
- **Customer C:** ramen


# Question 4

## Question
What is the most purchased item on the menu and how many times was it purchased by all customers?

## Solution

```sql
SELECT
    m.product_name,
    COUNT(s.product_id) AS total_purchase_count
FROM
    dannys_diner.menu AS m
JOIN dannys_diner.sales AS s 
    ON s.product_id = m.product_id
GROUP BY
    m.product_name
ORDER BY
    total_purchase_count DESC
LIMIT
    1;
```

## Output

| product_name | total_purchase_count |
| ------------ | -------------------- |
| ramen        | 8                    |

## Approach
Counted total purchases for each menu item, sorted the results in descending order, and selected the highest purchased item.

## Answer
Ramen was the most purchased item on the menu with a total of 8 purchases.


# Question 5

## Question
Which item was the most popular for each customer?

## Solution

```sql
WITH
    rank_item AS (
        SELECT
            s.customer_id,
            m.product_name,
            COUNT(*) AS order_count,
            DENSE_RANK() OVER (
                PARTITION BY
                    s.customer_id
                ORDER BY
                    COUNT(*) DESC
            ) as order_rank
        FROM
            dannys_diner.sales AS s
        JOIN dannys_diner.menu AS m 
            ON s.product_id = m.product_id
        GROUP BY
            s.customer_id,
            m.product_name
    )
SELECT
    customer_id,
    product_name,
    order_count
FROM
    rank_item
WHERE
    order_rank = 1;
```

## Output

| customer_id | product_name | order_count |
| ----------- | ------------ | ----------- |
| A           | ramen        | 3           |
| B           | sushi        | 2           |
| B           | curry        | 2           |
| B           | ramen        | 2           |
| C           | ramen        | 3           |

## Approach
Created a CTE to get the rank the total purchase by each customer and filtered rank 1 records to find out which item was the most pupular for each customer. 

## Answer
Most popular item for Customer A and C is ramen, while customer B likes all 3 items


# Question 6

## Question
Which item was purchased first by the customer after they became a member?

## Solution

```sql
WITH
    joined_as_member AS (
        SELECT
            s.customer_id,
            s.product_id,
            DENSE_RANK() OVER (
                PARTITION BY
                    s.customer_id
                ORDER BY
                    s.order_date
            ) AS rank
        FROM
            dannys_diner.sales AS s
        JOIN dannys_diner.members AS m 
            ON s.customer_id = m.customer_id
        WHERE
            s.order_date > m.join_date
    )
SELECT
    j.customer_id,
    menu.product_name
FROM
    joined_as_member AS j
JOIN dannys_diner.menu AS menu 
    ON j.product_id = menu.product_id
WHERE
    rank = 1;
``` 

## Output

| customer_id | product_name |
| ----------- | ------------ |
| A           | ramen        |
| B           | sushi        |

## Approach
Created a CTE to get the product details after customer became the memeber and filtered rank 1 records to find out which item was purchased first after they became the member 

## Note 
Used order_date > join_date because the question asks after becoming a member. If membership starts from the joining date, >= can also be considered depending on business rules.

## Answer
Customer A purchased ramen first after becoming a member, while Customer B purchased sushi first.

# Question 7

## Question
Which item was purchased just before the customer became a member?

## Solution

```sql
WITH
    purchased_before AS (
        SELECT
            s.customer_id,
            s.product_id,
            DENSE_RANK() OVER (
                PARTITION BY
                    s.customer_id
                ORDER BY
                    s.order_date DESC
            ) AS rank
        FROM
            dannys_diner.sales AS s
        JOIN dannys_diner.members AS mem
            ON s.customer_id = mem.customer_id
        WHERE
            s.order_date < mem.join_date
    )
SELECT
    b.customer_id,
    m.product_name
from
    purchased_before AS b
JOIN dannys_diner.menu AS m 
    ON b.product_id = m.product_id
WHERE
    rank = 1
ORDER BY
    b.customer_id;
```

## Output

| customer_id | product_name |
| ----------- | ------------ |
| A           | curry        |
| A           | sushi        |
| B           | sushi        |

## Approach
Created a CTE to get the product details before customer became the member along with using DENSE_RANK to rank rows as per order_date in descending order and filtered rank 1 records to find out which item was purchased just before they became the member.

## Answer
Customer A purchased curry and sushi just before becoming a member. Customer B purchased sushi just before becoming a member.


# Question 8

## Question
What is the total items and amount spent for each member before they became a member?

## Solution

```sql
WITH
    purchased_before AS (
        SELECT
            s.customer_id,
            s.product_id
        FROM
            dannys_diner.sales AS s
        JOIN dannys_diner.members AS mem 
            ON s.customer_id = mem.customer_id
        WHERE
            s.order_date < mem.join_date
    )
SELECT
    b.customer_id,
    COUNT(b.product_id) AS total_items,
    SUM(m.price) AS total_spent
FROM
    purchased_before AS b
JOIN dannys_diner.menu AS m
    ON b.product_id = m.product_id
GROUP BY
    b.customer_id
ORDER BY
    b.customer_id;
```

## Output

| customer_id | total_items | total_spent |
| ----------- | ----------- | ----------- |
| A           | 2           | 25          |
| B           | 3           | 40          |

## Approach
Created a CTE to get the product details before customer became the member. Then joined it with menu table to get the price and count of items purchased by customer before becoming a member

## Answer
Customer A purchased 2 items and spent $25 before becoming a member. Customer B purchased 3 items and spent $40 before becoming a member.


# Question 9

## Question
If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

## Solution

```sql
SELECT
    s.customer_id,
    SUM(
        CASE
            WHEN m.product_name = 'sushi' THEN (m.price * 20)
            ELSE (m.price * 10)
        END
    ) AS total_points
FROM
    dannys_diner.sales AS s
JOIN dannys_diner.menu AS m 
    ON s.product_id = m.product_id
GROUP BY
    s.customer_id
ORDER BY
    s.customer_id;
```

## Output

| customer_id | total_points |
| ----------- | --------- |
| A           | 860       |
| B           | 940       |
| C           | 360       |

## Approach
Used CASE statement to apply different point calculations based on product type. Sushi purchases received a 2x multiplier while other products received standard points.

## Answer
Customer A earned 860 points, Customer B earned 940 points, and Customer C earned 360 points.


# Question 10

## Question
In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

## Solution

```sql
WITH
    points_calculator AS (
        Select
            s.customer_id,
            m.product_name,
            m.price,
            s.order_date,
            mem.join_date,
            CASE
                WHEN m.product_name = 'sushi' THEN price * 20
                WHEN s.order_date >= mem.join_date
                AND s.order_date <= mem.join_date + 6 THEN price * 20
                ELSE price * 10
            END AS points
        FROM
            dannys_diner.sales AS s
        JOIN dannys_diner.menu AS m 
            ON s.product_id = m.product_id
        JOIN dannys_diner.members AS mem 
            ON s.customer_id = mem.customer_id
        WHERE
            s.order_date <= '2021-01-31'
    );
Select
    customer_id,
    SUM(points) AS total_points
FROM
    points_calculator
GROUP BY
    customer_id
ORDER BY
    customer_id
```

## Output

| customer_id | total_points |
| ----------- | ------------ |
| A           | 1370         |
| B           | 820          |

## Approach
Created a CTE to calculate the points as per given condition using CASE statement to apply different point calculations based on product type.

## Answer
Customer A earned 1370 points and Customer B has earned 820 points by the end of January.