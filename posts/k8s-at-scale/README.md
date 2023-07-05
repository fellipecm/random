# A journey to Kubernetes with Consul and Kong at an Enterprise

This repo has the code referred at [this article](https://fellipecm.blogspot.com/2023/07/a-journey-to-kubernetes-with-consul-and.html).

This should get you:

1. A Kubernetes cluster
2. Consul and Kong installed and configured to work toghether
3. A sample deployment that leverages Service Mesh and Kong Ingress capabilities

This is heavily based on the below references, I have only added more security defaults for Consul and Kong and basic auth.

- [Using HashiCorp Consul with Kong Ingress Controller for Kubernetes](https://www.hashicorp.com/blog/using-hashicorp-consul-with-kong-ingress-controller-for-kubernetes)
- [Getting Started with Consul Service Mesh for Kubernetes](https://developer.hashicorp.com/consul/tutorials/kubernetes-features/service-mesh-deploy)
- [Layer 7 Observability with Prometheus, Grafana, and Kubernetes](https://developer.hashicorp.com/consul/tutorials/kubernetes/kubernetes-layer7-observability)

## Pre-requisites

Soft:

- You know Kubernetes and how to operate it
- You read [the article](https://fellipecm.blogspot.com/2023/07/a-journey-to-kubernetes-with-consul-and.html)

Hard:

- You have a **Kubernetes cluster** that supports *Persistent Volume* and *Load Balancer*: I am adding one way of getting one and some other suggestions for a local one
- [terraform](https://developer.hashicorp.com/terraform/downloads)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [helm](https://helm.sh/docs/intro/install/)
- [jq](https://jqlang.github.io/jq/download/)
- `base64` - Mac and Linux users should have this already, if you are using Windows you can use [this](https://sourceforge.net/projects/base64-for-windows/)

## Setting up a local Kubernetes cluster

This definitely not the intent of this, however I just want to point out to what I use for my home setup which is [khuedoan/homelab](https://github.com/khuedoan/homelab).

You can probably use something like **minikube** with `minikube tunnel` like [this](https://medium.com/globant/load-balance-microservices-using-kubernetes-minikube-88b78dae4796) or alternativelly using **kind** with MetalLB like [this](https://kind.sigs.k8s.io/docs/user/loadbalancer/).

## Setting up a Kubernetes cluster using LKE

Linode Kubernetes Engine (LKE) is a Managed Kubernetes service by Akamain Connected Cloud (former Linode) and it is cheap/fast/easy way to get started, if you haven't used them already you can probably get USD100 to get started which is more than enough to do what is here.

### Create your Linode account

Create your free account and claim your USD100 using the [Fastlane Solutions](https://fastlane-it.com) promo code [here](https://www.linode.com/fastlane100) (if this link does not work just Google for Linode free credits sign-up).

### Creating a Linode API Token

1. Once you are in Akamai Connected Cloud [Console](https://cloud.linode.com/) go to [My Profile > API Tokens](https://cloud.linode.com/profile/tokens)
2. Click on **Create A Personal Access Token** and create a temporary one by giving it a *Label*, selecting *Expiry* as *1 month*, giving it all access (default) and clicking *Create Token*

### Preparation

Clone this repo and go to the post root folder:

```shell
git clone https://github.com/fellipecm/random.git
cd random/posts/k8s-at-scale
```

### Creating your cluster with Terraform

```shell
cd terraform
terraform init
terraform apply --auto-approve
```

Enter your Linode Token again and wait for it to be done.

You will see some output, you can optionally access the dashboard with the given URL, see below on how to get your kube config file.

### Accessing your cluster with kubectl

```shell
# grab your kubeconfig
terraform output -json | jq -r '.kubeconfig.value[0]' | base64 -di > ../k8s-at-scale-kubeconfig.yaml
# go back to the main folder of this repo
cd ..
# set it as your default
export KUBECONFIG="${PWD}/k8s-at-scale-kubeconfig.yaml"
# confirm it works, Node(s) STATUS needs to be Ready
kubectl get nodes
```

## Installing and configuring Consul

```shell
# https://github.com/hashicorp/consul-k8s
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install consul --version 1.2.0 hashicorp/consul --namespace consul --create-namespace -f helm/consul.yaml --wait
# grab the Consul IP to access the Dashboard
kubectl -n consul get svc consul-ui
```

Using the output above access https://EXTERNAL-IP to see the Consul Dashboard - ignore the SSL error as we are using self signed certs.

## Installing Kong

```shell
# https://github.com/Kong/charts/tree/main/charts/kong
helm repo add kong https://charts.konghq.com
helm repo update
helm install kong --version 2.24.0 kong/kong --namespace kong --create-namespace -f helm/kong.yaml --wait
```

Get the Kong LB IP and set it it as an environment variable:

```shell
export KONG_IP=$(kubectl get svc --namespace kong kong-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -ks https://${KONG_IP}
```

You will get no routes matched as we don't have anything configured.

## Deploying a sample application

First let's create the app with an ingress withtout ACLs and rate-limit.

```shell
kubectl apply -f sample/app.yaml
```

Access https://${KONG_IP} and check the nginx page or use curl:

```shell
curl -ks https:/${KONG_IP}
```

## Configure Consul and Kong

We need to deploy some Custom Resource Definitions (CRDs) in order to make Consul and Kong more secure, the high level descrition is below, check the files for more details:

Consul CRDs:

- default: block all connections inside the Service Mesh that are not declared via ServiceIntentions and allow Kong to connect to everything
- mesh: block all connections outside the Service Mesh that are not explicitly excluded via outbound-cidr
- global: set ProxyDefaults default protocol to *http*

Kong CRDs:

- acl-deny-all: block all connections without ACLs by default using a KongClusterPlugin
- basic-auth: the basic auth KongPlugin
- basic-auth-anon-kong: anonymous basic-auth KongPlugin to allow us to call the Kong *healthcheck*
- anonymous-users-kong: anonymous KongConsumer
- acl-allow-all-kong: acl to allow all connections
- healthcheck-request-termination: used to create a serviceless healthcheck for kong
- kong-healthcheck: the actual Ingres for the healthcheck that leverages all the above

Apply:

```shell
kubectl apply -f crds/consul-crds.yaml
kubectl apply -f crds/kong-crds.yaml
```

Check that the Kong healthcheck is accessible:

```shell
curl -ks https:/${KONG_IP}/healthcheck | jq
```
You should see the payload below:

```json
{
  "message": "success"
}
```

Apply Kong settings and test again:

```shell
# apply the app specific settings, this will make it use basic-auth and rate-limit plugin - we will patch its ingress
kubectl apply -f sample/kong.yaml
# test with no creds
curl -kv https://${KONG_IP}
# access the service with valid creds
curl -kv https://${KONG_IP} -u "b8f1c30f-8402-42ad-8dbe-cf0e839b375b:449c667c-0c8d-455d-aee6-17ec18db3c12"
```

We have the default rate-limit to 6 calls per minute, try again and notice a 429 - Too many requests.

## Tearing everything down

```shell
terraform destroy --auto-approve
```

Consul created a persistent volume, delete them by going to [Volumes in Linode Cloud](https://cloud.linode.com/volumes) and Detach / Delete it manually.
