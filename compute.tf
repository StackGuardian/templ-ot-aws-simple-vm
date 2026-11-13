data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_iam_role" "instance" {
  name = "${var.name_prefix}-vm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name_prefix}-vm"
  role = aws_iam_role.instance.name
}

resource "aws_security_group" "instance" {
  name        = "${var.name_prefix}-vm"
  description = "Simple VM"
  vpc_id      = aws_vpc.this.id
}

# Outbound HTTPS only, for SSM and package updates.
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
  count = var.ssh_public_key == null ? 0 : 1

  key_name   = "${var.name_prefix}-vm"
  public_key = var.ssh_public_key
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
