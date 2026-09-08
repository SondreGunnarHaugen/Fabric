# Remember to change code at TODO comments to your own values before running the script.

# Libraries tested for CVE (Common Vulnerabilities and Exposures) at https://security.snyk.io/ 28.05.2026
import struct
import urllib
import pandas as pd

from azure.identity import AzureCliCredential
from sqlalchemy import create_engine, event

# TODO: Change SQL endpoint here
SERVER   = "sql-endpoint-connection-string"
LAKEHOUSE_NAME = "Name_of_your_lakehouse"

# Example of how it should look
# SERVER   = "zk67cexmt33eljr6ebq3sv7i5y-ev6j7ufyteyenkdggihknivzam.datawarehouse.fabric.microsoft.com"
# LAKEHOUSE_NAME = "Kurs_Lakehouse"

# This code retrieves an access token for Microsoft Fabric (or Azure SQL) using your local Azure CLI authentication, and formats it into a specific binary structure often required for authentication against databases.
def get_fabric_token_struct() -> bytes:
    token = AzureCliCredential().get_token("https://database.windows.net/.default")
    token_bytes = token.token.encode("utf-16-le")
    return struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

# This is a standard ODBC connection string that defines how a Python program (or other applications) should connect to a SQL database.
conn_str = (
    f"Driver={{ODBC Driver 18 for SQL Server}};"
    f"Server={SERVER};Database={LAKEHOUSE_NAME};"
    f"Encrypt=yes;TrustServerCertificate=no;"
)

params = urllib.parse.quote_plus(conn_str) # Removes special characters with URL-legal characters
engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}", echo=False) # Creates the engine used to run queries against the database

# Connects SQLAlchemy and Azure AD/Entra ID authentication
@event.listens_for(engine, "do_connect")
def provide_token(dialect, conn_rec, cargs, cparams):
    cparams["attrs_before"] = {1256: get_fabric_token_struct()}


# TODO: Change the query to the data you wish to retrieve
sql_query = "SELECT TOP 10 * FROM dbo.Table"

# Example: 
# sql_query = "SELECT TOP 10 * FROM dbo.Date"

# Retrieves the desired data
with engine.connect() as conn:
    df = pd.read_sql(sql_query, conn)


# TODO: Perform the desired actions with the data
print(f"Rows returned: {len(df)}")
print(df)