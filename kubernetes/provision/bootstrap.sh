#!/bin/bash
# https://phoenixnap.com/kb/install-kubernetes-on-ubuntu
nodetype="$1"
ip_segment="$2"
echo "Node Type: $nodetype"
echo "ip_segment: $ip_segment"
exit 0
master_ip="${ip_segment}.11"
echo "[Step 1- Installing required components]"
apt update >/dev/null 2>&1
apt install -y apt-transport-https ca-certificates curl gnupg >/dev/null 2>&1
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
apt-get update
sudo apt install -y kubeadm=1.30.3-1.1 kubelet=1.30.3-1.1 kubectl=1.30.3-1.1 >/dev/null 2>&1
apt-mark hold kubeadm kubelet kubectl >/dev/null 2>&1
echo "[>- Install and configure Docker]"
apt install -y docker.io >/dev/null 2>&1
systemctl enable docker >/dev/null 2>&1
cat <<EOF | tee /etc/docker/daemon.json
{ "exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts":
{ "max-size": "100m" },
"storage-driver": "overlay2"
}
EOF
systemctl restart docker >/dev/null 2>&1

echo "[> set up kubelet]"
cat <<EOF > /etc/default/kubelet
KUBELET_EXTRA_ARGS="--cgroup-driver=cgroupfs"
EOF

echo "[-> setup cni]"
# setup cni, by default it is installed in /opt/cni/bin
ln -s /opt/cni/bin /usr/lib/cni

echo "[>- Disabling swap]"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[>- Enable IP_Forward]"
cat >> /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay >/dev/null 2>&1
modprobe br_netfilter >/dev/null 2>&1
tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null 2>&1

echo "[>- updating /etc/hosts file]"
# TODO set network ip range in variable
cat >>/etc/hosts<<"EOF"
${ip_segemnt}.11   master01.kubernetes.cluster     kmaster
${ip_segment}.21   worker01.kubernetes.cluster     worker01
${ip_segment}.22   worker02.kubernetes.cluster     worker02
EOF



if [ $nodetype == "master" ]; then
echo "[Step 2 - Initializing Master Node]"
whoami
echo "will run kubeadm now"
kubeadm init --apiserver-advertise-address $master_ip --control-plane-endpoint $master_ip --pod-network-cidr=10.244.0.0/16
echo "[>- Installing Kubernetes network plugin]"
echo "[>- Enable ssh password authentication]"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubeadm token create --print-join-command > /joincluster.sh 2>/dev/null
sudo -u vagrant mkdir /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
fi;

if [ $nodetype == "worker" ]; then
echo "[Join worker to cluster]"
apt install -qq -y sshpass >/dev/null 2>&1
sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no master01.kubernetes.cluster:/joincluster.sh /joincluster.sh 2>/dev/null
bash /joincluster.sh >/dev/null 2>&1
fi;

