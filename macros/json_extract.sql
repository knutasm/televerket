{% macro json_extract(column_name, path) %}
    {{ return(adapter.dispatch('json_extract')(column_name, path)) }}
{% endmacro %}

{% macro default__json_extract(column_name, path) %}
    json_value({{ column_name }}, '$.{{ path }}')
{% endmacro %}

{% macro duckdb__json_extract(column_name, path) %}
    json_extract_string({{ column_name }}, '$.{{ path }}')
{% endmacro %}

{% macro bigquery__json_extract(column_name, path) %}
    json_value({{ column_name }}, '$.{{ path }}')
{% endmacro %}

{% macro snowflake__json_extract(column_name, path) %}
    {{ column_name }}:{{ path }}::string
{% endmacro %}
