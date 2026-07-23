-- Verification queries for the star schema

-- dim_time: day/hour derive correctly from elapsed step
select * from `fincrime-501917.dbt_dsingh.dim_time`
order by step_hour
limit 30;

-- dim_accounts: most-flagged accounts
select * from `fincrime-501917.dbt_dsingh.dim_accounts`
order by suspicious_rate desc, total_transactions desc
limit 20;

-- dim_transaction_types: fraud rate per type
-- (confirms TRANSFER and CASH_OUT carry all the fraud)
select * from `fincrime-501917.dbt_dsingh.dim_transaction_types`
order by fraud_rate desc;

-- fct_transactions: join back to a dimension (proves the star works)
select
  f.transaction_type,
  t.fraud_rate,
  count(*) as txns
from `fincrime-501917.dbt_dsingh.fct_transactions` f
join `fincrime-501917.dbt_dsingh.dim_transaction_types` t
  using (transaction_type)
group by f.transaction_type, t.fraud_rate
order by txns desc;
