# Cybersecurity Breach Analytics — One Dataset, Four Tools

End-to-end analysis of a 904,501-row synthetic cybersecurity breach dataset (2010–2024, 30 fields), analyzed across **Excel, SQL, Python, and Power BI** to demonstrate depth of analytical thinking — not just chart-building — across the full BI toolchain.

**Live dashboards:**
- Excel dashboard:
- <img width="844" height="624" alt="excel dashboard" src="https://github.com/user-attachments/assets/4c16c21c-ca8c-49c0-bdca-ad8cae693189" />

---

## Why this project exists

Most portfolio projects show polished charts on data that was never questioned. This one is built around the opposite habit: **verify before you trust a number.**

The dataset started as 900K purely randomized synthetic rows. Every early "insight" — top countries by breach count, detection time vs. financial loss — turned out to be statistical noise: values clustered within a near-zero variance band with no real-world relationships between fields. Rather than write confident bullet points on meaningless numbers, the dataset was rebuilt from scratch with genuine, real-world-style correlations (severity driving response time, MFA/encryption reducing damage, industry-specific cost multipliers, geographic and temporal skew), and every downstream pivot table, chart, and finding was re-validated against source data before being finalized.

That validation discipline carried into the SQL phase too: an initial SQL pass at the MFA/encryption cost comparison used SUM-based totals and produced different percentages (97%/84%) than the already-validated Excel figures. Rather than accept the mismatch, the discrepancy was traced to SUM blending per-incident severity with group-size effects — switching to per-incident AVG reconciled the SQL result with Excel's original, correct figures. Catching and explaining a cross-tool inconsistency, rather than letting two dashboards quietly disagree, is the actual point of this project.

---

## Dataset

- **904,501 rows** (900,000 unique breach records + 4,501 intentional duplicates for cleaning practice), **30 columns**
- Fields include: BreachDate, Country, Industry, AttackType, ThreatActorType, SeverityLevel, RecordsExposed, FinancialLossUSD, RegulatoryFinesUSD, EncryptionUsed, MFAEnabled, ComplianceFramework, DetectionDays, ContainmentDays, ResolutionDays, and additional supporting fields
- Deliberately messy: duplicates, missing values, inconsistent text casing, a planted typo variant, negative values, mixed-type numeric fields, and hidden non-printing characters — mirroring realistic data quality issues

---

## Phase 1: Excel ✅ Complete

**Data Cleaning & Validation**
- Removed 4,501 duplicate records (verified via BreachID + full-row match)
- Standardized categorical fields (casing, whitespace, typo correction — e.g. a planted "Unites Kingdom" variant)
- Converted mixed-type numeric fields (currency-formatted text → numeric) and null-handled columns with documented, defensible logic:
  - `RecordsExposed`: negative values corrected via `ABS()` (verified as sign-entry errors, not corrupted records)
  - `RegulatoryFinesUSD`: "N/A" text entries → 0 (preserves numeric type; documented as a "no fine" assumption, not "unknown")
  - `SecurityTeamSize`: nulls → 1 (conservative minimum-team-size default)
- Outlier review via IQR method (Q1/Q3, 1.5×IQR bounds)
- Full validation report documenting every check, method, and assumption

**Dashboard** (8 charts, slicer-driven KPIs)
- KPI band: Total Breaches, Records Exposed, Financial Loss, Regulatory Fines, Avg Detection/Containment/Resolution/Notification Days — filterable by Severity Level
- Breach trend by Year and Month
- Response Time by Breach Severity (Low → Critical, 4-metric clustered comparison)
- Top 10 Countries by Breaches
- Financial Loss by Industry
- Breaches by Attack Type
- Financial Loss by MFA Status / Encryption Status

**Key findings**
- Critical-severity breaches take **5x longer to detect** than Low-severity ones (214 vs. 41 days), with the gap compounding through containment (299 vs. 57) and resolution (395 vs. 75)
- Breaches without MFA cost **81% more** on average per incident; without encryption, **124% more**
- Healthcare leads in both breach volume (170,767) and total financial loss ($126B) — the most expensive sector to be breached in
- Breach frequency and financial cost don't move in lockstep: Retail has more breaches than Technology, but less total loss

