{% macro test_validate_email_format(model, column_name) %}
  select {{ column_name }}
  from {{ model }}
  where {{ column_name }} is not null
    and not regexp_like({{ column_name }}, '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$')
{% endmacro %}