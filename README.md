
# ChatloopBackoff
<p align="center"><img src="/image/crashbloop.png" width="40%" alt="CrashLoopBackoff" /></p>

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


First we want to build the following cluster: 
<p align="center"><img src="/image/cluster.png" width="40%" alt="Logs IG" /></p>

## Create a k8S cluster

### 1.Let's configure the bridge network

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
wget https://raw.githubusercontent.com/henrikrexed/OpenYurt-crashloopbackoff/refs/heads/master/k8s%20cluster/setup.sh
chmod 777 setup.sh
sudo ./setup.sh
```

then We need to resart the control plane : 
```shell
sudo multipass restart k8s-control-plane
```
Let's launch our control-plane by connecting on the control-plane ( `sudo multiplass shell k8s-control-plane`)
```shell
sudo kubeadm init \
--pod-network-cidr 10.244.0.0/16 \
--apiserver-advertise-address 10.0.0.100
```
note: replace the apiserver adress with the ip return by multipass

p align="center"><img src="/image/install.png" width="40%" alt="Logs IG" /></p>

One the installation is finished copy the kubeconfig to add it to your local machine.

Once your kubeconfig is configured, we can install the networking layer of our cluster from our main machine:

```shell
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### 2.Let's start the worker node
```shell
sudo multipass launch --name k8s-worker-node --bridged --cpus 2 --memory 2G --disk 5G 22.04
```
once the machine is ready, connect to the worker node:
```shell
sudo multipass shell k8s-worker-node
```
and let's install k8S v1.30
```shell
wget https://raw.githubusercontent.com/henrikrexed/OpenYurt-crashloopbackoff/refs/heads/master/k8s%20cluster/setup.sh
chmod 777 setup.sh
sudo ./setup.sh
```
Let's reboot the worker node : sudo reboot
once the vm resarted , let's connect :`sudo multipass shell k8s-worker-node`
let's join our node to the control-plane:
```shell
sudo kubeadm join 10.0.0.100:6443 --token i3l8b6.ev7qp0fl5q4nhim1 \
	--discovery-token-ca-cert-hash sha256:3997edfa489aae75c216099d2a65f8695af9ecfce191f63f77e5ff507b3ed2a8 
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
helm upgrade --install yurt-hub -n kube-system --set kubernetesServerAddr=https://10.0.0.100:6443 openyurt/yurthub
```
Last we need to install raven, once all the pod of yurt hub is running.
```shell
helm upgrade --install raven-agent -n kube-system openyurt/raven-agent
```

### 3.Let's create a cloud instance
```shell
sudo multipass launch --name k8s-cloud-node --bridged --cpus 2 --memory 1G --disk 4G 20.04
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
wget https://github.com/openyurtio/openyurt/releases/download/v1.4.1/yurtadm-v1.4.1-linux-arm64.tar.gz
tar -xzf yurtadm-v1.4.1-linux-arm64.tar.gz 
cd linux-arm64/
```
let's join our cloud node to our cluster ( you will need the ip and the token of our control plane) : 
```shell
sudo ./yurtadm join 10.0.0.100:6443 --token i3l8b6.ev7qp0fl5q4nhim1  --node-type=cloud --discovery-token-unsafe-skip-ca-verification --cri-socket=/run/containerd/containerd.sock --v=5
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
first let's enable cgroup:
```shell
sudo sed -i '$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1/' /boot/firmware/cmdline.txt
sudo apt install systemd-resolved
sudo reboot
```
once the device rebooted, let's reconnect and install all the k8s components:
```shell
wget https://raw.githubusercontent.com/henrikrexed/OpenYurt-crashloopbackoff/refs/heads/master/k8s%20cluster/setup_edge.sh
sudo chmod 777 setup_edge.sh
sudo ./setup_edge.sh
```
and then add our edge node to the cluster:
```shell
sudo kubeadm join 10.0.0.100:6443 --token i3l8b6.ev7qp0fl5q4nhim1 \
	--discovery-token-ca-cert-hash sha256:3997edfa489aae75c216099d2a65f8695af9ecfce191f63f77e5ff507b3ed2a8 
```

## Convert our nodes to openyurt

With our current cluster we want to introduce OpenYur and build the following architecture:

first we want to build the following cluster:
<p align="center"><img src="/image/target.png" width="40%" alt="Logs IG" /></p>

### 1. label our edge nodes:
```shell
kubectl label node node1 node4 openyurt.io/is-edge-worker=true
kubectl label node k8s-cloud-node openyurt.io/is-edge-worker=false
```
let's annotate the autonomous flag for our rasperri pi node:
```shell
kubectl annotate node node1 node4 node.beta.openyurt.io/autonomy=true
```
### 2. Create a nodepool
Let's create a nodepool for the rasperri pi:

```shell
cat <<EOF | kubectl apply -f -
apiVersion: apps.openyurt.io/v1alpha1
kind: NodePool
metadata:
  name: rasperripi
spec:
  type: Edge
EOF
kubectl label node node1 node4 apps.openyurt.io/desired-nodepool=rasperripi
```

### 3. Setup Yurthub
let's connect on each rasperripi
and run the following command: 
```shell
wget https://raw.githubusercontent.com/openyurtio/openyurt/refs/heads/master/config/setup/yurthub.yaml
cat yurthub.yaml |
sed 's|__kubernetes_master_address__|10.0.0.100:6443|;
s|__boo```shelltstrap_token__|i3l8b6.ev7qp0fl5q4nhim1|' > yurthub-ack.yaml
sudo mv yurthub-ack.yaml /etc/kubernetes/manifests
```
make sure to replace your master node ip address and boostrap token
Let's wait few minutes to get the YurtHub ready

### 3. Configure kubelet
```shell
sudo mkdir -p /var/lib/openyurt
sudo cat << EOF > /var/lib/openyurt/kubelet.conf
apiVersion: v1
clusters:
- cluster:
  server: http://127.0.0.1:10261
  name: default-cluster
  contexts:
- context:
  cluster: default-cluster
  namespace: default
  user: default-auth
  name: default-context
  current-context: default-context
  kind: Config
  preferences: {}
  EOF
```
then we update the kubelet to use this new kubeconfig:
```shell
sudo sed -i "s|KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=\/etc\/kubernetes\/bootstrap-kubelet.conf\ --kubeconfig=\/etc\/kubernetes\/kubelet.conf|KUBELET_KUBECONFIG_ARGS=--kubeconfig=\/var\/lib\/openyurt\/kubelet.conf|g" \
/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
```
and we need to restart kubelet:
```shell
sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

