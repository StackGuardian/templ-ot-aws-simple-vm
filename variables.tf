variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.name_prefix))
    error_message = "Use 2-16 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "EC2 instance type (x86_64)"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "SSH public key for the ec2-user. Leave null or empty to use SSM Session Manager only."
  type        = string
  default     = null

  validation {
    condition     = var.ssh_public_key == null || var.ssh_public_key == "" || can(regex("^(ssh-ed25519|ssh-rsa) ", var.ssh_public_key))
    error_message = "Use an RSA or ED25519 public key, for example \"ssh-ed25519 AAAA...\". EC2 does not accept other key types."
  }
}

# Grouped so the StackGuardian form can show them in one "Advanced Settings" section.
variable "advanced_settings" {
  description = "Settings most deployments keep at their defaults"
  type = object({
    vpc_cidr              = optional(string, "10.0.0.0/16") # CIDR block of the VPC
    enable_public_ip      = optional(bool, false)           # Place the instance in the public subnet and attach an Elastic IP
    allowed_ingress_cidrs = optional(list(string), [])      # IPv4 CIDRs allowed to reach the instance when the public IP is enabled
    allowed_ingress_ports = optional(list(number), [22])    # TCP ports opened for allowed_ingress_cidrs when the public IP is enabled
    log_retention_days    = optional(number, 90)            # Retention of the VPC flow logs in CloudWatch
    tags                  = optional(map(string), {})       # Additional tags for all resources
  })
  default  = {}
  nullable = false

  validation {
    condition     = can(cidrnetmask(var.advanced_settings.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = alltrue([for c in var.advanced_settings.allowed_ingress_cidrs : can(cidrnetmask(c))])
    error_message = "All entries must be valid IPv4 CIDR blocks."
  }

  validation {
    condition     = alltrue([for c in var.advanced_settings.allowed_ingress_cidrs : try(tonumber(split("/", c)[1]) >= 8, false)])
    error_message = "CIDRs broader than /8, such as 0.0.0.0/0, are not allowed."
  }

  validation {
    condition     = alltrue([for p in var.advanced_settings.allowed_ingress_ports : p >= 1 && p <= 65535])
    error_message = "Ports must be between 1 and 65535."
  }

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.advanced_settings.log_retention_days)
    error_message = "CloudWatch Logs accepts only fixed retention values, for example 30, 90 or 365."
  }
}
