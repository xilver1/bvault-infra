variable "base_endpoint" {
    type = string
    description = "Proxmox base URL endpoint"
}

variable "prox_user" {
    type = string
    description = "Proxmox user for terraform access"
}

variable "prox_token_id" {
    type = string
    description = "Proxmox token ID for terraform access"
}

variable "environment" {
    type = string
    description = "Deployment environment name"
    default = "prod"

    validation {
        condition = contains(["dev", "prod"], var.environment)
        error_message = "Environment must be dev or prod."
    }
}