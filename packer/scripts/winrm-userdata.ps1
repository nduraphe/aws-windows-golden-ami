<powershell>

#
# Windows User Data used by Packer to enable WinRM over HTTP (port 5985)
# This script configures the instance so Packer can remotely connect
# and run provisioning steps.
#

# Set Administrator password
net user Administrator "PackerPassword@123"

# Enable remote PowerShell execution
Enable-PSRemoting -Force

# WinRM basic HTTP configuration
winrm quickconfig -force
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

# Increase WinRM stability (optional but recommended)
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
net localgroup "Remote Management Users" Administrator /add

# Ensure HTTP listener exists
winrm delete winrm/config/Listener?Address=*+Transport=HTTP 2>$null
winrm create winrm/config/Listener?Address=*+Transport=HTTP

# Open WinRM port in firewall
netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow

# Ensure WinRM service is running
Set-Service WinRM -StartupType Automatic
Start-Service WinRM

# Allow extra time for service to initialize before Packer attempts connection
Start-Sleep -Seconds 20

Write-Host "WinRM enabled and firewall rule configured."

</powershell>