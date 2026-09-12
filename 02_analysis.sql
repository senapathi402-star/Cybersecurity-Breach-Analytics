-- ============================================================
-- Cybersecurity Breaches Dataset — Data Manipulation & Analysis
-- 13 analytical questions answered using GROUP BY aggregations,
-- CASE-based categorization, window functions (RANK, LAG,
-- running totals), and subquery joins. Run against the cleaned
-- `breaches` table (see 01_cleaning.sql).
-- ============================================================

USE cybersecurity_project;

-- ------------------------------------------------------------
-- 1) What's the average detection time by severity level, and
--    how much longer do Critical breaches take to detect than Low?
-- ------------------------------------------------------------
WITH diff_days AS (
    SELECT SeverityLevel, ROUND(AVG(DetectionDays)) AS Avg_Detection
    FROM breaches
    GROUP BY SeverityLevel
)
SELECT
    MAX(CASE WHEN SeverityLevel = 'Critical' THEN Avg_Detection END)
    - MAX(CASE WHEN SeverityLevel = 'Low' THEN Avg_Detection END) AS days_variation
FROM diff_days;
-- Result: 173 days — matches the Excel-phase finding (214 - 41 = 173).

-- ------------------------------------------------------------
-- 2) How much more does the average breach cost when MFA is
--    disabled vs. enabled?
-- ------------------------------------------------------------
WITH Avg_breach_cost AS (
    SELECT
        ROUND(AVG(CASE WHEN MFAEnabled = 'Yes' THEN FinancialLossUSD END)) AS MFAEnabled,
        ROUND(AVG(CASE WHEN MFAEnabled = 'No' THEN FinancialLossUSD END)) AS MFADisabled
    FROM breaches
)
SELECT
    MFADisabled, MFAEnabled,
    CONCAT(ROUND((MFADisabled - MFAEnabled) / MFAEnabled * 100), '%') AS Difference
FROM Avg_breach_cost;
-- Result: 81% more (per-incident basis). An earlier attempt using
-- SUM(FinancialLossUSD) per group gave 97%, since group sizes differ
-- (468,269 No-MFA vs. 431,731 MFA-enabled breaches) — SUM blends
-- per-incident severity with group frequency. AVG isolates the
-- per-incident effect, which is what this question is actually asking.

-- ------------------------------------------------------------
-- 3) How much more does the average breach cost when encryption
--    is not used vs. used?
-- ------------------------------------------------------------
WITH Avg_breach_cost AS (
    SELECT
        ROUND(AVG(CASE WHEN EncryptionUsed = 'Yes' THEN FinancialLossUSD END)) AS Encryption_Used,
        ROUND(AVG(CASE WHEN EncryptionUsed = 'No' THEN FinancialLossUSD END)) AS Encryption_Not_Used
    FROM breaches
)
SELECT
    Encryption_Not_Used, Encryption_Used,
    CONCAT(ROUND((Encryption_Not_Used - Encryption_Used) / Encryption_Used * 100), '%') AS Difference
FROM Avg_breach_cost;
-- Result: 124% more (per-incident basis) — same AVG-vs-SUM
-- consideration as question 2 applies here.

-- ------------------------------------------------------------
-- 4) Which industry has the highest breach volume, and which
--    has the highest total financial loss?
-- ------------------------------------------------------------
SELECT
    Industry,
    COUNT(BreachID) AS breach_count,
    ROUND(SUM(FinancialLossUSD), 2) AS total_loss,
    ROUND(AVG(FinancialLossUSD), 2) AS avg_loss_per_breach
FROM breaches
GROUP BY Industry
ORDER BY avg_loss_per_breach DESC;
-- Result: Healthcare leads both volume and total loss.

-- ------------------------------------------------------------
-- 5) What's the year-over-year trend in breach count and total
--    financial loss, with a running cumulative total?
-- ------------------------------------------------------------
SELECT
    Year,
    COUNT(BreachID) AS Yearly_Breaches,
    SUM(FinancialLossUSD) AS Year_Loss,
    SUM(SUM(FinancialLossUSD)) OVER (ORDER BY Year) AS Running_Total
FROM breaches
GROUP BY Year;

-- ------------------------------------------------------------
-- 6) Which industry causes the highest total loss within each
--    individual country (the "costliest industry per country")?
-- ------------------------------------------------------------
WITH costliest_industry_per_country AS (
    SELECT
        Country, Industry,
        SUM(FinancialLossUSD) AS Country_Highest_Loss,
        DENSE_RANK() OVER (PARTITION BY Country ORDER BY SUM(FinancialLossUSD) DESC) AS country_rank
    FROM breaches
    GROUP BY Country, Industry
)
SELECT Country, Industry, Country_Highest_Loss
FROM costliest_industry_per_country
WHERE country_rank = 1;
-- Result: Healthcare tops every country in this dataset. Given
-- this holds with zero exceptions, it's more likely a strong
-- industry-level effect baked into the synthetic data than a
-- genuine country-specific finding — see the gap-size check below.

SELECT
    Country,
    MAX(CASE WHEN Industry = 'Healthcare' THEN avg_loss END) AS healthcare_avg,
    MAX(CASE WHEN Industry != 'Healthcare' THEN avg_loss END) AS next_best_avg
FROM (
    SELECT Country, Industry, AVG(FinancialLossUSD) AS avg_loss,
           RANK() OVER (PARTITION BY Country ORDER BY AVG(FinancialLossUSD) DESC) AS rnk
    FROM breaches
    GROUP BY Country, Industry
) x
WHERE rnk <= 2
GROUP BY Country;
-- The gap between Healthcare and the runner-up varies by country
-- (not a flat multiplier), suggesting genuine variation on top of
-- a dominant industry effect rather than a copy-pasted constant.

