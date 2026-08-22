# Cybersecurity Breach Analytics — One Dataset, Six Tools

End-to-end analysis of a 904,501-row synthetic cybersecurity breach dataset (2010–2024, 30 fields), analyzed across **Excel, SQL, Python, Power BI, Tableau, and Google Sheets** to demonstrate depth of analytical thinking — not just chart-building — across the full BI toolchain.

**Live dashboards:**
- Excel dashboard: <img width="955" height="381" alt="image" src="https://github.com/user-attachments/assets/a3224cb5-9299-4fff-80cc-7f03e379d029" />


---

## Why this project exists

Most portfolio projects show polished charts on data that was never questioned. This one is built around the opposite habit: **verify before you trust a number.**

The dataset started as 900K purely randomized synthetic rows. Every early "insight" — top countries by breach count, detection time vs. financial loss — turned out to be statistical noise: values clustered within a near-zero variance band with no real-world relationships between fields. Rather than write confident bullet points on meaningless numbers, the dataset was rebuilt from scratch with genuine, real-world-style correlations (severity driving response time, MFA/encryption reducing damage, industry-specific cost multipliers, geographic and temporal skew), and every downstream pivot table, chart, and finding was re-validated against source data before being finalized.

That validation discipline — not the chart count — is the actual point of this project.

---

## Dataset

- **904,501 rows** (900,000 unique breach records + 4,501 intentional duplicates for cleaning practice), **30 columns**
- Fields include: BreachDate, Country, Industry, AttackType, ThreatActorType, SeverityLevel, RecordsExposed, FinancialLossUSD, RegulatoryFinesUSD, EncryptionUsed, MFAEnabled, DetectionDays, ContainmentDays, ResolutionDays, and 16 additional supporting fields
- Deliberately messy: duplicates, missing values, inconsistent text casing, a planted typo variant, negative values, and mixed-type numeric fields — mirroring realistic data quality issues

---

## Phase 1: Excel ✅ Complete

**Data Cleaning & Validation**
- Removed 4,501 duplicate records (verified via BreachID + full-row match)
- Standardized 18 categorical fields (casing, whitespace, typo correction — e.g. a planted "Unites Kingdom" variant)
- Converted mixed-type numeric fields (currency-formatted text → numeric) and null-handled 5 columns with documented, defensible logic:
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
- Breaches without MFA cost **97% more** on average ($312.57B vs. $158.83B total); without encryption, **84% more**
- Healthcare leads in both breach volume (170,767) and total financial loss ($126B) — the most expensive sector to be breached in
- Breach frequency and financial cost don't move in lockstep: Retail has more breaches than Technology, but less total loss

Every figure above was cross-checked against the raw dataset using Python before being finalized in the Excel dashboard.

---

## Phase 2: SQL 🔄 In Progress

Window functions, CTEs, and aggregate analysis on the same dataset — coming next.

## Phase 3–5: Python, Power BI, Tableau, Google Sheets 📋 Planned

Same dataset, same validated findings, rebuilt in each tool to demonstrate cross-platform fluency.

---

## Repository Structure

```
/excel/           Excel workbook, dashboard, data validation report
/sql/             SQL scripts (in progress)
/python/          Pandas/EDA scripts (planned)
/data/            Source dataset (904,501 rows, CSV)
/screenshots/     Dashboard exports and validation summaries
```

---

## Tools & Techniques

**Excel:** Power Query, PivotTables & PivotCharts, SUMIF/AVERAGEIF, slicers, IQR outlier detection, data type validation (ISNUMBER/ISTEXT)
**Python:** Pandas, NumPy (dataset generation with engineered statistical correlations)
**SQL / Power BI / Tableau / Google Sheets:** in progress

---

## Author

**Krishna Sai** — Data Analyst
[LinkedIn](https://linkedin.com/in/senapathi-krishna-sai)
