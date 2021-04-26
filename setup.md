# Home Server Setup

## Prerequisites
The home server setup requires a machine running the Ubuntu 20.04 OS. It also requires a public facing modem and router that forwards TCP/IP traffic coming on ports 80 and 443 to this server.

## Installation of MicroK8s Kubernetes

MicroK8s is installed using these [instructions](https://ubuntu.com/tutorials/install-a-local-kubernetes-with-microk8s#1-overview).


## Install Flux




## Installation of cert-manager 

Followed the "Installting with regular manifests" method because of flux.

https://cert-manager.io/docs/installation/kubernetes/

The [`CustomResourceDefintions`](https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.yaml) were copied into the cert-manager folder so that it could be automatically installed with flux.
