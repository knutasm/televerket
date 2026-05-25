{% macro sample(fraction=10, limit=1000) %}
    {{ return(adapter.dispatch('sample')(fraction, limit)) }}
{% endmacro %}

{% macro default__sample(fraction, limit) %}
    limit {{ limit }}
{% endmacro %}

{% macro bigquery__sample(fraction, limit) %}
    tablesample system ({{ fraction }} percent)
{% endmacro %}

{% macro snowflake__sample(fraction, limit) %}
    sample ({{ fraction }})
{% endmacro %}

{% macro duckdb__sample(fraction, limit) %}
    using sample {{ fraction }} percent
{% endmacro %}

{% macro postgres__sample(fraction, limit) %}
    tablesample system ({{ fraction }})
{% endmacro %}
