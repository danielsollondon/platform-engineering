# Demo links
> Note!
The code here is NOT best practice, neither production quality, it is for illustration and should be reviewed with security and subject matter experts prior to deployment and not be deployed into production systems. The author does not accept any liability for using it.


* [ADE Runner example](https://github.com/Azure/ade-extensibility-model-terraform)
* [ADE Catalog Item for Cloud Native FIP(inc TF)](./environments/) 
* [Getting Started with ADE](aka.ms/ade/getstarted)
* [ADE Extensibility Model](https://learn.microsoft.com/en-us/azure/deployment-environments/how-to-configure-extensibility-model-custom-image?tabs=sample%2Cprivate-registry&pivots=arm-bicep)
* [Cloud Native Template](./scripts/full-backend-env-fips.yaml) 
* [Argo](https://argo-cd.readthedocs.io/en/stable/)

# AKS Features used
* [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview?tabs=dotnet)
* [AKS + FIPS](https://learn.microsoft.com/en-us/azure/aks/enable-fips-nodes)
* [AKS Cost Mgmt.](https://learn.microsoft.com/en-us/azure/aks/cost-analysis)
* [AKS Key Vault Secret Store Provider](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver)
* [Kubernetes AI Tool Chain Operator](https://learn.microsoft.com/en-us/azure/aks/ai-toolchain-operator)
* [Azure AKS Policy](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes)
* [Deployment Safe-Guards](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards)
* [Azure managed Prometheus + Grafana, Azure Monitoring/Container Insights (logs)](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-overview)
* [AKS AAD Enabled RBAC](https://learn.microsoft.com/en-us/azure/aks/azure-ad-rbac?tabs=portal)
* [AKS Automatic Clusters (provides many of the features above already configured)](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-automatic-deploy?pivots=azure-portal)

# Cloud Native Samples
* [AKS Cloud Native PE Samples (build a PE environment based GitOps and AKS, Backstage example)](https://github.com/Azure-Samples/aks-platform-engineering)
* [View K8s clusters with Headlamp in Backstage](https://headlamp.dev/blog/2024/11/11/introducing-an-integrated-backstage-and-headlamp-experience)
* [Crossplane + Argo on Azure Deep Dive](https://github.com/danielsollondon/platform-engineering/tree/main)

# Recorded Sessions
* [Enabling standardization, compliance and security in a platform](https://www.youtube.com/watch?v=qDIQHzjqlqQ)
    * Focus tech: Azure Security, Argo, Azure Policy (Policy as Code)
* [Enabling self service resource standardization](https://www.youtube.com/watch?v=mGq442iwAF0)
    * Focus Tech: Crossplane Composite Resources & Argo + TF Modules and GitHub Actions
* [Enabling self service of full developer environments with AKS multi-tenency & self service](https://www.youtube.com/watch?v=YvBPcY013i4)
    * Focus Tech: Argo, Terraform, Azure Deployment environments, Grafana, Log Analytics.


# More information links
* [Policy as code](aka.ms/policyAsCodeSample)
* [Azure Policy](aka.ms/azurepolicy)
* [GitHub Advanced Security](aka.ms/ghas)
* [Defender for Cloud](aka.ms/defenderforcloud)
* [Azure Deployment Environments(ADE) Blog](aka.ms/ignite24/ade-blog)
