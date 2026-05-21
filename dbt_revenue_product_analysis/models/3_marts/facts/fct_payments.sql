{#
Payment transactional fact table.
Grain: one row per payment_id.
Contains all recognised and non-recognised payments with FK references to
dim_users and dim_plans.
Join to dim_users for segment-level revenue analysis;
filter on is_revenue_recognised for MRR/ARR metrics.
#}

{{
    config(
        materialized         = 'incremental',
        unique_key           = 'sk_payment_id',
        incremental_strategy = 'merge'
    )
}}

with payments as (

    select *
    from {{ ref('stg_revenue__payments') }}
    {% if is_incremental() %}
        -- 3-day lookback handles late-arriving payments without reprocessing full history
        where
            payment_date
            >= (select date_sub(max(t.payment_date), 3) as max_date from {{ this }} as t)
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
    -- keys
    p.sk_payment_id,
    p.payment_id,
    u.sk_user_id,
    pl.sk_plan_id,
    p.user_id,
    p.plan_id,
    p.subscription_id,

    -- attributes
    p.billing_cycle,
    p.currency,
    p.status,

    -- flags
    p.is_revenue_recognised,
    p.is_failed,
    p.is_refunded,

    -- measures
    p.amount,
    p.mrr_contribution,

    -- date keys
    p.payment_date,
    p.payment_month,
    p.period_start,
    p.period_end,
    p.days_in_period,

    -- audit
    p._stg_loaded_at

from payments as p
left join dim_users as u on p.user_id = u.user_id
left join dim_plans as pl on p.plan_id = pl.plan_id
