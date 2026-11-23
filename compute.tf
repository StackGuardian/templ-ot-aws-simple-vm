data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_iam_role" "instance" {
  # IAM names are unique per account, so a generated name keeps a second deployment from clashing.
  name_prefix = "${var.name_prefix}-vm-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${var.name_prefix}-vm-"
  role        = aws_iam_role.instance.name

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "instance" {
  name        = "${var.name_prefix}-vm"
  description = "Simple VM"
  vpc_id      = aws_vpc.this.id
}

# Outbound HTTPS only, for SSM and package updates.
#trivy:ignore:AVD-AWS-0104 Outbound is limited to HTTPS (port 443), needed for SSM and package updates
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.instance.id
  description       = "HTTPS outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "public" {
  for_each = local.public_ingress

  security_group_id = aws_security_group.instance.id
  description       = "Allowed ingress on port ${each.value.port}"
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
}

resource "aws_key_pair" "this" {
  count = local.ssh_public_key == null ? 0 : 1

  key_name   = "${var.name_prefix}-vm"
  public_key = local.ssh_public_key
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.advanced_settings.enable_public_ip ? aws_subnet.public.id : aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  key_name                    = one(aws_key_pair.this[*].key_name)
  associate_public_ip_address = false
  monitoring                  = true
  ebs_optimized               = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = { Name = "${var.name_prefix}-vm" }

  lifecycle {
    # The image is picked once, when the VM is created. Without this, every new
    # Amazon Linux release changes `ami` and the next run would replace the VM.
    ignore_changes = [ami]

    precondition {
      condition     = local.az != null
      error_message = "No availability zone in this region offers the instance type. Pick another instance type or region."
    }

    precondition {
      condition     = !var.advanced_settings.enable_public_ip || length(var.advanced_settings.allowed_ingress_cidrs) > 0
      error_message = "allowed_ingress_cidrs must be set when enable_public_ip is true."
    }
  }

  depends_on = [aws_vpc_endpoint.interface]
}

resource "aws_eip" "this" {
  count = var.advanced_settings.enable_public_ip ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.this.id

  tags = { Name = "${var.name_prefix}-vm" }

  depends_on = [aws_internet_gateway.this]
}
