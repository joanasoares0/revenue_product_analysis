{#
User event transactional fact table.
Grain: one row per event_id.
Filter on is_funnel_event for funnel analysis;
use funnel_stage_order for ordering;
use is_activation_event / is_conversion_event for milestone analysis.
#}

{{
    config(
        materialized         = 'incremental',
        unique_key           = 'sk_event_id',
        incremental_strategy = 'merge'
    )
}}

with events as (

    select *
    from {{ ref('stg_revenue__events') }}
    {% if is_incremental() %}
        -- 3-day lookback handles late-arriving events without reprocessing full history
        where event_date >= (select date_sub(max(t.event_date), 3) as max_date from {{ this }} as t)
    {% endif %}

),

dim_users as (

    select
        user_id,
        sk_user_id
    from {{ ref('dim_users') }}

)

select
    -- keys
    e.sk_event_id,
    e.event_id,

    u.sk_user_id,
    e.user_id,

    e.session_id,

    -- attributes
    e.event_name,
    e.funnel_stage_order,

    -- flags
    e.is_funnel_event,
    e.is_activation_event,
    e.is_conversion_event,
    e.is_upsell_event,
    e.is_payment_failure_event,
    e.is_churn,

    -- JSON-extracted properties (pre-parsed at staging for self-serve use)
    e.event_source,
    e.activation_action,
    e.feature_used,
    e.upgraded_from_plan,
    e.upgraded_to_plan,
    e.churn_reason,
    e.raw_properties,

    -- dates
    e.event_date,
    e.event_month,

    -- audit
    e._stg_loaded_at

from events as e
left join dim_users as u on e.user_id = u.user_id
