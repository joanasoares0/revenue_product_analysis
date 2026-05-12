{#
Answers:
What is the retention rate over time (cohort analysis)?
How does activation impact user retention?
Grain: one row per (cohort_month × months_since_cohort).
#}


with cohort_retention as (
    select *
    from {{ ref('int_revenue__cohort_retention') }}
),

cohort_sizes as (
    select
        cohort_month,
        total_users as cohort_size
    from cohort_retention
)

select
    cr.cohort_month,
    cs.cohort_size,
    cr.months_since_cohort,

    cr.total_users,
    cr.retained_users,
    cr.retention_rate,

    -- Activation split
    cr.activated_total_users,
    cr.activated_retained_users,
    cr.activated_retention_rate,
    cr.non_activated_total_users,
    cr.non_activated_retained_users,
    cr.non_activated_retention_rate,

    -- Lift: how much better activated users retain vs non-activated
    case
        when
            cr.activated_retention_rate is not null
            and cr.non_activated_retention_rate is not null
            then round(cr.activated_retention_rate - cr.non_activated_retention_rate, 4)
    end as activation_retention_lift,

    case
        when cr.months_since_cohort = 0 then 'Month 0 (start)'
        else concat('Month ', cast(cr.months_since_cohort as string))
    end as period_label,

    case
        when cs.cohort_size < 10 then 'xs (< 10)'
        when cs.cohort_size < 50 then 'small (10–49)'
        when cs.cohort_size < 200 then 'medium (50–199)'
        else 'large (200+)'
    end as cohort_size_bucket,

    case
        when cr.months_since_cohort = 0 then 1.0
        when cr.months_since_cohort between 1 and 3 then 0.70
        when cr.months_since_cohort between 4 and 6 then 0.50
        when cr.months_since_cohort between 7 and 12 then 0.40
    end as retention_benchmark,

    round(
        cr.retention_rate - case
            when cr.months_since_cohort = 0 then 1.0
            when cr.months_since_cohort between 1 and 3 then 0.70
            when cr.months_since_cohort between 4 and 6 then 0.50
            when cr.months_since_cohort between 7 and 12 then 0.40
        end,
        4
    ) as retention_vs_benchmark

from cohort_retention as cr
inner join cohort_sizes as cs on cr.cohort_month = cs.cohort_month
