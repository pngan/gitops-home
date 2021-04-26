## About GitOps-Home

This repository contains configuration files to implement a single node Kubernetes server hosting non-commerical web apps.

The home server runs on a modest physical machine running Ubuntu Linux and the MicroK8s Kubernetes distribution. 

Provisioning of the cluster is performed using a _GitOps_ approach facilitated by the `fluxctl` Kubernetes operator, which runs on the cluster to be updated. The Kubernetes configuration files are checked into GitHub, and periodically the flux operator will read these configuration files and update the Kubernetes resources. This simplifies the maintenance of the Kubernetes resources to being a process of making changes to Kubernetes configuration files and checking them into the repo. Within five minutes, the local cluster will have been updated to reflect the configuration changes.

The public facing service web server is provided using Nginx, which routes requests to the internal services. This Nginx Ingress controller routes traffic accordng to path and sub-domain names to various web applications hosted on the cluster. The site supports a registered domain name whose A and CNAME DNS entries are managed by its domain registrar.

The Nginx server serves SSL traffic using a free Let's Encrypt SSL certificate. This initial certificate is retrieved and then kept up to date automatically using the `cert-manager` Kubernetes service. 

Setting up the Nginx ingress controller and cert-manager are the most involved parts of setting up this home server.

The instructions to set up this home server are described in [`setup.md`](setup.md)