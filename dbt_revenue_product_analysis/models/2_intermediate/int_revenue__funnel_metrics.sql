{#
Counts users at each funnel stage (signed up → activated → converted) and calculates conversion rates. 
Addresses funnel drop-offs, activation rates, and time-to-value insights.
#}


with events as (
    select *
    from {{ ref('stg_revenue__events') }}
),

-- Aggregate funnel stages by month (signed up, activated, converted)
funnel_stages as (
    select
        event_month,
        count(distinct case when funnel_stage_order = 1 then user_id end)
            as signed_up_users,
        count(distinct case when funnel_stage_order = 6 then user_id end)
            as activated_users,
        count(distinct case when funnel_stage_order = 10 then user_id end)
            as converted_users
    from events
    group by event_month
),

-- Calculate conversion rates
funnel_rates as (
    select
        event_month,
        signed_up_users,
        activated_users,
        converted_users,
        case
            when signed_up_users > 0 then activated_users / signed_up_users
            else 0
        end as activation_rate,
        case
            when activated_users > 0 then converted_users / activated_users
            else 0
        end as conversion_rate
    from funnel_stages
)

select *
from funnel_rates
