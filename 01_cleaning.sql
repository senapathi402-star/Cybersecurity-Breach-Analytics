-- ============================================================
-- Cybersecurity Breaches Dataset — SQL Data Cleaning
-- Raw data loaded into breaches_raw via command-line mysql
-- client (LOAD DATA LOCAL INFILE) after MySQL Workbench's GUI
-- importer repeatedly failed with Error 2013 on the bulk load.
-- ============================================================

-- ------------------------------------------------------------
-- STEP 0: Raw data import
-- Run from a terminal (not inside Workbench), since Workbench's
-- GUI importer could not handle a file this size:
--   1. cd "C:\Program Files\MySQL\MySQL Server 8.0\bin"
--   2. mysql -u root -p --local-infile=1 cybersecurity_project
--   3. Run the two statements below from the resulting mysql> prompt.
-- ------------------------------------------------------------
CREATE TABLE breaches_raw (
    BreachID                 TEXT,
    BreachDate               TEXT,
    Year                     TEXT,
    Month                    TEXT,
    Country                  TEXT,
    Industry                 TEXT,
    OrganizationSize         TEXT,
    AttackType               TEXT,
    ThreatActorType          TEXT,
    SeverityLevel            TEXT,
    RecordsExposed           TEXT,
    FinancialLossUSD         TEXT,
    RegulatoryFinesUSD       TEXT,
    DataTypeCompromised      TEXT,
    EncryptionUsed           TEXT,
    MFAEnabled               TEXT,
    IncidentResponsePlan     TEXT,
    SecurityTeamSize         TEXT,
    DetectionDays            TEXT,
    ContainmentDays          TEXT,
    ResolutionDays           TEXT,
    DetectionMethod          TEXT,
    ThirdPartyInvolved       TEXT,
    CloudEnvironment         TEXT,
    RemoteWorkRelated        TEXT,
    PreviousBreachHistory    TEXT,
    CustomerNotificationDays TEXT,
    RecoveryStatus           TEXT,
    ThreatActorCountryOrigin TEXT,
    ComplianceFramework      TEXT
);

LOAD DATA LOCAL INFILE 'C:/path/to/cybersecurity_breaches.csv'
INTO TABLE breaches_raw
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM breaches_raw;  -- confirms 904,501 rows loaded

USE cybersecurity_project;

-- ------------------------------------------------------------
-- Initial inspection
-- ------------------------------------------------------------
SELECT * FROM breaches_raw;
SELECT COUNT(BreachID) - COUNT(DISTINCT BreachID) FROM breaches_raw;  -- confirms 4,501 duplicates

-- ------------------------------------------------------------
-- Dedupe: in-place DELETE rather than a full-table copy —
-- far more disk-efficient at 900K+ rows. Uses a temporary
-- row_id primary key to identify which copy of each duplicate
-- BreachID to keep (the first-inserted one).
-- ------------------------------------------------------------
ALTER TABLE breaches_raw ADD COLUMN row_id INT AUTO_INCREMENT PRIMARY KEY;
CREATE INDEX idx_breachid ON breaches_raw(BreachID(20));

SET SQL_SAFE_UPDATES = 0;

DELETE r1 FROM breaches_raw r1
JOIN breaches_raw r2
    ON r1.BreachID = r2.BreachID
    AND r1.row_id > r2.row_id;

-- ------------------------------------------------------------
-- Rebuild as a clean, BreachID-sorted table; drop the raw table
-- and the temporary row_id helper column once confirmed clean.
-- ------------------------------------------------------------
CREATE TABLE breaches AS
SELECT * FROM breaches_raw ORDER BY BreachID;

SHOW INDEX FROM breaches;
DROP TABLE breaches_raw;
ALTER TABLE breaches DROP COLUMN row_id;

SHOW TABLES;
DESCRIBE breaches;

CREATE UNIQUE INDEX idx_breachid_unique ON breaches(BreachID(20));
SHOW INDEX FROM breaches;

SELECT * FROM breaches;
SELECT COUNT(BreachID) - COUNT(DISTINCT BreachID) FROM breaches;  -- expect 0

SET SQL_SAFE_UPDATES = 0;

-- ------------------------------------------------------------
-- BreachID / BreachDate / Year / Month — trim + proper types
-- ------------------------------------------------------------
UPDATE breaches SET BreachID = TRIM(BreachID);

UPDATE breaches SET BreachDate = STR_TO_DATE(BreachDate, '%d-%m-%Y');
ALTER TABLE breaches MODIFY COLUMN BreachDate DATE;

SELECT DISTINCT Year FROM breaches ORDER BY Year;
ALTER TABLE breaches MODIFY COLUMN Year INT;

SELECT DISTINCT Month FROM breaches ORDER BY Month;
ALTER TABLE breaches MODIFY COLUMN Month INT;

-- ------------------------------------------------------------
-- Country — casing + typo/abbreviation fixes (planted
-- "Unites Kingdom" typo, "UAE"/"SINGAPORE" variants)
-- ------------------------------------------------------------
SELECT DISTINCT Country FROM breaches ORDER BY Country;

