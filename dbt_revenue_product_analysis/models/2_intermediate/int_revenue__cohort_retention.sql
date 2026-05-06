{#
Performs cohort analysis with retention rates over months. 
Enables retention tracking and cohort comparisons.
#}

with subscriptions as (
    select * 
    from {{ ref('stg_revenue__subscriptions') }}
),

-- Calculate months since cohort for each active user
cohorts as (
    select
        cohort_month,
        user_id,
        subscription_start_date,
        effective_end_date,
        datediff(MONTH, cohort_month, date_trunc('month', current_date())) as months_since_cohort
    from subscriptions
    where is_active 
),

-- Calculate retention (retained_users and total_users) by cohort and months since cohort
retention as (
    select
        cohort_month,
        months_since_cohort,
        count(distinct user_id) as total_users,
        count(distinct 
            case when effective_end_date >= add_months(cohort_month, months_since_cohort) then user_id 
            end) as retained_users
    from cohorts
    where months_since_cohort <= 12
    group by cohort_month, months_since_cohort
),

-- Calculate retention rates
retention_rates as (
    select
        cohort_month,
        months_since_cohort,
        total_users,
        retained_users,
        case 
            when total_users > 0 then retained_users / total_users 
            else 0 
        end as retention_rate
    from retention
)

select * 
from retention_rates