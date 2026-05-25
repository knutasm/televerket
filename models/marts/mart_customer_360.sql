{#
  E5: dbt_utils.star() velger alle kolonner fra int__customers_enriched.
  Legg til en kolonne der, og den dukker automatisk opp her.
  Bruk except=[...] for å utelukke interne metadata-kolonner.
#}

select
    {{ dbt_utils.star(from=ref('int__customers_enriched')) }}
from {{ ref('int__customers_enriched') }}
