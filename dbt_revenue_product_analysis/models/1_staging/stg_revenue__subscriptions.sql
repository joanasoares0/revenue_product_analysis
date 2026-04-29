select
    subscription_id,
    user_id,
    plan_id,
    billing_cycle,
    status,
    trial_start,
    trial_end,
    subscription_start,
    subscription_end,
    cancelled_at,
    cancel_reason,
    mrr
from {{ source('revenue', 'subscriptions') }}
