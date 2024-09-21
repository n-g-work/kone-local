# 3. Setup Kubernetes Cluster

## 3.2 Install Helm

```sh
### on kone ###
# untaint node
kubectl taint node kone.local node-role.kubernetes.io/control-plane-

### install helm ###
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
bash ./get_helm.sh

# verify
helm version --short
```

## 3.3 Install Storage Provisioner

```sh
# install hostpath provisioner
helm repo add hostpath https://charts.rimusz.net
helm repo update
helm upgrade --install hostpath-provisioner --namespace kube-system hostpath/hostpath-provisioner

# OPTIONAL: verify host path provisioner
kubectl create -f https://raw.githubusercontent.com/rimusz/hostpath-provisioner/master/deploy/test-claim.yaml
kubectl create -f https://raw.githubusercontent.com/rimusz/hostpath-provisioner/master/deploy/test-pod.yaml

# OPTIONAL: remove hostpath test pod and pvc
kubectl delete -f https://raw.githubusercontent.com/rimusz/hostpath-provisioner/master/deploy/test-pod.yaml
kubectl delete -f https://raw.githubusercontent.com/rimusz/hostpath-provisioner/master/deploy/test-claim.yaml
```

## 3.4 Install Ingress Controller with TLS

```sh
# Create server key and CSR
openssl req -nodes -newkey rsa:2048 -keyout kone.local.key -out kone.local.csr -config kone-openssl.conf

# OPTIONAL: Check the CSR - look for the DNS
openssl req -in kone.local.csr -text -noout

# Sign the CRS with Kubernetes Root CA
sudo openssl x509 -req -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key \
  -in kone.local.csr -out kone.local.crt -days 36500 -sha256 -extensions v3_req -extfile kone-openssl.conf -CAcreateserial

# OPTIONAL: Check the issued certificate - again, look for the DNS
openssl x509 -in kone.local.crt -text -noout

# Output the Kubernetes Root CA certificate to console, to save and install it on host as Trusted Root Certification Authority
sudo cat /etc/kubernetes/pki/ca.crt

# Install the certificates locally
sudo cp /etc/kubernetes/pki/ca.crt /usr/local/share/ca-certificates/ \
  && sudo cp *crt /usr/local/share/ca-certificates/ \
  && sudo update-ca-certificates \
  && sudo systemctl restart containerd

# Create namespace for Ingress Controller and TLS secret
kubectl create ns ingress-nginx
kubectl -n ingress-nginx create secret tls kone-local-tls --key kone.local.key --cert kone.local.crt

# Add a chart repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install the ingress-nginx chart
helm upgrade --install ingress ingress-nginx/ingress-nginx --version 4.4.0 --values ingress_values.yaml --namespace ingress-nginx

# Wait for the controller and backend to become up and running
kubectl get pod -A --watch
```

## 3.5 Kubernetes Dashboard

```sh
# Create namespace for Kubernetes Dashboard and TLS secret
kubectl create ns kubernetes-dashboard
kubectl -n kubernetes-dashboard create secret tls kone-local-tls --key kone.local.key --cert kone.local.crt

# Add Kubernetes Dashboard helm repo and install it
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard
helm repo update
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --version 5.11.0 \
  --set ingress.enabled=true \
  --set ingress.hosts='{kubernetes-dashboard.kone.local}' \
  --set ingress.tls[0].hosts='{kubernetes-dashboard.kone.local}' \
  --set ingress.tls[0].secretName='kone-local-tls' \
  --set metrics-server.enabled=true \
  --set metrics-server.args="{--kubelet-insecure-tls}" \
  --set metricsScraper.enabled=true \
  --set settings.itemsPerPage=100 \
  --set settings.logsAutoRefreshTimeInterval=1 \
  --set settings.resourceAutoRefreshTimeInterval=5 \
  --set settings.disableAccessDeniedNotifications=true \
  --set settings.namespaceFallbackList="{default}" \
  --set settings.clusterName="kone" \
  --set extraArgs="{--token-ttl=43200}" \
  --namespace kubernetes-dashboard

# Wait for the dashboard and metrics server to become up and running
kubectl get pod -A --watch
```

## 3.4 Create Cluster Admin User

```sh
### on kone ###

# Create super admin service account and add cluster-admin permissions to it 
kubectl create sa super-admin -n kube-system
kubectl create clusterrolebinding super-admin-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:super-admin

# For Kubernetes 1.24+ add a secret to the service account
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: super-admin-secret
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: "super-admin"
EOF
# For Kubernetes 1.24+ issue a token for the service account
kubectl create token super-admin -n kube-system --duration 999999h

cat "${HOME}/.kube/config" | sed 's/10.10.0.10/kone.local/g'
```

## 3.5 Install Kubernetes Cluster Monitoring (OPTIONAL)

```sh
# Create namespace for Monitoring and TLS secret
kubectl create ns kube-observable
kubectl create -n kube-observable secret tls kone-local-tls --key kone.local.key --cert kone.local.crt

# Set helm chart values
cat <<EOF > prometheus_values.yaml
---
prometheus:
  ingress:
    enabled: true
    hostname: prometheus.kone.local
    extraTls:
      - hosts: [prometheus.kone.local]
        secretName: kone-local-tls
EOF

# Add Prometheus helm repo and install it
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade --install kube-prometheus bitnami/kube-prometheus -n kube-monitoring --values prometheus_values.yaml
```

## 3.6 Add Hostpath Storage Class (OPTIONAL)

```sh
### on kone / or with kubernetes-dashboard ###
# create hostpath storage class
cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp2
provisioner: hostpath
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
```

## 3.7 Adjust Cluster DNS Records (OPTIONAL)

```sh
## CoreDNS allows you to specify hosts directly in the hosts plugin (https://coredns.io/plugins/hosts/#examples).
## The ConfigMap can therefore be edited with

kubectl edit cm coredns -n kube-system
```

```yaml
apiVersion: v1
kind: ConfigMap
data:
  Corefile: |
    .:53 {
        errors
        health {
          lameduck 5s
        }
        hosts {
          10.10.0.10 kone.local
          10.10.0.10 prometheus.kone.local
          fallthrough
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . "/etc/resolv.conf"
        ## remove: cache 30
        loop
        reload
        loadbalance
    }
```

```sh
# You will still need to restart coredns so it rereads the config:
kubectl rollout restart -n kube-system deployment/coredns
```

## 3.8 Remove Kubernetes Cluster (OPTIONAL)

```sh
### on kone ###

# Remove cluster
sudo kubeadm reset -f && sudo rm -rf /etc/cni/net.d && rm -rf "${HOME}/.kube" && sudo reboot
sudo apt-mark unhold kubelet kubeadm kubectl
sudo apt remove -y kubelet kubeadm kubectl
```
