# Integration tests: deploy real resources, check them, then destroy them.
# This costs money and needs cloud credentials.
# Run: tofu test -test-directory=tests/integration
# Test case catalog: tests/README.md

variables {
  name_prefix = "itest"
  tags = {
    Purpose = "integration-test"
  }
}

# I-01
run "deploy_default" {
  command = apply

  assert {
    condition     = aws_instance.this.instance_state == "running"
    error_message = "The instance is not running."
  }

  assert {
    condition     = output.public_ip == null && aws_instance.this.public_ip == ""
    error_message = "The instance must not have a public IP by default."
  }
}

# I-02
run "ssm_registration" {
  module {
    source = "./tests/integration/ssm-check"
  }

  variables {
    instance_id = run.deploy_default.instance_id
  }

  assert {
    condition     = output.registered
    error_message = "The instance did not register with SSM Session Manager."
  }
}

# I-03
run "deploy_with_public_ip" {
  command = apply

  variables {
    enable_public_ip      = true
    allowed_ingress_cidrs = ["203.0.113.0/24"]
  }

  assert {
    condition     = output.public_ip != null && can(cidrhost("${output.public_ip}/32", 0))
    error_message = "The public IP output is not set."
  }
}
