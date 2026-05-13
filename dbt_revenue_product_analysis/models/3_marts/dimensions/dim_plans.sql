{#
Plan dimension table — pricing and feature attributes for each plan.
Grain: one row per plan_id.
#}


select
    -- keys
    sk_plan_id,
    plan_id,

    -- attributes
    plan_name,
    tier,
    max_seats,
    features,

    -- metrics
    monthly_price,
    annual_price,
    _stg_loaded_at,
    round(annual_price / 12.0, 2) as annual_monthly_equivalent,

    -- audit
    round(
        (1 - (annual_price / nullif(monthly_price * 12.0, 0))) * 100,
        1
    ) as annual_discount_pct

from {{ ref('stg_revenue__plans') }}
