{#
User-level funnel accumulating snapshot.
Grain: one row per user_id.

Tracks each user's highest funnel stage reached, activation, conversion,
and time-to-milestone metrics. User segment attributes are denormalised from
dim_users to allow self-serve slicing without extra joins.

Answers:
  - What is the conversion rate at each stage of the funnel?
  - Where are the biggest drop-offs?
  - How long does it take users to reach activation (time to first value)?
  - What differentiates users who convert vs those who don't?
  - Which acquisition channels or segments convert best?
#}


with events as (

    select *
    from {{ ref('fct_events') }}
    where is_funnel_event

),

dim_users as (

    select
        user_id,
        sk_user_id,
        acquisition_channel,
        company_size,
        industry,
        country,
        signed_up_at,
        signup_month
    from {{ ref('dim_users') }}

),

subscriptions as (

    select
        user_id,
        is_active,
        is_churned,
        mrr,
        subscription_duration_days,
        subscription_start_date,
        cancel_reason
    from {{ ref('fct_subscriptions') }}

),

-- First occurrence of each funnel milestone per user
user_funnel_events as (

    select
        user_id,
        min(case when event_name = 'signed up' then event_date end) as signed_up_date,
        min(case when event_name = 'email verified' then event_date end) as email_verified_date,
        min(case when event_name = 'trial started' then event_date end) as trial_started_date,
        min(case when event_name = 'onboarding step1' then event_date end) as onboarding_step1_date,
        min(case when event_name = 'onboarding step2' then event_date end) as onboarding_step2_date,
        min(case when is_activation_event then event_date end) as activated_date,
        min(case when is_conversion_event then event_date end) as converted_date,
        max(funnel_stage_order) as highest_funnel_stage_order,
        max_by(event_name, funnel_stage_order) as highest_funnel_stage_name,
        count(distinct event_name) as distinct_funnel_stages_reached
    from events
    group by user_id -- noqa: AM06

),

-- Collapse to one row per user; take metrics from the most recent subscription
user_subscriptions as (

    select
        user_id,
        bool_or(is_active) as has_paid_subscription,
        bool_or(is_churned) as has_churned,
        max_by(mrr, coalesce(subscription_start_date, current_date())) as current_mrr,
        max(subscription_duration_days) as max_subscription_duration_days,
        min(subscription_start_date) as first_subscription_start_date,
        max_by(
            case when is_churned then cancel_reason end,
            coalesce(subscription_start_date, current_date())
        ) as last_cancel_reason
    from subscriptions
    group by user_id -- noqa: AM06

)

select

    -- keys
    u.sk_user_id,
    u.user_id,

    -- user segment attributes (denormalised for self-serve slicing)
    u.acquisition_channel,
    u.company_size,
    u.industry,
    u.country,
    u.signed_up_at,
    u.signup_month,

    -- funnel milestone dates
    fe.email_verified_date,
    fe.trial_started_date,
    fe.onboarding_step1_date,
    fe.onboarding_step2_date,
    fe.activated_date,
    fe.converted_date,
    fe.highest_funnel_stage_order,

    -- funnel progression
    fe.highest_funnel_stage_name,
    fe.distinct_funnel_stages_reached,
    us.current_mrr,

    -- milestone flags
    us.max_subscription_duration_days,
    us.first_subscription_start_date,
    us.last_cancel_reason,
    coalesce(fe.signed_up_date, cast(u.signed_up_at as date)) as signed_up_date,

    -- time-to-milestone (days from signup; null if milestone not reached)
    fe.email_verified_date is not null as has_verified_email,
    fe.trial_started_date is not null as has_started_trial,
    fe.activated_date is not null as has_activated,

    -- subscription metrics
    fe.converted_date is not null as has_converted,
    datediff(
        fe.email_verified_date,
        coalesce(fe.signed_up_date, cast(u.signed_up_at as date))
    ) as days_to_email_verified,
    datediff(
        fe.activated_date,
        coalesce(fe.signed_up_date, cast(u.signed_up_at as date))
    ) as days_to_activation,
    datediff(
        fe.converted_date,
        coalesce(fe.signed_up_date, cast(u.signed_up_at as date))
    ) as days_to_conversion,
    coalesce(us.has_paid_subscription, false) as has_paid_subscription,
    coalesce(us.has_churned, false) as has_churned

from dim_users as u
left join user_funnel_events as fe on u.user_id = fe.user_id
left join user_subscriptions as us on u.user_id = us.user_id
