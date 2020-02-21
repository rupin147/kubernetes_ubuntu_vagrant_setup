#!/bin/bash

# Install docker from Docker-ce repository
echo "[TASK 1] Install docker container engine"
#yum install -y -q yum-utils device-mapper-persistent-data lvm2 > /dev/null 2>&1
#yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
#yum install -y -q docker-ce-18.06.0.ce-3.el7 >/dev/null 2>&1
#usermod -aG docker vagrant

#echo "[TASK 2] Install docker container engine"
#apt-get install apt-transport-https ca-certificates curl software-properties-common -y
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
#apt-get update -y
#apt-get install docker-ce -y

# add ccount to the docker group
usermod -aG docker vagrant

# Enable docker service
echo "[TASK 3] Enable and start docker service"
systemctl enable docker >/dev/null 2>&1
systemctl start docker > /dev/null 2>&1


# Enable docker service
#echo "[TASK 2] Enable and start docker service"
#systemctl enable docker >/dev/null 2>&1
#systemctl start docker

# Add yum repo file for Kubernetes
echo "[TASK 2.A] Enable and start docker service"
sed -i '/swap/d' /etc/fstab > /dev/null 2>&1
swapoff -a > /dev/null 2>&1

modprobe br_netfilter 

echo "1" >> /proc/sys/net/bridge/bridge-nf-call-ip6tables > /dev/null 2>&1
echo "1" >> /proc/sys/net/bridge/bridge-nf-call-iptables > /dev/null 2>&1
echo "[TASK 6] Add sysctl settings"
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p /etc/sysctl.d/kubernetes.conf >/dev/null 2>&1
sysctl --system >/dev/null 2>&1
sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
service systemd-resolved restart%

# Install apt-transport-https pkg
echo "[TASK 2.B] Installing apt-transport-https pkg"
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common sshpass >/dev/null 2>&1
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - > /dev/null 2>&1


# Install Kubernetes
echo "[TASK 4] Install Kubernetes (kubeadm, kubelet and kubectl)"
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
ls -ltr /etc/apt/sources.list.d/kubernetes.list >/dev/null 2>&1
apt-get update -y

# Install Kubernetes
echo "[TASK 4.A] Install Kubernetes kubeadm, kubelet and kubectl"
apt-get install -y kubelet kubeadm kubectl


# Start and Enable kubelet service
echo "[TASK 5] Enable and start kubelet service"
systemctl enable kubelet >/dev/null 2>&1
#echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/sysconfig/kubelet
systemctl start kubelet >/dev/null 2>&1

# Install Openssh server
echo "[TASK 6] Install and configure ssh"
apt-get install -y -q openssh-server >/dev/null 2>&1
#sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
systemctl enable sshd >/dev/null 2>&1
systemctl start sshd >/dev/null 2>&1

# Set Root password
echo "[TASK 7] Set root password"
#echo "kubeadmin" | passwd --stdin root >/dev/null 2>&1
echo -e "kubeadmin\nkubeadmin" | passwd root
# Install additional required packages
#echo "[TASK 8] Install additional packages"
#yum install -y -q which net-tools sudo sshpass less >/dev/null 2>&1

#######################################
# To be executed only on master nodes #
#######################################

if [[ $(hostname) =~ .*master.* ]]
then

  # Initialize Kubernetes
  echo "[TASK 9] Initialize Kubernetes Cluster"
#  kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=Swap,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,SystemVerification >> /root/kubeinit.log 2>&1
  kubeadm init --apiserver-advertise-address=192.168.5.11  --pod-network-cidr=192.168.0.0/16 >> /root/kubeinit.log 2>/dev/null
  # Copy Kube admin config
  echo "[TASK 10] Copy kube admin config to root user .kube directory"
  mkdir /home/vagrant/.kube
  cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
  chown -R vagrant:vagrant /home/vagrant/.kube


  # Deploy flannel network
  echo "[TASK 11] Deploy flannel network"
  #kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml > /dev/null 2>&1
  su - vagrant -c "kubectl create -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml"

  # Generate Cluster join command
  echo "[TASK 12] Generate and save cluster join command to /joincluster.sh"
#  joinCommand=$(kubeadm token create --print-join-command) 
  kubeadm token create --print-join-command > /joincluster.sh


fi

#######################################
# To be executed only on worker nodes #
#######################################

if [[ $(hostname) =~ .*worker.* ]]
then

  # Join worker nodes to the Kubernetes cluster
  echo "[TASK 9] Join node to Kubernetes Cluster"
#  sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no master-1:/joincluster.sh /joincluster.sh 2>/tmp/joincluster.log
sshpass -p 'kubeadmin' scp  -o StrictHostKeyChecking=no root@master-1:/joincluster.sh /joincluster.sh
  bash /joincluster.sh >> /tmp/joincluster.log 2>&1

fi
