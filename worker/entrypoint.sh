#!/bin/sh
/usr/sbin/sshd -D&

sysctl -p
NODE=$(hostname -s)
kubelet_path=/usr/local/bin/kubelet

sudo swapoff -a

dockerd-entrypoint.sh &

docker ps
while [ $? != 0 ]
do
  sleep 3
done

if [ -f "$kubelet_path" ]; then
  sudo $kubelet_path --cert-dir=/opt/kubernetes/certificates --kubeconfig=/opt/kubernetes/certificates/${NODE}.kubeconfig \
       --log-dir=/var/log --logtostderr=false --network-plugin=cni \
       --node-labels=nodegroup=workers,node.kubernetes.io/role=worker,node-role.kubernetes.io/worker=true \
       --pod-infra-container-image=k8s.gcr.io/pause-amd64:3.0 \
       --config=/opt/kubernetes/kubelet_config_${NODE}.yaml&
fi

tail -f /etc/hosts
