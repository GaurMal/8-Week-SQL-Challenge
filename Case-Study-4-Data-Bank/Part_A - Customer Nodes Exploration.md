# Part A: Customer Nodes Exploration

This section explores how Data Bank customers are distributed across different regions and data nodes.

The analysis focuses on understanding the number of available nodes, customer distribution by region, node reallocation patterns, and the amount of time customers remain assigned to a particular node.

These questions provide an initial overview of the customer-node structure before moving into transaction and data-allocation analysis.

---

# Question 1

## Question
How many unique nodes are there on the Data Bank system?

## Solution

```sql
SELECT
    COUNT(DISTINCT node_id) AS unique_nodes_count
FROM
    data_bank.customer_nodes;
```

## Output

| unique_nodes_count |
| ------------------ |
| 5                  |

## Answer
The Data Bank system consists of **5 unique nodes**, which are used to allocate customers across different regions.

---

# Question 2

## Question
What is the number of nodes per region?

## Solution

```sql
SELECT
    r.region_name,
    COUNT(DISTINCT n.node_id) AS nodes_count
FROM
    data_bank.customer_nodes AS n
    JOIN data_bank.regions AS r 
        ON n.region_id = r.region_id
GROUP BY
    r.region_name
ORDER BY
    r.region_name;
```

## Output

| region_name | nodes_count |
| ----------- | ----------- |
| Africa      | 5           |
| America     | 5           |
| Asia        | 5           |
| Europe      | 5           |
| Oceania     | 5           |

## Answer
There are 3,500 customer-node records distributed across the five regions. Africa has the highest count (770), while Oceania has the lowest (616).

---

# Question 3

## Question
How many customers are allocated to each region?

## Solution

```sql
SELECT
    r.region_name,
    COUNT(DISTINCT n.customer_id) AS customers_count
FROM
    data_bank.customer_nodes AS n
    JOIN data_bank.regions AS r 
        ON n.region_id = r.region_id
GROUP BY
    r.region_name
ORDER BY
    customers_count DESC;
```

## Output

| region_name | customers_count |
| ----------- | --------------- |
| Africa      | 110             |
| America     | 105             |
| Asia        | 102             |
| Europe      | 95              |
| Oceania     | 88              |

## Answer
There are **500 customers** distributed across the five regions. Africa has the highest number of customers (110), while Oceania has the lowest (88).

---

# Question 4

## Question
How many days on average are customers reallocated to a different node?

## Solution

```sql
SELECT
    ROUND(AVG(end_date - start_date), 2) AS avg_reallocation_days
FROM
    data_bank.customer_nodes
WHERE
    end_date != '9999-12-31';
```

## Output

| avg_reallocation_days |
| --------------------- |
| 14.63                 |

## Answer
Customers are reallocated to a different node after an average of **14.63 days**.

---

# Question 5

## Question
What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

## Solution

```sql
SELECT
    r.region_name,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY
            n.end_date - n.start_date
    ) AS median_days,
    PERCENTILE_CONT(0.8) WITHIN GROUP (
        ORDER BY
            n.end_date - n.start_date
    ) AS percentile_80_days,
    PERCENTILE_CONT(0.95) WITHIN GROUP (
        ORDER BY
            n.end_date - n.start_date
    ) AS percentile_95_days
FROM
    data_bank.customer_nodes AS n
    JOIN data_bank.regions AS r 
        ON n.region_id = r.region_id
WHERE
    end_date != '9999-12-31'
GROUP BY
    r.region_name;
```

## Output

| region_name | median_days | percentile_80_days | percentile_95_days |
| ----------- | ----------- | ------------------ | ------------------ |
| Africa      | 15          | 23                 | 28                 |
| America     | 15          | 23                 | 28                 |
| Asia        | 15          | 24                 | 28                 |
| Europe      | 15          | 23                 | 28                 |
| Oceania     | 15          | 24                 | 28                 |

## Answer
The median reallocation period is **15 days across all five regions**.

The 80th percentile ranges from **23 to 24 days**, while the 95th percentile is **28 days across every region**. This shows that customer reallocation timing is broadly consistent across regions.

