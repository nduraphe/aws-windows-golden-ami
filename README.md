# Windows Golden AMI Build Pipeline

This repository automates the creation of Windows Golden AMIs using:

- GitHub Actions
- HashiCorp Packer (amazon-ebs)
- WinRM-based provisioning
- Software installation scripts stored in S3
- Optional AMI sharing across AWS accounts

Supports:

- Predefined server types
- Custom server types
- Automatic AMI naming (UTC timestamp)
- Script selection from S3
- Full install logs
- Clean, modular variable management

---

## Folder Structure

```
repo-root/
├── .github/
│   └── workflows/
│       └── build-windows-ami.yml
└── packer/
    ├── windows-golden.pkr.hcl
    ├── variables.pkr.hcl
    ├── pkrvars.hcl
    └── scripts/
        └── winrm-userdata.ps1
```

Software install scripts (member_server, domain_controller, custom)  
are not stored locally — they are downloaded from S3 at runtime.

---

## GitHub Actions Workflow

Trigger from:

Actions → Build Windows Golden AMI → Run workflow

### Server Type Options

| Option | Behavior |
|--------|----------|
| member_server | Uses default S3 script: windows/scripts/member_server_software_install.ps1 |
| domain_controller | Uses default S3 script: windows/scripts/domain_controller_software_install.ps1 |
| custom | Requires user-defined bucket + script path |

### Custom build inputs required (if server_type=custom):

```
custom_name   → Name of server type (example: sql2022)
custom_bucket → S3 bucket containing script
custom_script → Path to .ps1 script inside the bucket
```

### Optional AMI Sharing

Comma-separated list, example:

```
111122223333, 444455556666
```

Converted internally to:

```
["111122223333", "444455556666"]
```

---

## Automatic AMI Naming

Packer generates the AMI name using:

```
Golden-AMI-<server_type>-YYMMDDTHHMMZ
```

Examples:

```
Golden-AMI-member_server-250127T1032Z
Golden-AMI-sql2022-250127T0915Z
```

User does not provide AMI name.  
Workflow does not generate AMI name.

---

## Variable Flow Summary

| User Input | Packer Behavior |
|------------|-----------------|
| Predefined server type | Loads script from script_map |
| Custom build | Uses manual_script_key |
| Empty share list | AMI not shared |
| AMI name | Always auto-generated |

---

## Required S3 Structure

```
<bucket>/
└── windows/
    └── scripts/
        ├── member_server_software_install.ps1
        └── domain_controller_software_install.ps1
```

Custom scripts may be placed anywhere.

---

## Required IAM Role (EC2 Instance Profile)

Attach to the instance profile:

GoldenAmiBuilderRole

Minimum permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*Image*",
        "ec2:*Snapshot*",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:Describe*",
        "ec2:CreateTags",
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": "*"
    }
  ]
}
```

---

## GitHub Secrets Required

| Secret Name | Description |
|-------------|-------------|
| AWS_ACCESS_KEY_ID | GitHub runner credential |
| AWS_SECRET_ACCESS_KEY | GitHub runner credential |

---

## Local Packer Build (Optional)

```
cd packer
packer init windows-golden.pkr.hcl
packer build -var-file=pkrvars.hcl windows-golden.pkr.hcl
```

Use pkrvars.hcl for local overrides.

---

## AMI Build Flow

1. User starts GitHub Action
2. Workflow validates inputs
3. Workflow passes variables into Packer
4. Packer launches Windows EC2 builder instance
5. User-data script enables WinRM
6. Packer connects via WinRM (port 5985)
7. Packer installs AWS CLI
8. Script downloaded from S3
9. Script executed
10. Logs saved at: C:\Temp\packer_install_log.txt
11. Cleanup
12. AMI created
13. AMI optionally shared

---

## Example Install Script (S3)

member_server_software_install.ps1:

```powershell
Write-Host "Installing IIS..."
Install-WindowsFeature -Name Web-Server

Write-Host "Member Server provisioning complete."
```

---

## Recommended S3 Folder Layout

```
my-bucket/
├── windows/
│   └── scripts/
│       ├── member_server_software_install.ps1
│       ├── domain_controller_software_install.ps1
│       └── custom/
│           ├── sql_install.ps1
│           └── hardening.ps1
└── software/
    ├── installers/
    ├── configs/
    └── tools/
```

---

## Architecture Diagram (Text)

```
GitHub Actions
      |
      v
Packer Template (amazon-ebs)
      |
      v
Launch Windows EC2 Builder Instance
      |
      v
Userdata Enables WinRM (5985)
      |
      v
Packer Connects via WinRM
      |
      v
Downloads Script from S3
      |
      v
Runs Install Script and Captures Logs
      |
      v
Creates AMI, Tags, and Shares
```

---

## Sequence Diagram (Text)

```
User → GitHub Workflow: Provide inputs
Workflow → Packer: Pass variables
Packer → EC2: Launch builder instance
EC2 → Userdata: Enable WinRM
Packer → EC2: Connect via WinRM
Packer → S3: Download install script
EC2 → Packer: Execute install script
Packer → AWS: Stop + Create AMI
AWS → Packer: Return AMI ID
Packer → AWS: Share AMI if required
```

---

## Troubleshooting Guide

### Packer cannot connect (WinRM)

- Port 5985 open?
- Security group inbound 5985 allowed?
- Administrator password set?
- Base Windows AMI supports WinRM?
- Userdata script applied correctly?
- WinRM service running?

### S3 download failed

Check S3 key:

```
s3://bucket/path/script.ps1
```

### AMI not shared

- share_account_ids must be valid 12-digit AWS IDs
- IAM role must allow ModifyImageAttribute

### Script failed

Check:

```
C:\Temp\packer_install_log.txt
```

---

End of README.