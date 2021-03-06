function InstalarServicios { param ($maquina, $rutaRaiz)
    $hostname = $maquina.Hostname
    $so = $maquina.SistemaOperativo
    $usuario = $maquina.Credenciales.Usuario
    $vname = "$($hostname)-$($so)"
    $servicio = $maquina.Servicios
    $winDefender = $servicio.WindowsDefender
    $activeDirectory = $servicio.ActiveDirectory
    $certServices = $servicio.CertificateServices
    $iis = servicio.IIS
    
    switch -regex ($so) {
        "Windows*" { 
            #RDP
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
         }
        "Windows Server 2019" { 
            if($winDefender){ Install-WindowsFeature -Name "Windows-Defender" -IncludeManagementTools }
            if($activeDirectory){ 
                Install-WindowsFeature -Name "AD-Domain-Services" -IncludeManagementTools 
                Install-ADDSForest -DomainName $activeDirectory.Dominio -DomainNetbiosName $activeDirectory.Netbios -DomainMode $activeDirectory.DomainMode -ForestMode $activeDirectory.ForestMode -Force -SafeModeAdministratorPassword $safePass
            }
            if($certServices){ Install-WindowsFeature -Name "AD-Certificate" -IncludeManagementTools }
            if($iis){ Install-WindowsFeature -Name "Web-WebServer" -IncludeManagementTools -IncludeAllSubFeature }
         }
    }
}