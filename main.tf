terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

module "vpc" {
  source              = "./modules/vpc"
  env                 = var.env
  cidr_block          = "10.0.0.0/16"
  public_subnets      = ["10.0.1.0/24", "10.0.2.0/24"]
  azs                 = ["ap-northeast-2a", "ap-northeast-2c"]
}

module "ec2" {
  source        = "./modules/ec2"
  env           = var.env
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.public_subnet_ids
  instance_type = var.instance_type
  key_name      = var.key_name
}
