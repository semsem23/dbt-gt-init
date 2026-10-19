with order_items as (
    select * from {{ source('jaffle_shop_raw', 'order_items') }}
),

orders as (
    select * from {{ source('jaffle_shop_raw', 'orders') }}
)

select
    order_items.id as order_item_id,
    order_items.order_id,
    orders.store_id as location_id,
    order_items.sku as product_id

from order_items
left join orders on order_items.order_id = orders.id
