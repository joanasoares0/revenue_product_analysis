select 
    user_id
    ,company_name
    ,email
    ,country
    ,industry
    ,company_size
    ,acquisition_channel
    ,created_at
    ,is_deleted
from {{ source('revenue', 'events') }}