UPDATE breaches SET
Country = CASE
    WHEN LOWER(TRIM(Country)) = 'singapore' THEN 'Singapore'
    WHEN LOWER(TRIM(Country)) = 'uae' THEN 'United Arab Emirates'
    WHEN LOWER(TRIM(Country)) = 'unites kingdom' THEN 'United Kingdom'
    ELSE TRIM(Country)
END;

-- ------------------------------------------------------------
-- Categorical inspection: Industry, OrganizationSize,
-- AttackType, ThreatActorType, SeverityLevel
-- ------------------------------------------------------------
SELECT DISTINCT Industry FROM breaches ORDER BY Industry;
SELECT DISTINCT OrganizationSize FROM breaches ORDER BY OrganizationSize;
SELECT DISTINCT AttackType FROM breaches ORDER BY AttackType;

SELECT DISTINCT ThreatActorType FROM breaches ORDER BY ThreatActorType;
UPDATE breaches SET ThreatActorType = 'Unknown' WHERE ThreatActorType = '';

SELECT DISTINCT SeverityLevel FROM breaches ORDER BY SeverityLevel;

-- ------------------------------------------------------------
-- RecordsExposed — fix negatives, convert to INT
-- ------------------------------------------------------------
SELECT DISTINCT RecordsExposed FROM breaches ORDER BY RecordsExposed;
UPDATE breaches SET RecordsExposed = ABS(RecordsExposed);
ALTER TABLE breaches MODIFY COLUMN RecordsExposed INT;

-- ------------------------------------------------------------
-- FinancialLossUSD — strip "$", convert to DECIMAL
-- ------------------------------------------------------------
SELECT FinancialLossUSD FROM breaches ORDER BY FinancialLossUSD DESC;
UPDATE breaches SET FinancialLossUSD = REPLACE(FinancialLossUSD, '$', '');
ALTER TABLE breaches MODIFY COLUMN FinancialLossUSD DECIMAL(15,2);

-- ------------------------------------------------------------
-- RegulatoryFinesUSD — blank -> 0, convert to DECIMAL
-- ------------------------------------------------------------
SELECT RegulatoryFinesUSD FROM breaches;
UPDATE breaches SET RegulatoryFinesUSD = 0 WHERE RegulatoryFinesUSD = '';
ALTER TABLE breaches MODIFY COLUMN RegulatoryFinesUSD DECIMAL(15,2);

-- ------------------------------------------------------------
-- ComplianceFramework — found via investigation that every
-- value carried an invisible trailing carriage-return
-- character (hex 0D) from the CSV's Windows-style line
-- endings, left over because the last column in each row
-- picks up whatever trails the final delimiter. Confirmed via
-- HEX() inspection, not visible in normal SELECT output.
-- ------------------------------------------------------------
SELECT DISTINCT DataTypeCompromised FROM breaches;
SELECT DISTINCT ComplianceFramework FROM breaches ORDER BY ComplianceFramework;
SELECT COUNT(*) FROM breaches WHERE ComplianceFramework = '';
SELECT COUNT(*) FROM breaches WHERE ComplianceFramework IS NULL;

SELECT ComplianceFramework, LENGTH(ComplianceFramework), HEX(ComplianceFramework)
FROM breaches
WHERE ComplianceFramework NOT IN ('GDPR', 'General/Other', 'HIPAA', 'PCI-DSS')
LIMIT 10;
-- Hex output confirmed a trailing 0D (carriage return) on every value.

UPDATE breaches
SET ComplianceFramework = TRIM(TRAILING '\r' FROM ComplianceFramework);

UPDATE breaches SET ComplianceFramework = 'Unknown' WHERE ComplianceFramework = '';

-- ------------------------------------------------------------
-- Yes/No standardization across all binary indicator columns
-- ------------------------------------------------------------
SELECT DISTINCT EncryptionUsed FROM breaches;
UPDATE breaches SET
EncryptionUsed = CASE
    WHEN EncryptionUsed = 'Y' THEN 'Yes'
    WHEN EncryptionUsed = 'N' THEN 'No'
    WHEN EncryptionUsed = 'YES' THEN 'Yes'
    WHEN EncryptionUsed = 'NO' THEN 'No'
    ELSE TRIM(EncryptionUsed)
END;

SELECT DISTINCT MFAEnabled FROM breaches;
UPDATE breaches SET
MFAEnabled = CASE
    WHEN MFAEnabled = 'Y' THEN 'Yes'
    WHEN MFAEnabled = 'N' THEN 'No'
    WHEN MFAEnabled = 'YES' THEN 'Yes'
    WHEN MFAEnabled = 'NO' THEN 'No'
    ELSE TRIM(MFAEnabled)
END;

