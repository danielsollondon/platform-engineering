# Cloud Native Platform Engineering Concepts with Azure Part 2 (DRAFT)

## Using Crossplane to deploy preconfigured, standardized solutions in Azure
In Terraform you have [TF modules](https://developer.hashicorp.com/terraform/language/modules) that can simplify deploying multiple resources in a sequence, integrate them etc. In Crossplane you have composite resource that represents one or more resource, but they different because they are represented as a K8s resource.

Composite resources are made up of (definitions referenced from [Crossplane documentation](https://docs.crossplane.io)):
1. [Claim (XCs)](https://docs.crossplane.io/latest/concepts/claims/) - Claims represents a set of managed resources as a single Kubernetes object, inside a namespace.
2. [Composite Resource Definition (XRDs)](https://docs.crossplane.io/latest/concepts/composite-resource-definitions/) - Composite resource definitions define the schema for a custom API.
3. [Composite resources (XRs)](https://docs.crossplane.io/latest/concepts/composite-resources/) - A composite resource represents a set of managed resources as a single Kubernetes object. 

In summary, you can create a solution by calling an XRD with some properties, rather than see the underlying complexity, for example this XRD called 'staging-aks', which we will create in the forth coming steps will create a curated AKS cluster with an option to deploy it with an app. This could be used for a dev team and deployed by a dev lead with delegated permissions.

```yaml
apiVersion: compute.example.com/v1alpha1
kind: staging-aks
metadata:
  name: $name
spec: 
  clustername: $clustername
  teamname: $teamname
  location: EU
  repourl: $repourl
  repopath: $repopath

```

### Creating a composite resource
In the example we are going to walk through, we are going to:
1. Shared app AKS cluster 
2. Create a providerConfig that will allow you to create an Argo configuration 
3. Create an XRD that will define the composite resource schema
4. Create an XR that defines the resources and their integrations
4. Deploy the solution via an XC

#### Steps
> Note - Just to reiterate, there are better ways to do this, but the document is focused on ensuring you understand all the moving parts by building them up, at the end of the doc we will link to a complete sample.

# Create Composite resource to create a shared cluster.
In this step you will create and XRD, as per the official documentation they are similar to K8s custom resource definition, and allow you to describe the resource in K8s and the parameters to pass in. In the following example we are going to simulate that your organization has an approved AKS cluster configuration that must be used by teams, you wll create and XRD that will accept 3 properties; clustername, location, rgname, teamName, these are all mandatory. This will then be backed by a XR that  create an AKS cluster and resource group of a specific configuration using those 3 properties, the end user cannot change them. Please review the Crossplane documentation for details on XRD properties.

* From the cloned repo you will have this file that describes the XRD: `mgmtCluster/bootstrap/control-plane/xp-staging-cluster-definitions.yaml`, what it is expecting, and what is required.
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: staging-aks.compute.example.com
spec:
  group: compute.example.com
  names:
    kind: staging-aks
    plural: staging-aks
  versions:
  - name: v1alpha1
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              location:
                type: string
                oneOf:
                  - pattern: '^EU$'
                  - pattern: '^US$'
              clustername:
                type: string
              teamname:
                type: string
              repourl:
                type: string
              repopath:
                type: string
            required:
              - location
              - clustername
              - teamname
    served: true
    referenceable: true
  claimNames:
    kind: staging-aks-claim
    plural: staging-aks-claims
```

* Check the status:
```bash
kubectl get CompositeResourceDefinitions
kubectl describe CompositeResourceDefinitions staging-aks
```
# Create an XRC that defines the resources and their integrations
Now you have the XRD, you need the XRC behind it that will create the resource group and AKS cluster.

* From the cloned repo you will have this file that describes the ARD: `mgmtCluster/bootstrap/control-plane/xp-staging-cluster-comp.yaml`, the resources it is composed of and integrations for these resources:
  * staging-resourcegroup
  * staging-aks-cluster
  * prov-config-helm
  * argo-install
  * prov-config-object
  * add-core-it-config

Open the file locally and familarize yourself: `code xp-staging-cluster-comp.yaml`.

* All of the resources should look familar to you as we were deploying in a yaml template, but in the composition it allows us to reference them by a claim with a select number of parameters.
* One thing you will notice is how we are using [Crossplane Patches](https://docs.crossplane.io/latest/concepts/patch-and-transform/) to set values in the resources, in this example we are taking inputs from the XR claim and setting specific properties, such as clustername, and we are also using it for string concatenation.

We would like to call out some salient points for the specific KinDs:
* ProviderConfig
  1. `secretRef` - this is referencing the secret that contains the AKS kubeconfig
  2. `readinessChecks` - THIS IS IMPORTANT!!!! [Resource readiness checks](https://docs.crossplane.io/latest/concepts/compositions/#resource-readiness-checks) need to be set to `None` because ProviderConfig are never considered Ready!!!



```yaml
    - name: prov-config-object
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: ProviderConfig
        metadata:
          name: clu-prov-name
          namespace: upbound-system
        spec:
          credentials:
            source: Secret
            secretRef:
              name: clu-secret
              namespace: upbound-system
              key: kubeconfig
      patches:
        - type: CombineFromComposite
          combine:
            variables:
              - fromFieldPath: spec.clustername
            strategy: string
            string:
              fmt: "%s-secret"
          toFieldPath: "spec.credentials.secretRef.name"
          policy:
          fromFieldPath: Required

        - type: CombineFromComposite
          combine:
            variables:
              - fromFieldPath: spec.clustername
            strategy: string
            string:
              fmt: "%s-prov-conf-object"
          toFieldPath: "metadata.name"
          policy:
          fromFieldPath: Required
      readinessChecks:
      - type: None
```


* Deploy the cluster configuration:
```bash
name=my56app
clustername=my56cluster
teamname=team01
repourl="https://github.com/danielsollondon/teaminfra/"
repopath="infra/shared/k8s-cluster-config/sh01-wus2-01"

cat <<EOF | kubectl apply -f -
apiVersion: compute.example.com/v1alpha1
kind: staging-aks
metadata:
  name: $name
spec: 
  clustername: $clustername
  teamname: $teamname
  location: EU
  repourl: $repourl
  repopath: $repopath
EOF
```

* Check the claim: `kubectl describe staging-aks.compute.example.com/$name`
* Here you wll see:
1. Metadata for the associated resources
```bash
  Resource Refs:
    API Version:  azure.upbound.io/v1beta1
    Kind:         ResourceGroup
    Name:         my56app-kzzj2
    API Version:  containerservice.azure.upbound.io/v1beta1
    Kind:         KubernetesCluster
    Name:         my56cluster
    API Version:  helm.crossplane.io/v1beta1
    Kind:         ProviderConfig
    Name:         my56cluster-prov-conf-helm
....
```
2. Status of the claim
This will update as the resources are being created.

```bash
Status:
  Conditions:
    Last Transition Time:  2024-07-24T14:03:48Z
    Reason:                ReconcileSuccess
    Status:                True
    Type:                  Synced
    Last Transition Time:  2024-07-24T14:03:57Z
    Message:               Unready resources: staging-aks-cluster
    Reason:                Creating
    Status:                False
    Type:                  Ready
```
3. events for resource creation and issues:
```bash
Events:
  Type    Reason             Age                 From                                                             Message
  ----    ------             ----                ----                                                             -------
  Normal  SelectComposition  7m                  defined/compositeresourcedefinition.apiextensions.crossplane.io  Successfully selected composition: staging-aks
  Normal  SelectComposition  7m                  defined/compositeresourcedefinition.apiextensions.crossplane.io  Selected composition revision: staging-aks-106b3f5
  Normal  ComposeResources   6m59s (x4 over 7m)  defined/compositeresourcedefinition.apiextensions.crossplane.io  Composed resource "staging-resourcegroup" is not yet ready
  Normal  ComposeResources   4m34s (x9 over 7m)  defined/compositeresourcedefinition.apiextensions.crossplane.io  Composed resource "staging-aks-cluster" is not yet ready
  Normal  ComposeResources   94s (x12 over 7m)   defined/compositeresourcedefinition.apiextensions.crossplane.io  Successfully composed resources
```
4. If you want to dig deeper into the resources you can view the Crossplane managed resources, their name will be prefixed with 'my56cluster-', here you are looking to see if the resource is 'READY', note some resources take time to create and in more complex deployments their many be dependencies that must be created before.
```bash
kubectl get managed

NAME                                            SYNCED   READY   EXTERNAL-NAME    AGE
resourcegroup.azure.upbound.io/my56app-kzzj2    True     True    my56app-kzzj2    8d

NAME                                                               SYNCED   READY   EXTERNAL-NAME   AGE
kubernetescluster.containerservice.azure.upbound.io/my56cluster    True     True    my56cluster     8d

NAME                                           CHART     VERSION   SYNCED   READY   STATE      REVISION   DESCRIPTION        AGE
release.helm.crossplane.io/my56app-85dt9       argo-cd   7.4.1     True     True    deployed   1          Install complete   8d

NAME                                            KIND          PROVIDERCONFIG                 SYNCED   READY   AGE
object.kubernetes.crossplane.io/my56app-r568q   Application   my56cluster-prov-conf-object   True     True    8d
```
You can then dump out more details about their resource and review creation issues:
kubectl describe kubernetescluster.containerservice.azure.upbound.io/my56cluster 

For example here is an error from another claim:
```bash
Status:
  At Provider:
  Conditions:
    Last Transition Time:  2024-07-24T14:03:49Z
    Reason:                Creating
    Status:                False
    Type:                  Ready
    Last Transition Time:  2024-07-24T14:03:49Z
    Reason:                ReconcileSuccess
    Status:                True
    Type:                  Synced
    Last Transition Time:  2024-07-24T14:03:49Z
    Message:               async create failed: failed to create the resource: [{0 `dns_prefix` should be set if it is not a private cluster  []}]
    Reason:                AsyncCreateFailure
    Status:                False
    Type:                  LastAsyncOperation
Events:
  Type    Reason                   Age                  From                                                                       Message
  ----    ------                   ----                 ----                                                                       -------
  Normal  CreatedExternalResource  13m (x5 over 15m)    managed/containerservice.azure.upbound.io/v1beta1, kind=kubernetescluster  Successfully requested creation of external resource
  Normal  PendingExternalResource  47s (x115 over 15m)  managed/containerservice.azure.upbound.io/v1beta1, kind=kubernetescluster  Waiting for external resource existence to be confirmed
```

For more understanding on Claims, review the Crossplane [docs](https://docs.crossplane.io/latest/concepts/claims/).

* Please keep this cluster running for the next demo!!!
  * if you really must delete the resources then run: kubectl delete staging-aks.compute.example.com/my56app
* If you want to login and check out Argo, you can connect: `az aks get-credentials -n my54cluster -g my54app-tvfq9`


#### Recap
* You have built on the previous example where we were creating resources in Crossplane by adding them into a Yaml file, which required an understanding.
* You have a created a baseline cluster configuration that:
  * Will allow dev teams to deploy standardized, compliant clusters within your organization
  * Will not require an understanding of the underlying complexity and options of all the components.  
* But developers need more than just a K8s cluster and namespace for their applications.

In the next [section](readme3.md) we will use this as a shared App cluster and deploy a cloud native app with a full app environment in Azure.
