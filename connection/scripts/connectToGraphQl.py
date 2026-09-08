import requests
from azure.identity import AzureCliCredential

# 1. Authenticate using Azure CLI credentials
credential = AzureCliCredential()
token_result = credential.get_token("https://analysis.windows.net/powerbi/api/.default")

# TODO: Change the GraphQL endpoint
graphql_url = "https://your-graphql-endpoint/graphql" 

# Example:
# graphql_url = "https://d09f7c2599b84630a866320ea6a2b903.zd0.graphql.fabric.microsoft.com/v1/workspaces/d09f7c25-99b8-4630-a866-320ea6a2b903/graphqlapis/711a88ce-4279-42c4-afa7-d835893fe022/graphql"

# TODO: Change the GraphQL query to your desired query
query = """
query GetTableData {
  tableName {
    items {
      column_1
      column_2
      column_3
    }
  }
}
"""

# Example:
# query = """
# query GetTableData {
#   geographies {
#     items {
#       GeographyID
#       ZipCodeBKey
#       County
#       City
#       State
#       Country
#       ZipCode
#     }
#   }
# }
# """

# 3. Send HTTP POST request
headers = {
    "Authorization": f"Bearer {token_result.token}",
    "Content-Type": "application/json"
}

response = requests.post(graphql_url, json={"query": query}, headers=headers)
data = response.json()

print(data)
