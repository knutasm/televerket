with source as (
    select * from {{ source("catalog", "products") }}
),

casts as (
    select
        product_code,
        product_name,
        category,
        monthly_fee_eur,
        data_gb,
        voice_min,
        valid_from::date as valid_from,
        valid_to::date as valid_to
    from source
)

select
    product_code,
    product_name,
    category,
    monthly_fee_eur,
    data_gb,
    voice_min,
    valid_from,
    valid_to
from casts
