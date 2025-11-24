<powershell>
# Set Administrator password
net user Administrator "PackerPassword@123"

# Enable PS Remoting
Enable-PSRemoting -Force

# WinRM configuration
winrm quickconfig -force
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'

# Increase WinRM limits
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'

# Listener recreate
winrm delete winrm/config/Listener?Address=*+Transport=HTTP 2>$null
winrm create winrm/config/Listener?Address=*+Transport=HTTP

# Firewall
netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in action=allow localport=5985

# Start WinRM
Set-Service WinRM -StartupType Automatic
Restart-Service WinRM

Start-Sleep -Seconds 30

Write-Host "WinRM initialized via user-data"
</powershell>