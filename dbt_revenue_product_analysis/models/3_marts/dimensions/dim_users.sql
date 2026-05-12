{#
User dimension table — all user attributes for slicing and filtering.
Grain: one row per user_id.
#}



select
    -- keys
    sk_user_id,
    user_id,

    -- attributes
    company_name,
    company_size,
    company_size_order,
    industry,
    acquisition_channel,
    country,

    -- flags (1 = deleted, 0 = active, 999999 = unknown)
    is_deleted,

    -- dates
    signed_up_at,
    signup_month,

    -- audit
    _stg_loaded_at

from {{ ref('stg_revenue__users') }}
