# Privacy Level
[Privacy Levels](https://learn.microsoft.com/en-us/power-query/privacy-levels) in [Power Query](../power_query/index.md) classify data sources. They control how data from one source can be combined with, or folded into, another source. Here are the options:

| **Setting** | **Description** |
| --- | --- |
| **None** | There are no privacy settings | 
| **Private** | Data sources set to **Private** contain sensitive or confidential information and cannot be folded into other data sources, including other private data sources |
| **Organizational** | Data sources set to **Organizational** can fold in to private and other organizational data sources |
| **Public** | Data sources set to **Public** can fold in to other data sources |

These labels define how [data can be combined](https://learn.microsoft.com/en-us/power-query/privacy-levels#preventing-accidental-data-transfer).

**Example**:  Two tables where one is sensitive and one is non sensitive. For both tables the privacy level is set to *Organizational*, where the sensitive table is used for a querying the nonsensitive one. With [Query Folding](../power_query/query_folding.md), the data from the sensitive table will be sent to the non sensitive source and data is leaked.

This is one security measure that must be concidered when using [Power Query](../power_query/index.md).