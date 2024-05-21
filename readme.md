# //build 24 demos
## Terraform & GHA  Demo
* Built from [TF GHA](https://github.com/hashicorp/setup-terraform) and this [sample](https://github.com/Azure-Samples/terraform-github-actions?tab=readme-ov-file) 
* Here is the [module definition example](./terraform/tfModuleExample.md).


## Crossplane & ArgoCD
### Installation
* [Crossplane Azure Upbound Provider](https://marketplace.upbound.io/providers/upbound/provider-family-azure/v1.1.0)
* [Argo](https://argo-cd.readthedocs.io/en/stable/)

### Demo
To deploy the who environment relies on (installed in this order):
1. Frontend app [CRD](./crossplane-comp/crd.yaml)
2. Frontend app composition
3. Frontend app claim

#### Claim example from the demo:
```yaml
apiVersion: compute.example.com/v1alpha1
kind: FrontEndApp
metadata:
  name: bingo
spec: 
  location: EU
  repoUrl:  https://github.com/danielsollondon/teaminfra
  repoPath: infra/shared/k8s-cluster-config/main-infra-002
  appName: testfront02
```

The full composition example and "how-to" in the //build demo will be shared end ETA - end of May.




>NOTE Demos are functional examples and not production ready and not necessarily best practice!