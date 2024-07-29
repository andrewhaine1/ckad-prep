Update the apt package index

```
sudo apt-get update
```

install packages needed to use the Kubernetes apt repository

```
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```

Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL:

```
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

Add the appropriate Kubernetes apt repository.
This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
```
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version:
```
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

## Install and configure prerequisites

### CGroup configuration

Enable IPv4 packet forwarding
```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
```

Apply sysctl params without reboot

```
sudo sysctl --system
```

Download containerd
```
wget https://github.com/containerd/containerd/releases/download/v1.7.19/containerd-1.7.19-linux-amd64.tar.gz
```

Untar containerd to /usr/local

```
sudo tar Cxzvf /usr/local containerd-1.7.19-linux-amd64.tar.gz
```

If you intend to start containerd via systemd, you should also download the containerd.service unit file from https://raw.githubusercontent.com/containerd/containerd/main/containerd.service into /usr/local/lib/systemd/system/containerd.service, and run the following commands:

```
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
```

Create containerd systemd service dir

```
sudo mkdir -p /usr/local/lib/systemd/system
```

Move containerd service file into containerd systemd service dir

```
sudo mv containerd.service /usr/local/lib/systemd/system/
```

Reload systemd service daemon

```
sudo systemctl daemon-reload
```

Enable systemd service

```
systemctl enable --now containerd
```

### Install runc

Download the runc.<ARCH> binary from https://github.com/opencontainers/runc/releases , verify its sha256sum, and install it as /usr/local/sbin/runc.

Download binary tar

```
wget https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64
```

Install runc

```
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
```

### Installing CNI plugins

Copy link address

```
wget https://github.com/containernetworking/plugins/releases/download/v1.5.1/cni-plugins-linux-amd64-v1.5.1.tgz
```

Create cni bin dir

```
mkdir -p /opt/cni/bin
```

Extract cni tar to cni bin dir

```
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.5.1.tgz
```

Kubeadm init (Only for COntrol plane, normal node will need to be joined to cluster)

```
sudo kubeadm init
sudo kubeadm init --kubernetes-version v1.29.1
```

Create network config file & Copy below into network config file

```
sudo touch /etc/cni/net.d/10-mynet.conf
sudo vi /etc/cni/net.d/10-mynet.conf
```

```
{
	"cniVersion": "0.2.0",
	"name": "mynet",
	"type": "bridge",
	"bridge": "cni0",
	"isGateway": true,
	"ipMasq": true,
	"ipam": {
		"type": "host-local",
		"subnet": "10.22.0.0/16",
		"routes": [
			{ "dst": "0.0.0.0/0" }
		]
	}
}

```

Create network config file & Copy below into network config file

```
sudo touch /etc/cni/net.d/99-loopback.conf
sudo vi /etc/cni/net.d/99-loopback.conf
```

```
{
	"cniVersion": "0.2.0",
	"name": "lo",
	"type": "loopback"
}
```

## Node setup

run the following command to install some package dependencies

```
sudo apt install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```

Next, run the following command to create a new directory and download the GPG key for the Docker repository.

```
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

Add the Docker repository to your system using the below command.

```
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

update and refresh the package index for your Ubuntu system

```
sudo apt update
```

Install containerd

```
sudo apt install containerd.io
```

installation is finished, start and enable the "containerd" service using the below systemctl command.

```
sudo systemctl start containerd
sudo systemctl enable containerd
```

Generate a new config file for the Containerd Container Runtime. Run the following command to backend the default configuration provides by the Docker repository. Then, generate a new configuration file using the "containerd" command as below.

```
sudo mv /etc/containerd/config.toml /etc/containerd/config.toml.orig
containerd config default | sudo tee /etc/containerd/config.toml
```

Now run the command below to enable the "SystemdCgroup" for the Containerd.

```
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
```

Run the wget command below to download the CNI plugin.

```
wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
```

Now create a new directory "/opt/cni/bin" using the below command. Then, extract the CNI plugin via the tar command as below.

```
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz
```

Create network config file & Copy below into network config file

```
sudo touch /etc/cni/net.d/10-mynet.conf
sudo vi /etc/cni/net.d/10-mynet.conf
```

```
{
	"cniVersion": "0.2.0",
	"name": "mynet",
	"type": "bridge",
	"bridge": "cni0",
	"isGateway": true,
	"ipMasq": true,
	"ipam": {
		"type": "host-local",
		"subnet": "10.22.0.0/16",
		"routes": [
			{ "dst": "0.0.0.0/0" }
		]
	}
}

```

Create network config file & Copy below into network config file

```
sudo touch /etc/cni/net.d/99-loopback.conf
sudo vi /etc/cni/net.d/99-loopback.conf
```

```
{
	"cniVersion": "0.2.0",
	"name": "lo",
	"type": "loopback"
}
```

install packages needed to use the Kubernetes apt repository

```
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```

Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL:

```
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

Add the appropriate Kubernetes apt repository.
This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
```
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version:
```
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

Run kubeadm join

```
sudo kubeadm join 10.0.2.6:6443 --token 6cgx78.h4yrw2dl05nlg710 --discovery-token-ca-cert-hash sha256:098c6b49dfea99eab74bb6ed923c78783bbfb7c7678fec127e4eb490a31a7862
```
