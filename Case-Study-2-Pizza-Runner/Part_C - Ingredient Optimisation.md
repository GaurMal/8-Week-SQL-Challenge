# Part C - Ingredient Optimisation

This section explores pizza customization by analyzing ingredients, exclusions, extras, and overall ingredient usage across delivered orders.

---

# Question 1

## Question
What are the standard ingredients for each pizza?

## Solution

```sql
SELECT
    p.pizza_name,
    STRING_AGG (
        topping_name,
        ', '
        ORDER BY
            topping_name
    ) AS standard_ingredients
From
    pizza_runner.pizza_names AS p
    JOIN pizza_runner.normalized_pizza_recipes AS rec 
        ON p.pizza_id = rec.pizza_id
    JOIN pizza_runner.pizza_toppings AS t 
        ON rec.toppings_id = t.topping_id
GROUP BY
    p.pizza_name;
```

## Output

| pizza_name | standard_ingredients                                                  |
| ---------- | --------------------------------------------------------------------- |
| Meatlovers | Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami |
| Vegetarian | Cheese, Mushrooms, Onions, Peppers, Tomato Sauce, Tomatoes            |

## Approach
Joined pizza_names, normalized_pizza_recipes, and pizza_toppings to map each pizza to its default toppings, then used STRING_AGG() to consolidate the ingredients into a single comma-separated list for each pizza.

## Answer
The standard ingredients for Meatlovers are Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, and Salami. The standard ingredients for Vegetarian are Cheese, Mushrooms, Onions, Peppers, Tomatoes, and Tomato Sauce.

---

# Question 2

## Question
What was the most commonly added extra?

## Solution

```sql
WITH
    extra AS (
        SELECT
            toppings_id,
            COUNT(*) AS extra_count
        FROM
            pizza_runner.normalized_customer_modification
        WHERE
            modification_type = 'extras'
        GROUP BY
            toppings_id
    )
SELECT
    t.topping_name AS commonly_added_extra
FROM
    pizza_runner.pizza_toppings AS t
    JOIN extra AS e 
        ON t.topping_id = e.toppings_id
ORDER BY
    extra_count DESC
LIMIT
    1;
```

## Output

| commonly_added_extra |
| -------------------- |
| Bacon                |

## Answer
Bacon was the most commonly added extra topping.

---

# Question 3

## Question
What was the most common exclusion?

## Solution

```sql
WITH
    exclusions AS (
        SELECT
            toppings_id,
            COUNT(*) AS exclusion_count
        FROM
            pizza_runner.normalized_customer_modification
        WHERE
            modification_type = 'exclusions'
        GROUP BY
            toppings_id
    )
SELECT
    t.topping_name AS most_common_exclusion
FROM
    pizza_runner.pizza_toppings AS t
    JOIN exclusions AS e 
        ON t.topping_id = e.toppings_id
ORDER BY
    exclusion_count DESC
LIMIT
    1;
```

## Output

| most_common_exclusion |
| --------------------- |
| Cheese                |

## Answer
Cheese was the most commonly excluded topping.

--- 

# Question 4

## Question
Generate an order item for each record in the customers_orders table in the format of one of the following:
- Meat Lovers
- Meat Lovers - Exclude Beef
- Meat Lovers - Extra Bacon
- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

## Solution

```sql
WITH
    exclusions AS (
        SELECT
            line_item_id,
            CONCAT (
                '- Exclude ',
                String_AGG (
                    DISTINCT topping_name,
                    ', '
                    ORDER BY
                        topping_name
                )
            ) AS exclusions
        FROM
            pizza_runner.normalized_customer_modification AS mod
            JOIN pizza_runner.pizza_toppings AS t 
                ON mod.toppings_id = t.topping_id
        WHERE
            modification_type = 'exclusions'
        GROUP BY
            line_item_id
    ),
    extras AS (
        SELECT
            line_item_id,
            CONCAT (
                '- Extra ',
                String_AGG (
                    DISTINCT topping_name,
                    ', '
                    ORDER BY
                        topping_name
                )
            ) AS extras
        FROM
            pizza_runner.normalized_customer_modification AS mod
            JOIN pizza_runner.pizza_toppings AS t 
                ON mod.toppings_id = t.topping_id
        WHERE
            modification_type = 'extras'
        GROUP BY
            line_item_id
    )
SELECT
    c.order_id,
    c.customer_id,
    CONCAT (
        p.pizza_name,
        CASE
            WHEN exc.exclusions IS NOT NULL THEN ' ' || exc.exclusions
        END,
        CASE
            WHEN ext.extras IS NOT NULL THEN ' ' || ext.extras
        END
    ) AS order_item
FROM
    pizza_runner.cleaned_customer_orders AS c
    LEFT JOIN exclusions AS exc 
        ON c.line_item_id = exc.line_item_id
    LEFT JOIN extras AS ext 
        ON c.line_item_id = ext.line_item_id
    JOIN pizza_runner.pizza_names AS p 
        ON c.pizza_id = p.pizza_id;
```

