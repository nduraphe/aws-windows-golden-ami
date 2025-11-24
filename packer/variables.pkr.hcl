####################################################
# DEFAULT VARIABLE DEFINITIONS
####################################################

variable "aws_region" {
  description = "AWS region where the AMI will be built"
  type        = string
  default     = "us-east-1"
}

variable "server_type" {
  description = "Type of server to build (member_server, domain_controller, or custom)"
  type        = string
  default     = "member_server"
}

variable "software_bucket" {
  description = "S3 bucket name that contains software/scripts"
  type        = string
  default     = "golden-ami-softwares-nagesh"
}

variable "manual_script_key" {
  description = "Custom S3 script key for custom server type builds"
  type        = string
  default     = ""
}

variable "share_account_ids" {
  description = "List of AWS accounts to share the generated AMI with"
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "EC2 instance type used for AMI build"
  type        = string
  default     = "t3.large"
}

variable "instance_profile" {
  description = "IAM instance profile used for the builder instance"
  type        = string
  default     = "GoldenAmiBuilderRole"
}

variable "security_group_ids" {
  description = "Security groups attached to the builder EC2"
  type        = list(string)
  default     = ["sg-08a23ad128e577f24"]
}

variable "subnet_id" {
  description = "Subnet where the builder EC2 instance is launched"
  type        = string
  default     = "subnet-0b3c8ac9c163bb072"
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address to builder EC2"
  type        = bool
  default     = true
}

variable "winrm_password" {
  description = "WinRM Administrator password for the builder EC2"
  type        = string
  default     = "PackerPassword@123"
}

variable "user_data_file" {
  description = "User-data file used to configure WinRM on the builder EC2"
  type        = string
  default     = "scripts/winrm-userdata.yml"
}

variable "base_ami_name_filter" {
  description = "Filter pattern for selecting the base Windows AMI"
  type        = string
  default     = "Windows_Server-2022-English-Full-Base-*"
}

variable "base_ami_owners" {
  description = "List of AWS account IDs that own the base Windows AMIs"
  type        = list(string)
  default     = ["801119661308"]
}