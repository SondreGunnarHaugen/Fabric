# Power Query
As a general rule, the use of Power Query should be minimized. For complex ETL processes, code-based solutions such as [Fabric Notebooks](https://learn.microsoft.com/en-us/fabric/data-engineering/author-execute-notebook) offer significantly greater scalability, version control, and performance than [Dataflow](https://learn.microsoft.com/en-us/power-query/dataflows/overview-dataflows-across-power-platform-dynamics-365) (which utilize Power Query). Additionally, approaches like [Direct Lake](https://learn.microsoft.com/en-us/fabric/fundamentals/direct-lake-overview) offer better governance over traditional Power Query [import modes](https://learn.microsoft.com/en-us/power-bi/connect-data/service-dataset-modes-understand#import-mode) for data in Power BI.

However, there are still specific scenarios where Power Query remains useful. When using Power Query, consider the following key aspects:

* [Minimize Power Query](minimize_power_query.md) - Use other tools for transformation of data
* [Query Folding](query_folding.md) - If Power Query is used, try to keep query folding
* [Minimize steps](minimizing_steps.md) - Minimize steps to secure Query Folding and optimizing transformation
* [Power Query Functions](functions.md) - What functions to use and which to drop
* [Privacy Levels](../governance/privacy_levels.md) - Under governance folder about effects of privacy levels


TODO: 
* M scripts for date and time
* Variables
