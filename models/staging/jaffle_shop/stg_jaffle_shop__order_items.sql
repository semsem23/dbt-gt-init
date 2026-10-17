select
    id as order_item_id,
    order_id,
    sku as product_id

from {{ source('jaffle_shop_raw', 'order_items') }}
