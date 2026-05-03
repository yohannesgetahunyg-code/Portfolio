-- ================================================
-- Bank Loan Default Analysis
-- Author: Yohannes Getahun
-- Tools: MySQL
-- Dataset: 100,514 loan records
-- ================================================

-- Query 1: Overall loan default rate
SELECT 
  `Loan Status`,
  COUNT(*) AS total_loans,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM credit_train
WHERE `Loan Status` IS NOT NULL
GROUP BY `Loan Status`;

-- Query 2: Default rate by loan purpose
SELECT 
  `Purpose`,
  COUNT(*) AS total_loans,
  SUM(CASE WHEN `Loan Status` = 'Charged Off' THEN 1 ELSE 0 END) AS defaults,
  ROUND(SUM(CASE WHEN `Loan Status` = 'Charged Off' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM credit_train
WHERE `Purpose` IS NOT NULL
GROUP BY `Purpose`
ORDER BY default_rate_pct DESC;

-- Query 3: Default rate by credit score band
-- Note: Credit scores normalized due to data quality issue
-- Some scores were stored at 10x scale (e.g. 7500 instead of 750)
SELECT 
  CASE 
    WHEN normalized_score >= 750 THEN 'Excellent (750+)'
    WHEN normalized_score >= 700 THEN 'Good (700-749)'
    WHEN normalized_score >= 650 THEN 'Fair (650-699)'
    ELSE 'Poor (<650)'
  END AS credit_band,
  COUNT(*) AS total_loans,
  ROUND(SUM(CASE WHEN `Loan Status` = 'Charged Off' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM (
  SELECT 
    CASE 
      WHEN `Credit Score` > 850 THEN `Credit Score` / 10
      ELSE `Credit Score`
    END AS normalized_score,
    `Loan Status`
  FROM credit_train
  WHERE `Credit Score` IS NOT NULL 
    AND `Credit Score` != 0
) AS cleaned
GROUP BY credit_band
ORDER BY default_rate_pct DESC;

-- Query 4: Data quality check on credit scores
-- Identified mixed scale issue (normal 300-850 and inflated 10x)
SELECT 
  MIN(`Credit Score`) AS min_score,
  MAX(`Credit Score`) AS max_score,
  AVG(`Credit Score`) AS avg_score,
  COUNT(*) AS total,
  SUM(CASE WHEN `Credit Score` = 0 THEN 1 ELSE 0 END) AS zero_scores
FROM credit_train;

-- Query 5: Find customers appearing in both train and test datasets
SELECT 
  t.`Customer ID`,
  t.`Loan Status`,
  t.`Current Loan Amount` AS train_loan_amount,
  te.`Current Loan Amount` AS test_loan_amount,
  t.`Credit Score`,
  t.`Purpose`
FROM credit_train t
INNER JOIN credit_test te 
  ON t.`Customer ID` = te.`Customer ID`
LIMIT 20;

-- Query 6: Repeat vs new customer default rate
SELECT 
  'Repeat Customer' AS customer_type,
  COUNT(*) AS total_loans,
  ROUND(SUM(CASE WHEN t.`Loan Status` = 'Charged Off' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM credit_train t
INNER JOIN credit_test te 
  ON t.`Customer ID` = te.`Customer ID`

UNION ALL

SELECT 
  'New Customer' AS customer_type,
  COUNT(*) AS total_loans,
  ROUND(SUM(CASE WHEN t.`Loan Status` = 'Charged Off' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM credit_train t
LEFT JOIN credit_test te 
  ON t.`Customer ID` = te.`Customer ID`
WHERE te.`Customer ID` IS NULL;