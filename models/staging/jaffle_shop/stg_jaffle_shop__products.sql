select
    sku as product_id,
    name as product_name,
    type as product_type,
    description as product_description,
    {{ cents_to_dollars('price') }} as product_price

from {{ source('jaffle_shop_raw', 'products') }}
