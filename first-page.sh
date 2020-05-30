{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}

{

cat > admin-csr.json <<eof
{
  "cn": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "c": "us",
      "l": "portland",
      "o": "system:masters",
      "ou": "kubernetes the hard way",
      "st": "oregon"
    }
  ]
}
eof

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

}

{

  cat > kubectl-csr.json <<eof
{
  "cn": "kubectl",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "c": "us",
      "l": "portland",
      "o": "kubectl",
      "ou": "kubernetes the hard way",
      "st": "oregon"
    }
  ]
}
eof

  cfssl gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -profile=kubernetes \
        kubectl-csr.json | cfssljson -bare kubectl

}

for instance in master-0 master-1 master-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

IP=$(vagrant ssh ${instance} -c "/sbin/ifconfig eth0" \
  | grep "inet addr" | tail -n 1 | egrep -o "[0-9\.]+" \
  | head -n 1 2>&1)

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

for instance in worker-0 worker-1 worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

IP=$(vagrant ssh ${instance} -c "/sbin/ifconfig eth0" \
  | grep "inet addr" | tail -n 1 | egrep -o "[0-9\.]+" \
  | head -n 1 2>&1)

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

{

cat > kube-controller-manager-csr.json <<eof
{
  "cn": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "c": "us",
      "l": "portland",
      "o": "system:kube-controller-manager",
      "ou": "kubernetes the hard way",
      "st": "oregon"
    }
  ]
}
eof

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}
{

cat > kube-proxy-csr.json <<eof
{
  "cn": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "c": "us",
      "l": "portland",
      "o": "system:node-proxier",
      "ou": "kubernetes the hard way",
      "st": "oregon"
    }
  ]
}
eof

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}

{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}

KUBERNETES_ADDRESS_0=$(vagrant ssh master-0 -c "/sbin/ifconfig eth0" \
  | grep "inet addr" | tail -n 1 | egrep -o "[0-9\.]+" \
  | head -n 1 2>&1)

KUBERNETES_ADDRESS_1=$(vagrant ssh master-1 -c "/sbin/ifconfig eth0" \
  | grep "inet addr" | tail -n 1 | egrep -o "[0-9\.]+" \
  | head -n 1 2>&1)

KUBERNETES_ADDRESS_2=$(vagrant ssh master-2 -c "/sbin/ifconfig eth0" \
  | grep "inet addr" | tail -n 1 | egrep -o "[0-9\.]+" \
  | head -n 1 2>&1)

{

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.198.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_ADDRESS_0},${KUBERNETES_ADDRESS_1},${KUBERNETES_ADDRESS_2},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}

{

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}

mv ca* mountdirs/certificates
mv admin* mountdirs/certificates
mv worker-* mountdirs/certificates
mv master-* mountdirs/certificates
mv kube* mountdirs/certificates
mv service-account* mountdirs/certificates
cp static_kubelet_config.yaml mountdirs/kubelet_config_master-0.yaml
cp static_kubelet_config.yaml mountdirs/kubelet_config_master-1.yaml
cp static_kubelet_config.yaml mountdirs/kubelet_config_master-2.yaml

