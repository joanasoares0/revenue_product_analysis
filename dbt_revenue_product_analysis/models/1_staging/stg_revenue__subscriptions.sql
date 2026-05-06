with source as (
 
    select * from {{ source('revenue', 'subscriptions') }}
 
),
 
cleaned as (
 
    select
        -- keys 
        {{ dbt_utils.generate_surrogate_key(['subscription_id']) }} as sk_subscription_id,
        trim(subscription_id)                                       as subscription_id,
        trim(user_id)                                               as user_id,
        trim(plan_id)                                               as plan_id,
 
        -- attributes 
        lower(trim(billing_cycle))              as billing_cycle,
        lower(trim(status))                     as status,
        coalesce(lower(trim(replace(cancel_reason, '_', ' '))), 'not cancelled')  as cancel_reason,
 
        -- flags
        lower(trim(status)) = 'active'          as is_active,
        lower(trim(status)) = 'cancelled'       as is_churned,
        lower(trim(status)) = 'trial expired'   as is_trial_expired,
 
        -- metrics 
        cast(mrr as decimal(10, 2))                                 as mrr,
        cast(mrr * 12 as decimal(10, 2))                            as acv,
        -- timestamps 
        cast(trial_start        as date)                            as trial_start_date,
        cast(trial_end          as date)                            as trial_end_date,
        cast(subscription_start as date)                            as subscription_start_date,
        cast(subscription_end   as date)                            as subscription_end_date,
        cast(cancelled_at       as date)                            as cancelled_date,
        cast(subscription_end as date))                             as effective_end_date,
 
        -- derived durations 
        datediff(
            'day',
            cast(trial_start as date),
            coalesce(cast(trial_end   as date), current_date())
        )                                                           as trial_duration_days,
 
        case
            when cast(subscription_start as date) is not null
            then datediff(
                'day',
                cast(subscription_start as date),
                coalesce(cast(subscription_end as date), current_date())
            )
        end                                                         as subscription_duration_days,
 
        -- cohort 
        date_trunc('month', cast(trial_start as date))              as cohort_month,
 
        -- churn spike: Jul–Dec 2023 pricing event
        (
            lower(trim(replace(status, '_', ' '))) = 'cancelled'
            and cast(cancelled_at as date) >= cast('{{ var("mrr_spike_start") }}' as date)
            and cast(cancelled_at as date) <  cast('{{ var("mrr_spike_end") }}' as date)
        )                                                           as is_spike_churn,
 
        -- audit 
        current_timestamp()                                         as _stg_loaded_at
 
    from source
    where trim(subscription_id) is not null
)
 
select * 
from cleaned
