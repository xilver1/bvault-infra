variable "base_endpoint" {
  type        = string
  default     = "https://192.168.0.190:8006"
  description = "Proxmox base URL endpoint"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "prod"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod."
  }
}