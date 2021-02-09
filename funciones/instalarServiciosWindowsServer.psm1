# Funcion que instala IIS

<#
function Install-IIS {
    param([string]$vname, [PSCredential]$cred)
    
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ 
        Install-WindowsFeature -Name Web-Server –IncludeManagementTools
    }
    #Realiza la creación de sitios con sus respectivos bindings
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio)
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
                }
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
        } -args $service
}
#>

#Funcion instala DHCP
function Install-DHCP {
    param([string]$vname, [PSCredential]$cred, [string]$os)
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
            Install-WindowsFeature DHCP -IncludeManagementTools
            Add-DhcpServerSecurityGroup
        }
        #Crea los diferentes scopes declarados
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio, [string]$domain)
            
            foreach($scope in $servicio.Scope){
                #Scope IPv4
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
                    if($scope.DNSHost -ne "" -and $scope.DNSHost -ne $null){
                        $dns = $scope.DNSHost + "." + $domain
                        Set-DhcpServerv4OptionValue -ScopeID $exclude.ID -DnsDomain $dns -DnsServer $scope.DNSIP -Router $scope.Router
                    }
                } 
                #Scope IPv6
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
        } -ArgumentList $service.Config,$domain
}

#Funcion instala DNS
function Install-DNS {
    param([string]$vname, [PSCredential]$cred, [string]$os)
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
            Install-WindowsFeature DNS -IncludeManagementTools
        }
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio)
            #Se agregan las zonas Reverse para poder crear los registros PTR en las zonas Forward
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
            #Se agregan las zonas Forward y sus respectivos registros A, AAAA, CNAME, con sus respectivos PTR
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

#Funcion instala RDP
function Install-RDP {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    }
}

#Funcion instala AD Certificate Services
function Install-Certificate {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
        Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools
    }
}

#Funcion instala AD Domain Services
function Install-ADDS {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio,[SecureString]$safePass)
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        $modes = @{ "Windows Server 2008" = "Win2008"; "Windows Server 2008 R2" = "Win2008R2"; "Windows Server 2012" = "Win2012"; "Windows Server 2012 R2" = "Win2012R2"; "Windows Server 2016" = "Win2016"}
        #Revisa el modo de dominio y de bosque
        foreach($mode in $modes.keys){
            Write-Host $mode $servicio.ForestMode $servicio.DomainMode
            if($mode -eq $servicio.DomainMode){
                $domainMode = $modes[$mode]
            }
            if($mode -eq $servicio.ForestMode){
                $forest = $modes[$mode]
            }
        }
        #Agrega el bosque en el dominio
        if($forest -ne $null -and $domainMode -ne $null){
            Install-ADDSForest -DomainName $servicio.Domain -DomainNetbiosName $servicio.Netbios -ForestMode $forest -DomainMode $domainMode -Force -SafeModeAdministratorPassword $safePass
        }
    } -ArgumentList ($service.Config,$password)
}

#Funcion instala Windows Defender
function Install-Defender {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio)
        Install-WindowsFeature -Name Windows-Defender -IncludeManagementTools
        #Habilita el analisis de archivos como .rar y .zip
        Set-MpPreference -DisableArchiveScanning 0
        #Excluye rutas para analizar
        foreach($pathEx in $servicio.ExclusionPath){
            if(Test-Path -Path $pathEx){
                Add-MpPreference -ExclusionPath $pathEx
            }
            else{
                mkdir $pathEx
                Add-MpPreference -ExclusionPath $pathEx
            }
        }
        #Excluye procesos para analizar
        foreach($processEx in $servicio.ExclusionProcess){
            Add-MpPreference -ExclusionProcess $processEx
        }
        #Excluye extensiones para analizar
        foreach($extensionEx in $servicio.ExclusionExtension){
            Add-MpPreference -ExclusionExtension $extensionEx
        }
    } -args $service.Config
}

#Funcion instala WebDAV
function Install-WebDAV {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio,[string]$domain)
        Install-WindowsFeature -Name Web-DAV-Publishing
        Restart-Service W3SVC 
        foreach($group in $servicio.Groups){
            #Crecion de grupos
            New-LocalGroup -Name $group.Name
            foreach($member in $group.Members){
                #Agrega los miembros al grupo
                $memUser = $doman +"/" +$member
                Add-LocalGroupMember -Group $group.Name -Member $memUser
            }
            #Agrega las locaciones del directorio virtual
            foreach($location in $group.Locations){
                if(Test-Path -Path $location.Path){
                    New-WebVirtualDirectory -Site $location.Site -Name $location.Name -PhysicalPath $location.Path 
                }
                else{
                    mkdir $location.Path
                    New-WebVirtualDirectory -Site $location.Site -Name $location.Name -PhysicalPath $location.Path
                }
                # habilitar webDAV
                Set-WebConfigurationProperty -Filter '/system.webServer/webdav/authoring' -Location $location.Site -Name enabled -Value True
                foreach($folder in $location["Site"].Folders){
                    #deshabilitar autenticacion anonima
                    $f=$location.Site+"/"+$folder
                    Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/anonymousAuthentication' -Location $f -Name enabled -Value False
                    #habilitar autenticacion basica
                    Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/basicAuthentication' -Location $f -Name enabled -Value True
                    #otorgar persmisos a grupo
                    Add-WebConfiguration -Filter "/system.webServer/webdav/authoringRules" -Location $f -Value @{path="*";roles=$group.Name;access=$location.Permiso}
                    #habilitar Directory Browse
                    Set-WebConfigurationProperty -Filter '/system.webServer/directoryBrowse' -Location $f -Name enabled -Value True
                }
            }
        }
    } -args $service.Config,$domain
}