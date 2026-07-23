-- Intermediate model: filters to the fraud-bearing transaction types and
-- engineers the balance-error features (the core fraud signal in PaySim).

with transactions as (

    select * from {{ ref('stg_transactions') }}

),

with_features as (

    select
        *,

        -- balance error on the origin side (~0 for a clean transaction)
        (origin_balance_after + amount - origin_balance_before) as error_balance_orig,

        -- balance error on the destination side (strongest fraud signal)
        (dest_balance_before + amount - dest_balance_after)     as error_balance_dest

    from transactions

)

select * from with_features
where transaction_type in ('TRANSFER', 'CASH_OUT')   -- fraud occurs only in these two
