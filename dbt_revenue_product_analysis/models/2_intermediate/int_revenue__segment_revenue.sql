{#
Segments revenue by company size, industry, and acquisition channel, including ARPU. 
Supports segment analysis and channel performance.
#}

with users as (
    select * from {{ ref('stg_revenue__users') }}
),

payments as (
    select * from {{ ref('stg_revenue__payments') }}
),

-- Aggregate revenue and user counts by segment
user_payments as (
    select
        u.company_size,
        u.industry,
        u.acquisition_channel,
        sum(p.amount) as total_revenue,
        count(distinct p.user_id) as unique_users
    from users u
    left join payments p on u.user_id = p.user_id
    where p.is_revenue_recognised
    group by 1,2,3
),

-- Calculate ARPU (Avg Revenue Per User, the amount of money a company earns from each customer over a given period) by segment
segment_arpu as (
    select
        company_size,
        industry,
        acquisition_channel,
        total_revenue,
        unique_users,
        case when unique_users > 0 then total_revenue / unique_users else 0 end as arpu
    from user_payments
)

select * 
from segment_arpu