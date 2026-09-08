# Connection with SQL

## Fabric

In Fabric, you can also run SQL queries directly within the platform. Click on the lakehouse:

![Fabric SQL Lakehouse](images/Fabric_SQL_Lakehouse.png)

Then click on "New SQL query" and choose your preference:

![Fabric New SQL](images/Fabric_New_SQL.png)


## VS Code

First, download MSSQL:

![Last ned MSSQL](images/VS_code_mssql_install.png)

Then, create a connection:

![VS Code MSSQL Connection](images/VS_code_connection.png)

Check that you have connected:

![VS Code Connection Check](images/VS_code_check_connection.png)

Next, create a .sql file, press **Ctrl+Shift+P**, and type *MS SQL: Connect*. Select the desired connection. When creating a SQL query, ensure it is linked to the correct connection:

![VS Code Run SQL](images/VS_code_run_SQL.png)

## Retrieving SQL Analytics Endpoints

Go to the workspace where the data is located and find a lakehouse/warehouse. Then, locate the SQL analytics endpoint and copy it:

![SQL Analytic Endpoint](images/sql_analytic_endpoint.png)

## SQL Server Management Studio (SSMS)

Use [SSMS](https://learn.microsoft.com/en-us/ssms/sql-server-management-studio-ssms) for this procedure. Use the link you found in [SQL analytics endpoint](#retrieving-sql-analytics-endpoints) for the "Server Name":

![SSMS Connection](images/SSMS_connection.png)

Then, authenticate using the following account:

![SSMS Authentication](images/SSMS_authentication.png)