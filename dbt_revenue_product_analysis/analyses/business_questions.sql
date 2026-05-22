-- ============================================================
-- FINTEX REVENUE & PRODUCT ANALYSIS
-- Ad-hoc queries to answer core business questions.
-- ============================================================

-- ============================================================
-- REVENUE ANALYSIS
-- ============================================================

-- 1. How has MRR/ARR evolved over time?
-- Filters out synthetic churned rows so each month shows only the live revenue base
-- churned rows exist to record revenue loss, not active MRR.
-- Multiplying by 12 gives ARR as a parallel annualised view.
-- The time series surfaces growth trajectory and inflection
-- points: the ramp through 2022–2023, the 2023 pricing-driven churn spike, and the 2024
-- recovery.
select
    mrr_month,
    SUM(mrr) as total_mrr,
    SUM(mrr) * 12 as arr
from {{ ref('fct_mrr') }}
where mrr_movement_type != 'churned'
group by 1
order by 1;


-- 2. What are the main drivers of revenue change (new, expansion, contraction, churn)?
-- mrr_movement_type classifies every row into the six standard SaaS waterfall categories.
-- Summing mrr_delta per category per month builds the MRR waterfall: the signed view of
-- how revenue flows in (new, expansion, reactivation) and out (contraction, churn) each
-- period. This is the diagnostic tool for "why did MRR move?", it separates growth
-- problems from churn problems.
select
    mrr_month,
    mrr_movement_type,
    SUM(mrr_delta) as mrr_impact,
    COUNT(distinct user_id) as subscriber_count
from {{ ref('fct_mrr') }}
group by 1, 2
order by 1, 2;


-- 3. What is the revenue churn rate and how is it impacting growth?
-- Revenue churn rate = churned MRR / active MRR —> the standard measure of how much of the
-- existing revenue base is lost each month.
-- Net Revenue Retention (NRR) extends this:
-- NRR > 100% means expansion from existing customers more than covers losses, so the
-- business can grow even with no new customers. NRR < 100% means contraction and churn
-- outpace expansion, so growth relies on new customer acquisition.
with monthly as (
    select
        mrr_month,
        SUM(case when mrr_movement_type != 'churned' then mrr else 0 end) as active_mrr,
        ABS(SUM(case when mrr_movement_type = 'churned' then mrr_delta else 0 end)) as churned_mrr,
        SUM(case when mrr_movement_type = 'new' then mrr_delta else 0 end) as new_mrr,
        SUM(case when mrr_movement_type = 'expansion' then mrr_delta else 0 end) as expansion_mrr
    from {{ ref('fct_mrr') }}
    group by 1
)

select
    mrr_month,
    active_mrr,
    churned_mrr,
    new_mrr,
    expansion_mrr,
    ROUND(churned_mrr / NULLIF(active_mrr, 0) * 100, 2) as revenue_churn_rate_pct,
    ROUND((new_mrr + expansion_mrr - churned_mrr) / NULLIF(active_mrr, 0) * 100, 2
    ) as net_revenue_retention_pct
from monthly
order by 1;


-- 4. Which customer segments generate the most revenue?
-- Snapshots the latest mrr_month only (inner subquery) to avoid double-counting revenue
-- across months —> this is a point-in-time revenue ranking, not a cumulative total.
select
    u.acquisition_channel,
    u.company_size,
    p.plan_name,
    SUM(m.mrr) as total_mrr,
    COUNT(distinct m.user_id) as active_subscribers
from {{ ref('fct_mrr') }} as m
inner join {{ ref('dim_users') }} as u on m.sk_user_id = u.sk_user_id
inner join {{ ref('dim_plans') }} as p on m.sk_plan_id = p.sk_plan_id
where
    m.mrr_movement_type != 'churned'
    and m.mrr_month = (select MAX(f.mrr_month) as max_mrr_month from {{ ref('fct_mrr') }} as f)
group by 1, 2, 3
order by 4 desc;


-- 5. What is ARPU and how does it vary by plan?
-- ARPU = total MRR / distinct active users per plan per month.
-- Tracking ARPU over time per plan reveals pricing-change impacts (did ARPU jump after a
-- price increase?), plan mix
-- shifts (are users moving to higher tiers?), and whether growth is driven by volume or by
-- acquiring higher-value customers.
select
    p.plan_name,
    m.mrr_month,
    ROUND(SUM(m.mrr) / NULLIF(COUNT(distinct m.user_id), 0), 2) as arpu
from {{ ref('fct_mrr') }} as m
inner join {{ ref('dim_plans') }} as p on m.sk_plan_id = p.sk_plan_id
where m.mrr_movement_type != 'churned'
group by 1, 2
order by 2, 1;


