# Date and Time
Handling date and time in modern data platforms requires a clear separation between the two. While source systems often combine them into a single `DATETIME` field, analytics and reporting tools (like Power BI) perform better if they are split into distinct dimensions.

## Why Split Date and Time?

### 1. Cardinality and Performance
Combining date and time into a single dimension creates extremely high cardinality (unique values).

* A single combined `Datetime` dimension for 10 years at a 1-minute granularity results in over **5.2 million rows**. At 1-second granularity, it jumps to **315 million rows**, which severely degrades Power BI compression and performance.
* Splitting them into `Dim_Date` (3,650 rows for 10 years) and `Dim_Time` (86,400 rows for every second of a day) drastically reduces memory footprint while retaining full granularity.

### 2. Granularity Stability
Data tracking may change over time. If your system currently tracks data hourly and later upgrades to 15-minute or 1-second intervals, a combined dimension table could require a complete rebuild to facilitate historical- & new data and reports. By separating them, your `Dim_Time` table can easily scale to higher granularities without affecting your `Dim_Date` table or historical relationships.

## Time Zone Standardization
* **Standardize to UTC:** Convert all timestamps to **UTC** in into the Silver layer. This eliminates issues with daylight savings times (DST) and differing regional source clocks.
* **Reporting Time Zones:** If the business requires local time for reporting, preserve the local time as a secondary field in the fact table.

## Key Design: "Smart Keys"
For date and time dimensions, do not use random hash values as Surrogate Keys. Use predictable **integer-based "Primary Keys"**:

* **Date PK format:** `YYYYMMDD` (e.g., `20260714` for July 14, 2026).
* **Time PK format:** `HHMMSS` (e.g., `135731` for 13:57:31)

This approach allows for easier partition slicing and troubleshooting without needing to join the dimensions.

## Analytics & Modeling in Power BI
Power BI handles the combination of `Date` from `Dim_Date` and `Time` from `Dim_Time` as **categorical values**, not continuous variables. If visuals require continuous values, then use the datetime from the fact table and use the dim values for filtering. A problem may arise when comparing values across different fact tables. If the data visualization spans more than 4 weeks, aggregate by date, week, or month instead of datetime as the level of grunularity is unecessary.

## Dim_Date: Extended Attributes
To support advanced reporting requirements, the standard `Dim_Date` table should be enriched with the following values: 
* **Fiscal Values:** Standard calendar years do not always align with a company’s financial year. Include fields for **Fiscal Year** and **Fiscal Quarter** (e.g., `FY2026`, `FQ1`) based on the organization's financial calendar to allow seamless financial reporting.
* **ISO Weeks:** Standard calendar weeks often split the first and last weeks of a year. Use **ISO-8601 Weeks** (`Week_ISO` and `Year_ISO`) to ensure every week has exactly 7 days and weeks remain consistent and comparable from year to year.
* **Rolling Values (Offsets):** To simplify relative-date filtering and boost Power BI performance, include dynamic integer rolling columns (e.g., `Rolling_Day`, `Rolling_Month`, `Rolling_Year`).
    - **Logic:** `0` represents the **current** period (today/this month/this year etc.).
    - **Negative integers** ($< 0$) represent the **past** (e.g., `-1` is yesterday/last month etc.).
    - **Positive integers** ($> 0$) represent the **future** (e.g., `1` is tomorrow/next month etc.).
    - **Pipeline Note:** Because these offsets shift daily, the pipeline loading `Dim_Date` **must be re-processed daily** to keep the semantic models and Power BI filters accurate.
* **Holiday:** For companies operating in multiple countries, holiday tracking must scale without duplicating rows. 
    - Implement a boolean flag for each operating country (e.g., `Is_Holiday_NO`, `Is_Holiday_US`).
    - Include a corresponding description field where appropriate (e.g., `Holiday_Name_NO`)
* **Working Days:** Same definition as holdiay, but for working days for each country/region.
* **Months:** Include the month number (as text with 0x for month number $< 10$), full name, and short name (abbreviation). The month number is required to sort the text-based month columns chronologically, while the full and short names provide flexibility to fit different visual layouts in reports.


### Example Dim Date Schema
Below is an example of how these extended columns are structured in the `Dim_Date` table (other colums is also welcomed)

