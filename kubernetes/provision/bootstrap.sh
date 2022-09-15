#!/bin/bash


nodetype="$1"

echo "[Step 1- Installing required components]"
sudo apt update >/dev/null 2>&1
sudo apt install -y curl >/dev/null 2>&1
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - >/dev/null 2>&1
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/dev/null 2>&1
sudo apt install -y kubeadm=1.22.10-00 kubelet=1.22.10-00 kubectl=1.22.10-00 >/dev/null 2>&1
sudo apt-mark hold kubeadm kubelet kubectl >/dev/null 2>&1
echo "[>- Install and configure Docker]"
sudo apt install -y docker.io >/dev/null 2>&1
sudo systemctl enable docker >/dev/null 2>&1
sudo cat <<EOF | sudo tee /etc/docker/daemon.json
{ "exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts":
{ "max-size": "100m" },
"storage-driver": "overlay2"
}
EOF
sudo systemctl restart docker >/dev/null 2>&1


echo "[>- Disabling swap]"
sed -i '/swap/d' /etc/fstab
swapoff -a

echo "[>- Enable IP_Forward]"

sudo modprobe overlay >/dev/null 2>&1
sudo modprobe br_netfilter >/dev/null 2>&1
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system >/dev/null 2>&1

echo "[>- updating /etc/hosts file]"
cat >>/etc/hosts<<EOF
192.168.60.11   master01.kubernetes.cluster     kmaster
192.168.60.21   worker01.kubernetes.cluster     worker01
192.168.60.22   worker02.kubernetes.cluster     worker02
EOF
echo "[>- Adding flannel network subnets]"
mkdir -p /run/flannel >/dev/null 2>&1
tee /run/flannel/subnet.env<<EOF
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOF

if [ $1 == "master" ]; then
echo "[Step 2 - Initializing Master Node]"
sudo kubeadm init --apiserver-advertise-address 192.168.60.11 --control-plane-endpoint 192.168.60.11 >/dev/null 2>&1
echo "[>- Installing Kubernetes network plugin]"
echo "[>- Enable ssh password authentication]"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubeadm token create --print-join-command > /joincluster.sh 2>/dev/null
echo -e "---------COPY AND PASTE THE FOLLOWING IN ~/.kube/config OG MACHINE YOU WANT TO RUN KUBECTL COMMANDS-------\n"
cat /etc/kubernetes/admin.conf
echo -e "\n---------------------"
fi;

if [ $1 == "worker" ]; then
echo "[Join worker to cluster]"
apt install -qq -y sshpass >/dev/null 2>&1
sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no master01.kubernetes.cluster:/joincluster.sh /joincluster.sh 2>/dev/null
bash /joincluster.sh >/dev/null 2>&1
fi;

