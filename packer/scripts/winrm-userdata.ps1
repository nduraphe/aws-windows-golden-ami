<powershell>

# Set Administrator password so Packer can authenticate
net user Administrator "PackerPassword@123"

# Enable PowerShell Remoting (creates listener, service config)
Enable-PSRemoting -Force

# Configure WinRM for HTTP and allow unencrypted Basic auth
winrm quickconfig -force
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'

# Explicitly ensure listener exists
winrm delete winrm/config/Listener?Address=*+Transport=HTTP 2>$null
winrm create winrm/config/Listener?Address=*+Transport=HTTP

# Create firewall rule for WinRM
netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow

# Ensure WinRM service is running
Set-Service WinRM -StartupType Automatic
Start-Service WinRM

# Delay to ensure WinRM is fully ready
Start-Sleep -Seconds 20

Write-Host "WinRM enabled + password set + firewall opened"
</powershell>