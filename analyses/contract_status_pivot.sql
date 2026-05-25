{# Blokk 1 — oppgave 4: løkke over statusverdier med {% for %} #}

{% set statuser = ['active', 'suspended', 'terminated'] %}

select
    customer_id
    {% for s in statuser %}
    , sum(case when status = '{{ s }}' then 1 else 0 end) as {{ s }}_contracts
    {% endfor %}
from {{ ref('stg__crm_contracts') }}
group by 1
