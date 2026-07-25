terraform {
    required_version = ">= 1.11"

    backend "s3" {
        bucket = "terraform-state-854469103070-us-east-1-an"
        key = "lab-infra/terraform.tfstate"
        region = "us-east-1"
        use_lockfile = true
    }

    required_providers {
        proxmox = {
            source = "bpg/proxmox"
            version = "0.111.1"
        }

        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"
        }
    }
}

provider "aws" {
    region = "us-east-1"
}

ephemeral "aws_ssm_parameter" "api_token" {
    arn = "arn:aws:ssm:us-east-1:854469103070:parameter/lab/compute/api-token"
}

provider "proxmox" {
    endpoint = var.base_endpoint
    insecure = true
    api_token = ephemeral.aws_ssm_parameter.api_token.value
}