<powershell>
# Enable WinRM for Packer builds
winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Create a firewall rule for WinRM
netsh advfirewall firewall add rule name="WinRM 5985" dir=in localport=5985 protocol=TCP action=allow

Write-Host "WinRM enabled via user data"
</powershell>