-- ------------------------------------------------------------
-- 7) How does financial loss and detection time compare across
--    four groups: neither MFA nor encryption, one of the two, or both?
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN MFAEnabled = 'No'  AND EncryptionUsed = 'No'  THEN 'Neither protection'
        WHEN MFAEnabled = 'Yes' AND EncryptionUsed = 'No'  THEN 'MFA only'
        WHEN MFAEnabled = 'No'  AND EncryptionUsed = 'Yes' THEN 'Encryption only'
        WHEN MFAEnabled = 'Yes' AND EncryptionUsed = 'Yes' THEN 'Both protections'
    END AS protection_group,
    COUNT(*) AS breach_count,
    ROUND(AVG(FinancialLossUSD), 2) AS avg_loss_usd,
    ROUND(AVG(DetectionDays)) AS avg_detection_days
FROM breaches
GROUP BY protection_group
ORDER BY avg_loss_usd DESC;

-- ------------------------------------------------------------
-- 8) What are the 10 costliest individual breaches, and how far
--    above their industry's average loss is each one?
-- ------------------------------------------------------------
SELECT
    b.BreachID,
    b.Industry,
    b.Country,
    ROUND(b.FinancialLossUSD, 2) AS FinancialLossUSD,
    ROUND(ind_avg.avg_industry_loss, 2) AS Avg_Industry_Loss,
    ROUND(b.FinancialLossUSD - ind_avg.avg_industry_loss, 2) AS above_industry_avg
FROM breaches b
JOIN (
    SELECT Industry, AVG(FinancialLossUSD) AS avg_industry_loss
    FROM breaches
    GROUP BY Industry
) ind_avg ON b.Industry = ind_avg.Industry
ORDER BY b.FinancialLossUSD DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 9) Does breach detection and containment time improve as
--    security team size increases, when grouped into tiers?
--
-- NOTE: SecurityTeamSize is heavily right-skewed (min 1, max 500,
-- median 3). These fixed cutoffs (<=166, <=332) put 899,664
-- breaches in "Small," only 318 in "Medium," and just 18 in
-- "Large" — the Large/Medium averages aren't statistically
-- reliable at that sample size. This question is better answered
-- with quantile-based tiers (e.g. pandas' qcut) in the Python
-- phase, which splits the data into genuinely balanced groups
-- regardless of skew. Left here for reference, not as a trusted
-- finding.
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN SecurityTeamSize <= 166 THEN 'Small'
        WHEN SecurityTeamSize <= 332 THEN 'Medium'
        ELSE 'Large'
    END AS team_size,
    ROUND(AVG(DetectionDays)) AS Avg_detection_days,
    ROUND(AVG(ContainmentDays)) AS Avg_containment_days,
    COUNT(BreachID) AS breach_count
FROM breaches
GROUP BY team_size;

-- ------------------------------------------------------------
-- 10) Which threat actor type is associated with the highest
--     average financial loss?
-- ------------------------------------------------------------
SELECT
    ThreatActorType,
    COUNT(*) AS breach_count,
    ROUND(AVG(FinancialLossUSD), 2) AS avg_loss
FROM breaches
GROUP BY ThreatActorType
ORDER BY avg_loss DESC
LIMIT 1;

-- ------------------------------------------------------------
-- 11) Do breaches involving third parties or remote work cost
--     more on average than those that don't?
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN ThirdPartyInvolved = 'Yes' OR RemoteWorkRelated = 'Yes' THEN 'Yes'
        ELSE 'No'
    END AS ThirdPartyOrRemoteWork,
    ROUND(AVG(FinancialLossUSD), 2) AS avg_loss
FROM breaches
GROUP BY
    CASE
        WHEN ThirdPartyInvolved = 'Yes' OR RemoteWorkRelated = 'Yes' THEN 'Yes'
        ELSE 'No'
    END;

-- ------------------------------------------------------------
-- 12) What's the average number of days between detection,
--     containment, and resolution — and does that gap widen
--     for more severe breaches?
-- ------------------------------------------------------------
SELECT
    SeverityLevel,
    ROUND(AVG(DetectionDays)) AS avg_detection,
    ROUND(AVG(ContainmentDays)) AS avg_containment,
    ROUND(AVG(ResolutionDays)) AS avg_resolution,
    ROUND(AVG(ContainmentDays - DetectionDays)) AS detection_to_containment,
    ROUND(AVG(ResolutionDays - ContainmentDays)) AS containment_to_resolution
FROM breaches
GROUP BY SeverityLevel
ORDER BY avg_detection;

-- ------------------------------------------------------------
-- 13) Which compliance framework category has the most breaches,
--     and do breaches with a named framework (GDPR/HIPAA/PCI-DSS)
--     show a different average financial loss than breaches with
--     no framework (General/Other or Unknown)?
-- ------------------------------------------------------------
SELECT
    ComplianceFramework,
    COUNT(BreachID) AS breach_count,
    ROUND(AVG(FinancialLossUSD), 2) AS avg_loss_usd
FROM breaches
GROUP BY ComplianceFramework;

SELECT
    CASE
        WHEN ComplianceFramework IN ('GDPR', 'HIPAA', 'PCI-DSS') THEN 'Has framework'
        ELSE 'No framework (General/Other or Unknown)'
    END AS framework_status,
    COUNT(*) AS breach_count,
    ROUND(AVG(FinancialLossUSD), 2) AS avg_loss_usd
FROM breaches
GROUP BY framework_status;
