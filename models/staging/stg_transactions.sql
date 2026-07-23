-- Staging model: light cleanup ONLY.
-- Renames PaySim's inconsistent columns into clean snake_case.
-- No filters, no business logic - that lives in the mart layer.

with source as (

    select * from {{ source('fincrime', 'raw_transactions') }}

),

renamed as (

    select
        step            as step_hour,
        type            as transaction_type,
        amount,
        nameOrig        as origin_account,
        oldbalanceOrg   as origin_balance_before,   -- PaySim spells this "Org" (no i)
        newbalanceOrig  as origin_balance_after,    -- but this one "Orig" (with i)
        nameDest        as dest_account,
        oldbalanceDest  as dest_balance_before,
        newbalanceDest  as dest_balance_after,
        isFraud         as is_fraud,
        isFlaggedFraud  as is_flagged_fraud

    from source

)

select * from renamed
