with source as (
 
    select * 
    from {{ source('revenue', 'payments') }}
 
),
 
cleaned as (
 
    select
        -- keys
        {{ dbt_utils.generate_surrogate_key(['payment_id']) }} as sk_payment_id,
        trim(payment_id)        as payment_id,
        trim(subscription_id)   as subscription_id,
        trim(user_id)           as user_id,
        trim(plan_id)           as plan_id,
 
        -- attributes 
        lower(trim(billing_cycle))     as billing_cycle,
        upper(trim(currency))   as currency,
        lower(trim(status))            as status,
 
        -- flags
        lower(trim(status)) = 'succeeded'  as is_revenue_recognised,
        lower(trim(status)) = 'failed'     as is_failed,
        lower(trim(status)) = 'refunded'   as is_refunded,
 
        -- metrics 
        cast(amount as decimal(10, 2))                      as amount,
        -- this metric is used to account for monthly input, even if billing cycle is annual (e.g. $1200 annual = $100 MRR)
         case lower(trim(billing_cycle))
            when 'monthly' then cast(amount as decimal(10, 2))
            when 'annual'  then round(cast(amount as decimal(10, 2)) / 12.0, 2)
        end                                                 as mrr_contribution, 
 
        -- timestamps 
        cast(payment_date  as date)                         as payment_date,
        date_format(cast(payment_date as date), 'yyyyMM')  as payment_month,
        cast(period_start  as date)                         as period_start,
        cast(period_end    as date)                         as period_end,
 
        datediff(
            DAY,
            cast(period_start as date),
            cast(period_end   as date)
        )                                                   as days_in_period,
 
        -- audit 
        current_timestamp()                                 as _stg_loaded_at
 
    from source
    where trim(payment_id) is not null
 
)

select *
from cleaned