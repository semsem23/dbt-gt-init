{% snapshot orders_snapshot %}

{{
    config(
      unique_key='id',
      strategy='check',
      check_cols=['status'],
    )
}}

select * from {{ source('jaffle_shop', 'orders') }}

{% endsnapshot %}