-- 6. What is the customer lifetime value (LTV)?
-- LTV = avg MRR / avg monthly churn rate, by plan and on subscription level
-- Churn rate = churned subscriptions / all subscriptions,
-- which gives the fraction of the base expected to leave per month.
-- Dividing avg MRR by that rate yields the expected revenue before a customer leaves.
with plan_mrr as (
    select
        p.plan_name,
        AVG(s.mrr) as avg_mrr
    from {{ ref('fct_subscriptions') }} as s
    inner join {{ ref('dim_plans') }} as p on s.sk_plan_id = p.sk_plan_id
    group by 1
),

plan_churn as (
    select
        p.plan_name,
        CAST(COUNT(case when s.is_churned then 1 end) as decimal(18, 4)
        )
        /
        NULLIF(COUNT(*), 0
        ) as monthly_churn_rate
    from {{ ref('fct_subscriptions') }} as s
    inner join {{ ref('dim_plans') }} as p on s.sk_plan_id = p.sk_plan_id
    group by 1
)

select
    m.plan_name,
    ROUND(m.avg_mrr, 2) as avg_mrr,
    ROUND(c.monthly_churn_rate * 100, 2) as monthly_churn_rate_pct,
    ROUND(m.avg_mrr / NULLIF(c.monthly_churn_rate, 0), 2) as ltv
from plan_mrr as m
inner join plan_churn as c on m.plan_name = c.plan_name
order by 4 desc;


-- 7. Are there seasonality patterns or trends in revenue?
-- Extracts the two-digit calendar month (MM) from the yyyyMM string and averages monthly
-- MRR across all years for that month. This isolates the seasonal pattern from the
-- year-over-year growth trend: a month with consistently higher avg_mrr_for_month is
-- seasonally strong regardless of absolute scale. The inner subquery de-duplicates from the
-- subscription × month grain to a single MRR total per month before averaging.
select
    SUBSTRING(mrr_month, 1, 4) as revenue_year,
    SUBSTRING(mrr_month, 5, 2) as month_of_year,
    SUM(mrr) as monthly_mrr
from {{ ref('fct_mrr') }}
where mrr_movement_type != 'churned'
group by 1, 2
order by 1, 2;


-- ============================================================
-- PRODUCT FUNNEL ANALYSIS
-- ============================================================

-- 8. What is the conversion rate at each stage of the funnel?
-- fct_user_funnel has one row per user with boolean flags at every funnel stage
select
    COUNT(*) as total_users,
    SUM(CAST(has_verified_email as int)) as email_verified,
    SUM(CAST(has_started_trial as int)) as trial_started,
    SUM(CAST(has_activated as int)) as activated,
    SUM(CAST(has_converted as int)) as converted,
    ROUND(SUM(CAST(has_verified_email as int)) / COUNT(*) * 100, 1) as email_verified_pct,
    ROUND(SUM(CAST(has_started_trial as int)) / COUNT(*) * 100, 1) as trial_started_pct,
    ROUND(SUM(CAST(has_activated as int)) / COUNT(*) * 100, 1) as activation_rate_pct,
    ROUND(SUM(CAST(has_converted as int)) / COUNT(*) * 100, 1) as conversion_rate_pct
from {{ ref('fct_user_funnel') }};


-- 9. Where are the biggest drop-offs?
-- highest_funnel_stage_name captures the last stage each user reached, which is the exact
-- definition of where they stopped — users who stopped at onboarding_step2 never reached
-- activation, regardless of what happened earlier.
select
    highest_funnel_stage_order as stage_order,
    highest_funnel_stage_name as stage_name,
    COUNT(*) as users_stopped_here,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) over (), 1) as pct_of_all_users
from {{ ref('fct_user_funnel') }}
group by 1, 2
order by 1;


-- 10. How long does it take users to reach activation (time to first value)?
-- Median (p50) is the primary metric here because a long tail of churned or inactive users
-- who never activated would skew the mean upwards. Reporting both p50 and avg makes the
-- shape of the distribution visible: a large gap between them indicates a heavy tail and
-- signals that a significant segment is activating much later (or not at all). The
-- days_to_* columns are pre-computed in fct_user_funnel from event timestamps.
select
    PERCENTILE(days_to_email_verified, 0.5) as p50_days_to_email_verified,
    PERCENTILE(days_to_activation, 0.5) as p50_days_to_activation,
    PERCENTILE(days_to_conversion, 0.5) as p50_days_to_conversion,
    AVG(days_to_email_verified) as avg_days_to_email_verified,
    AVG(days_to_activation) as avg_days_to_activation,
    AVG(days_to_conversion) as avg_days_to_conversion
from {{ ref('fct_user_funnel') }};


-- 11. How does activation impact user retention?
-- fct_cohort_retention pre-segments each cohort by activation status and computes retention
-- rates for each group, so this query just averages across cohorts per time offset.
-- Pooling multiple cohorts into a single avg per months_since_cohort gives a more stable estimate
-- than any individual cohort, which may have been affected by seasonality or a product change.
select
    months_since_cohort,
    ROUND(AVG(case
        when activated_total_users > 0
            then activated_retention_rate
    end) * 100, 1) as activated_retention_pct,
    ROUND(AVG(case
        when non_activated_total_users > 0
            then non_activated_retention_rate
    end) * 100, 1) as non_activated_retention_pct,
    ROUND(AVG(activation_retention_lift) * 100, 1) as avg_retention_lift_pct
