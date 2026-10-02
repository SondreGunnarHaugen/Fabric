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
* Usage of V-ordering, Optimize, Z-ordering, and VACUUM 
* Usage of [User Data Functions](https://learn.microsoft.com/en-us/fabric/data-engineering/user-data-functions/user-data-functions-overview)
* How to deal with schema changes
    * Adding Columns
    * Changing data types of existing columns
    * Renaming columns
    * Removing columns
    * Changing nullable attributes
* Use of Material Views
* Change deployment to only use test and prod workspace
    * Only all files in local version of branch
        * Calculations group does not work in Tabular Editor 2, but can still edit them in the .tmdl files
    * Developers only work on items on local github branch and switch the branch test is connected to
        * allows for multiple project to be tested at the same time (create more test workspace if multiple projects must be tested at the same time)
        * Allows for better git history of commits and PR as one can clean up before pr
