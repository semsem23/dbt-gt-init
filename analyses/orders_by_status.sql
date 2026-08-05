-- Ad-hoc: order counts and revenue by readable status,
-- joining the fact table to the order_status_descriptions seed.
with orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),

order_amounts as (
    select * from {{ ref('fct_orders') }}
),

status_lookup as (
    select * from {{ ref('order_status_descriptions') }}
)

select
    status_lookup.status_description,
    status_lookup.is_completed,
    count(orders.order_id) as number_of_orders,
    sum(order_amounts.amount)  as total_amount
from orders
left join order_amounts using (order_id)
left join status_lookup  using (status)
group by 1, 2
order by number_of_orders desc