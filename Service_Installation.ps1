function Install-IIS {
    param([string]$vname, [string]$passwd, [string]$usuario, [string]$os)

    $password = ConvertTo-SecureString $passwd -AsPlainText -Force
    $cred= New-Object System.Management.Automation.PSCredential ($usuario, $password)

    if($os -eq "Windows Server"){
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ 
            Install-WindowsFeature -Name Web-Server –IncludeManagementTools
        }
        Crear-Site -vname $vname -cred $cred -service $service.Config -os $os
    }
    elseif($os -eq "Windows 10"){
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
            Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures, IIS-ManagementConsole, IIS-HttpErrors, IIS-HttpRedirect, IIS-WindowsAuthentication, IIS-StaticContent, IIS-DefaultDocument, IIS-HttpCompressionStatic, IIS-DirectoryBrowsing
        }
        Crear-Site -vname $vname -cred $cred -service $service.Config -os $os
    }
    elseif($os -eq "Windows 10 Home"){
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
            Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures, IIS-ManagementConsole, IIS-HttpErrors, IIS-HttpRedirect, IIS-StaticContent, IIS-DefaultDocument, IIS-HttpCompressionStatic, IIS-DirectoryBrowsing
        }
        Crear-Site -vname $vname -cred $cred -service $service.Config -os $os
    }
}

function Install-DHCP {
    param([string]$vname, [string]$passwd, [string]$usuario, [string]$os)
    
    $password = ConvertTo-SecureString $passwd -AsPlainText -Force
    $cred= New-Object System.Management.Automation.PSCredential ($usuario, $password)
    if($os -eq "Windows Server"){
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
            Install-WindowsFeature DHCP -IncludeManagementTools
            Add-DhcpServerSecurityGroup -ComputerName dhcpsrv1
        }
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio, [string]$hostname, [string]$domain)
            #netsh dhcp add securitygroups
            #Restart-service dhcpserver
            #$computerName = $hostname + "." + $domain
            $host = hostname
            Add-DhcpServerSecurityGroup -ComputerName $host

            foreach($scope in $servicio.Scope){
                if($scope.Type -eq "IPv4"){
                    if($scope.State -eq "Active"){
                        Add-DhcpServerv4Scope -name $scope.Name -StartRange $scope.Start -EndRange $scope.End -SubnetMask $scope.Mask -State Active
                    }
                    else{
                        Add-DhcpServerv4Scope -name $scope.Name -StartRange $scope.Start -EndRange $scope.End -SubnetMask $scope.Mask -State Inactive
                    }
                    foreach($exclude in $scope.Exclude){
                        Add-DhcpServerv4ExclusionRange -ScopeID $exclude.ID -StartRange $exclude.Start -EndRange $exclude.End
                    }
                    if($scope.DNSHost -eq "" -or $scope.DNSHost -eq $null){
                        $dns = ""
                    }
                    else{
                        $dns = $scope.DNSHost + "." + $domain
                    }
                    Set-DhcpServerv4OptionValue -ScopeID $exclude.ID -DnsDomain $dns -DnsServer $scope.DNSIP -Router $scope.Router
                } 
                elseif($scope.Type -eq "IPv6"){
                    if($scope.State -eq "Active"){
                            Add-DhcpServerv6Scope -name $scope.Name -Prefix $scope.Prefix -State Active
                        }
                        else{
                            Add-DhcpServerv6Scope -name $scope.Name -Prefix $scope.Prefix -State Inactive
                        }
                        foreach($exclude in $scope.Exclude){
                            Add-DhcpServerv6ExclusionRange -Prefix $scope.Prefix -StartRange $exclude.Start -EndRange $exclude.End
                        }
                    }
            }
        } -ArgumentList $service.Config,$domain,$hostname
    }
}

function Install-DNS {
    param([string]$vname, [string]$passwd, [string]$usuario, [string]$os)
    
    $password = ConvertTo-SecureString $passwd -AsPlainText -Force
    $cred= New-Object System.Management.Automation.PSCredential ($usuario, $password)
    if($os -eq "Windows Server"){
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
            Install-WindowsFeature DNS -IncludeManagementTools
        }
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio, [string]$hostname, [string]$domain)
            foreach($zone in $servicio.Zone){
                if($zone.Type -eq "Reverse"){
                    Add-DnsServerPrimaryZone -NetworkID $zone.Network -ZoneFile $zone.File
                    foreach($record in $zone.Records){
                        if($record.Type -eq "PTR"){
                             Add-DnsServerResourceRecordPtr -Name $record.Name -ZoneName $zone.Name -AllowUpdateAny -PtrDomainName $record.PtrDomain
                        }
                    }
                }
            }
            foreach($zone in $servicio.Zone){
                if($zone.Type -eq "Forward"){
                    Add-DnsServerPrimaryZone -Name $zone.Name -ZoneFile $zone.File
                    foreach($record in $zone.Records){
                        if($record.Type -eq "A"){
                            Add-DnsServerResourceRecordA -Name $record.Name -ZoneName $zone.Name -AllowUpdateAny -IPv4Address $record.IP -CreatePtr
                        }
                        elseif($record.Type -eq "AAAA"){
                            Add-DnsServerResourceRecordAAAA -Name $record.Name -ZoneName $zone.Name -AllowUpdateAny -IPv6Address $record.IP -CreatePtr
                        }
                        elseif($record.Type -eq "CNAME"){
                             Add-DnsServerResourceRecordCName -Name $record.Name -HostNameAlias $record.Alias -ZoneName $zone.Name
                        }
                    }
                }
            }
        } -ArgumentList $service.Config
    }
}

