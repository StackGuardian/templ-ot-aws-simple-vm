locals {
  tags = merge(
    {
      Project     = var.name_prefix
      Environment = "demo"
      ManagedBy   = "opentofu"
      Repository  = "tf-aws-simple-vm"
    },
    var.advanced_settings.tags,
  )

  # An empty field in the form must count as "no key", like null.
  ssh_public_key = var.ssh_public_key == "" ? null : var.ssh_public_key

  # The first zone that offers the instance type. Not every zone offers every type.
  az = try([for z in data.aws_availability_zones.available.names : z if contains(data.aws_ec2_instance_type_offerings.this.locations, z)][0], null)

  # Short suffix from the VPC id, new for every deployment. Names that must be unique
  # in the account and region carry it, so a second deployment with the same name_prefix works.
  suffix = substr(sha256(aws_vpc.this.id), 0, 8)

  # One rule per CIDR and port, only when the public IP is enabled.
  public_ingress = var.advanced_settings.enable_public_ip ? {
    for pair in setproduct(var.advanced_settings.allowed_ingress_cidrs, var.advanced_settings.allowed_ingress_ports) :
    "${pair[0]}-${pair[1]}" => { cidr = pair[0], port = pair[1] }
  } : {}
}