from {{ ref('fct_cohort_retention') }}
group by 1
order by 1;


-- 12. What differentiates users who convert vs those who don't?
-- Slicing by has_converted × acquisition_channel × company_size surfaces segment-level
-- Comparing avg_days_to_activation between converted and non-converted rows shows whether
-- speed-to-activation predicts conversion.
-- The activation_rate_pct within each segment distinguishes two failure modes: users who never
-- activate (product onboarding problem) from users who activate but don't convert (value or
-- pricing problem).
select
    has_converted,
    acquisition_channel,
    company_size,
    COUNT(*) as total_users,
    ROUND(AVG(days_to_activation), 1) as avg_days_to_activation,
    ROUND(AVG(days_to_conversion), 1) as avg_days_to_conversion,
    ROUND(SUM(CAST(has_activated as int)) * 100.0 / COUNT(*), 1) as activation_rate_pct
from {{ ref('fct_user_funnel') }}
group by 1, 2, 3
order by 1 desc, 4 desc;


-- 13. What is the retention rate over time (cohort analysis)?
-- retention_vs_benchmark compares each cohort against
-- the SaaS industry benchmark (embedded in fct_cohort_retention).
select
    cohort_month,
    months_since_cohort,
    cohort_size,
    retained_users,
    ROUND(retention_rate * 100, 1) as retention_pct,
    ROUND(retention_benchmark * 100, 1) as benchmark_pct,
    ROUND(retention_vs_benchmark * 100, 1) as vs_benchmark_pct
from {{ ref('fct_cohort_retention') }}
order by 1, 2;


-- 14. Which acquisition channels or segments convert best?
-- Comparing conversion_rate_pct alongside activation_rate_pct per channel and
-- company_size separates
-- two distinct failure modes: channels that bring users who activate but don't convert
-- (value/pricing problem) from channels that bring users who neither activate nor convert
-- (targeting/fit problem).
select
    acquisition_channel,
    company_size,
    COUNT(*) as total_users,
    ROUND(SUM(CAST(has_converted as int)) * 100.0 / COUNT(*), 1) as conversion_rate_pct,
    ROUND(SUM(CAST(has_activated as int)) * 100.0 / COUNT(*), 1) as activation_rate_pct,
    ROUND(AVG(days_to_activation), 1) as avg_days_to_activation
from {{ ref('fct_user_funnel') }}
where acquisition_channel is not null
group by 1, 2
order by 4 desc;


-- ============================================================
-- SUBSCRIPTION & PAYMENT ANALYSIS
-- ============================================================

-- 15. What are the most common cancellation reasons?
-- cancel_reason is captured at subscription cancellation and reflects the user's stated
-- reason (e.g. too_expensive, missing_features, pricing_change). Joining dim_plans shows
-- whether certain reasons concentrate on specific tiers — a high "too_expensive" share on
-- the Growth plan points to a pricing fit issue there, not a product-wide problem.
-- The two window functions give % of all churned (global share) and % within each reason
-- across plans (within-reason plan mix) in a single pass.
select
    s.cancel_reason,
    p.plan_name,
    COUNT(*) as churned_subscriptions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) over (), 1) as pct_of_all_churned,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) over (partition by s.cancel_reason), 1
    ) as pct_within_reason
from {{ ref('fct_subscriptions') }} as s
inner join {{ ref('dim_plans') }} as p on s.sk_plan_id = p.sk_plan_id
where s.is_churned and s.cancel_reason is not null
group by 1, 2
order by 3 desc;


-- 16. What is the payment success rate by plan and billing cycle?
-- is_revenue_recognised flags payments that completed successfully; is_failed flags declined
-- or errored transactions. Grouping by plan and billing cycle reveals whether annual billing
-- has higher failure rates (larger single charges) or whether a specific plan tier has a
-- structural payment problem. success_rate_pct is the primary metric; failed_payments gives
-- the raw count for operational triage.
select
    p.plan_name,
    fp.billing_cycle,
    COUNT(*) as total_payments,
    SUM(CAST(fp.is_revenue_recognised as int)) as successful_payments,
    SUM(CAST(fp.is_failed as int)) as failed_payments,
    ROUND(SUM(CAST(fp.is_revenue_recognised as int)) * 100.0 / NULLIF(COUNT(*), 0), 1
    ) as success_rate_pct
from {{ ref('fct_payments') }} as fp
inner join {{ ref('dim_plans') }} as p on fp.sk_plan_id = p.sk_plan_id
group by 1, 2
order by 1, 2;
