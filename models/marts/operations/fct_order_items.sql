with order_items as (
    select * from {{ ref('stg_jaffle_shop__order_items') }}
),

products as (
    select * from {{ ref('dim_products') }}
),

final as (
    select
        order_items.order_item_id,
        order_items.order_id,
        order_items.product_id,
        products.product_type,
        products.product_price,
        products.supply_cost,
        products.gross_margin
    from order_items
    left join products on order_items.product_id = products.product_id
)

select * from final
