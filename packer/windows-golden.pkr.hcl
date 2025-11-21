packer {
  required_version = ">= 1.11.0"

  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region where AMI will be built"
  default     = "us-west-2"
}

variable "server_type" {
  type        = string
  description = "Type of server to build (member_server or domain_controller)"
}

variable "software_bucket" {
  type        = string
  description = "S3 bucket containing install scripts and software"
}

variable "share_account_ids" {
  type        = list(string)
  description = "AWS accounts to share AMI with"
  default     = []
}

locals {
  script_map = {
    member_server     = "windows/scripts/member_server_software_install.yml"
    domain_controller = "windows/scripts/domain_controller_software_install.yml"
  }

  selected_script_key = local.script_map[var.server_type]

  common_tags = {
    Project     = "GoldenAMI"
    ManagedBy   = "Packer"
    Creator     = "GitHubActions"
    ServerType  = var.server_type
    Environment = "Personal"
  }
}

source "amazon-ebs" "windows" {
  region                   = var.aws_region
  instance_type            = "t3.large"

  ami_name = "win-${var.server_type}-golden-ami-{{timestamp}}"

  communicator             = "winrm"
  winrm_username           = "Administrator"
  winrm_password           = "PackerPassword@123"
  winrm_port               = 5985
  winrm_use_ssl            = false

  user_data_file           = "scripts/winrm-userdata.ps1"

  iam_instance_profile     = "arn:aws:iam::284495578504:instance-profile/GoldenAmiBuilderRole"

  security_group_ids       = ["sg-08a23ad128e577f24"]
  subnet_id                = "subnet-0b3c8ac9c163bb072"
  associate_public_ip_address = true

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2019-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["801119661308"]
    most_recent = true
  }

  tags          = local.common_tags
  snapshot_tags = local.common_tags
  run_tags      = local.common_tags
}

build {
  name = "windows-golden-${var.server_type}"
  sources = ["source.amazon-ebs.windows"]

  provisioner "powershell" {
    environment_vars = [
      "S3_BUCKET=${var.software_bucket}",
      "S3_SCRIPT_KEY=${local.selected_script_key}"
    ]

    inline = [
      "$ErrorActionPreference='Stop'",

      "Write-Host '=== Preparing system ==='",
      "New-Item -ItemType Directory -Force -Path 'C:\\Temp' | Out-Null",

      "Write-Host '=== Downloading install YAML from S3 ==='",
      "$yamlPath = 'C:\\install.yml'",
      "aws s3 cp ('s3://'+$env:S3_BUCKET+'/'+$env:S3_SCRIPT_KEY) $yamlPath",

      "Write-Host 'Install YAML saved to:' $yamlPath",

      "Write-Host '=== Parsing YAML ==='",
      "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted",
      "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force",
      "Install-Module -Name powershell-yaml -Force -Scope AllUsers",

      "$yaml = Get-Content $yamlPath | ConvertFrom-Yaml",

      "foreach ($item in $yaml.software) {",
      "   Write-Host 'Installing:' $item.name",

      "   $s3File = 's3://'+$env:S3_BUCKET+'/'+$item.s3_path",
      "   $localFile = 'C:\\Temp\\'+$item.installer",

      "   Write-Host 'Downloading installer:' $s3File",
      "   aws s3 cp $s3File $localFile",

      "   Write-Host 'Executing installer:' $item.installer",
      "   Start-Process -FilePath $localFile -ArgumentList $item.silent_args -Wait",

      "   Write-Host 'Completed installation of' $item.name",
      "}",
      
      "Write-Host '=== All installations completed ==='"
    ]
  }


  provisioner "powershell" {
    inline = [
      "Write-Host 'Cleaning up temporary files...'",
      "Remove-Item -Force C:\\install.yml -ErrorAction SilentlyContinue"
    ]
  }
}