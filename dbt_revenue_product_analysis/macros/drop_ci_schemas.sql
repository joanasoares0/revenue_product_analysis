{% macro drop_ci_schemas(pr_number) %}

  {% set show_query %}
    SHOW SCHEMAS IN dev
  {% endset %}

  {% set schemas = run_query(show_query) %}
  {% set prefix = 'ci_pr_' ~ pr_number ~ '_' %}
  {% set dropped = [] %}

  {% for row in schemas %}
    {% set schema_name = row[0] %}
    {% if schema_name.startswith(prefix) %}
      {% set drop_query %}
        DROP SCHEMA IF EXISTS `dev`.`{{ schema_name }}` CASCADE
      {% endset %}
      {% do run_query(drop_query) %}
      {% do dropped.append(schema_name) %}
      {{ log("Dropped: dev." ~ schema_name, info=True) }}
    {% endif %}
  {% endfor %}

  {% if dropped | length == 0 %}
    {{ log("No CI schemas found for PR " ~ pr_number, info=True) }}
  {% endif %}

{% endmacro %}
