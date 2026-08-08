# Terraform configuration pour T-CLO-902
# Provisionnement de 4 VMs EC2 : kube-1, kube-2, ingress, monitoring

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider AWS avec la région eu-central-1 (Francfurt)
provider "aws" {
  region = "eu-central-1"
}

# Variables
variable "aws_access_key" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "Nom de la clé SSH SSH-Key-Group-50"
  default     = "SSH-Key-Group-50"
}

# Data sources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Récupérer la clé privée depuis AWS Systems Manager Parameter Store
data "aws_ssm_parameter" "ssh_private_key" {
  name = "/kubequest/group-50/ssh-private-key"
}

# Créer le répertoire .ssh si nécessaire et sauvegarder la clé
resource "local_file" "ssh_private_key" {
  content  = data.aws_ssm_parameter.ssh_private_key.value
  filename = "${path.module}/ssh-key-group-50.pem"
  file_permission = "0400"
}

# VPC et réseau
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "kubequest-vpc-group-50"
    Project     = "T-CLO-902"
    Group       = "group-50"
    Environment = "education"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "kubequest-igw-group-50"
    Project     = "T-CLO-902"
    Group       = "group-50"
  }
}

# Subnet publique
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"

  tags = {
    Name        = "kubequest-public-subnet-group-50"
    Project     = "T-CLO-902"
    Group       = "group-50"
  }
}

# Table de routage
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "kubequest-public-rt-group-50"
    Project     = "T-CLO-902"
    Group       = "group-50"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group pour les nodes Kubernetes
resource "aws_security_group" "kubernetes_nodes" {
  name        = "kubernetes-nodes-sg-group-50"
  description = "Security group for Kubernetes nodes"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Kubernetes API server (6443)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Kubernetes API server"
  }

  # Pod network (pour Flannel/Calico)
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Pod network overlay"
  }

  # NodePort services (30000-32767)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NodePort services"
  }

  # Ping et ICMP
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ICMP for ping"
  }

  # Tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "kubernetes-nodes-sg-group-50"
    Project     = "T-CLO-902"
    Group       = "group-50"
  }
}

# Security Group pour Ingress
resource "aws_security_group" "ingress" {
  name        = "ingress-sg-group-50"
  description = "Security group for Ingress controller"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP web traffic"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS web traffic"
  }

  # Health checks depuis load balancer AWS si nécessaire
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Health check port"
  }

  # Tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "ingress-sg-group-50"
    Project     = "T-CLO-902"
    Group       = "group-50"
  }
}

# Security Group pour Monitoring
resource "aws_security_group" "monitoring" {
  name        = "monitoring-sg-group-50"
  description = "Security group for monitoring tools"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Prometheus (9090)
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Prometheus web UI"
  }

  # Grafana (3000)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana web UI"
  }

  # Node Exporter (9100)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Node Exporter metrics"
  }

  # Tout le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "monitoring-sg-group-50"
    Project     = "T-CLO-902"
    Group       = "group-50"
  }
}

# Instance EC2 pour kube-1
resource "aws_instance" "kube_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.kubernetes_nodes.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
  }

  tags = {
    Name        = "kube-1"
    Role        = "kubernetes-node"
    Project     = "T-CLO-902"
    Group       = "group-50"
    Environment = "education"
    Node-Type   = "worker"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Mise à jour du système
              apt-get update && apt-get upgrade -y

              # Installation des prérequis Kubernetes
              apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release

              # Installation de Docker/containerd
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
              apt-get update
              apt-get install -y containerd.io
              systemctl enable containerd
              systemctl start containerd

              # Installation de kubeadm, kubelet, kubectl
              curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
              echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
              apt-get update
              apt-get install -y kubelet kubeadm kubectl
              apt-mark hold kubelet kubeadm kubectl

              # Configuration containerd pour Kubernetes
              mkdir -p /etc/containerd
              containerd config default > /etc/containerd/config.toml
              sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
              systemctl restart containerd

              # Désactiver swap
              swapoff -a
              sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

              # Configuration sysctl pour Kubernetes
              cat <<EOF | tee /etc/sysctl.d/k8s.conf
              net.bridge.bridge-nf-call-iptables  = 1
              net.bridge.bridge-nf-call-ip6tables = 1
              net.ipv4.ip_forward                 = 1
              EOF
              sysctl --system

              echo "kube-1 - Kubernetes prerequisites installed successfully"
              EOF
}

