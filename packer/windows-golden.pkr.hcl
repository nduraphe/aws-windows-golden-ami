###############################################################
# PACKER CONFIGURATION
###############################################################

packer {
  required_version = ">= 1.11.0"

  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.6.0"
    }
  }
}

###############################################################
# LOCAL VALUES
###############################################################

locals {
  # Predefined script paths stored in S3
  script_map = {
    member_server     = "windows/scripts/member_server_software_install.ps1"
    domain_controller = "windows/scripts/domain_controller_software_install.ps1"
  }

  # Determine which script to use:
  # - If custom provided → use manual_script_key
  # - Else → use the predefined map
  selected_script_key = (
                          var.manual_script_key != "" ?
                          var.manual_script_key :
                          local.script_map[var.server_type]
                        )

  # Standard tags applied to AMI, snapshot, and the build instance
  common_tags = {
    Project     = "GoldenAMI"
    ManagedBy   = "Packer"
    Creator     = "GitHubActions"
    ServerType  = var.server_type
    Environment = "Personal"
  }
}

###############################################################
# SOURCE BUILDER: AMAZON EBS
###############################################################

source "amazon-ebs" "windows" {
  region        = var.aws_region
  instance_type = var.instance_type

  ami_name  = "Golden-AMI-${var.server_type}-${formatdate('YYMMDD''T''HHmm''Z''', timestamp())}"
  ami_users = var.share_account_ids

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.winrm_password
  winrm_port     = 5985
  winrm_use_ssl  = false

  user_data_file = var.user_data_file

  iam_instance_profile = var.instance_profile

  security_group_ids          = var.security_group_ids
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Base Windows AMI selection
  source_ami_filter {
    filters = {
      name                = var.base_ami_name_filter
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = var.base_ami_owners
    most_recent = true
  }

  tags          = local.common_tags
  snapshot_tags = local.common_tags
  run_tags      = local.common_tags
}

###############################################################
# BUILD STEPS
###############################################################

build {
  name    = "windows-golden-${var.server_type}"
  sources = ["source.amazon-ebs.windows"]

  ###############################################################
  # 1. DOWNLOAD AND RUN SOFTWARE INSTALL SCRIPTS FROM S3
  ###############################################################

  provisioner "powershell" {
    environment_vars = [
      "S3_BUCKET=${var.software_bucket}",
      "S3_SCRIPT_KEY=${local.selected_script_key}"
    ]

    inline = [
      "$ErrorActionPreference='Stop'",

      "Write-Host '=== Initializing Install Process ==='",
      "New-Item -ItemType Directory -Force -Path 'C:\\Temp' | Out-Null",
      "Start-Transcript -Path 'C:\\Temp\\packer_install_log.txt' -Append",

      "Write-Host 'Installing AWS CLI v2...'",
      "Invoke-WebRequest -Uri 'https://awscli.amazonaws.com/AWSCLIV2.msi' -OutFile 'C:\\Temp\\AWSCLIV2.msi'",
      "Start-Process 'msiexec.exe' -ArgumentList '/i C:\\Temp\\AWSCLIV2.msi /qn /norestart' -Wait",

      "Write-Host 'Downloading install script from S3...'",
      "& 'C:\\Program Files\\Amazon\\AWSCLIV2\\aws.exe' s3 cp ('s3://'+$env:S3_BUCKET+'/'+$env:S3_SCRIPT_KEY) 'C:\\install.ps1'",

      "Write-Host 'Running install script...'",
      "PowerShell.exe -ExecutionPolicy Bypass -File 'C:\\install.ps1'",

      "Write-Host '=== Install Script Completed ==='",
      "Stop-Transcript"
    ]
  }

  ###############################################################
  # 2. PRINT LOGS ON THE CONSOLE
  ###############################################################

  provisioner "powershell" {
    inline = [
      "Write-Host '=== Printing Logs ==='",
      "if (Test-Path 'C:\\Temp\\packer_install_log.txt') {",
      " Get-Content 'C:\\Temp\\packer_install_log.txt' | Write-Host",
      "} else {",
      " Write-Host 'Log file missing'",
      "}"
    ]
  }

  ###############################################################
  # 3. CLEANUP TEMP FILES
  ###############################################################

  provisioner "powershell" {
    inline = [
      "Write-Host 'Cleaning up temporary files...'",
      "Remove-Item -Force 'C:\\install.ps1' -ErrorAction SilentlyContinue",
      "Remove-Item -Force 'C:\\Temp\\AWSCLIV2.msi' -ErrorAction SilentlyContinue"
    ]
  }
}