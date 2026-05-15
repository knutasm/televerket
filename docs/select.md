```bash
--select models/min_mappe # Kjør alle modeller i min_mappe
--select std_customers # Kjør std_customers
--select std_customers std_locations # Kjør disse to
--select +std_customers # Kjør std_customer og alle oppstrøms modeller
--select std_customers+ # Kjør std_customers og alle nedstrøms modeller
```
