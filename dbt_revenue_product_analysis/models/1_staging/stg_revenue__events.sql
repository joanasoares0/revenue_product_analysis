{{
    config(
        materialized = 'incremental',
        unique_key   = 'sk_event_id',
        on_schema_change = 'sync_all_columns'
    )
}}

with source as (

    select *
    from {{ source('revenue', 'events') }}
    {% if is_incremental() %}
        where cast(event_at as date) > (select max(event_date) from {{ this }})
    {% endif %}

),
 
cleaned as (
 
    select
        -- keys 
        {{ dbt_utils.generate_surrogate_key(['event_id']) }} as sk_event_id, -- noqa: TMP,PRS
        trim(event_id)              as event_id,
        trim(user_id)               as user_id,
        trim(session_id)            as session_id,
 
        -- event classification 
        lower(trim(replace(event_name, '_', ' ')))     as event_name,
 
        case lower(trim(replace(event_name, '_', ' ')))
            when 'signed up'                then 1
            when 'email verified'           then 2
            when 'trial started'            then 3
            when 'onboarding step1'         then 4
            when 'onboarding step2'         then 5
            when 'activated'                then 6
            when 'feature core used'        then 7
            when 'feature advanced used'    then 8
            when 'invited team member'      then 9
            when 'converted paid'           then 10
            when 'upgraded plan'            then 11
            when 'payment failed'           then 12
            when 'cancellation initiated'   then 13
            else                                 999999
        end                                                 as funnel_stage_order,
 
        -- timestamps 
        cast(event_at as date)                              as event_date,
        date_format(cast(event_at as date), 'yyyyMM')      as event_month,

        -- flags
        lower(trim(replace(event_name, '_', ' '))) = 'activated'               as is_activation_event,
        lower(trim(replace(event_name, '_', ' '))) = 'converted paid'          as is_conversion_event,
        lower(trim(replace(event_name, '_', ' '))) = 'upgraded plan'           as is_upsell_event,
        lower(trim(replace(event_name, '_', ' '))) = 'payment failed'          as is_payment_failure_event,
        lower(trim(replace(event_name, '_', ' '))) = 'cancellation initiated'  as is_churn,
        lower(trim(replace(event_name, '_', ' '))) in (
            'signed up', 'email verified', 'trial started',
            'onboarding step1', 'onboarding step2',
            'activated', 'feature core used',
            'feature advanced used', 'converted paid'
        )                                                   as is_funnel_event,
 
        -- JSON property extraction 
        lower(trim(cast(properties as string)))             as raw_properties,
        get_json_object(cast(properties as string), '$.source')             as event_source,
        get_json_object(cast(properties as string), '$.action')             as activation_action,
        get_json_object(cast(properties as string), '$.feature')            as feature_used,
        get_json_object(cast(properties as string), '$.from_plan')          as upgraded_from_plan,
        get_json_object(cast(properties as string), '$.to_plan')            as upgraded_to_plan,
        get_json_object(cast(properties as string), '$.reason')             as churn_reason,

        -- audit 
        current_timestamp()                                 as _stg_loaded_at
 
    from source
    where trim(event_id)   is not null
 
)
 
select * 
from cleaned