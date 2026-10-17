select
    id as location_id,
    name as location_name,
    tax_rate,
    cast(opened_at as timestamp) as opened_at

from {{ source('jaffle_shop_raw', 'stores') }}
