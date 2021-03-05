#Funcion instala RDP
function InstalarRDP {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}
#Funcion instala Windows Defender
function InstalarWindowsDefender {
    Install-WindowsFeature -Name "Windows-Defender" -IncludeManagementTools
}
function InstalarActiveDirectory { param ($activeDirectory)
    Install-WindowsFeature -Name "AD-Domain-Services" -IncludeManagementTools
    Install-ADDSForest -DomainName $activeDirectory.Dominio -DomainNetbiosName $activeDirectory.Netbios -DomainMode $activeDirectory.DomainMode -ForestMode $activeDirectory.ForestMode -Force -SafeModeAdministratorPassword $safePass
}
function InstalarCertificateServices {
    Install-WindowsFeature -Name "AD-Certificate" -IncludeManagementTools
}
function Install-IIS { param ($iis)
    Install-WindowsFeature -Name "Web-Server" -IncludeManagementTools
    #Realiza la creación de sitios con sus respectivos bindings
    foreach($sitio in $iis){
        $nombre = $sitio.Nombre
        $directorio = $sitio.directorio
        foreach($binding in $sitio.Bindings){
            
        }
    }
    
    
    
    
    $numeroSitios = ($servicio.Sites | Measure-Object).Count # Numero de sitios por configurar
            for($i=0; $i -le $numeroSitios-1;$i++){
                Write-Host "Creando sitio " $servicio.Sites[$i].Name
                $bindings = $servicio.Sites[$i].Bindings #Array de objetos
                $siteName = $servicio.Sites[$i].Name
                $sitePath = $servicio.Sites[$i].SitePath
                #Creacion el directorio del sitio
                while(-not (Test-Path -Path $sitePath)){
                    Write-Host "Creando directorio " $sitePath
                    mkdir $sitePath
                #Revisa todos los binding declarados
                foreach($bind in $bindings){
                    $ip = $bind.IP
                    $protocol = $bind.Protocol
                    if($ip -eq "" -or $ip -eq $null){
                        $ip = "*"
                    }
                    $binding = $ip + ":" + $bind.Port + ":" + $bind.Host
                    if($protocol -eq "https"){
                        #Crea sitio con bindig https
                        if($bind -eq $bindings[0]){
                            New-IISSite -Name $siteName -PhysicalPath $sitePath -BindingInformation $binding -Protocol "https"  -Force
                        }
                        #Agrega binding http al sitio
                        else{
                            New-IISSiteBinding -Name $siteName -BindingInformation $binding -Protocol "https"
                        }
                    }
                    elseif($protocol -eq "http"){
                        #Crea sitio con bindig http
                        if($bind -eq $bindings[0]){
                            New-IISSite -Name $siteName -PhysicalPath $sitePath -BindingInformation $binding -Protocol "http"  -Force
                        }
                        #Agrega binding http al sitio
                        else{
                            New-IISSiteBinding -Name $siteName -BindingInformation $binding  -Protocol "http" -Force
                        }
                    }
                }
}