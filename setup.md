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

The `seq` service, among others require persistent storage to be enables. In `microk8s`, the following command needs to be run:

    microk8s.enable storage
    
 Ref: [Stackoverflow ref](https://stackoverflow.com/a/60213860/41410)  


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
