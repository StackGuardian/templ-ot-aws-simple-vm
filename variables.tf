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

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "EC2 instance type (x86_64)"
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "enable_public_ip" {
  description = "Place the instance in the public subnet and attach an Elastic IP"
  type        = bool
  default     = false
}

variable "allowed_ingress_cidrs" {
  description = "IPv4 CIDRs allowed to reach the instance when the public IP is enabled"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_ingress_cidrs : can(cidrnetmask(c))])
    error_message = "All entries must be valid IPv4 CIDR blocks."
  }

  validation {
    condition     = alltrue([for c in var.allowed_ingress_cidrs : try(tonumber(split("/", c)[1]) >= 8, false)])
    error_message = "CIDRs broader than /8, such as 0.0.0.0/0, are not allowed."
  }
}

variable "allowed_ingress_ports" {
  description = "TCP ports opened for allowed_ingress_cidrs when the public IP is enabled"
  type        = list(number)
  default     = [22]

  validation {
    condition     = alltrue([for p in var.allowed_ingress_ports : p >= 1 && p <= 65535])
    error_message = "Ports must be between 1 and 65535."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for the ec2-user. Leave null to use SSM Session Manager only."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Retention of the VPC flow logs in CloudWatch"
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "CloudWatch Logs accepts only fixed retention values, for example 30, 90 or 365."
  }
}
