# Home Server Setup
The home server is a physical machine running Ubuntu with a MicroK8s Kubernetes single machine cluster. Minikube was considered but not chosen because it runs in a virtual machine, and therefore did not make the best use of the modest hardware of the home server. 

Formation of the cluster is performed using a _GitOps_ approach facilitated by the `fluxctl` Kubernetes operator. Flux is a service that runs on the kubernetes cluster that polls at 5 minute intervals a GitHub repository and applies kubernetes configuration files contained in that repository. This eases the provisioning of kubernetes resources by simply making changes to yaml files and checking them in.

The system comprises an Nginx Ingress Controller exposing a TLS protected public endpoint hosting Let's Encrypt certificates that are automatically updated using `cert-manager`. The site has a domain name whose A and CNAME DNS entries are managed by its domain registrar. The Ingress controller routes traffic accordng to path and sub-domain names to various web applications hosted on the cluster.


## Prerequisites
The home server setup requires a machine running the Ubuntu 20.04 OS. It also requires a public facing modem and router that forwards TCP/IP traffic coming on ports 80 and 443 to this server.

## Installation of MicroK8s Kubernetes

MicroK8s is installed using these [instructions](https://ubuntu.com/tutorials/install-a-local-kubernetes-with-microk8s#1-overview).


## Install Flux




## Install 