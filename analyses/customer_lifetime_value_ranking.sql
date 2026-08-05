-- Ad-hoc: rank customers by lifetime value.
-- `dbt compile` resolves this; it is NOT built by `dbt run`.
with customers as (
    select * from {{ ref('dim_customers') }}
)

select
    customer_id,
    first_name,
    last_name,
    number_of_orders,
    lifetime_value,
    row_number() over (order by lifetime_value desc) as ltv_rank
from customers
where lifetime_value is not null
order by lifetime_value desc