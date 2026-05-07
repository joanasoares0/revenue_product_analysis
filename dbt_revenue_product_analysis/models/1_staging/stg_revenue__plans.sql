with source as (

    select * 
    from {{ ref('plans') }}

),

cleaned as (

    select
        -- keys 
        {{ dbt_utils.generate_surrogate_key(['plan_id']) }} as sk_plan_id, -- noqa: TMP,PRS
        trim(plan_id)                                       as plan_id,

        -- attributes 
        lower(trim(plan_name))                              as plan_name,
        cast(monthly_price as decimal(10, 2))               as monthly_price,
        cast(annual_price as decimal(10, 2))                as annual_price,
        cast(tier as int)                                   as tier,
        cast(max_seats as int)                              as max_seats,
        lower(trim(features))                               as features,

        -- audit 
        current_timestamp()                                 as _stg_loaded_at

    from source
    where trim(plan_id) is not null

)

select * 
from cleaned