Every figure above was cross-checked against the raw source data before being finalized in the Excel dashboard.

---

## Phase 2: SQL ✅ Complete

**Setup Notes** (see [`sql/01_cleaning.sql`](sql/01_cleaning.sql))
The raw CSV was too large for MySQL Workbench's GUI importer, which failed repeatedly with **Error 2013**. It was instead loaded via the command-line `mysql` client using `LOAD DATA LOCAL INFILE`, which handled the full 904,501-row file directly — a reminder that GUI and CLI tools can hit different practical limits against the exact same database.

**Data Cleaning & Validation** (see [`sql/01_cleaning.sql`](sql/01_cleaning.sql))
Rebuilt the Excel-phase cleaning logic natively in SQL, plus full type conversion from raw text to proper numeric/date types:
- Deduplicated 904,501 → 900,000 rows using an indexed, in-place DELETE rather than a full-table copy, which proved far more efficient at this scale
- ABS()-corrected negative RecordsExposed; stripped $/commas from FinancialLossUSD and RegulatoryFinesUSD, converted to DECIMAL
- Replaced null/blank SecurityTeamSize with 1; standardized Country, EncryptionUsed, MFAEnabled casing
- Caught a subtler issue in ComplianceFramework: every value carried an invisible trailing carriage-return character (hex 0D) from the original CSV's Windows-style line endings — invisible on screen, confirmed via HEX() inspection, and cleaned with TRIM(TRAILING '\r' FROM ...)

**Data Manipulation & Analysis** (see [`sql/02_analysis.sql`](sql/02_analysis.sql))
13 analytical questions answered using GROUP BY aggregations, CASE-based categorization, window functions (RANK, LAG, running totals via SUM() OVER), and subquery joins, including:
- Detection time by severity level
- Cost impact of MFA and encryption (per-incident basis)
- Industry-level breach volume and financial loss
- Year-over-year trend with running cumulative loss
- Costliest industry per country
- Combined MFA + encryption protection-level comparison
- Top 10 costliest individual breaches vs. their industry average
- Threat actor type cost comparison
- Compliance framework category breakdown

**Key finding: reconciling a cross-tool discrepancy**
An initial SQL query compared MFA/encryption cost impact using SUM(FinancialLossUSD) per group, producing 97%/84% — different from Excel's validated 81%/124%. The mismatch traced to SUM conflating two effects: per-incident severity and group size (there are meaningfully more no-MFA breaches than MFA-enabled ones in the dataset). Recomputing with per-incident AVG reconciled the SQL result with Excel's original figures, confirming both were measuring the same underlying pattern correctly — just at different levels of aggregation.

---

## Phase 3–4: Python, Power BI 📋 Planned

Same dataset, same validated findings, extended in each tool — Python for statistical analysis (correlation, distribution-aware percentile analysis) that SQL and Excel aren't well-suited for, Power BI for an interactive cross-platform dashboard.

---

## Repository Structure

```
/excel/           Excel workbook, dashboard, data validation report
/sql/
  01_cleaning.sql   Raw data import (LOAD DATA LOCAL INFILE), dedupe,
                    type conversion, and full column-by-column cleaning
  02_analysis.sql   13 analytical queries: cost impact comparisons,
                    industry/country breakdowns, trends, rankings
/python/          Planned: statistical analysis (correlation, distribution work)
/data/            Source dataset (904,501 rows, CSV)
/screenshots/     Dashboard exports and validation summaries
```

---

## Tools & Techniques

**Excel:** Power Query, PivotTables & PivotCharts, SUMIF/AVERAGEIF, slicers, IQR outlier detection, data type validation (ISNUMBER/ISTEXT)
**SQL:** MySQL — CTEs, window functions (RANK, LAG, running totals), subquery joins, indexing for performance, CLI-based bulk loading
**Python:** planned — correlation analysis, distribution-aware percentile analysis
**Power BI:** in progress

---

## Author

**Krishna Sai** — Data Analyst
[LinkedIn](https://linkedin.com/in/senapathi-krishna-sai)
