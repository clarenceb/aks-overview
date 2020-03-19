Azure Kubernetes Service (AKS) Overview
=======================================

Pre-requisities
---------------

* Install Azure CLI
* Login to your Azure subscription using the Azure CLI
* Install `jq` package for json output manipulation
* Install `openssh-client` package to generate SSH key (i.e. `ssh-keygen`)
* Install Helm 3

Create AKS cluster
------------------

Create the AKS cluster using am ARM Template deployment:

```sh
source ./aks-overview-env.sh

# Generate SSH key pair
mkdir -p ./ssh-keys
ssh-keygen -t rsa -b 4096 -c "azure ssh key" -f ./ssh-keys/${cluster_name}

# Create Service Principal for AKS cluster to manage Azure resources
az ad sp create-for-rbac --name "${cluster_name}" --skip-assignment > ./aks-service-principal.json

az group create -n "${cluster_name}" -l "${location}"

SSH_KEY_PUB="$(cat ./ssh-keys/${cluster_name}.pub)"
SP_APP_ID="$(cat ./aks-service-principal.json | jq -r .appId)"
SP_APP_SECRET="$(cat ./aks-service-principal.json | jq -r .password)"

az group deployment create \
    -g "${cluster_name}" \
    -n "${cluster_name}" \
    -f ./infra/101-aks/azuredeploy.json \
    --parameters clusterName="${cluster_name}" \
                 dnsPrefix="${cluster_name}" \
                 kubernetesVersion="1.15.7" \
                 agentVMSize="Standard_DS3_v2" \
                 servicePrincipalClientId="${SP_APP_ID}" \
                 servicePrincipalClientSecret="${SP_APP_SECRET}"
                 sshRSAPublicKey="${SSH_KEY_PUB}"

# Check cluster creation succeeded.
az aks list -o table
```

Connect to the AKS cluster
--------------------------

```sh
az aks get-credentials -n "${cluster_name}" -g "${cluster_name}"
az aks install-cli # May require prefixing `sudo`, e.g. `sudo <cmd>`
# Or install to a user path that is included your PATH environment variable:
#   mkdir -p $HOME/.local/bin/
#   az aks install-cli --install-location $HOME/.local/bin/kubectl
#   export PATH=$HOME/.local/bin/:$PATH
kubectl get nodes
```

Deploy Azure Vote App
---------------------

This will deploy a basic web app with ephemeral state in an incluster Redis instance.

Deploy app:

```sh
kubectl create ns azure-vote
kubectl apply -f apps/azure-vote/azure-vote-all-in-one.yaml -n azure-vote
kubectl get all -n azure-vote
kubectl get svc azure-vote-front -n azure-vote --watch  # wait for frontend IP address, CTRL+C to exit
```

Access the front end app in your browser using the service IP address: `http://<azure-vote-front_svc_loadbalancer_external_ip>/`

Deploy KubeView to visualise Kubernetes objects
-----------------------------------------------

```sh
git clone https://github.com/benc-uk/kubeview.git <kubeview_clone_path>/kubeview

curl https://raw.githubusercontent.com/benc-uk/kubeview/master/deployments/helm/myvalues-sample.yaml -o <kubeview_clone_path>/kubeview-values.yaml

helm3 install kubeview <kubeview_clone_path>/kubeview/deployments/helm/kubeview/ -f ./kubeview-values.yaml

kubectl get svc --selector app.kubernetes.io/name=kubeview -w # wait for frontend IP address, CTRL+C to exit
```

Access KubeView in your browser using the service IP address: `http://<kubeview_svc_loadbalancer_external_ip>/`

Scale the Azure Votew front deployment and observe change in KubeView:

```sh
 kubectl scale --replicas=3 deploy/azure-vote-front -n azure-vote
```

Deploy Traefik Ingress Controller
---------------------------------

Follow steps outlined here: https://github.com/clarenceb/traefik-ingress-example

This will set up the Traefik Ingress Controller.

Update the manifest `apps/azure-vote/azure-vote-ingress.yaml` with your DNS hostname.

Deploy the Ingress object (and updated Service object):

```sh
kubectl apply -f apps/azure-vote/azure-vote-ingress.yaml -n azure-vote
```

Access the app through the ingress endpoint in your browser: `https://<DNSNAME>.<LOCATION>.cloudapp.azure.com`
You should notice that you have a TLS certificate obtained from Let's Encrypt.

Cleanup
-------

Remove azure-vote app (optional at end of demo):

```sh
kubectl delete -f apps/azure-vote/azure-vote-all-in-one.yaml -n azure-vote
kubectl delete -f apps/azure-vote/azure-vote-ingress.yaml -n azure-vote
```

TODO
----

* Add container monitoring solution in the ARM Template

References / Resources
----------------------

* [Azure / azure-quickstart-templates](https://github.com/Azure/azure-quickstart-templates) - [101-aks](https://github.com/Azure/azure-quickstart-templates/tree/master/101-aks) example ARM Temaplte for a basic AKS basic setup.
* [KubeView](http://kubeview.benco.io/) - Kubernetes cluster visualiser and graphical explorer, created by Ben Coleman.
* [Azure Vote Quickstart](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough), [Azure Vote Source Code](https://github.com/Azure-Samples/azure-voting-app-redis)