function Crear-Site {
    param ([string]$vname, [PSCredential]$cred, [Object[]]$service, [string]$os)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio)
            #Install-WindowsFeature -Name Web-Server –IncludeManagementTools
            $numeroSitios = ($servicio.Sites | Measure-Object).Count # Numero de sitios por configurar
            for($i=0; $i -le $numeroSitios-1;$i++){
                Write-Host "Creando sitio " $i $servicio.Sites[$i].Name

                $bindings = $servicio.Sites[$i].Bindings #Array de objetos
                $siteName = $servicio.Sites[$i].Name
                $sitePath = $servicio.Sites[$i].SitePath
                foreach($bind in $bindings){
                    $ip = $bind.IP
                    $protocol = $bind.Protocol
                    if($ip -eq "" -or $ip -eq $null){
                        $ip = "*"
                    }
                    $binding = $ip + ":" + $bind.Port + ":" + $bind.Host
                    if($protocol -eq "https"){
                        $certPath = $bind.CertPath
                        Write-Host $certPath
                        if($bind -eq $bindings[0]){
                            Write-Host "Entrada 0"
                            if($os -eq "Windows Server"){
                                New-IISSite -Name $siteName -PhysicalPath $sitePath -BindingInformation $binding -Protocol https  -Force
                            }
                            else{
                                New-WebSite -Name $siteName -PhysicalPath $sitePath -IPAddress $ip -Port $bind.Port -HostHeader $bind.Host -Force
                            }
                        }
                        else{
                            Write-Host "Entrada 1"
                            if($os -eq "Windows Server"){
                                New-IISSiteBinding -Name $siteName -BindingInformation $binding -Protocol https
                            }
                            else{
                                New-WebBinding -Name $siteName -IPAddress $ip -Port $bind.Port -HostHeader $bind.Host  -Protocol https -Force
                            }
                            # -CertificateThumbPrint "D043B153FCEFD5011B9C28E186A60B9F13103363" -CertStoreLocation $certPath
                        }
                    }
                    elseif($protocol -eq "http"){
                        if($bind -eq $bindings[0]){
                            Write-Host "Entrada 0"
                            if($os -eq "Windows Server"){
                                New-IISSite -Name $siteName -PhysicalPath $sitePath -BindingInformation $binding -Protocol http  -Force
                            }
                            else{
                                New-WebSite -Name $siteName -PhysicalPath $sitePath -IPAddress $ip -Port $bind.Port -HostHeader $bind.Host -Force
                            }
                        }
                        else{
                            Write-Host "Entrada 1"
                            if($os -eq "Windows Server"){
                                New-IISSiteBinding -Name $siteName -BindingInformation $binding  -Protocol http -Force
                            }
                            else{
                                New-WebBinding -Name $siteName -IPAddress $ip -Port $bind.Port -HostHeader $bind.Host Protocol http  -Force
                            }
                        }
                    }
                }


            }
        } -args $service
}

#Pseudo-Main
Import-Module -Name Microsoft.PowerShell.Utility
    $vname = "WindowsContoso"
    $passwd = "hola123.,"
    $usuario = "Administrator"
    $os = "Windows Server"

if ($args.Count -eq 1) {
    $rutaJSON = $args[0] # Se lee la ruta donde está el archivo de entrada
    if (Test-Path -Path $rutaJSON) { # Se valida que el archivo exista
        $archivoEntrada = Get-Content -Raw -Path $rutaJSON | ConvertFrom-Json # Se lee el archivo de entrada en formato JSON
        $numeroMaquinas = ($ArchivoEntrada[0].VMs | Measure-Object).Count # Numero de Máquinas por instalar
        for($i=0; $i -le $numeroMaquinas-1;$i++) {
            $services = $archivoEntrada.VMs[$i].Services
            $hostname = $archivoEntrada.VMs[$i].Hostname
            $domain = $archivoEntrada.VMs[$i].Domain
            foreach($service in $services){
                if($service.Name -eq "IIS"){
                    Write-Host "Servicio | IIS"
                    Install-IIS -vname $vname -passwd $passwd -usuario $usuario -os $os
                }
                elseif($service.Name -eq "DHCP"){
                    Write-Host "Servicio | DHCP"
                    Install-DHCP -vname $vname -passwd $passwd -usuario $usuario -os $os
                }
                elseif($service.Name -eq "DNS"){
                    Write-Host "Servicio | DNS"
                    Install-DNS -vname $vname -passwd $passwd -usuario $usuario -os $os
                }
            }
            
        }
    } else {
        "No se ha logrado encontrar el archivo de entrada ingresado"   
    }
} else {
    "Sólo se debe de ingrear como algumento, la ruta donde se encuentre el archivo de entrada en formato JSON"
}