# Helper for the integration test: waits until the instance registers with SSM.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

variable "instance_id" {
  type = string
}

# The SSM agent needs a few minutes after boot to register.
resource "time_sleep" "wait" {
  create_duration = "180s"
}

data "aws_ssm_instances" "this" {
  filter {
    name   = "InstanceIds"
    values = [var.instance_id]
  }

  depends_on = [time_sleep.wait]
}

output "registered" {
  value = contains(data.aws_ssm_instances.this.ids, var.instance_id)
}
