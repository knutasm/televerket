{% macro test_is_positive_or_credited(model, column_name) %}
    select *
    from {{ model }}
    where {{ column_name }} < 0
      and status != 'credited'
{% endmacro %}