## Output

| order_id | customer_id | order_item                                                      |
| -------- | ----------- | --------------------------------------------------------------- |
| 1        | 101         | Meatlovers                                                      |
| 2        | 101         | Meatlovers                                                      |
| 3        | 102         | Meatlovers                                                      |
| 3        | 102         | Vegetarian                                                      |
| 4        | 103         | Meatlovers - Exclude Cheese                                     |
| 4        | 103         | Meatlovers - Exclude Cheese                                     |
| 4        | 103         | Vegetarian - Exclude Cheese                                     |
| 5        | 104         | Meatlovers - Extra Bacon                                        |
| 6        | 101         | Vegetarian                                                      |
| 7        | 105         | Vegetarian - Extra Bacon                                        |
| 8        | 102         | Meatlovers                                                      |
| 9        | 103         | Meatlovers - Exclude Cheese - Extra Bacon, Chicken              |
| 10       | 104         | Meatlovers - Exclude BBQ Sauce, Mushrooms - Extra Bacon, Cheese |
| 10       | 104         | Meatlovers                                                      |

## Approach
Created separate CTEs to aggregate exclusions and extras for each pizza using STRING_AGG(). Then joined them back to cleaned_customer_orders and pizza_names, and used CONCAT() with conditional logic to generate a human-readable order description.

## Answer
Successfully generated a formatted description for each customer order record, including default pizzas as well as any exclusions and extras applied.

---

# Question 5

## Question
Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients

- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

## Solution

```sql
WITH
    exclusions AS (
        SELECT
            line_item_id,
            order_id,
            pizza_id,
            toppings_id
        FROM
            pizza_runner.normalized_customer_modification
        WHERE
            modification_type = 'exclusions'
    ),
    std_after_exc AS (
        SELECT
            c.line_item_id,
            c.order_id,
            c.customer_id,
            c.pizza_id,
            rec.toppings_id
        FROM
            pizza_runner.cleaned_customer_orders AS c
            JOIN pizza_runner.normalized_pizza_recipes AS rec 
                ON c.pizza_id = rec.pizza_id
            LEFT JOIN exclusions AS exc 
                ON c.line_item_id = exc.line_item_id
            AND exc.toppings_id = rec.toppings_id
        WHERE
            exc.toppings_id IS NULL
    ),
    extras AS (
        SELECT
            c.line_item_id,
            c.order_id,
            c.customer_id,
            c.pizza_id,
            mod.toppings_id
        FROM
            pizza_runner.cleaned_customer_orders AS c
            JOIN pizza_runner.normalized_customer_modification AS mod 
                ON c.line_item_id = mod.line_item_id
        WHERE
            mod.modification_type = 'extras'
    ),
    all_ingredients AS (
        SELECT
            *
        FROM
            std_after_exc
        UNION ALL
        SELECT
            *
        FROM
            extras
    ),
    ingredients_count AS (
        SELECT
            line_item_id,
            order_id,
            customer_id,
            pizza_id,
            toppings_id,
            COUNT(*) AS toppings_count
        FROM
            all_ingredients
        GROUP BY
            line_item_id,
            order_id,
            customer_id,
            pizza_id,
            toppings_id
    )
SELECT
    i.line_item_id,
    i.order_id,
    i.customer_id,
    CONCAT (
        p.pizza_name,
        ': ',
        STRING_AGG (
            CASE
                WHEN i.toppings_count > 1 THEN i.toppings_count || 'x' || t.topping_name
                ELSE t.topping_name
            END,
            ', '
            ORDER BY
                t.topping_name
        )
    ) AS ingredients
FROM
    ingredients_count AS i
    JOIN pizza_runner.pizza_names AS p 
        ON i.pizza_id = p.pizza_id
    JOIN pizza_runner.pizza_toppings AS t 
        ON i.toppings_id = t.topping_id
GROUP BY
    i.line_item_id,
    i.order_id,
    i.customer_id,
    p.pizza_name
ORDER BY
    i.line_item_id;
```

## Output

