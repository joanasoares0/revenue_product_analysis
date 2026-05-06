{#
Aggregates payments by month to track MRR growth, total revenue, paying users, and growth percentages. 
Supports revenue evolution and seasonality questions.
#}

with payments as (
    select * 
    from {{ ref('stg_revenue__payments') }}
),

-- Normalize revenue to MRR based on billing cycle (monthly vs annual)
monthly_revenue as (
    select
        payment_month,
        sum(amount) as total_revenue,
        sum(mrr_contribution) as total_mrr_contribution,
        count(distinct user_id) as paying_users,
        avg(amount) as avg_payment_amount
    from payments
    where is_revenue_recognised
    group by payment_month
),

-- Calculate month-over-month MRR growth
revenue_growth as (
    select
        payment_month,
        total_revenue,
        total_mrr_contribution,
        paying_users,
        avg_payment_amount,
        lag(total_mrr_contribution) over (order by payment_month) as prev_month_mrr,
        (total_mrr_contribution - lag(total_mrr_contribution) over (order by payment_month)) 
        / 
        nullif(lag(total_mrr_contribution) over (order by payment_month), 0) * 100 as mrr_growth_pct
    from monthly_revenue
)

select * 
from revenue_growth