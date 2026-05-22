with source as (

    select * from {{ source('revenue', 'subscriptions') }}

),

cleaned as (

    select
        -- keys  -- noqa: LT02
        {{ dbt_utils.generate_surrogate_key(['subscription_id']) }} as sk_subscription_id, -- noqa: TMP,PRS,LT02,LT05
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
        -- A pricing change in Jul 2023 caused a 2× churn spike that lasted until Dec 2023.
        -- This flag isolates that cohort for waterfall analysis (see fct_mrr.is_spike_churn).
        -- Window is controlled by vars mrr_spike_start / mrr_spike_end in dbt_project.yml.
        (
            is_churned
            and cast(cancelled_at as date) >= cast('{{ var("mrr_spike_start") }}' as date)
            and cast(cancelled_at as date) <  cast('{{ var("mrr_spike_end") }}' as date)
        )                                                           as is_spike_churn,

        -- metrics
        cast(mrr as decimal(10, 2))                                 as mrr,

        -- timestamps
        cast(trial_start        as date)                            as trial_start_date,
        date_format(cast(trial_start as date), 'yyyyMM')              as cohort_month,
        cast(trial_end          as date)                            as trial_end_date,
        cast(subscription_start as date)                            as subscription_start_date,
        cast(subscription_end   as date)                            as subscription_end_date,
        cast(cancelled_at       as date)                            as cancelled_date,
        coalesce(
            cast(subscription_end as date),
            cast('2099-12-31' as date)
        )                                                           as effective_end_date,

        -- derived durations
        datediff(
            DAY,
            cast(trial_start as date),
            coalesce(cast(trial_end   as date), current_date())
        )                                                           as trial_duration_days,

        case
            when cast(subscription_start as date) is not null
            then datediff(
                DAY,
                cast(subscription_start as date),
                coalesce(cast(subscription_end as date), current_date())
            )
        end                                                         as subscription_duration_days,

        -- audit
        current_timestamp()                                         as _stg_loaded_at

    from source
    where trim(subscription_id) is not null
)

select *
from cleaned
