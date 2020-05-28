# Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in [etcd](https://github.com/etcd-io/etcd). In this lab you will bootstrap a three node etcd cluster and configure it for high availability and secure remote access.

## Prerequisites

The commands in this lab must be run on each controller instance: `controller-0`, `controller-1`, and `controller-2`. Login to each controller instance using the `gcloud` command. Example:

```
gcloud compute ssh controller-0
```

### Running commands in parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

## Bootstrapping an etcd Cluster Member

### Download and Install the etcd Binaries

Download the official etcd release binaries from the [etcd](https://github.com/etcd-io/etcd) GitHub project:

```
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"
```

Extract and install the `etcd` server and the `etcdctl` command line utility:

```
{
  tar -xvf etcd-v3.4.0-linux-amd64.tar.gz
  sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
}
```

### Configure the etcd Server

```
{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
}
```

The instance internal IP address will be used to serve client requests and communicate with etcd cluster peers. Retrieve the internal IP address for the current compute instance:

```
KUBERNETES_ADDRESS=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
```

Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the hostname of the current compute instance:

```
ETCD_NAME=$(hostname -s)
```

Create the `etcd.service` systemd unit file:

```
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${KUBERNETES_ADDRESS}:2380 \\
  --listen-peer-urls https://${KUBERNETES_ADDRESS}:2380 \\
  --listen-client-urls https://${KUBERNETES_ADDRESS}:4001,https://127.0.0.1:4001 \\
  --advertise-client-urls https://${KUBERNETES_ADDRESS}:4001 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the etcd Server

```
{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
}
```

> Remember to run the above commands on each controller node: `controller-0`, `controller-1`, and `controller-2`.

## Verification

List the etcd cluster members:

```
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:4001 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

> output

```
3a57933972cb5131, started, controller-2, https://10.240.0.12:2380, https://10.240.0.12:4001
f98dc20bce6225a0, started, controller-0, https://10.240.0.10:2380, https://10.240.0.10:4001
ffed16798470cab5, started, controller-1, https://10.240.0.11:2380, https://10.240.0.11:4001
```

## For Vagrant

The instance internal IP address will be used to serve client requests and communicate with etcd cluster peers. Retrieve the internal IP address for the current compute instance.
Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the hostname of the current compute instance.
Finally, create the `etcd.service` systemd unit file:

```
KUBERNETES_ADDRESS_0=$(vagrant ssh master-0 -c "/sbin/ifconfig eth0" \
  | grep "inet addr" | tail -n 1 | egrep -o "[0-9\.]+" \
  | head -n 1 2>&1)
KUBERNETES_ETCD_NAME_0=$(vagrant ssh master-0 -c "hostname -s")

KUBERNETES_ADDRESS_1=$(vagrant ssh master-1 -c "/sbin/ifconfig eth0" \
  | grep "inet addr" | tail -n 1 | egrep -o "[0-9\.]+" \
  | head -n 1 2>&1)
KUBERNETES_ETCD_NAME_1=$(vagrant ssh master-1 -c "hostname -s")

KUBERNETES_ADDRESS_2=$(vagrant ssh master-2 -c "/sbin/ifconfig eth0" \
  | grep "inet addr" | tail -n 1 | egrep -o "[0-9\.]+" \
  | head -n 1 2>&1)
KUBERNETES_ETCD_NAME_2=$(vagrant ssh master-2 -c "hostname -s")

cp manifests/etcd.yaml mountdirs/manifests/master-0/etcd.yaml
cp manifests/etcd.yaml mountdirs/manifests/master-1/etcd.yaml
cp manifests/etcd.yaml mountdirs/manifests/master-2/etcd.yaml

sed -i "s/etcd_master_name/${KUBERNETES_ETCD_NAME_0}/" mountdirs/manifests/master-0/etcd.yaml
sed -i "s/INTERNAL_IP/${KUBERNETES_ADDRESS_0}/" mountdirs/manifests/master-0/etcd.yaml
sed -i "s/etcd_master_name/${KUBERNETES_ETCD_NAME_1}/" mountdirs/manifests/master-1/etcd.yaml
sed -i "s/INTERNAL_IP/${KUBERNETES_ADDRESS_1}/" mountdirs/manifests/master-1/etcd.yaml
sed -i "s/etcd_master_name/${KUBERNETES_ETCD_NAME_2}/" mountdirs/manifests/master-2/etcd.yaml
sed -i "s/INTERNAL_IP/${KUBERNETES_ADDRESS_2}/" mountdirs/manifests/master-2/etcd.yaml
sed -i "s/KUBERNETES_ADDRESS_0/${KUBERNETES_ADDRESS_0}/" mountdirs/manifests/master-0/etcd.yaml
sed -i "s/KUBERNETES_ADDRESS_1/${KUBERNETES_ADDRESS_1}/" mountdirs/manifests/master-0/etcd.yaml
sed -i "s/KUBERNETES_ADDRESS_2/${KUBERNETES_ADDRESS_2}/" mountdirs/manifests/master-0/etcd.yaml
sed -i "s/KUBERNETES_ADDRESS_0/${KUBERNETES_ADDRESS_0}/" mountdirs/manifests/master-1/etcd.yaml
sed -i "s/KUBERNETES_ADDRESS_1/${KUBERNETES_ADDRESS_1}/" mountdirs/manifests/master-1/etcd.yaml
sed -i "s/KUBERNETES_ADDRESS_2/${KUBERNETES_ADDRESS_2}/" mountdirs/manifests/master-1/etcd.yaml
sed -i "s/KUBERNETES_ADDRESS_0/${KUBERNETES_ADDRESS_0}/" mountdirs/manifests/master-2/etcd.yaml
sed -i "s/KUBERNETES_ADDRESS_1/${KUBERNETES_ADDRESS_1}/" mountdirs/manifests/master-2/etcd.yaml
sed -i "s/KUBERNETES_ADDRESS_2/${KUBERNETES_ADDRESS_2}/" mountdirs/manifests/master-2/etcd.yaml
sed -i "s/NODE_NAME/master-0/" mountdirs/kubelet_config_master-0.yaml
sed -i "s/NODE_NAME/master-1/" mountdirs/kubelet_config_master-1.yaml
sed -i "s/NODE_NAME/master-2/" mountdirs/kubelet_config_master-2.yaml
# or use gsed if you are on MacOS:
gsed -i "s/etcd_master_name/${KUBERNETES_ETCD_NAME_0}/" mountdirs/manifests/master-0/etcd.yaml
gsed -i "s/INTERNAL_IP/${KUBERNETES_ADDRESS_0}/" mountdirs/manifests/master-0/etcd.yaml
gsed -i "s/etcd_master_name/${KUBERNETES_ETCD_NAME_1}/" mountdirs/manifests/master-1/etcd.yaml
gsed -i "s/INTERNAL_IP/${KUBERNETES_ADDRESS_1}/" mountdirs/manifests/master-1/etcd.yaml
gsed -i "s/etcd_master_name/${KUBERNETES_ETCD_NAME_2}/" mountdirs/manifests/master-2/etcd.yaml
gsed -i "s/INTERNAL_IP/${KUBERNETES_ADDRESS_2}/" mountdirs/manifests/master-2/etcd.yaml
gsed -i "s/KUBERNETES_ADDRESS_0/${KUBERNETES_ADDRESS_0}/" mountdirs/manifests/master-0/etcd.yaml
gsed -i "s/KUBERNETES_ADDRESS_1/${KUBERNETES_ADDRESS_1}/" mountdirs/manifests/master-0/etcd.yaml
gsed -i "s/KUBERNETES_ADDRESS_2/${KUBERNETES_ADDRESS_2}/" mountdirs/manifests/master-0/etcd.yaml
gsed -i "s/KUBERNETES_ADDRESS_0/${KUBERNETES_ADDRESS_0}/" mountdirs/manifests/master-1/etcd.yaml
gsed -i "s/KUBERNETES_ADDRESS_1/${KUBERNETES_ADDRESS_1}/" mountdirs/manifests/master-1/etcd.yaml
gsed -i "s/KUBERNETES_ADDRESS_2/${KUBERNETES_ADDRESS_2}/" mountdirs/manifests/master-1/etcd.yaml
gsed -i "s/KUBERNETES_ADDRESS_0/${KUBERNETES_ADDRESS_0}/" mountdirs/manifests/master-2/etcd.yaml
gsed -i "s/KUBERNETES_ADDRESS_1/${KUBERNETES_ADDRESS_1}/" mountdirs/manifests/master-2/etcd.yaml
gsed -i "s/KUBERNETES_ADDRESS_2/${KUBERNETES_ADDRESS_2}/" mountdirs/manifests/master-2/etcd.yaml
gsed -i "s/NODE_NAME/master-0/" mountdirs/kubelet_config_master-0.yaml
gsed -i "s/NODE_NAME/master-1/" mountdirs/kubelet_config_master-1.yaml
gsed -i "s/NODE_NAME/master-2/" mountdirs/kubelet_config_master-2.yaml
```

### Run kubelet on masters

Download the packages, create the installation directories and install the binaries:

```
for instance in master-0 master-1 master-2; do
  vagrant ssh ${instance} -c "
    wget \
      https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz \
      https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz \
      https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl \
      https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet

    sudo mkdir -p \
      /etc/cni/net.d \
      /opt/cni/bin \
      /var/lib/kubelet \
      /var/lib/kubernetes \
      /var/run/kubernetes

    tar -xvf crictl-v1.15.0-linux-amd64.tar.gz
    sudo tar -xvf cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/
    chmod +x crictl kubectl kubelet 
    sudo mv crictl kubectl kubelet /usr/local/bin/
  "
done
```

### Start the etcd Server

```
vagrant halt master-0 master-1 master-2
vagrant up master-0 master-1 master-2
```

> Remember to run the above commands on each controller node: `controller-0`, `controller-1`, and `controller-2`.

## Verification

Log into one of the etcd containers:
```
vagrant ssh master-0
docker exec -ti <container_name> sh
```

List the etcd cluster members:
```
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:4001 \
  --cacert=/opt/kubernetes/certificates/ca.pem \
  --cert=/opt/kubernetes/certificates/kubernetes.pem \
  --key=/opt/kubernetes/certificates/kubernetes-key.pem
```

> output

```
6c00e5f14b18bcdb, started, master-2, https://10.240.0.4:2380, https://10.240.0.4:4001, false
cb56e9a82da31ab6, started, master-1, https://10.240.0.3:2380, https://10.240.0.3:4001, false
dd78bbaa611a97ad, started, master-0, https://10.240.0.2:2380, https://10.240.0.2:4001, false
```

```
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:4001 \
  --cacert=/opt/kubernetes/certificates/ca.pem \
  --cert=/opt/kubernetes/certificates/kubernetes.pem \
  --key=/opt/kubernetes/certificates/kubernetes-key.pem \
  endpoint status --cluster
```

> output

```
https://10.240.0.4:4001, 6c00e5f14b18bcdb, 3.4.1, 20 kB, false, false, 12, 9, 9,
https://10.240.0.3:4001, cb56e9a82da31ab6, 3.4.1, 20 kB, false, false, 12, 9, 9,
https://10.240.0.2:4001, dd78bbaa611a97ad, 3.4.1, 20 kB, true, false, 12, 9, 9,
```

NOTE: The logs will show a lot of error here. Kubelet will want to connect to kube-apiserver which is not yet present. You can ignore this for the time being.

Next: [Bootstrapping the Kubernetes Control Plane](08-bootstrapping-kubernetes-controllers.md)
