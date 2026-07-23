-- dim_transaction_types: one row per transaction type with its fraud rate.
-- A classic small "lookup" dimension.
-- Built from STAGING (not the mart) so it covers all five types, including
-- the clean ones (PAYMENT, CASH_IN, DEBIT).

with txns as (

    select * from {{ ref('stg_transactions') }}

),

type_summary as (

    select
        transaction_type,
        count(*)      as total_transactions,
        sum(is_fraud) as fraud_transactions
    from txns
    group by transaction_type

)

select
    *,
    round(fraud_transactions / total_transactions, 4) as fraud_rate
from type_summary
