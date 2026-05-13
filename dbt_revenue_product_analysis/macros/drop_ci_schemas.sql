{% macro drop_ci_schemas(pr_number) %}

  {% set show_query %}
    SHOW SCHEMAS IN ci_revenue_product_analysis
  {% endset %}

  {% set schemas = run_query(show_query) %}
  {% set prefix = 'pr_' ~ pr_number ~ '__' %}
  {% set dropped = [] %}

  {% for row in schemas %}
    {% set schema_name = row[0] %}
    {% if schema_name.startswith(prefix) %}
      {% set drop_query %}
        DROP SCHEMA IF EXISTS `ci_revenue_product_analysis`.`{{ schema_name }}` CASCADE
      {% endset %}
      {% do run_query(drop_query) %}
      {% do dropped.append(schema_name) %}
      {{ log("Dropped: ci_revenue_product_analysis." ~ schema_name, info=True) }}
    {% endif %}
  {% endfor %}

  {% if dropped | length == 0 %}
    {{ log("No CI schemas found for PR " ~ pr_number, info=True) }}
  {% endif %}

{% endmacro %}
