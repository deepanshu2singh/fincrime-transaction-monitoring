-- dim_accounts: one row per ORIGIN account (entity-level view).
-- Turns transaction-level data into entity-level insight - how a FinCrime
-- team actually investigates (accounts, not lone transactions).
--
-- Scope note: built on the mart, so it covers accounts that SENT
-- TRANSFER/CASH_OUT only. On PaySim accounts barely repeat, so suspicious_rate
-- is mostly 0.0 or 1.0 here; the model would rank genuine risk on real data
-- with repeating accounts.

with txns as (

    select * from {{ ref('mart_suspicious_activity') }}

),

account_summary as (

    select
        origin_account,

        case
            when starts_with(origin_account, 'C') then 'customer'   -- PaySim: C = customer
            when starts_with(origin_account, 'M') then 'merchant'   --         M = merchant
            else 'unknown'
        end as account_type,

        count(*)                          as total_transactions,
        sum(amount)                       as total_amount_sent,
        sum(is_fraud)                     as fraud_transactions,
        sum(cast(is_suspicious as int64)) as flagged_transactions   -- cast bool -> int to SUM

    from txns
    group by origin_account

)

select
    *,
    round(flagged_transactions / total_transactions, 3) as suspicious_rate
from account_summary
