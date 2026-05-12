{#
Cohort retention logic — encapsulates non-trivial date arithmetic that would be
impractical to replicate in a BI tool: casting yyyyMM strings to dates,
add_months range checks against effective_end_date, and months-since-cohort
window. Also splits retention by whether the user ever completed the activation
event. Consumed by fct_cohort_retention in the marts layer.
#}

with subscriptions as (
    select *
    from {{ ref('stg_revenue__subscriptions') }}
),

-- Users who completed the activation event at least once
activated_users as (
    select distinct user_id
    from {{ ref('stg_revenue__events') }}
    where is_activation_event
),

-- Cast cohort_month (yyyyMM string) to a first-of-month date for arithmetic
cohorts as (
    select
        s.cohort_month,
        s.user_id,
        s.subscription_start_date,
        s.effective_end_date,
        to_date(concat(s.cohort_month, '01'), 'yyyyMMdd') as cohort_start_date,
        datediff(
            month,
            to_date(concat(s.cohort_month, '01'), 'yyyyMMdd'),
            date_trunc('month', current_date())
        ) as months_since_cohort,
        a.user_id is not null as has_activated
    from subscriptions as s
    left join activated_users as a on s.user_id = a.user_id
    where s.is_active
),

retention as (
    select
        cohort_month,
        months_since_cohort,
        -- Overall
        count(distinct user_id) as total_users,
        count(
            distinct
            case
                when
                    effective_end_date
                    >= add_months(cohort_start_date, months_since_cohort)
                    then user_id
            end
        ) as retained_users,
        -- Activated users
        count(
            distinct case when has_activated then user_id end
        ) as activated_total_users,
        count(
            distinct
            case
                when
                    has_activated
                    and effective_end_date >= add_months(
                        cohort_start_date,
                        months_since_cohort
                    )
                    then user_id
            end
        ) as activated_retained_users,
        -- Non-activated users
        count(
            distinct case when not has_activated then user_id end
        ) as non_activated_total_users,
        count(
            distinct
            case
                when
                    not has_activated
                    and effective_end_date >= add_months(
                        cohort_start_date,
                        months_since_cohort
                    )
                    then user_id
            end
        ) as non_activated_retained_users
    from cohorts
    where months_since_cohort <= 12
    group by cohort_month, months_since_cohort -- noqa: AM06
)

select
    cohort_month,
    months_since_cohort,
    total_users,
    retained_users,
    activated_total_users,
    activated_retained_users,
    non_activated_total_users,
    non_activated_retained_users,
    round(
        retained_users / cast(total_users as decimal(10, 4)),
        4
    ) as retention_rate,
    case
        when activated_total_users > 0
            then round(
                activated_retained_users
                / cast(activated_total_users as decimal(10, 4)),
                4
            )
    end as activated_retention_rate,
    case
        when non_activated_total_users > 0
            then round(
                non_activated_retained_users
                / cast(non_activated_total_users as decimal(10, 4)),
                4
            )
    end as non_activated_retention_rate
from retention
