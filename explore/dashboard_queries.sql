-- SQL equivalents of each Looker Studio dashboard element.
-- Useful for verifying the dashboard's numbers.

-- 1. Scorecards: headline totals
select
  count(*)                          as total_transactions,   -- 117,103
  sum(is_fraud)                     as total_fraud,          -- 8,213
  sum(cast(is_suspicious as int64)) as total_flagged         -- 52,580
from `fincrime-501917.dbt_dsingh.fct_transactions`;

-- 2. Bar chart: fraud rate by transaction type
--    (AVG of a 0/1 flag = the rate)
select
  transaction_type,
  count(*)      as txns,
  sum(is_fraud) as frauds,
  avg(is_fraud) as fraud_rate
from `fincrime-501917.dbt_dsingh.fct_transactions`
group by transaction_type
order by fraud_rate desc;

-- 3. Time series: volume and fraud per elapsed hour
--    NOTE: step_hour is ELAPSED hours since simulation start, not a calendar date.
select
  step_hour,
  count(*)      as txns,
  sum(is_fraud) as frauds
from `fincrime-501917.dbt_dsingh.fct_transactions`
group by step_hour
order by step_hour;

-- 4. Hour-of-day pattern (legitimate use of the relative time dimension)
select
  t.hour_of_day,
  count(*)        as txns,
  sum(f.is_fraud) as frauds
from `fincrime-501917.dbt_dsingh.fct_transactions` f
join `fincrime-501917.dbt_dsingh.dim_time` t using (step_hour)
group by t.hour_of_day
order by t.hour_of_day;

-- 5. Top suspicious accounts (optional dashboard table)
select
  origin_account,
  account_type,
  total_transactions,
  total_amount_sent,
  flagged_transactions,
  suspicious_rate
from `fincrime-501917.dbt_dsingh.dim_accounts`
order by flagged_transactions desc, total_amount_sent desc
limit 25;
