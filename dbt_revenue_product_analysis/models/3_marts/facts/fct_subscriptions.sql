{#
Subscription accumulating snapshot fact table.
Grain: one row per subscription_id. Each row spans the full lifecycle of a
subscription from trial start to cancellation (or current if active).
Accumulating snapshots are updated as milestones change (trial end, paid start,
cancellation).
Use effective_end_date for point-in-time range queries.
#}

{{
    config(
        materialized         = 'incremental',
        unique_key           = 'sk_subscription_id',
        incremental_strategy = 'merge'
    )
}}

with subscriptions as (

    select *
    from {{ ref('stg_revenue__subscriptions') }}
    {% if is_incremental() %}
        -- Active subscriptions can update any time (milestones fill in over lifecycle).
        -- Also capture recently started subscriptions (last 3 months).
        where
            is_active
            or trial_start_date >= add_months(current_date(), -3)
    {% endif %}

),

dim_users as (

    select
        user_id,
        sk_user_id
    from {{ ref('dim_users') }}

),

dim_plans as (

    select
        plan_id,
        sk_plan_id
    from {{ ref('dim_plans') }}

)

select
    -- surrogate key
    s.sk_subscription_id,
    s.subscription_id,
    u.sk_user_id,
    pl.sk_plan_id,
    s.user_id,
    s.plan_id,

    -- attributes
    s.billing_cycle,
    s.status,
    s.cancel_reason,
    s.cohort_month,

    -- flags
    s.is_active,
    s.is_churned,
    s.is_trial_expired,
    s.is_spike_churn,

    -- measures
    s.mrr,
    s.trial_duration_days,
    s.subscription_duration_days,

    -- milestone dates (accumulating snapshot pattern)
    s.trial_start_date,
    s.trial_end_date,
    s.subscription_start_date,
    s.subscription_end_date,
    s.cancelled_date,
    s.effective_end_date,   -- sentinel '2099-12-31' for active subscriptions

    -- audit
    s._stg_loaded_at

from subscriptions as s
left join dim_users as u on s.user_id = u.user_id
left join dim_plans as pl on s.plan_id = pl.plan_id