| PK_Date | Date | ... |Fiscal_Year | Fiscal_Quarter | Year_ISO | Week_ISO | Rolling_Day |  Rolling_Month | Rolling_Year | Is_Holiday_NO | Holiday_Name_NO | Is_Holiday_US | Holiday_Name_US | Is_Working_Day_NO | Is_Working_Day_US | Month_Number | Month_Name_Full | Month_Name_Short |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20260713 | 2026-07-13 | ... | FY2026 | FQ3 | 2026 | 29 | -1 | 0 | 0 | False | *NULL* | False | *NULL* | True | True | 07 | July | Jul |
| 20260714 | 2026-07-14 | ... | FY2026 | FQ3 | 2026 | 29 | 0 | 0 | 0 | False | *NULL* | False | *NULL* | True | True | 07 | July | Jul |
| 20260715 | 2026-07-15 | ... | FY2026 | FQ3 | 2026 | 29 | 1 | 0 | 0 | False | *NULL* | False | *NULL* | True | True | 07 | July | Jul |
| 20261126 | 2026-11-26 | ... | FY2026 | FQ4 | 2026 | 48 | 135 | 4 | 0 | False | *NULL* | True | Thanksgiving Day | True | False | 11 | November | Nov |
| 20261225 | 2026-12-25 | ... | FY2026 | FQ4 | 2026 | 52 | 164 | 5 | 0 | True | 1. Juledag | True | Christmas Day | False | False | 12 | December | Dec |


## Dim_Time: Extended Attributes

To support granular behavioral tracking and high-performance time-of-day analytics, the standard `Dim_Time` table should be enriched with the following attributes:
* **Time Granularity (Time Buckets):** Analyses rarely look at time down to the exact second. Standardizing time into larger intervals makes reporting much cleaner.
    - Include dedicated columns that group individual times into standard buckets of **15, 30, and 60 minutes** (or the specific intervals required by the business).
    - These groupings allow users to easily aggregate for example transactions or traffic patterns without heavy calculations in Power BI.
* **Classification of Day (Day periods):** Categorize the 24-hour cycle into distinct shifts or business periods (e.g., `Morning`, `Afternoon`, `Evening`, `Night`). This allows users to easily filter and compare performance across broad daily segments.
* **Peak Hours:** Include a boolean flag (`Is_Peak_Hour`) to identify high-volume business hours. This enables quick analysis of peak versus off-peak activities (e.g., rush-hour traffic, peak dining hours, or high-volume system load periods).

### Example Schema

Below is an example of how these extended columns are structured in the `Dim_Time` table, assuming a business with peak hours defined between 08:00–10:00 and 16:00–18:00.

| PK_Time | Time | Hour | Minute | Second | Bucket_15_Min | Bucket_30_Min | Bucket_60_Min | Day_Period | Is_Peak_Hour |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 081459 | 08:14:59 | 08 | 14 | 59 | 08:00 | 08:00 | 08:00 | Morning | True |
| 081500 | 08:15:00 | 08 | 15 | 00 | 08:15 | 08:00 | 08:00 | Morning | True |
| 134512 | 13:45:12 | 13 | 45 | 12 | 13:45 | 13:30 | 13:00 | Afternoon | False |
| 200500 | 20:05:00 | 20 | 05 | 00 | 20:00 | 20:00 | 20:00 | Evening | False |
| 023000 | 02:30:00 | 02 | 30 | 00 | 02:30 | 02:30 | 02:00 | Night | False |

### Fact Table Example
The fact table references both keys and retains the raw `Datetime_UTC` for continuous analytical calculations. If needed, include local time as their own FK

| FK_Date_UTC_00  | FK_Time_UTC_00 | Datetime_UTC_00 | FK_Date_Local  | FK_Time_Local | Datetime_Local |... | Value_1 |
| --- | --- | --- | --- | --- |
| 20260714 | 135700 | 2026-07-14 13:57:00.000 | 20260714 | 155700 | 2026-07-14 15:57:00.000 |... | 150.00 |
| 20260714 | 135701 | 2026-07-14 13:57:01.000 | 20260714 | 155700 | 2026-07-14 15:57:00.000 |... | 45.50 |