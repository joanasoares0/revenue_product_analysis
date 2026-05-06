with source as (
 
    select * 
    from {{ source('revenue', 'users') }}
 
),
 
cleaned as (
 
    select
        -- keys 
        {{ dbt_utils.generate_surrogate_key(['user_id']) }}         as sk_user_id,
        trim(user_id)                                               as user_id,
        
        -- descriptions
        upper(trim(company_name))                                   as company_name,
        lower(trim(email))                                          as email,
        upper(trim(country))                                        as country,
        coalesce(trim(industry), 'unknown')                         as industry,
        coalesce(trim(acquisition_channel), 'unknown')              as acquisition_channel,
        
        -- derived descriptions        
        case trim(company_size)
            when '1-5'    then 'micro'
            when '6-20'   then 'small'
            when '21-50'  then 'medium'
            when '51-200' then 'large'
            else               'unknown'
        end                                                         as company_size,
 
        case trim(company_size)
            when '1-5'    then 1
            when '6-20'   then 2
            when '21-50'  then 3
            when '51-200' then 4
            else               0
        end                                                         as company_size_order,
 
        trim(company_size)                                          as company_size_raw,
        
        -- timestamps
        cast(created_at as date)                               as signed_up_at,
        date_trunc('month', cast(created_at as date))          as signup_month,
 
        -- flags 
        case
            when lower(trim(is_deleted)) = 'true'  then 1
            when lower(trim(is_deleted)) = 'false' then 0
            else 999999
        end                                                         as is_deleted,
        -- audit 
        current_timestamp()                                         as _stg_loaded_at
 
    from source
    where trim(user_id) is not null
)
 
select * 
from cleaned