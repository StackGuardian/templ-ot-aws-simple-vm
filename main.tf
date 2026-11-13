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

  # One rule per CIDR and port, only when the public IP is enabled.
  public_ingress = var.advanced_settings.enable_public_ip ? {
    for pair in setproduct(var.advanced_settings.allowed_ingress_cidrs, var.advanced_settings.allowed_ingress_ports) :
    "${pair[0]}-${pair[1]}" => { cidr = pair[0], port = pair[1] }
  } : {}
}
