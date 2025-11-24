###############################################################
# USER-PROVIDED VARIABLES (Only used for local packer runs)
#
# NOTE:
# GitHub Actions overrides these values automatically using:
#   -var server_type=...
#   -var software_bucket=...
#   -var manual_script_key=...
#   -var share_account_ids=...
#
# This file is mainly for manual/local packer testing:
#   packer build -var-file=pkrvars.hcl windows-golden.pkr.hcl
###############################################################

# AWS region to build the AMI in
aws_region = "us-east-1"

# Server type:
#   - member_server        (uses default script from script_map)
#   - domain_controller    (uses default script from script_map)
#   - custom               (requires manual_script_key)
server_type = "member_server"

# S3 bucket containing software/install scripts
software_bucket = "golden-ami-softwares-nagesh"

# For custom builds only — provide S3 path:
# Example:
#   manual_script_key = "custom/windows/scripts/my_script.ps1"
manual_script_key = ""

# Optional: list of AWS account IDs to share the AMI with
share_account_ids = []

# Example custom:
# server_type       = "my_custom_type"
# software_bucket   = "my-other-bucket"
# manual_script_key = "custom/scripts/myinstaller.ps1"
# share_account_ids = ["111122223333"]