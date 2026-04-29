select
    payment_id,
    subscription_id,
    user_id,
    plan_id,
    billing_cycle,
    amount,
    currency,
    status,
    payment_date,
    period_start,
    period_end
from {{ source('revenue', 'payments') }}
