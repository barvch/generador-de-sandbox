Import-Module WebAdministration

function ConfigurarIIS {
    #Realiza la creación de sitios con sus respectivos bindings
    foreach($sitio in $maquina.Servicios.IIS){
        $nombre = $sitio.Nombre
        $directorio = "C:\inetpub\$($sitio.Directorio)"
        New-Item -ItemType "Directory" $directorio | Out-Null
        Write-Host "Directorio $directorio creado."
        $contador = 0
        $path = "C:\Windows\System32\drivers\etc\hosts"
        foreach($binding in $sitio.Bindings){
            $dominio = $binding.Dominio
            $ip = $binding.Interfaz
            $protocolo = $binding.Protocolo
            $puerto = $binding.Puerto
            $webDAV = $binding.WebDAV
            $usuario = $maquina.Credenciales.Usuario
            
            $bindingInfo = "$($ip):$($puerto):$($dominio)"
            if($protocolo -eq "https"){
                if($contador -eq 0){
                    New-Item "IIS:\AppPools\$nombre" | Out-Null
                    New-Item "IIS:\Sites\$nombre" -physicalPath $directorio -bindings @{protocol=$protocolo;bindingInformation="$($ip):$($puerto):$dominio"} | Out-Null
                    $newCert = New-SelfSignedCertificate -DnsName $dominio -CertStoreLocation cert:\LocalMachine\My
                    Set-ItemProperty "IIS:\Sites\$nombre" -name applicationPool -value $nombre
                    (Get-WebBinding -Name $nombre -Protocol "https").AddSslCertificate($newCert.GetCertHashString(), "my")
                    Write-Host "Binding SSL creado."
                }else{
                    New-IISSiteBinding -Name $nombre -BindingInformation $bindingInfo -Protocol $protocolo | Out-Null
                    Write-Host "Binding normal creado."
                }
            }else{
                if($contador -eq 0){
                    New-Item "IIS:\AppPools\$nombre" | Out-Null
                    New-Item "IIS:\Sites\$nombre" -physicalPath $directorio -bindings @{protocol=$protocolo;bindingInformation="$($ip):$($puerto):$dominio"} | Out-Null
                    Set-ItemProperty "IIS:\Sites\$nombre" -name applicationPool -value $nombre                
                }else{
                    New-IISSiteBinding -Name $nombre -BindingInformation $bindingInfo -Protocol $protocolo | Out-Null
                }
            }
            Set-Content "$($directorio)\Default.htm" '<h1>Hello IIS</h1>'
            if($webDAV){
                New-LocalGroup -Name "DavGroup" | Out-Null
                Add-LocalGroupMember -Group "DavGroup" -Member $usuario
                $webDav = "$($directorio)\WebDAV\"
                New-Item -ItemType "Directory" $webDAV | Out-Null
                New-WebVirtualDirectory -Site $nombre -Name "WebDAV" -PhysicalPath $webDAV | Out-Null
                Set-WebConfigurationProperty -Filter '/system.webServer/webdav/authoring' -Location $nombre -Name enabled -Value True 
                Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/anonymousAuthentication' -Location $webDAV -Name enabled -Value False 
                Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/basicAuthentication' -Location $webDAV -Name enabled -Value True 
                Add-WebConfiguration -Filter "/system.webServer/webdav/authoringRules" -Location $nombre -Value @{path="*";roles="DavGroup";access="Read,Write,Source"} 
                icacls $webDAV /grant "DavGroup:(OI)(CI)(F)" | Out-Null
                Set-WebConfigurationProperty -Filter '/system.webServer/directoryBrowse' -Location $directorio -Name enabled -Value True 
                Restart-WebItem -PSPath "IIS:\Sites\$nombre"
            }
            $contador++
        }
        Restart-Service "W3SVC" | Out-Null
    }
}
function ConfigurarDNS {
    foreach($zona in $maquina.Servicios.DNS){
        if($zona.Backup){
            $nombreArchivo = ($zona.Backup).Split("\")[-1]
            Copy-Item "C:\sources\`$OEM`$\`$1\$nombreArchivo" "C:\Windows\System32\dns"
            $file = $nombreArchivo
        }
        if($zona.Tipo -eq "Forward"){
            $nombre = $zona.Nombre
            if(-not $zona.Backup){$file = "$($nombre).dns"}
            Add-DnsServerPrimaryZone -Name $nombre -ZoneFile $file
            foreach($record in $zona.Registros){
                switch ($record.Tipo) {
                    A { Add-DnsServerResourceRecordA -Name $record.Hostname -ZoneName $nombre -AllowUpdateAny -IPv4Address $record.IP; break}
                    CNAME { Add-DnsServerResourceRecordCName -Name $record.Alias -HostNameAlias $record.FQDN -ZoneName $nombre; break }
                    MX { Add-DnsServerResourceRecordMX -Name $record.ChildDomain -MailExchange $record.FQDN -ZoneName $nombre; break }
                }
            }
        }else{
            $netID = $zona.NetID
            if(-not $zona.Backup){$file = "$($netID.Split('/')[0]).in-addr.arpa.dns"}
            Add-DnsServerPrimaryZone -NetworkID $netID -ZoneFile $file
            $netNombre = "$($netID.Split('/')[0].Replace('.0', '')).in-addr.arpa"
            foreach($record in $zona.Registros){
                switch ($record.Tipo) {
                    PTR { Add-DnsServerResourceRecordPtr -Name $record.Host -ZoneName $netNombre -AllowUpdateAny -PtrDomainName $record.Hostname; break}
                    CNAME { Add-DnsServerResourceRecordCName -Name $record.Alias -HostNameAlias $record.FQDN -ZoneName $netNombre; break }
                }
            }
        }
    }
}
function ConfigurarDHCP {
    foreach($scope in $maquina.Servicios.DHCP){
        $mascaraRed = $scope.Rango.MascaraRed
        $rangoInicio = $scope.Rango.Inicio
        Add-DhcpServerv4Scope -name $scope.Nombre -StartRange $rangoInicio -EndRange $scope.Rango.Fin -SubnetMask $mascaraRed -LeaseDuration "$($scope.Lease):00" -State Active -ComputerName $maquina.Hostname
        if($scope.Exclusiones){
            $ipSplit = $rangoInicio.Split(".")
            switch -regex ($mascaraRed) {
                ("255.255.255.0") { $rango = 0,1,2; $padding = ".0" ; break}
                ("255.255.0.0") { $rango = 0,1 ; $padding = ".0.0"; break}
                ("255.0.0.0") { $rango = 0 ; $padding = ".0.0.0"; break}
            }
            $netID = "$($ipSplit[$rango] -join ".")$padding"
            if($scope.Exclusiones.Tipo -eq "Unica"){
                $inicio = $fin = $scope.Exclusiones.IP
            }else{
                $inicio = $scope.Exclusiones.Inicio
                $fin = $scope.Exclusiones.Fin
            }
                Add-DhcpServerv4ExclusionRange -ScopeID $netID -StartRange $inicio -EndRange $fin
        }
        if($scope.DNS){
            Set-DhcpServerv4OptionValue -ScopeID $netID -DnsServer $scope.DNS
        }
        if($scope.Gateway){
            Set-DhcpServerv4OptionValue -ScopeID $netID -Router $scope.Gateway
        }
    }
}
function ConfigurarAD {
    $activeDirectory = $maquina.Servicios.ActiveDirectory
    Install-ADDSForest -DomainName $activeDirectory.Dominio -DomainNetbiosName $activeDirectory.Netbios -DomainMode $activeDirectory.DomainMode -ForestMode $activeDirectory.ForestMode -Force -SafeModeAdministratorPassword (ConvertTo-SecureString -String $maquina.Credenciales.Contrasena -AsPlainText -Force)
}

# Se ejecuta el contenido de la tarea programada
Write-Host "Esperando a que los servicios se encuentren disponibles..." -ForegroundColor Yellow
Start-Sleep 60
Write-Host "Leyendo archivo temp.json..." -ForegroundColor Yellow
$maquina = Get-Content -Raw -Path "C:\sources\`$OEM`$\`$1\tmp.json" | ConvertFrom-Json
Write-Host "Configurando servicios del equipo..." -ForegroundColor Yellow
if($maquina.Servicios.DNS){ Write-Host "Configurando DNS..." -ForegroundColor Yellow; ConfigurarDNS }
if($maquina.Servicios.DHCP){ Write-Host "Configurando DHCP..." -ForegroundColor Yellow; ConfigurarDHCP }
if($maquina.Servicios.ActiveDirectory){ Write-Host "Configurando AD... -ForegroundColor Yellow";ConfigurarAD }
if($maquina.Servicios.IIS){ Write-Host "Configurando IIS..." -ForegroundColor Yellow; ConfigurarIIS }
# Se elimina el contenido de los archivos y la tarea programada
Unregister-ScheduledTask -TaskName "ConfigurarServicios" -Confirm:$false