| line_item_id | order_id | customer_id | ingredients                                                                         |
| ------------ | -------- | ----------- | ----------------------------------------------------------------------------------- |
| 1            | 1        | 101         | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |
| 2            | 2        | 101         | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |
| 3            | 3        | 102         | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |
| 4            | 3        | 102         | Vegetarian: Cheese, Mushrooms, Onions, Peppers, Tomato Sauce, Tomatoes              |
| 5            | 4        | 103         | Meatlovers: Bacon, BBQ Sauce, Beef, Chicken, Mushrooms, Pepperoni, Salami           |
| 6            | 4        | 103         | Meatlovers: Bacon, BBQ Sauce, Beef, Chicken, Mushrooms, Pepperoni, Salami           |
| 7            | 4        | 103         | Vegetarian: Mushrooms, Onions, Peppers, Tomato Sauce, Tomatoes                      |
| 8            | 5        | 104         | Meatlovers: 2xBacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami |
| 9            | 6        | 101         | Vegetarian: Cheese, Mushrooms, Onions, Peppers, Tomato Sauce, Tomatoes              |
| 10           | 7        | 105         | Vegetarian: Bacon, Cheese, Mushrooms, Onions, Peppers, Tomato Sauce, Tomatoes       |
| 11           | 8        | 102         | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |
| 12           | 9        | 103         | Meatlovers: 2xBacon, BBQ Sauce, Beef, 2xChicken, Mushrooms, Pepperoni, Salami       |
| 13           | 10       | 104         | Meatlovers: 2xBacon, Beef, 2xCheese, Chicken, Pepperoni, Salami                     |
| 14           | 10       | 104         | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |

## Approach 
Created separate CTEs to identify excluded toppings, retain the remaining standard recipe ingredients, and append any extra toppings using UNION ALL. Then counted each topping at the individual pizza-record level using line_item_id, formatted repeated ingredients with an Nx prefix, and used STRING_AGG() to produce an alphabetically ordered ingredient list for each pizza.

## Answer 
Successfully generated an alphabetically ordered ingredient list for every pizza record after applying exclusions and extras, with repeated ingredients labelled using the appropriate quantity prefix such as 2xBacon.

---

# Question 6

## Question
What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

## Solution

```sql
WITH
    delivered_order_items AS (
        SELECT
            c.*
        FROM
            pizza_runner.cleaned_customer_orders AS c
            JOIN pizza_runner.cleaned_runner_orders AS r 
                ON c.order_id = r.order_id
        WHERE
            r.cancellation IS NULL
    ),
    exclusions AS (
        SELECT
            line_item_id,
            order_id,
            pizza_id,
            toppings_id
        FROM
            pizza_runner.normalized_customer_modification
        WHERE
            modification_type = 'exclusions'
    ),
    std_after_exc AS (
        SELECT
            d.line_item_id,
            d.order_id,
            d.customer_id,
            d.pizza_id,
            rec.toppings_id
        FROM
            delivered_order_items AS d
            JOIN pizza_runner.normalized_pizza_recipes AS rec 
                ON d.pizza_id = rec.pizza_id
            LEFT JOIN exclusions AS exc 
                ON d.line_item_id = exc.line_item_id
            AND exc.toppings_id = rec.toppings_id
        WHERE
            exc.toppings_id IS NULL
    ),
    extras AS (
        SELECT
            d.line_item_id,
            d.order_id,
            d.customer_id,
            d.pizza_id,
            mod.toppings_id
        FROM
            delivered_order_items AS d
            JOIN pizza_runner.normalized_customer_modification AS mod 
                ON d.line_item_id = mod.line_item_id
        WHERE
            mod.modification_type = 'extras'
    ),
    all_ingredients AS (
        SELECT
            *
        FROM
            std_after_exc
        UNION ALL
        SELECT
            *
        FROM
            extras
    ),
    ingredients_count AS (
        SELECT
            toppings_id,
            COUNT(*) AS toppings_count
        FROM
            all_ingredients
        GROUP BY
            toppings_id
    )
SELECT
    t.topping_name,
    i.toppings_count
FROM
    ingredients_count AS i
    JOIN pizza_runner.pizza_toppings AS t 
        ON i.toppings_id = t.topping_id
ORDER BY
    i.toppings_count DESC,
    t.topping_name;
```

## Output

| topping_name | toppings_count |
| ------------ | -------------- |
| Bacon        | 12             |
| Mushrooms    | 11             |
| Cheese       | 10             |
| Beef         | 9              |
| Chicken      | 9              |
| Pepperoni    | 9              |
| Salami       | 9              |
| BBQ Sauce    | 8              |
| Onions       | 3              |
| Peppers      | 3              |
| Tomato Sauce | 3              |
| Tomatoes     | 3              |

## Approach 
Filtered the data to include only successfully delivered orders, then rebuilt the final ingredient composition for each pizza by removing exclusions and adding extras. After combining all ingredients with UNION ALL, counted each topping across all delivered pizzas and sorted the results from most to least frequently used.

## Answer
Bacon was the most frequently used ingredient with 12 occurrences, followed by Mushrooms with 11 and Cheese with 10. Pepperoni, Salami, Chicken, and Beef were each used 9 times, while Tomato Sauce, Onions, Peppers, and Tomatoes were each used 3 times.