-- =====================================================================
-- BigQuery practice (Weeks 1-2)
-- Dataset: fincrime-501917.fincrime.raw_transactions  (PaySim subsample)
-- Save location in repo: /explore
--
-- Notes:
--  * Project = fincrime-501917, dataset = fincrime (region: EU).
--  * The Week 2 nested-data queries hit a US public dataset; BigQuery
--    auto-routes those jobs to US. Just don't join EU + US in one query.
--  * Subsample keeps ALL fraud rows + a slice of legit rows, so fraud
--    rates here are inflated vs the full 6M-row PaySim file.
-- =====================================================================


-- ---------------------------------------------------------------------
-- A5. Verify the load
-- 'rows' is a reserved word in BigQuery -> alias as row_count instead.
-- Expected: ~258,213 rows, ~8,213 frauds.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS row_count, SUM(isFraud) AS frauds
FROM `fincrime-501917.fincrime.raw_transactions`;


-- =====================================================================
-- WEEK 1 - Cost model + core querying
-- =====================================================================

-- ---------------------------------------------------------------------
-- B1. Bytes-scanned habit
-- BigQuery is columnar: it only reads the columns you name.
-- Check the "This query will process X" estimate (top-right) BEFORE running.
--   SELECT *          -> ~25 MB  (reads all 11 columns)
--   SELECT type,amount-> ~4.5 MB (reads 2 columns)
-- LIMIT does NOT reduce bytes scanned.
-- ---------------------------------------------------------------------
SELECT * FROM `fincrime-501917.fincrime.raw_transactions`;

SELECT type, amount FROM `fincrime-501917.fincrime.raw_transactions`;


-- ---------------------------------------------------------------------
-- B2. Fraud rate by transaction type  (first FinCrime finding)
-- Finding: fraud occurs ONLY in TRANSFER and CASH_OUT.
--          CASH_IN, DEBIT, PAYMENT are all 0% fraud.
-- This is why downstream models filter to TRANSFER + CASH_OUT.
-- ---------------------------------------------------------------------
SELECT
  type,
  COUNT(*)                                AS txns,
  SUM(isFraud)                            AS frauds,
  ROUND(SUM(isFraud) / COUNT(*) * 100, 3) AS fraud_pct
FROM `fincrime-501917.fincrime.raw_transactions`
GROUP BY type
ORDER BY fraud_pct DESC;


-- ---------------------------------------------------------------------
-- B3. Clustering (concept)
-- Clustering sorts data by chosen columns so filters on them scan less.
-- On a table this small the benefit is ~zero (data fits one block) -
-- clustering/partitioning pay off at large scale, not on 258k rows.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `fincrime-501917.fincrime.tx_clustered`
CLUSTER BY type AS
SELECT * FROM `fincrime-501917.fincrime.raw_transactions`;

-- compare bytes processed (Job information tab) on these two:
SELECT COUNT(*) FROM `fincrime-501917.fincrime.raw_transactions`
WHERE type = 'TRANSFER';

SELECT COUNT(*) FROM `fincrime-501917.fincrime.tx_clustered`
WHERE type = 'TRANSFER';


-- =====================================================================
-- WEEK 2 - Window functions, nested data, sharded tables
-- =====================================================================

-- ---------------------------------------------------------------------
-- C1a. Window function + QUALIFY
-- Each account's single largest transaction, then the top 20 overall.
-- QUALIFY filters on a window result without a wrapping subquery
-- (a BigQuery/Snowflake convenience).
-- ---------------------------------------------------------------------
SELECT nameOrig, type, amount
FROM `fincrime-501917.fincrime.raw_transactions`
QUALIFY ROW_NUMBER() OVER (PARTITION BY nameOrig ORDER BY amount DESC) = 1
ORDER BY amount DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- C1b. Ordered running count (account velocity pattern)
-- Finding: txn_number is ~always 1 -> origin accounts rarely repeat in
-- PaySim, so account-velocity signals are weak on this dataset.
-- The technique still transfers to real data where accounts recur.
-- ---------------------------------------------------------------------
SELECT
  nameOrig, step, amount,
  COUNT(*) OVER (
    PARTITION BY nameOrig ORDER BY step
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS txn_number
FROM `fincrime-501917.fincrime.raw_transactions`
ORDER BY nameOrig, step
LIMIT 50;


-- ---------------------------------------------------------------------
-- C1c. Diagnostic: do accounts repeat at all?
-- Finding: max repeats = 2. Confirms accounts are near-unique.
-- ---------------------------------------------------------------------
SELECT nameOrig, COUNT(*) AS n
FROM `fincrime-501917.fincrime.raw_transactions`
GROUP BY nameOrig
HAVING COUNT(*) > 1
ORDER BY n DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- C2. Structuring pattern (many sub-threshold transfers)
-- Finding: returns NO rows - given accounts don't repeat, structuring
-- can't appear here. Empty result = information: this rule belongs on
-- real transaction data, not synthetic PaySim.
-- ---------------------------------------------------------------------
SELECT nameOrig, COUNT(*) AS sub_threshold_transfers
FROM `fincrime-501917.fincrime.raw_transactions`
WHERE type = 'TRANSFER' AND amount BETWEEN 9000 AND 10000
GROUP BY nameOrig
HAVING COUNT(*) >= 2
ORDER BY sub_threshold_transfers DESC;


-- ---------------------------------------------------------------------
-- C3a. Sharded tables + _TABLE_SUFFIX  (US public dataset)
-- Wildcard * spans date-named tables; _TABLE_SUFFIX reads AND filters
-- which shards get scanned (a cost lever). Sample only has 20170801 here.
-- ---------------------------------------------------------------------
SELECT
  _TABLE_SUFFIX AS day,
  COUNT(*)      AS sessions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE _TABLE_SUFFIX BETWEEN '20170801' AND '20170807'
GROUP BY day
ORDER BY day;


-- ---------------------------------------------------------------------
-- C3b. UNNEST on nested/repeated data  (the Monzo-shaped skill)
-- `hits` is an ARRAY of STRUCTs inside each session row.
-- UNNEST(hits) explodes the array; the comma cross-joins each session
-- to its hits; hit.page.pagePath reaches into the nested struct.
-- ---------------------------------------------------------------------
SELECT
  hit.page.pagePath AS page,
  COUNT(*)          AS hits
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_20170801`,
     UNNEST(hits) AS hit
WHERE hit.type = 'PAGE'
GROUP BY page
ORDER BY hits DESC
LIMIT 20;


-- ---------------------------------------------------------------------
-- C4. Defensive casting with SAFE_CAST
-- Bad input -> NULL instead of a query-killing error. Used to defend
-- type conversions in dbt staging models.
-- Result: bad = NULL, good = 42.
-- ---------------------------------------------------------------------
SELECT SAFE_CAST('not_a_number' AS INT64) AS bad,
       SAFE_CAST('42' AS INT64)           AS good;


-- =====================================================================
-- BONUS - capstone seed (not run yet; for the dbt staging model)
-- Balance-error features from the Kaggle notebook. These are per-
-- transaction (not account-based), so unlike velocity/structuring they
-- WORK on PaySim. For a clean transaction both errors sit near zero;
-- a large error is the fraud tell.
-- =====================================================================
SELECT
  *,
  newbalanceOrig + amount - oldbalanceOrg  AS error_balance_orig,
  oldbalanceDest + amount - newbalanceDest AS error_balance_dest
FROM `fincrime-501917.fincrime.raw_transactions`
WHERE type IN ('TRANSFER', 'CASH_OUT');
