-- Confusion matrix: is_suspicious (prediction) vs is_fraud (truth)

select
  is_suspicious,
  is_fraud,
  count(*) as txns
from `fincrime-501917.dbt_dsingh.mart_suspicious_activity`
group by is_suspicious, is_fraud
order by is_suspicious, is_fraud;

-- Read as:
--   is_suspicious=true,  is_fraud=1  -> True Positive  (caught fraud)
--   is_suspicious=true,  is_fraud=0  -> False Positive (false alarm)
--   is_suspicious=false, is_fraud=1  -> False Negative (missed fraud)
--   is_suspicious=false, is_fraud=0  -> True Negative  (correctly ignored)
--
--   Recall    = TP / (TP + FN)   = caught / all real fraud
--   Precision = TP / (TP + FP)   = caught / everything flagged
--
-- TUNING RESULTS (total fraud in sample = 8,213):
--
-- | Threshold | TP    | FP     | FN    | TN      | Recall | Precision |
-- |-----------|-------|--------|-------|---------|--------|-----------|
-- | >= 2      | 6,820 | 45,760 | 1,393 |  63,130 |  83%   |   13%     |
-- | >= 3      | 2,562 |     16 | 5,651 | 108,874 |  31%   |   99.4%   |
--
-- Tightening the threshold trades recall for precision. Shipped at >= 2
-- (first-line screening). See README for the full discussion.
