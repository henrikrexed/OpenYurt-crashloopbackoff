
# CrashloopBackoff
<p align="center"><img src="/image/logo.png" width="40%" alt="CrashLoopBackoff" /></p>

## OpenYurt
This repository contains the files utilized during the tutorial presented in during the livestream on OpenYurt
<p align="center"><img src="/image/openyurtlogo.png" width="40%" alt="Logs IG" /></p>

this tutorial will also utilize the OpenTelemetry Operator with:
* OpenYurt
* 1 k8s cluster v1.30 with one worker node
* 1 cloud yurt device
* 2 edge yurt devices running on rasperri pi 

## Prerequisite
The following tools need to be install on your machine :
- jq
- kubectl
- git
- Helm
- multipass
- 2 rasperriPi 3B


### 1.Let's configure the brige network

To start we need to know the network interface that we would use to bridge our network
```shell
sudo multipass networks
```
<p align="center"><img src="/image/networks.png" width="40%" alt="Logs IG" /></p>

In my case i will use the wifi : `en0`
```shell
sudo multipass set local.bridged-network=en0 
```
### 1.Let's start the control plane
```shell
sudo multipass launch --name k8s-control-plane --bridged --cpus 2 --memory 3G --disk 5G 22.04
```
let's get the ip adress of our control-plane
```shell
sudo multipass list
Name                    State             IPv4             Image
k8s-control-plane       Running           192.168.64.6     Ubuntu 22.04 LTS
10.0.0.97
```
in this example our control plane ip would be `10.0.0.97`

let's connect to the contror-plane and install kubeadm :
```shell
sudo multipass shell k8s-control-plane
```
Once connected let's get the setup script deploy k8s v1.30
```shell
wget 
chmod 777 setup.sh
./setup.sh
```

then We need to resart the control plane : 
```shell
sudo multipass restart k8s-control-plane
```
Let's launch our control-plane by connecting on the control-plane ( `sudo multiplass shell k8s-control-plane`)
```shell
sudo kubeadm init \
--pod-network-cidr 10.244.0.0/16 \
--apiserver-advertise-address 10.0.0.97
```
note: replace the apiserver adress with the ip return by multipass

p align="center"><img src="/image/install.png" width="40%" alt="Logs IG" /></p>

One the installation is finished copy the kubeconfig to add it to your local machine.

Once your kubeconfig is configured, we can install the networking layer of our cluster from our main machine:

```shell
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### 2.Let's start the control plane
```shell
multipass launch --name k8s-worker-node --bridged --cpus 2 --memory 2G --disk 5G 22.04
```
once the machine is ready, connect to the worker node:
```shell
multipass shell k8s-worker-node
```
and let's install k8S v1.30
```shell
wget setup script
chmod 777 setup.sh
./setup.sh
```
Let's reboot the worker node : sudo reboot
once the vm resarted , let's connect :`sudo multipass shell k8s-worker-node`
let's join our node to the control-plane:
```shell
sudo kubeadm join 10.0.0.97:6443 --token qgpdv5.7m9dhlwz1urps4vj \
--discovery-token-ca-cert-hash sha256:b1a1f59171ad54fbe87be2ed0f36ad8de107de346e488764aa5c25bcd73e39f4 
```
make sure to replace the ip and the token provided after launching the control-plane

Now you should have a cluster withe one control plane node and one worker node

### 3.Let's install OpenYurt

let's install OpenYurt on the control Plane:
```shell
helm repo add openyurt https://openyurtio.github.io/openyurt-helm
helm repo update
helm upgrade --install yurt-manager -n kube-system openyurt/yurt-manager
```

the OpenYurt pod will fail , it requires to change the clusterrole yurt-manager-basecontroller
```shell
kubectl apply -f openyurt/clusterrole.yaml -n kube-system
```
Let's restart the pod failing :
```shell
kubectl delete pod -l app.kubernetes.io/name=yurt-manager -n kube-system
```
let's use the ip of our control-plane to install yurt-hub:
```shell
helm upgrade --install yurt-hub -n kube-system --set kubernetesServerAddr=https://10.0.0.97:6443 openyurt/yurthub
```
Last we need to install raven, once all the pod of yurt hub is running.
```shell
helm upgrade --install raven-agent -n kube-system openyurt/raven-agent
```

### 3.Let's create a cloud instance
```shell
multipass launch --name k8s-cloud-node --bridged --cpus 2 --memory 1G --disk 4G 22.04
```
once the machine is ready, let's connect to it with sudo multipass shell k8s-cloud-node

Let's first install contairned :
```shell
sudo apt install containerd 
```
and launch the containerd service :
```shell
sudo systemctl enable containerd
sudo systemctl start containerd
```
Now that we have install yumadm :
```shell
wget https://github.com/openyurtio/openyurt/releases/download/v1.6.1/yurtadm-v1.6.1-linux-arm64.tar.gz
tar -xzf yurtadm-v1.6.1-linux-arm64.tar.gz 
cd linux-arm64/
```
let's join our cloud node to our cluster ( you will need the ip and the token of our control plane) : 
```shell
sudo ./yurtadm join 10.0.0.97:6443 --token qgpdv5.7m9dhlwz1urps4vj  --node-type=cloud --discovery-token-unsafe-skip-ca-verification --cri-socket=/run/containerd/containerd.sock --v=5
```
### 3.Let's create an edge instance

on a rasperri pi 3 B, use the Rasperry pi manager
and select the following OS: RaspberryPi lite OS ( without ui)
<p align="center"><img src="/image/raspberriImager.png" width="40%" alt="os" /></p>

Preconfigure the instance by adding the:
- wifi settings 
- name of the machine
- default password.

Once the raspberryPi is running , let's connect using ssh and install :

Let's first install contairned :
```shell
sudo apt install containerd 
```
and launch the containerd service :
```shell
sudo systemctl enable containerd
sudo systemctl start containerd
```
Now that we have install yumadm :
```shell
wget https://github.com/openyurtio/openyurt/releases/download/v1.6.1/yurtadm-v1.6.1-linux-arm64.tar.gz
tar -xzf yurtadm-v1.6.1-linux-arm64.tar.gz 
cd linux-arm64/
```
let's join our cloud node to our cluster ( you will need the ip and the token of our control plane) :
```shell
sudo ./yurtadm join 10.0.0.97:6443 --token qgpdv5.7m9dhlwz1urps4vj  --node-type=edge --discovery-token-unsafe-skip-ca-verification --cri-socket=/run/containerd/containerd.sock --v=5
```
