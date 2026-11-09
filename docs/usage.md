# AWS Virtual Machine (EC2)

Creates a single Linux server (Amazon Linux 2023) in its own network. By default the server has no public IP: you reach it through AWS Systems Manager Session Manager, without opening any port.

Use it when you need one VM for a test, a demo or a small tool.

## What gets created

- A VPC with a private and a public subnet
- Private connections to the AWS services the server needs (Session Manager and package repositories), so it works without internet access
- The EC2 instance with an IAM role for Session Manager
- VPC flow logs in CloudWatch Logs
- Optional: a public IP (Elastic IP) and an SSH key pair

## Before you start

- A workflow with an AWS cloud connector for the target account
- Permissions to create VPC, EC2, IAM and CloudWatch Logs resources
- To connect with Session Manager: the AWS CLI with the Session Manager plugin

## Form fields

| Field | What it does | Default |
|---|---|---|
| Name prefix | Prefix for all resource names. 2 to 16 lowercase letters, digits or hyphens, starting with a letter | `demo` |
| Region | AWS region | `eu-central-1` |
| Tags | Extra tags added to all resources | none |
| Instance type | Size of the server (x86_64) | `t3.micro` |
| VPC cidr | IP range of the new network | `10.0.0.0/16` |
| Enable public ip | Puts the server in the public subnet and gives it a public IP | off |
| Allowed ingress cidrs | IP ranges that may connect when the public IP is on. Required in that case. `0.0.0.0/0` and ranges broader than `/8` are rejected | empty |
| Allowed ingress ports | TCP ports opened for those ranges | `22` |
| SSH public key | Your public SSH key, for SSH login with a public IP. Leave empty to use only Session Manager | empty |
| Log retention days | How long flow logs are kept | `90` |

For a quick demo, keep all defaults and connect with Session Manager.

## After the run

The workflow outputs show:

- `instance_id` and `private_ip`
- `ssm_command`: run it to open a shell on the server, for example `aws ssm start-session --target <instance_id> --region <region>`
- `public_ip` and `ssh_command`: only set when the public IP and an SSH key are configured

## Security defaults

- No public IP and no inbound rules unless you switch them on
- Inbound traffic, when enabled, is limited to the IP ranges and ports you list
- SSH only with a key. Instance metadata requires IMDSv2. The disk is encrypted
- The server can only send HTTPS traffic out
- Flow logs record all network traffic

## Cost and cleanup

The server is billed per hour. The three private service connections (VPC endpoints) are billed per hour, also when idle. A public IP is billed while it exists. Destroy the resources from the workflow when the demo is over.

## Limits

- One availability zone, no high availability
- No internet access from the private subnet beyond the AWS services listed above
