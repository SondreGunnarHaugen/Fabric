# Table structure
Within the data lakehouse, establishing a clear and consistent table structure is critical. 

>[!Note]
> Please note that **Date** and **Time tables/columns** are exceptions to this rule and follow their own specific design patterns, which are [detailed separately here](date_time_values.md) from the structural guidelines below.

## Dimension Tables
A dimension table is a supporting table that provides context to fact tables. They describe the who, what, where, and when surrounding an event. Dimension tables contain descriptive attributes that make it possible to filter, group, and analyze data in meaningful ways. The [foreign keys](https://learn.microsoft.com/en-us/sql/relational-databases/tables/primary-and-foreign-key-constraints?view=sql-server-ver17#FKeys) in the fact table correspond to the [primary keys](https://learn.microsoft.com/en-us/sql/relational-databases/tables/primary-and-foreign-key-constraints?view=sql-server-ver17#PKeys) (PK) in the dimension tables.

Dimension tables are the first components to be created in the Gold layer. Within these tables, we implement a **Surrogate Key (SK)**, **Retained Key (RK)**, and **Business Key (BK)** (all being string for flexibility purpose). This design empowers users to select their preferred primary key (PK) and define their own level of granularity when analyzing the data. Additionally, including **Slowly Changing Dimension (SCD) tracking columns** such as validation dates (`FROM_DATE` and `TO_DATE`), an active flag, and a row operational status (e.g., Created, Updated, or Deleted) helps provide a comprehensive audit trail of how the data has evolved over time.

### Dimension Table Example
| SK_name | rk_name | bk_name | ... | SC_FROM_DATE | SC_TO_DATE | SC_Active | SC_STATUS |
| --- | --- | --- | --- | --- | --- | --- | --- |
| hash_value_sk_1 | hash_value_rk_1 | BK_1 | ... | 2023-01-01 | 2024-02-02 | 0 | C |
| hash_value_sk_2 | hash_value_rk_1 | BK_1 | ... | 2024-02-03 | 2025-06-02 | 0 | U |
| hash_value_sk_3 | hash_value_rk_1 | BK_1 | ... | 2025-06-03 | 9999-12-31 | 1 | D |

> [!NOTE]
> SC_Active indicates whether a row is the last registered movement for that key, not whether the underlying record is currently valid or existing at the source. This is why row 3 can carry SC_Active = 1 together with SC_STATUS = D: it means a deletion is the most recent movement registered for BK_1, and that row remains the open-ended (SC_TO_DATE = 9999.12.31) current state until a new movement, such as the record being re-created, is registered against the same key.

Surrogate key (SK) and retained key (RK) hash values do not need to be [Globally Unique Identifiers (GUIDs)](https://learn.microsoft.com/en-us/dotnet/api/system.guid?view=net-10.0); they only need to be unique within their specific dimension table. If an accidental duplicate hash value occurs across two different dimension tables, it does not pose a systemic failure for data analysis. This is because the mismatched keys will only align under an incorrect relationship and for only a few data points. The resulting data will immediately signal to the developer or user that something is wrong with the numbers. This acts as a natural indicator, prompting them to verify that the correct connection points used for the relationship.

## Fact Tables
A fact table contains measurable, quantitative data that describes business events. Typical examples are sales amounts, number of units sold, or costs. Fact tables contain [foreign keys](https://learn.microsoft.com/en-us/sql/relational-databases/tables/primary-and-foreign-key-constraints?view=sql-server-ver17#FKeys) (FK) that connect them to dimension tables. Before building a fact table, explicitly **define its granularity**. Keeping the granularity strictly consistent across all rows prevents double-counting issues.

### Design & Structure
Fact tables are created in the pipeline after their corresponding dimension tables have been processed.
* **Format:** Fact tables are stored in a **long format**. This structure is highly optimized for analytical engines and Power BI, though it is less optimal for Excel (which prefers wide, flat tables).
* **Surrogate-, Retention-, and Business Keys:** The fact table stores the Surrogate Key (SK), Retention Key (RK) and Business Key (BK) for each associated dimension.
* **Degenerate Dimensions (BKs in Fact):** We intentionally include the Business Key (BK) from the dimension tables directly in the fact table. This allows users to understand the data, troubleshoot, and trace errors without needing to join the dimension tables.
* **Handling missing values:** NA values are never allowed in key columns of fact table in order to maintain referential integrity. If a dimension value is missing or not applicable for a record, map the SK, RK and BK to a designated default row in the dimension table as `-1`. 

#### Fact Table Example
| SK_dim_1 | RK_dim_1 | BK_dim_1 | SK_dim_2 | RK_dim_2 | BK_dim_2 | ... | SK_dim_N | RK_dim_N | BK_dim_N | value_1 | value_2 | ... | value_N |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| hash_value_sk_1 | hash_value_rk_1 | BK_1 | hash_value_sk_4 | hash_value_rk_4 | BK_4 | ... | hash_value_sk_N | hash_value_rk_N | BK_N | x | x | ... | x |
| hash_value_sk_2 | hash_value_rk_2 | BK_2 | hash_value_sk_5 | hash_value_rk_5 | BK_5 | ... | hash_value_sk_N+1 | hash_value_rk_N | BK_N | x | x | ... | x |
| hash_value_sk_3 | hash_value_rk_3 | BK_3 | hash_value_sk_6 | hash_value_rk_6 | BK_6 | ... | hash_value_sk_N+2 | hash_value_rk_N | BK_N | x | x | ... | x |

> [!NOTE] 
> Date and time tracking are excluded here as they follow [another structure](date_time_values.md)


### Pipeline Dependencies & Resilience
While a fact table is logically dependent on its dimension tables, a failure in a dimension pipeline should not entirely block the fact pipeline.

* **Incremental Resilience:** Because dimensions are loaded incrementally, existing dimension rows remain available to successfully be joined into the fact table.
* **Late-Arriving Dimensions:** If a brand-new transaction arrives with a Business Key (BK) that failed to load into the dimension table, the fact pipeline should handle this by defaulting to `-1` as [described above](#design--structure).