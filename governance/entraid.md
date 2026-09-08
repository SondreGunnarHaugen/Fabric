# Entra ID

[Entra ID Groups](https://docs.azure.cn/en-us/entra/fundamentals/concept-learn-about-groups#microsoft-entra-groups-overview) allow organizations to manage access rights, licenses, and security policies collectively rather than on an individual basis. While Entra ID includes both Microsoft 365 groups and Security Groups, Security Groups are the primary focus for governance.

Typically, the IT department controls the creation and configuration of Entra ID Security Groups, making collaboration with them essential. The gold standard for group management is automation: utilizing dynamic groups to minimize manual maintenance. Instead of manually adding or removing users, individuals are automatically assigned to security groups based on their organizational attributes or roles. With this model, access management for individuals are handeled by the employees manager instead of the workspace admin/report builder. This ensures a secure, scalable and automated governance model.

> [!Note]
> While I have experience utilizing this governance model in practice, I have not personally developed the backend automation. The exact technical configuration is therefore uncertaint.

Within Power BI, these Entra ID security groups serve as the primary mechanism for managing access to Workspaces, Power BI Apps, and Row-Level/Object-Level Security (RLS/OLS) roles.