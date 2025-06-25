variable "env" {
  description = "배포 환경 (dev/stage/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.env)
    error_message = "올바른 환경이 아닙니다 (dev/stage/prod 중 선택)."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "key_name" {
  description = "EC2 키 페어 이름"
  type        = string
  default     = "CHE-key"  # 실제 키 페어명으로 변경 필요
}

variable "instance_count" {
  type        = number
  description = "Number of EC2 instances to create"
  default     = 1
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t2.micro"  # 기본값 설정 (필요시 덮어쓰기 가능)
}
