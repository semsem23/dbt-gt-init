select
    {{ dbt_utils.generate_surrogate_key(['id', 'sku']) }} as supply_key,
    id as supply_id,
    sku as product_id,
    name as supply_name,
    {{ cents_to_dollars('cost') }} as supply_cost,
    perishable as is_perishable

from {{ source('jaffle_shop_raw', 'supplies') }}
