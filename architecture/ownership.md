# Ownership & Service Principal
All semantic models should be owned by a **Service Principal (SP)** rather than an individual user account. This is because it can prevent refresh failures if the owner leaves the company, changes roles, or updates their credentials. Silent refresh failures often go undetected until business users report stale data. Resolving this manually requires another employee to locate every affected semantic model and take over ownsership. 

To fix this I have made a ownership transfer script to the Service Principal. Before running the script, the tenant setting **"Service principals can call Fabric public APIs"** must be enabled by a Fabric admin in the Admin Portal. Without it, the Service Principal cannot take ownership of any item regardless of the credentials used. Before the script can be used, you must first aquire these values: 
* **Tenant ID:** Your Microsoft Entra (Azure AD) directory ID.
* **Client ID (App ID):** The unique application identifier for the Service Principal.
* **Client Secret (Password):** The authentication secret for the Service Principal.

Either ask your IT department to aquire them or run this script in PowerShell (if you know the username and client secret):

```powershell
# Prerequisites: Install-Module AzureAD -Scope CurrentUser (or Microsoft.Graph)
az ad sp list --display-name "Your-Service-Principal-Name" --query "[].{Name:displayName, ClientID:appId, TenantID:appOwnerOrganizationId, ObjectID:id}" -o table
```

Ones you have done this, run this PowerShell [takeover script](scripts/fabricSemanticModelTakeover.ps1)

> [!NOTE]
> **Best Practice:** This script is a remediation tool for models that have already fallen back to individual ownership. It is not yet wired into the CI/CD pipeline. The best practice is to have the deployment pipeline set the Service Principal as owner automatically at publish time (e.g., as a step in the same GitHub Actions workflow described in the [deployment guide](deployment.md)), so ownership never lands on an individual account in the first place. This automated takeover step has not been developed yet and should be treated as a follow-up item.