# Part A - Customer Journey

This section explores the subscription journeys of Foodie-Fi customers and highlights how customers transition between plans over time.

---

 # Question 1

## Question
Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.

Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!

Note: This question specifically references the 8 sample customers shown in the Foodie-Fi case study documentation. Therefore, customer IDs 1, 2, 11, 13, 15, 16, 18, and 19 were used to recreate and summarize their onboarding journeys as presented in the sample dataset.

## Solution

```sql
SELECT
    s.customer_id,
    p.plan_name,
    s.start_date
FROM
    foodie_fi.subscriptions AS s
    JOIN foodie_fi.plans AS p 
        ON s.plan_id = p.plan_id
WHERE
    s.customer_id in (1, 2, 11, 13, 15, 16, 18, 19)
ORDER BY
    s.customer_id,
    s.start_date;
```

## Output

| customer_id | plan_name     | start_date |
| ----------- | ------------- | ---------- |
| 1           | trial         | 2020-08-01 |
| 1           | basic monthly | 2020-08-08 |
| 2           | trial         | 2020-09-20 |
| 2           | pro annual    | 2020-09-27 |
| 11          | trial         | 2020-11-19 |
| 11          | churn         | 2020-11-26 |
| 13          | trial         | 2020-12-15 |
| 13          | basic monthly | 2020-12-22 |
| 13          | pro monthly   | 2021-03-29 |
| 15          | trial         | 2020-03-17 |
| 15          | pro monthly   | 2020-03-24 |
| 15          | churn         | 2020-04-29 |
| 16          | trial         | 2020-05-31 |
| 16          | basic monthly | 2020-06-07 |
| 16          | pro annual    | 2020-10-21 |
| 18          | trial         | 2020-07-06 |
| 18          | pro monthly   | 2020-07-13 |
| 19          | trial         | 2020-06-22 |
| 19          | pro monthly   | 2020-06-29 |
| 19          | pro annual    | 2020-08-29 |

## Answer
Customer 1 began with a trial plan on 1 August 2020 and subscribed to the Basic Monthly plan after completing the 7-day trial period.


Customer 2 began with a trial plan on 20 September 2020 and subscribed to the Pro Annual plan after completing the 7-day trial period.


Customer 11 began with a trial plan on 19 November 2020 and churned after completing the trial on 26 November 2020.


Customer 13 began with a trial plan on 15 December 2020, subscribed to the Basic Monthly plan on 22 December 2020 after completing the 7-day trial period, and later upgraded to the Pro Monthly plan on 29 March 2021.


Customer 15 began with a trial plan on 17 March 2020, subscribed to the Pro Monthly plan on 24 March 2020 after completing the 7-day trial period, and later transitioned to the Churn plan on 29 April 2020.


Customer 16 began with a trial plan on 31 May 2020, subscribed to the Basic Monthly plan on 7 June 2020 after completing the 7-day trial period, and later upgraded to the Pro Annual plan on 21 October 2020.


Customer 18 began with a trial plan on 6 July 2020 and subscribed to the Pro Monthly plan on 13 July 2020 after completing the 7-day trial period.


Customer 19 began with a trial plan on 22 June 2020, subscribed to the Pro Monthly plan on 29 June 2020 after completing the 7-day trial period, and later upgraded to the Pro Annual plan on 29 August 2020. 