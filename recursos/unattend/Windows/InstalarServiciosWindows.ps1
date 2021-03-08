$maquina = Get-Content -Raw -Path "C:\sources\`$OEM`$\`$1\tmp.json" | ConvertFrom-Json
$so = $maquina.SistemaOperativo
$servicio = $maquina.Servicios
$winDefender = $servicio.WindowsDefender
$activeDirectory = $servicio.ActiveDirectory
$certServices = $servicio.CertificateServices
$iis = $servicio.IIS
$dhcp = $servicio.DHCP
$dns = $servicio.DNS
$cont = 0
foreach ($interfaz in $maquina.Interfaces) {
    if ($interfaz.Tipo -eq "Static") {
        $ip = $interfaz.IP
        $mascara = $interfaz.MascaraRed
        $gateway = $interfaz.Gateway
        $dns = $interfaz.DNS
        switch ($mascara) {
            "255.0.0.0" { $prefix = "8"; break }
            "255.255.0.0" { $prefix = "16"; break }
            "255.255.255.0" { $prefix = "24"; break }
        }
        $indexInterfaz = $((Get-NetAdapter)[$cont].ifIndex)
        if ($gateway) {
            New-NetIpAddress -InterfaceIndex $indexInterfaz -IpAddress "$ip" -PrefixLength "$prefix" -DefaultGateway "$gateway"
        } else {
            New-NetIpAddress -InterfaceIndex $indexInterfaz -IpAddress "$ip" -PrefixLength "$prefix"
        }
        if ($dns) {
            Set-DnsClientServerAddress -InterfaceIndex $indexInterfaz -ServerAddresses "$dns"
        }
    }
    $cont++
}
switch -regex ($so) {
    "Windows*" { 
        #RDP
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
     }
    "Windows Server 2019" { 
        if($winDefender){ Install-WindowsFeature -Name "Windows-Defender" -IncludeManagementTools }
        if($certServices){ Install-WindowsFeature -Name "AD-Certificate" -IncludeManagementTools }
        if($iis){ 
            Add-WindowsFeature "Web-Scripting-Tools"
            Install-WindowsFeature -Name "Web-WebServer" -IncludeManagementTools -IncludeAllSubFeature 
        }
        if($dhcp){ 
            Install-WindowsFeature -Name "DHCP" -IncludeManagementTools
            Add-DHCPServerSecurityGroup
         }
        if($dns){ Install-WindowsFeature -Name "DNS" -IncludeManagementTools }
        if($activeDirectory){ Install-WindowsFeature -Name "AD-Domain-Services" -IncludeManagementTools }
     }
}
$principal = New-ScheduledTaskPrincipal -RunLevel "Highest" -GroupId "BUILTIN\Administrators"
$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-file C:\sources\`$OEM`$\`$1\ConfigurarServiciosWindows.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogOn 
Register-ScheduledTask -TaskName "ConfigurarServicios" -Trigger $trigger -Action $taskAction -Principal $principal
Restart-Computer -Force