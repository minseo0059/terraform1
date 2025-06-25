# modules/ec2/main.tf

# AMI 조회 (최신 Ubuntu 22.04 LTS)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical 공식 계정 ID

  filter {
    name    = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name    = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 인스턴스에 대한 보안 그룹 정의 (SSH 및 HTTP 허용)
resource "aws_security_group" "ec2" {
  name        = "${var.env}-ec2-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = var.vpc_id

  # SSH (22번 포트) 허용
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP에서 접속 허용 (운영 환경에서는 특정 IP로 제한 권장)
  }

  # HTTP (80번 포트) 허용
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP에서 접속 허용
  }

  # 모든 아웃바운드 트래픽 허용 (EC2 인스턴스가 외부 인터넷에 접속 가능하도록)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 인스턴스 정의 (하나만 존재하도록 수정됨) ---
# 이 블록에 user_data 스크립트가 포함되어 EC2 인스턴스 내부에 Ansible을 설치합니다.
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id  # 조회된 AMI 사용
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = var.key_name # deploy.yml에서 CH3-key 값으로 전달됩니다.
  associate_public_ip_address = true # EC2에 퍼블릭 IP 할당

  # EC2 인스턴스가 처음 부팅될 때 실행될 User Data 스크립트
  # 이 스크립트가 EC2 인스턴스 내부에 Ansible 및 관련 라이브러리들을 설치합니다.
  user_data = <<-EOF
              #!/bin/bash
              echo "Starting user data script on EC2 instance..."
              
              # 1. 시스템 패키지 업데이트
              echo "Running apt-get update..."
              sudo apt-get update -y

              # 2. Python 및 pip 설치 (Ansible 실행에 필수)
              echo "Installing Python3 and pip3..."
              sudo apt-get install -y python3 python3-pip

              # 3. Ansible 설치 (pip를 통해)
              echo "Installing Ansible via pip3..."
              sudo pip3 install ansible

              # 4. Ansible AWS Collection 설치 및 boto3/botocore 라이브러리 설치
              # AWS 서비스 (S3, RDS 등)를 Ansible로 제어하기 위해 필요합니다.
              echo "Installing Ansible Community AWS collection and boto3/botocore..."
              sudo ansible-galaxy collection install community.aws
              sudo pip3 install boto3 botocore

              echo "Ansible and its dependencies installation complete on EC2 instance."
              EOF
  # --- user_data 블록 끝 ---

  tags = {
    Name = "${var.env}-ec2"
  }
}
# --- aws_instance.this 리소스 끝 ---
