{{ config(materialized='table') }}

-- Analyst-facing scoring mart. Scores each transaction against three rules,
-- sums them into risk_score, and flags is_suspicious at the chosen threshold.
-- Materialised as a table: queried repeatedly by dashboards.

with features as (

    select * from {{ ref('int_transactions_features') }}

),

scored as (

    select
        *,

        -- Rule 1: destination balance zero before AND after.
        -- Money is "received" but the balance never updates. Strongest tell.
        case when dest_balance_before = 0 and dest_balance_after = 0
             then 1 else 0 end as flag_zero_dest_balance,

        -- Rule 2: origin account fully emptied by this single transaction.
        case when origin_balance_after = 0 and amount > 0
             then 1 else 0 end as flag_origin_emptied,

        -- Rule 3: unusually large amount (tunable threshold).
        case when amount >= 200000
             then 1 else 0 end as flag_large_amount

    from features

),

final as (

    select
        *,
        (flag_zero_dest_balance + flag_origin_emptied + flag_large_amount) as risk_score

    from scored

)

select
    *,
    -- Operating point. >= 2 : ~83% recall / ~13% precision (first-line screen).
    --                 >= 3 : ~31% recall / ~99.4% precision (auto-action).
    case when risk_score >= 2 then true else false end as is_suspicious
from final
