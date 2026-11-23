# Unit tests: plan only, providers are mocked. No cloud account, no cost.
# Run: tofu test -test-directory=tests/unit
# Test case catalog: tests/README.md

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-central-1a"]
    }
  }

  mock_data "aws_ec2_instance_type_offerings" {
    defaults = {
      locations = ["eu-central-1a"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  # Some arguments are validated as ARNs, so mocked values must look like ARNs.
  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-central-1:123456789012:log-group:mock"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }
}

# U-01
run "defaults_are_valid" {
  command = plan

  assert {
    condition = (
      local.tags["Environment"] == "demo" &&
      local.tags["ManagedBy"] == "opentofu" &&
      local.tags["Project"] == var.name_prefix &&
      local.tags["Repository"] != ""
    )
    error_message = "Default tags are missing or wrong."
  }
}

# U-02
run "invalid_name_prefix_is_rejected" {
  command = plan

  variables {
    name_prefix = "Invalid_Prefix"
  }

  expect_failures = [var.name_prefix]
}

# U-03
run "custom_tags_are_merged" {
  command = plan

  variables {
    advanced_settings = {
      tags = {
        Owner = "tester"
      }
    }
  }

  assert {
    condition     = local.tags["Owner"] == "tester" && local.tags["ManagedBy"] == "opentofu"
    error_message = "Custom tags are not merged with the default tags."
  }
}

# U-04
run "no_public_ip_by_default" {
  command = apply

  assert {
    condition     = length(aws_eip.this) == 0 && output.public_ip == null
    error_message = "No Elastic IP must be created by default."
  }

  assert {
    condition     = aws_instance.this.subnet_id == aws_subnet.private.id && !aws_instance.this.associate_public_ip_address
    error_message = "By default the instance must be in the private subnet without a public IP."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.public) == 0
    error_message = "No inbound rules must exist by default."
  }
}

# U-05
run "imdsv2_is_enforced" {
  command = apply

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be enforced."
  }
}

# U-06
run "root_volume_is_encrypted" {
  command = apply

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted
    error_message = "The root volume must be encrypted."
  }
}

# U-07
run "instance_profile_allows_ssm" {
  command = apply

  assert {
    condition     = aws_iam_role_policy_attachment.ssm.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "The instance role must include AmazonSSMManagedInstanceCore."
  }
}

# U-08
run "public_ip_without_cidrs_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      enable_public_ip = true
    }
  }

  expect_failures = [aws_instance.this]
}

# U-09
run "open_cidr_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      enable_public_ip      = true
      allowed_ingress_cidrs = ["0.0.0.0/0"]
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-10
run "public_ingress_is_restricted" {
  command = apply

  variables {
    advanced_settings = {
      enable_public_ip      = true
      allowed_ingress_cidrs = ["203.0.113.0/24"]
      allowed_ingress_ports = [22]
    }
  }

  assert {
    condition     = length(aws_eip.this) == 1 && aws_instance.this.subnet_id == aws_subnet.public.id
    error_message = "With enable_public_ip the instance must be in the public subnet with an Elastic IP."
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.public) == 1 &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.public : r.cidr_ipv4 == "203.0.113.0/24" && r.from_port == 22 && r.to_port == 22])
    )
    error_message = "Inbound rules must allow only the given CIDRs and ports."
  }
}

# U-11
run "vpc_flow_logs_are_enabled" {
  command = apply

  assert {
    condition     = aws_flow_log.this.vpc_id == aws_vpc.this.id && aws_flow_log.this.traffic_type == "ALL"
    error_message = "VPC flow logs must capture all traffic."
  }
}

# U-12
run "broad_cidr_is_rejected" {
  command = plan

  variables {
    advanced_settings = {
      enable_public_ip      = true
      allowed_ingress_cidrs = ["128.0.0.0/1"]
    }
  }

  expect_failures = [var.advanced_settings]
}

# U-13
run "create_vm_for_ami_check" {
  command = apply

  override_data {
    target = data.aws_ami.al2023
    values = {
      id = "ami-0123456789abcdef0"
    }
  }
}

run "new_ami_does_not_replace_the_vm" {
  command = plan

  override_data {
    target = data.aws_ami.al2023
    values = {
      id = "ami-0fedcba9876543210"
    }
  }

  assert {
    condition     = aws_instance.this.ami != "ami-0fedcba9876543210"
    error_message = "A newer AMI must not change the instance, which would replace the VM."
  }
}

# U-14
run "empty_ssh_key_means_no_key_pair" {
  command = plan

  variables {
    ssh_public_key = ""
  }

  assert {
    condition     = length(aws_key_pair.this) == 0
    error_message = "An empty SSH key field must not create a key pair."
  }
}

# U-15
run "ssh_key_of_an_unsupported_type_is_rejected" {
  command = plan

  variables {
    ssh_public_key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTY"
  }

  expect_failures = [var.ssh_public_key]
}

run "ed25519_ssh_key_creates_a_key_pair" {
  command = plan

  variables {
    ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMockKeyMockKeyMockKeyMockKeyMockKeyMockKeyMock"
  }

  assert {
    condition     = length(aws_key_pair.this) == 1
    error_message = "A valid SSH key must create a key pair."
  }
}

# U-16
run "zone_is_one_that_offers_the_instance_type" {
  command = plan

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["eu-central-1a", "eu-central-1b"]
    }
  }

  override_data {
    target = data.aws_ec2_instance_type_offerings.this
    values = {
      locations = ["eu-central-1b"]
    }
  }

  assert {
    condition     = aws_subnet.private.availability_zone == "eu-central-1b" && aws_subnet.public.availability_zone == "eu-central-1b"
    error_message = "Both subnets must be in a zone that offers the instance type."
  }
}

run "instance_type_not_offered_anywhere_is_rejected" {
  command = plan

  override_data {
    target = data.aws_ec2_instance_type_offerings.this
    values = {
      locations = []
    }
  }

  expect_failures = [aws_instance.this]
}

# U-17
run "iam_names_are_generated_and_flow_log_role_is_scoped" {
  command = plan

  assert {
    condition = (
      aws_iam_role.instance.name_prefix == "demo-vm-" &&
      aws_iam_instance_profile.instance.name_prefix == "demo-vm-" &&
      aws_iam_role.flow_logs.name_prefix == "demo-vpc-flow-logs-"
    )
    error_message = "IAM names are unique per account, so they need a generated suffix (name_prefix)."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.flow_logs.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "123456789012" &&
      can(regex("^arn:aws:ec2:eu-central-1:123456789012:vpc-flow-log/\\*$", jsondecode(aws_iam_role.flow_logs.assume_role_policy).Statement[0].Condition.ArnLike["aws:SourceArn"]))
    )
    error_message = "The flow log role may only be assumed for flow logs of this account (confused deputy protection)."
  }
}

# U-18
run "flow_log_group_name_is_unique_per_deployment" {
  command = apply

  assert {
    condition     = can(regex("^/demo-[0-9a-f]{8}/vpc-flow-logs$", aws_cloudwatch_log_group.flow_logs.name))
    error_message = "The flow log group needs a per deployment suffix, otherwise a second deployment in the same region fails."
  }
}
