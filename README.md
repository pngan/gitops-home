## About GitOps-Home

This repository contains kubernetes configuration files to implement a single node Kubernetes server hosting non-commerical web apps.

The home server runs on a modest physical machine running Ubuntu Linux and the [MicroK8s Kubernetes](https://microk8s.io/) distribution. 

The instructions to set up this home server are described in [`setup.md`](setup.md)

### General Notes

Public facing access to the cluster is mediated by an Nginx Ingress controller routes traffic accordng to path and sub-domain names to various web applications hosted on the cluster. An ingress controller is required to support SSL certificates for the publicly accessible end points. This particular home server is accessible by a registered domain name whose A and CNAME DNS entries are managed by its domain registrar.

The Nginx server serves SSL traffic using a free Let's Encrypt SSL certificate. This initial certificate is retrieved and then kept up to date automatically using the `cert-manager` Kubernetes service. 

Setting up the Nginx ingress controller and cert-manager are the most involved parts of setting up this home server.

Kubernetes services that are internally accessible only, are accessed using a NodePort for each Service.

Provisioning of the cluster is performed using a _GitOps_ approach facilitated by the `fluxctl` Kubernetes operator, which runs on the cluster to be updated. The Kubernetes configuration files are checked into GitHub, and periodically the flux operator will read these configuration files and update the Kubernetes resources. This simplifies the maintenance of the Kubernetes resources to being a process of making changes to Kubernetes configuration files and checking them into the repo. Within five minutes, the local cluster will have been updated to reflect the configuration changes. Update: `fluxctl` has been temporarily disabled due to the rate limited restrictions imposed by DockerHub. Because `fluxctl` polls DockerHub the rate limiting restriction can be easily triggered.
