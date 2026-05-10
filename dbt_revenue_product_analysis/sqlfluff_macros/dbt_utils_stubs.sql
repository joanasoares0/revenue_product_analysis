{% macro generate_surrogate_key(field_list) %}cast(null as string){% endmacro %}
{% set dbt_utils = {"generate_surrogate_key": generate_surrogate_key} %}