SELECT DISTINCT IncidentResponsePlan FROM breaches;
UPDATE breaches SET
IncidentResponsePlan = CASE
    WHEN IncidentResponsePlan = 'Y' THEN 'Yes'
    WHEN IncidentResponsePlan = 'N' THEN 'No'
    WHEN IncidentResponsePlan = 'YES' THEN 'Yes'
    WHEN IncidentResponsePlan = 'NO' THEN 'No'
    ELSE TRIM(IncidentResponsePlan)
END;

-- ------------------------------------------------------------
-- SecurityTeamSize — blank -> 1 (minimum team-size default),
-- convert to INT
-- ------------------------------------------------------------
SELECT DISTINCT SecurityTeamSize FROM breaches ORDER BY SecurityTeamSize;
UPDATE breaches SET SecurityTeamSize = 1 WHERE SecurityTeamSize = '';
ALTER TABLE breaches MODIFY COLUMN SecurityTeamSize INT;

-- ------------------------------------------------------------
-- Response timeline columns — convert to INT
-- ------------------------------------------------------------
SELECT DISTINCT DetectionDays FROM breaches ORDER BY DetectionDays;
ALTER TABLE breaches MODIFY COLUMN DetectionDays INT;

SELECT DISTINCT ContainmentDays FROM breaches ORDER BY ContainmentDays;
ALTER TABLE breaches MODIFY COLUMN ContainmentDays INT;

SELECT DISTINCT ResolutionDays FROM breaches ORDER BY ResolutionDays;
ALTER TABLE breaches MODIFY COLUMN ResolutionDays INT;

-- ------------------------------------------------------------
-- DetectionMethod — blank -> Unknown
-- ------------------------------------------------------------
SELECT DISTINCT DetectionMethod FROM breaches ORDER BY DetectionMethod;
SELECT COUNT(DetectionMethod) FROM breaches WHERE DetectionMethod = '';
UPDATE breaches SET DetectionMethod = 'Unknown' WHERE DetectionMethod = '';

-- ------------------------------------------------------------
-- Remaining Yes/No standardization columns
-- ------------------------------------------------------------
SELECT DISTINCT ThirdPartyInvolved FROM breaches;
UPDATE breaches SET
ThirdPartyInvolved = CASE
    WHEN ThirdPartyInvolved = 'Y' THEN 'Yes'
    WHEN ThirdPartyInvolved = 'N' THEN 'No'
    WHEN ThirdPartyInvolved = 'YES' THEN 'Yes'
    WHEN ThirdPartyInvolved = 'NO' THEN 'No'
    ELSE TRIM(ThirdPartyInvolved)
END;

SELECT DISTINCT CloudEnvironment FROM breaches;
UPDATE breaches SET
CloudEnvironment = CASE
    WHEN CloudEnvironment = 'Y' THEN 'Yes'
    WHEN CloudEnvironment = 'N' THEN 'No'
    WHEN CloudEnvironment = 'YES' THEN 'Yes'
    WHEN CloudEnvironment = 'NO' THEN 'No'
    ELSE TRIM(CloudEnvironment)
END;

SELECT DISTINCT RemoteWorkRelated FROM breaches;
UPDATE breaches SET
RemoteWorkRelated = CASE
    WHEN RemoteWorkRelated = 'Y' THEN 'Yes'
    WHEN RemoteWorkRelated = 'N' THEN 'No'
    WHEN RemoteWorkRelated = 'YES' THEN 'Yes'
    WHEN RemoteWorkRelated = 'NO' THEN 'No'
    ELSE TRIM(RemoteWorkRelated)
END;

SELECT DISTINCT PreviousBreachHistory FROM breaches;
UPDATE breaches SET
PreviousBreachHistory = CASE
    WHEN PreviousBreachHistory = 'Y' THEN 'Yes'
    WHEN PreviousBreachHistory = 'N' THEN 'No'
    WHEN PreviousBreachHistory = 'YES' THEN 'Yes'
    WHEN PreviousBreachHistory = 'NO' THEN 'No'
    ELSE TRIM(PreviousBreachHistory)
END;

-- ------------------------------------------------------------
-- CustomerNotificationDays — convert to INT
-- ------------------------------------------------------------
SELECT COUNT(CustomerNotificationDays) FROM breaches WHERE CustomerNotificationDays IS NULL;
ALTER TABLE breaches MODIFY COLUMN CustomerNotificationDays INT;

-- ------------------------------------------------------------
-- RecoveryStatus, ThreatActorCountryOrigin — inspection + fix
-- ------------------------------------------------------------
SELECT DISTINCT RecoveryStatus FROM breaches;

SELECT DISTINCT ThreatActorCountryOrigin FROM breaches ORDER BY ThreatActorCountryOrigin;
UPDATE breaches SET
ThreatActorCountryOrigin = CASE
    WHEN TRIM(ThreatActorCountryOrigin) = 'UAE' THEN 'United Arab Emirates'
    ELSE TRIM(ThreatActorCountryOrigin)
END;

-- ------------------------------------------------------------
-- Final verification
-- ------------------------------------------------------------
DESCRIBE breaches;
SELECT COUNT(*) FROM breaches;  -- expect 900,000
