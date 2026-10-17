with locations as (
    select * from {{ ref('stg_jaffle_shop__locations') }}
),

final as (
    select
        location_id,
        location_name,
        tax_rate,
        opened_at
    from locations
)

select * from final
