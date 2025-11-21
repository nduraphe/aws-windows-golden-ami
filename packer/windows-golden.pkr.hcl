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
  default     = "us-east-1"
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

  ami_name = "windows-${var.server_type}-golden-ami-{{timestamp}}"

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = "PackerPassword@123"
  winrm_port     = 5985
  winrm_use_ssl  = false

  user_data_file = "scripts/winrm-userdata.ps1"

  iam_instance_profile = "GoldenAmiBuilderRole"

  security_group_ids          = ["sg-08a23ad128e577f24"]
  subnet_id                   = "subnet-0b3c8ac9c163bb072"
  associate_public_ip_address = true

  # IMDSv2 mandatory
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # forces IMDSv2
    http_put_response_hop_limit = 2
  }

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
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
  name    = "windows-golden-${var.server_type}"
  sources = ["source.amazon-ebs.windows"]

  # === SOFTWARE INSTALL WITH LOGGING ===
  provisioner "powershell" {
    environment_vars = [
      "S3_BUCKET=${var.software_bucket}",
      "S3_SCRIPT_KEY=${local.selected_script_key}"
    ]

    inline = [
      "$ErrorActionPreference='Stop'",

      "Write-Host '=== Starting Transcript ==='",
      "Start-Transcript -Path 'C:\\Temp\\packer_install_log.txt' -Append",

      "Write-Host '=== Preparing system ==='",
      "New-Item -ItemType Directory -Force -Path 'C:\\Temp' | Out-Null",

      Write-Host '=== Installing AWS CLI v2 ==='
      $cliInstaller = 'C:\Temp\AWSCLIV2.msi'
      Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $cliInstaller
      Start-Process msiexec.exe -ArgumentList "/i $cliInstaller /qn" -Wait

      # verify
      aws --version | Write-Host

      "Write-Host '=== Downloading install YAML from S3 ==='",
      "$yamlPath = 'C:\\install.yml'",
      "aws s3 cp ('s3://'+$env:S3_BUCKET+'/'+$env:S3_SCRIPT_KEY) $yamlPath",

      "Write-Host 'Install YAML saved to:' $yamlPath",

      "Write-Host '=== Parsing YAML ==='",
      "Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted",
      "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force",
      "Install-Module -Name powershell-yaml -Force -Scope AllUsers",

      "$yaml = Get-Content $yamlPath | ConvertFrom-Yaml",
      "Write-Host 'YAML content loaded:'",
      "$yaml.software | ConvertTo-Json | Write-Host",

      "foreach ($item in $yaml.software) {",
      "   Write-Host '---------------------------------------------'",
      "   Write-Host 'Installing:' $item.name",
      "   Write-Host 'S3 Path:' $item.s3_path",
      "   Write-Host 'Installer:' $item.installer",
      "   Write-Host 'Args:' $item.silent_args",

      "   $s3File = 's3://'+$env:S3_BUCKET+'/'+$item.s3_path",
      "   $localFile = 'C:\\Temp\\'+$item.installer",

      "   Write-Host 'Downloading installer from S3...'",
      "   aws s3 cp $s3File $localFile | Write-Host",

      "   Write-Host 'Running installer...'",
      "   $process = Start-Process -FilePath $localFile -ArgumentList $item.silent_args -PassThru -Wait",
      "   Write-Host 'Installer Exit Code:' $process.ExitCode",

      "   if ($process.ExitCode -ne 0) { Write-Host 'ERROR: Installation failed for' $item.name }",
      "}",

      "Write-Host '=== All installations completed ==='",

      "Stop-Transcript"
    ]
  }

  # === PRINT LOGS BEFORE TERMINATION ===
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Printing software installation logs from EC2 ==='",
      "if (Test-Path 'C:\\Temp\\packer_install_log.txt') {",
      "   Get-Content -Path 'C:\\Temp\\packer_install_log.txt' | Write-Host",
      "} else {",
      "   Write-Host 'Log file not found: C:\\Temp\\packer_install_log.txt'",
      "}",
      "Write-Host '=== End of software installation logs ==='"
    ]
  }

  # === CLEANUP BLOCK ===
  provisioner "powershell" {
    inline = [
      "Write-Host 'Cleaning up temporary files...'",
      "Remove-Item -Force C:\\install.yml -ErrorAction SilentlyContinue"
    ]
  }
}