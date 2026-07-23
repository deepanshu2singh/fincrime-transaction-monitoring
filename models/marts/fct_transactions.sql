{{ config(materialized='table') }}

-- fct_transactions: the central FACT table (one row per transaction).
-- Holds the measures + foreign keys out to the three dimensions:
--   step_hour        -> dim_time
--   origin_account   -> dim_accounts
--   transaction_type -> dim_transaction_types

select
    -- foreign keys (join out to dimensions)
    step_hour,
    origin_account,
    transaction_type,

    -- context
    dest_account,

    -- measures
    amount,
    error_balance_orig,
    error_balance_dest,
    risk_score,
    flag_zero_dest_balance,
    flag_origin_emptied,
    flag_large_amount,
    is_suspicious,
    is_fraud

from {{ ref('mart_suspicious_activity') }}
