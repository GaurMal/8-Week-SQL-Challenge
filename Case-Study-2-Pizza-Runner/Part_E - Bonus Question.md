# Part E - Bonus Question

This section demonstrates how the existing data model can support future business expansion by introducing a new Supreme pizza to the menu.

---

# Question 1

## Question
If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?

## Solution

```sql
INSERT INTO
    pizza_runner.pizza_names
VALUES
    (3, 'Supreme');

SELECT
    *
FROM
    pizza_runner.pizza_names;

INSERT INTO
    pizza_runner.pizza_recipes (pizza_id, toppings)
SELECT
    3,
    STRING_AGG (
        topping_id::TEXT,
        ', '
        ORDER BY
            topping_id
    )
FROM
    pizza_runner.pizza_toppings;
    
SELECT
    *
FROM
    pizza_runner.pizza_recipes;
```

## Output

| pizza_id | pizza_name |
| -------- | ---------- |
| 1        | Meatlovers |
| 2        | Vegetarian |
| 3        | Supreme    |

| pizza_id | toppings                              |
| -------- | ------------------------------------- |
| 1        | 1, 2, 3, 4, 5, 6, 8, 10               |
| 2        | 4, 6, 7, 9, 11, 12                    |
| 3        | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 |

## Approach
Leveraged the existing normalized data design by inserting a new pizza entry into pizza_names and dynamically generating its recipe using all available topping IDs from pizza_toppings with STRING_AGG(). This demonstrates that new pizza varieties can be added without changing the underlying schema.

## Answer
The current data model is scalable and supports the addition of new pizzas without requiring any structural changes. By adding a new record to pizza_names and its corresponding toppings to pizza_recipes, a new Supreme pizza containing all available toppings can be seamlessly introduced to the Pizza Runner menu.