# Instance EC2 pour kube-2
resource "aws_instance" "kube_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.kubernetes_nodes.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
  }

  tags = {
    Name        = "kube-2"
    Role        = "kubernetes-node"
    Project     = "T-CLO-902"
    Group       = "group-50"
    Environment = "education"
    Node-Type   = "worker"
  }

  user_data = aws_instance.kube_1.user_data
}

# Instance EC2 pour ingress
resource "aws_instance" "ingress" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ingress.id, aws_security_group.kubernetes_nodes.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  tags = {
    Name        = "ingress"
    Role        = "ingress-controller"
    Project     = "T-CLO-902"
    Group       = "group-50"
    Environment = "education"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Mise à jour du système
              apt-get update && apt-get upgrade -y

              # Installation des prérequis
              apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                nginx

              # Installation de Docker
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
              apt-get update
              apt-get install -y containerd.io docker-compose
              systemctl enable docker
              systemctl start docker

              # Installation de kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              mv kubectl /usr/local/bin/

              echo "ingress - Prerequisites installed successfully"
              EOF
}

# Instance EC2 pour monitoring
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.monitoring.id, aws_security_group.kubernetes_nodes.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
  }

  tags = {
    Name        = "monitoring"
    Role        = "monitoring-server"
    Project     = "T-CLO-902"
    Group       = "group-50"
    Environment = "education"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Mise à jour du système
              apt-get update && apt-get upgrade -y

              # Installation de Docker
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
              echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
              apt-get update
              apt-get install -y docker-compose
              systemctl enable docker
              systemctl start docker

              # Installation de Node Exporter
              wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
              tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
              mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
              useradd node_exporter
              chown node_exporter:node_exporter /usr/local/bin/node_exporter

              # Créer le service systemd pour Node Exporter
              cat <<'NODEEXPORTER' > /etc/systemd/system/node_exporter.service
              [Unit]
              Description=Node Exporter
              Wants=network-online.target
              After=network-online.target

              [Service]
              User=node_exporter
              Group=node_exporter
              Type=simple
              ExecStart=/usr/local/bin/node_exporter

              [Install]
              WantedBy=multi-user.target
              NODEEXPORTER

              systemctl daemon-reload
              systemctl enable node_exporter
              systemctl start node_exporter

              echo "monitoring - Monitoring tools installed successfully"
              EOF
}

# Output des informations importantes
output "vpc_id" {
  description = "ID du VPC créé"
  value       = aws_vpc.main.id
}

output "kube_1_public_ip" {
  description = "IP publique de kube-1"
  value       = aws_instance.kube_1.public_ip
}

output "kube_1_private_ip" {
  description = "IP privée de kube-1"
  value       = aws_instance.kube_1.private_ip
}

output "kube_2_public_ip" {
  description = "IP publique de kube-2"
  value       = aws_instance.kube_2.public_ip
}

output "kube_2_private_ip" {
  description = "IP privée de kube-2"
  value       = aws_instance.kube_2.private_ip
}

output "ingress_public_ip" {
  description = "IP publique de ingress"
  value       = aws_instance.ingress.public_ip
}

output "ingress_private_ip" {
  description = "IP privée de ingress"
  value       = aws_instance.ingress.private_ip
}

output "monitoring_public_ip" {
  description = "IP publique de monitoring"
  value       = aws_instance.monitoring.public_ip
}

output "monitoring_private_ip" {
  description = "IP privée de monitoring"
  value       = aws_instance.monitoring.private_ip
}

output "ssh_key_path" {
  description = "Chemin de la clé SSH privée"
  value       = local_file.ssh_private_key.filename
}

output "ssh_connection_example" {
  description = "Exemple de commande SSH"
  value       = "ssh -i ${local_file.ssh_private_key.filename} ubuntu@${aws_instance.kube_1.public_ip}"
}
