# Home Server Setup

## Prerequisites
The home server setup requires a machine running the Ubuntu 20.04 OS or later, and access to the superuser account to issue `sudo` commands. It requires an internet connected modem and router that forwards TCP/IP traffic arriving at ports 80 and 443 to the server ports 30000 and 30001, respectively.

## Installation of MicroK8s Kubernetes

The home server is made of a number of containerised web applications, whose lifetimes are managed by a Kubernetes orchestrator. There are several Kubernetes distributions suitable for small scale deployments. MicroK8s was chosen because it is well supported on Ubuntu Linux and runs well on modest hardware since it does not require an underlying virtual machine or a docker infrastructure.

MicroK8s is installed using these [instructions](https://ubuntu.com/tutorials/install-a-local-kubernetes-with-microk8s#1-overview).

Note that once microK8s is installed, the `kubectl` command to use is the microK8s version of it: `microk8s kubectl`. For convenience this command can be aliased by adding the line in the `~/.bashrc` file:

    alias k='microk8s kubectl'

With Kubernetes installed, we are ready to install Flux v1.

## Initial configuraiton of MicroK8s

### Enable storage

The `seq` service, among others require persistent storage to be enabled. In `microk8s`, the following command needs to be run:

    microk8s.enable storage
    
 Ref: [Stackoverflow ref](https://stackoverflow.com/a/60213860/41410)  


### Enable DNS

The `ipmon` service, needs to contact the `seqserver` servcice in order to upload log data. For this internal network to work a DNS services needs to be installed. In `microk8s`, the following command needs to be run:

    microk8s.enable dns
    
 Ref: [Microk8s ref](https://microk8s.io/docs)


## Install Flux v1

The primary source of information used to install flux, was Nigel Brown's Pluralsight course called [Automating Kubernetes Deployments Using a GitOps Workflow](https://app.pluralsight.com/library/courses/automating-kubernetes-deployments-gitops-workflow/table-of-contents). 

In Ubuntu, fluxctl was installed using the snap package manager:

    sudo snap install fluxctl --classic

Check that the installation was successful by listing the help information:

    fluxctl --help

The flux examples was based on Nigel Brown's [GitHub repo](https://github.com/nbrownuk/gitops-nginxhello). The next step is to install the flux operator into Kubernetes:

    kubectl create namespace flux   # create a namespace called flux
    fluxctl install \
        --namespace flux \
        --git-url https://github.com/pngan/gitops-home \
        --git-user <git-user> \
        --git-email <git-email> | kubectl apply -f -

Check that flux is running in Kubernetes:

    kubectl -n flux get all    

Set the flux port forwarding namespace as environment variable in `~/.bashrc`:

    export FLUX_FORWARD_NAMESPACE=flux

Since flux needs to read and write from the git repository, we need to register flux's SSH public key with GitHub. The public key is retrieved using:

    fluxctl identity

Take note of the `ssh-rsa` key, navigate to GitHub, and open your user's SSH Setting, and add a public SSH Key using the previous output.

With flux installed, it will run every 5 minutes to pull the `*.yaml` files from the git repo, and run the equivalent of `kubectl apply -f ...` on each of the yaml configuration files, which will update the local cluster. A manual sync can be run at any time using the command:

    fluxctl sync

If the flux operator has been correctly configured and is running properly, then the only manual steps remaining to get the site up and running is to replace with your specific values in `ingress.yaml` and `clusterissuer.yaml`. Once this is done, then the automatic flux syncing will provision the entire cluster. The rest of this file does not contain any further required manual steps, but exists for background information about why the configuration files were created as they are.


## Installation of the Ingress Controller

`nginx-service.yaml`

The primary source of information for the installation of the Ingress Controller and Ingress Configure is the Pluralsight course by Anthony Nocentino, [Configuring and Managing Kubernetes Networking, Services, and Ingress](https://app.pluralsight.com/library/courses/configuring-managing-kubernetes-networking-services-ingress/table-of-contents). 

In order for the web apps to be reachable from the internet the gateway router should route incoming traffic on ports `80` and `443` to the IP address of your server machine, and to ports `30000` and `30001`, respectively. These ports are defined in the configuration file `nginx-service.yaml`.

A bit of terminology. The _Ingress Controller_ can be thought of as a web server that in turns calls specific web applications depending on the path or route definitions - these definitions are defined by the _Ingress_. In this case the _Ingress Controller_ is of type _NodePort_. NodePorts, by default, can expose only ports in the range 30000-32767. Don't use an Ingress Controller of any other type for a local machine setup, e.g. don't use LoadBalancer - which are for large installations that actually have a load balancer running on them.

There are many ways of installing an ingress controller but we used a [Nginx baremetal NodePort configuration](https://github.com/kubernetes/ingress-nginx/blob/master/deploy/static/provider/baremetal/deploy.yaml). You can install this directly with the command:

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.45.0/deploy/static/provider/baremetal/deploy.yaml

However because we are using flux to do the provisioning, we took a copy of it and included it in our repo as the file `nginx-service.yaml`.  We also added the flux annotation to make sure flux uses it:

    annotations:
        fluxcd.io/ignore: "false"

The Ingress on which the Ingress Controller acts upon is defined in the file `ingress.yaml`. The routes defined in this file should be changed to match your own domain name, and routes to your own web applications. 

## Installation of cert-manager 

`clusterissuer.yaml`

Up to this point, the Ingress Controller and Ingress will be able to serve HTTP traffic, but not HTTPS traffic because the Nginx server does not have a SSL certificate to accompany the SSL endpoints. Such a certificate can be obtained from the certificate issuer Let's Encrypt who issues SSL certificates that have to be renewed every 90 days. Certificates are retrieved and renewed using a Kubernetes certificate managment controller called `cert-manager`. 

Instructions to install the cert-manager is given in the cert-manager site, under the section [Installing with regular manifests](https://cert-manager.io/docs/installation/kubernetes/).

The cert-manager is provisioned by the file `cert-manager.yaml` which in turn is a download of this [file](https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.yaml). It is explicitly downloaded so that it could be automatically installed using flux. Again the flux ignore false annotation is required to be added.

Cert-manager reads information of how and where to get the certificate, from the configuration file `clusterissuer.yaml`. In our case, we use the Let's Encrypt ACME server to issue an HTTP01 challenge to authenticate site. This file will need to be customized using your own values before it is useable.

Run the following command to check that a certificate has been correctly issued:

    kubectl get certificates

## Install Secrets

The `ipmon-deployment.yaml` pod requires the provision of a secret named `ovh-secrets`. This is done by applying a yaml file like this:
```
apiVersion: v1
kind: Secret
metadata:
  name: ovh-secrets
type: Opaque
stringData:
  endpoint: <redacted>
  application_key: <redacted>
  application_secret: <redacted>
  consumer_key: <redacted>
```  
This file is not checked into git because it contains secret information. To view the secrets, look at the log for the pod `secrets-test-deployment.yaml`.

## Install seq server

`seqserver.yaml`

This home server supports a central repository for application logs. This is provided by a [`seq` server](https://datalust.co/seq). The kubernetes manifest file for installing the seq server is provided in the file `seqserver.yaml`. The docker-compose file for seq was converted to `seqserver.yaml` by running the tool [`Kompose`](https://kompose.io/) over it.


## Install Kubernetes Horizontal Pod Autoscaler

Install the official [Kubernetes autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) that can increase the number of pods according to the CPU or memory used. A prerequisite for running the autoscaler is to install the [Metric Server](https://github.com/kubernetes-sigs/metrics-server) which collects cluster metrics used by the autoscaler to determine whether scaling is required. To install the metrics server in microk8s, run the command:

`microk8s enable metrics-server`

Check that the metrics server is enabled by running the following command:

`kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"`

It should output something similar to:
```json
{"kind":"NodeMetricsList","apiVersion":"metrics.k8s.io/v1beta1","metadata":{"selfLink":"/apis/metrics.k8s.io/v1beta1/nodes"},"items":[{"metadata":{"name":"manuka","selfLink":"/apis/metrics.k8s.io/v1beta1/nodes/manuka","creationTimestamp":"2021-07-16T06:34:10Z"},"timestamp":"2021-07-16T06:33:50Z","window":"30s","usage":{"cpu":"1164143878n","memory":"5347416Ki"}}]}
```

Now you should be able to get the top pods by CPU:

`kubectl top pods`

# Install Monitoring

Resource monitoring is provided by Prometheus and Grafana by running the command. Grafana is installed when installing the dashboard.

`microk8s.enable dashboard prometheus`

### Access Kubernetes Dashboard

Before the Kubernetes dashboard can be accessed, a token must be generated:

```bash
export TOKEN=$(kubectl describe secret $(kubectl get secret | awk '/^dashboard-token-/{print $1}') | awk '$1=="token:"{print $2}') && echo -e "\n--- Copy and paste this token for dashboard access --\n$TOKEN\n---"
```

Then open the dashboard at:

http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

### Access Grafana dashboard

First get the IP address and port for grafana using the command:

`k get services --namespace=monitoring`

Open browser to the IP and Port given tby the service called `grafana`.

The credentials for `grafana` are `admin/admin`.


Reference https://ubuntu.com/blog/monitoring-at-the-edge-with-microk8s


# Setup K9s

## First create the kube config
You need to install the kubernetes config file using the command:
```bash
cd 
mkdir .kube
cd .kube
microk8s config > config
```

## Install k9s

`sudo snap install k9s`

## Create a k9s config file

First find the location of where the config file should go:

`k9s info`

Then create an empty file shown in the `Configuration` path.

Populate the information using the values seeded from [here](https://github.com/derailed/k9s#k9s-configuration). 

Set the values:
```yaml
  currentContext: microk8s
  currentCluster: microk8s-cluster
```


Put `export KUBECONFIG=$HOME/.kube/config` into the the `.bashrc` file.

Run k9s by running `k9s`


# Trouble Shooting

## Running `kubectl`:

If you get the message: `"The connection to the server localhost:8080 was refused - did you specify the right host or port?" `

You need to install the kubernetes config file using the command:
```bash
cd 
mkdir .kube
cd .kube
microk8s config > config
```
----
## Running `k9s`

If you see: `Boom!! Unable to locate K8s cluster configuration.`

Put `export KUBECONFIG=$HOME/.kube/config` into the the `.bashrc` file.

----

## Running `kubectl top pods`

If you see `Error from server (ServiceUnavailable): the server is currently unable to handle the request (get pods.metrics.k8s.io)`
Then the metrics server needs to have [additional configuration](https://www.linuxsysadmins.com/service-unavailable-kubernetes-metrics/).

Run:

```bash
kubectl edit deployments.apps -n kube-system metrics-server
```
Add this below dns policy or at the end of the container section above the restart Policy.

```yaml
hostNetwork: true
```

__Tip__: you should put the line

```bash
export KUBE_EDITOR="nano"
```
in your `.bashrc` file to use nano instead of vim as your default kubectl editor
