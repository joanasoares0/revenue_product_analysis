{#
Cohort retention logic — encapsulates non-trivial date arithmetic that would be
impractical to replicate in a BI tool: casting yyyyMM strings to dates,
add_months range checks against effective_end_date, and months-since-cohort
window. Consumed by fct_cohort_retention in the marts layer.
#}

with subscriptions as (
    select *
    from {{ ref('stg_revenue__subscriptions') }}
),

-- Cast cohort_month (yyyyMM string) to a date (first of month) for date arithmetic
cohorts as (
    select
        cohort_month,
        to_date(concat(cohort_month, '01'), 'yyyyMMdd') as cohort_start_date,
        user_id,
        subscription_start_date,
        effective_end_date,
        datediff(
            month,
            to_date(concat(cohort_month, '01'), 'yyyyMMdd'),
            date_trunc('month', current_date())
        )                                               as months_since_cohort
    from subscriptions
    where is_active
),

retention as (
    select
        cohort_month,
        months_since_cohort,
        count(distinct user_id) as total_users,
        count(
            distinct
            case
                when effective_end_date
                    >= add_months(cohort_start_date, months_since_cohort)
                then user_id
            end
        )                       as retained_users
    from cohorts
    where months_since_cohort <= 12
    group by cohort_month, months_since_cohort
)

select
    cohort_month,
    months_since_cohort,
    total_users,
    retained_users,
    round(
        retained_users / cast(total_users as decimal(10, 4)),
        4
    )                           as retention_rate
from retention
