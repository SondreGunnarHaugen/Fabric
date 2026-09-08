# Architecture
This is the overview of how the architecture is connected in Fabric: 
* [Medallion](medallion.md) - The ETL process 
* [Table structure](tables_structure.md) - How tables should be structured
* [Date time values](date_time_values.md) - Date and Time has their own approach for their structures
* [Deployment](deployment.md) - How to deploy changes for different stakeholders
* [Ownership](ownership.md) - Who owns semantic models


TODO: 
* Administer connections within Fabric
* GitHub Actions (referance in deployment)
    * CI/CD script for semantic model owner (make sure that the Service Principal always own the semantic model)
    * CI/CD script for swapping connection strings
    * CI/CD script for removing shortcuts to tables in prod for developer branches
    * CI/CD script for formatting DAX measures
    * CI/CD script for warning for the DAX measures that don't have comments / descriptions in them
    * CI/CD script for filling the description of a Measure with the DAX formula (withouth overwriting existing comments)
    * CI/CD script for discourage implicit measures and hiding them (reference with )
* Delegated OneLake Shortcuts (Preview)
* Creation of hash values for RK and SK
