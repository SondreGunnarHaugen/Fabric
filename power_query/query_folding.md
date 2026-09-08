# Query Folding

[Query Folding](https://learn.microsoft.com/en-us/power-query/power-query-folding) is the process in Power Query where applied transformations are translated into a single native query (such as SQL) and executed directly on the source database, rather than processed locally within the Power Query engine. This allows Power Query to leverage the compute power and optimization of the underlying source system, whether it is a relational database, a big data platform, or a web service. 

> [!Note]
> If connected to a supported database (mostly SQL), it is recommended to use [native database queries](minimize_power_query.md#native-database-query) over focusing on Query Folding. If a combination of native database query and Query Folding is needed, see these [steps](#query-folding-with-native-database-query)

When Query Folding is active, operations like filtering, grouping, aggregation, and joins are pushed down to the data source. Consequently, only the required subset of data is loaded into Power Query, significantly reducing data transfer volume and accelerating scheduled refresh performance.

## Key Benefits of Query Folding

* **Superior Refresh Performance:** Offloads resource-heavy computing to optimized database engines.
* **Reduced Data Transfer:** Fetches only the necessary rows and columns over the network.
* **Optimized Local Resource Consumption:** Minimizes CPU and RAM usage on local machines and On-Premises Data Gateways.
* **Automated Query Generation:** Power Query dynamically determines which transformation steps can be translated into native code.

Not all data sources or transformation steps support Query Folding. Complex custom transformations may cause folding to stop, forcing subsequent steps to be processed locally in memory. Certain sources support partial folding, while flat files (like CSVs or Excel spreadsheets) do not support it at all. To achieve optimal model performance, extensive transformations should be performed as far upstream as possible, prioritizing foldable data sources whenever feasible.

## Step Ordering & Preventing "Fold Breaks"

Query folding processes sequentially from top to bottom through the **Applied Steps** pane. The moment a non-foldable operation is introduced, query folding breaks for that step and every step that follows—forcing all remaining operations to be processed locally on your machine or Gateway.

### Best Practices for Step Ordering

* **Push Foldable Steps to the Top:** Place all operations natively supported by database engines at the very beginning of your query. This includes filtering rows (`Table.SelectRows`), removing unneeded columns (`Table.SelectColumns`), and basic grouping or sorting.
* **Defer Non-Foldable Operations:** Delay operations that inherently break folding until the absolute end of your transformation steps. Common "fold breakers" include:
    * Adding an Index Column (`Table.AddIndexColumn`)
    * Calling custom M functions or external API scripts
    * Complex string manipulation or data type conversions unsupported by the source
* **Isolate Non-Foldable Source Merges:** Merging a foldable database source with a non-foldable source (such as an Excel sheet or CSV) breaks folding for all subsequent steps. Perform as much filtering and aggregation as possible on the database source *before* executing the merge.

### Query Folding with native database query
[Query Folding on native queries](https://learn.microsoft.com/en-us/power-query/native-query-folding) is possible, however, it must be [supported](https://learn.microsoft.com/en-us/power-query/native-query-folding#supported-data-connectors). To enable it, remember to define `EnableFolding = true` in Power Query like this:
```text
    Source = Sql.Database("ServerName", "DatabaseName", [
        Query = "SELECT * FROM TABLE", //
        EnableFolding = true
    ])
```