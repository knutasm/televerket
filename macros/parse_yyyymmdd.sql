{% macro parse_yyyymmdd(column_name) %}
    {{ return(adapter.dispatch('parse_yyyymmdd')(column_name)) }}
{% endmacro %}

{% macro default__parse_yyyymmdd(column_name) %}
    to_date({{ column_name }}, 'YYYYMMDD')
{% endmacro %}

{% macro duckdb__parse_yyyymmdd(column_name) %}
    strptime({{ column_name }}, '%Y%m%d')::date
{% endmacro %}

{% macro bigquery__parse_yyyymmdd(column_name) %}
    parse_date('%Y%m%d', {{ column_name }})
{% endmacro %}
