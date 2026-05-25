{# E1: bruk log() til å inspisere Jinja-variabler og target-objektet.
   Kjør: dbt compile --select debug_target
   Sjekk terminalen for output — log() vises ikke i kompilert SQL. #}

{% set statuser = ['active', 'suspended', 'terminated'] %}
{{ log("Antall statuser: " ~ statuser | length, info=true) }}
{{ log("target: " ~ target | tojson, info=true) }}

select
    '{{ target.name }}'    as target_name,
    '{{ target.schema }}'  as target_schema,
    '{{ target.type }}'    as target_type
