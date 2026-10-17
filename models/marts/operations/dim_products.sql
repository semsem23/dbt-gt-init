with products as (
    select * from {{ ref('stg_jaffle_shop__products') }}
),

supplies as (
    select * from {{ ref('stg_jaffle_shop__supplies') }}
),

product_supplies as (
    select
        product_id,
        count(supply_id) as number_of_supplies,
        round(sum(supply_cost), 2) as supply_cost,
        logical_or(is_perishable) as has_perishable_supplies
    from supplies
    group by 1
),

final as (
    select
        products.product_id,
        products.product_name,
        products.product_type,
        products.product_description,
        products.product_price,
        coalesce(product_supplies.number_of_supplies, 0) as number_of_supplies,
        coalesce(product_supplies.supply_cost, 0) as supply_cost,
        round(
            products.product_price - coalesce(product_supplies.supply_cost, 0),
            2
        ) as gross_margin,
        coalesce(
            product_supplies.has_perishable_supplies, false
        ) as has_perishable_supplies
    from products
    left join product_supplies
        on products.product_id = product_supplies.product_id
)

select * from final
