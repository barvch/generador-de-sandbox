function InstalarIIS {
    #Realiza la creación de sitios con sus respectivos bindings
    foreach($sitio in $maquina.Servicios.IIS){
        Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "$ip $dominio"
        $nombre = $sitio.Nombre
        $directorio = "C:\inetpub\$($sitio.directorio)"
        New-Item -ItemType "Directory" $directorio | Out-Null
        $contador = 0
        foreach($binding in $sitio.Bindings){
            $dominio = $binding.Dominio
            $ip = $binding.Interfaz
            $protocolo = $binding.Protocolo
            $puerto = $binding.$puerto
            $webDAV = $binding.WebDAV
            $bindingInfo = "$($ip):$($puerto):$($dominio)"
            if($protocolo -eq "https"){
                $rutaCert = $binding.RutaCertificado
                if($contador -eq 0){
                    New-Item "IIS:\AppPools\$nombre" | Out-Null
                    New-Item "IIS:\Sites\$nombre" -physicalPath $directorio -bindings @{protocol=$protocol;bindingInformation="$($ip):$($puerto):$dominio";sslcertificate=$rutaCert} | Out-Null
                    $newCert = New-SelfSignedCertificate -DnsName $dominio -CertStoreLocation cert:\LocalMachine\My
                    Set-ItemProperty "IIS:\Sites\$nombre" -name applicationPool -value $nombre
                    (Get-WebBinding -Name $nombre -Protocol "https").AddSslCertificate($newCert.GetCertHashString(), "my")
                }
                New-IISSiteBinding -Name $dominio -BindingInformation $bindingInfo -Protocol $protocolo
            }else{
                if($contador -eq 0){
                    New-Item "IIS:\AppPools\$nombre" | Out-Null
                    New-Item "IIS:\Sites\$nombre" -physicalPath $directorio -bindings @{protocol=$protocol;bindingInformation="$($ip):$($puerto):$dominio"} | Out-Null
                    Set-ItemProperty "IIS:\Sites\$nombre" -name applicationPool -value $nombre                
                }
                New-IISSiteBinding -Name $dominio -BindingInformation $bindingInfo -Protocol $protocolo
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
function InstalarDHCP {
    foreach($scope in $maquina.Servicios.DHCP){
        $mascaraRed = $scope.Rango.MascaraRed
        $rangoInicio = $scope.Rango.Inicio
        Add-DhcpServerv4Scope -name $scope.Nombre -StartRange $rangoInicio -EndRange $scope.Rango.Fin -SubnetMask $mascaraRed -LeaseDuration "$($scope.Lease):00" -State Active
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

$maquina = Get-Content -Raw -Path "C:\sources\`$OEM`$\`$1\tmp.json" | ConvertFrom-Json
$usuario = $maquina.Credenciales.Usuario
if($maquina.Servicios.IIS){ InstalarIIS }
if($maquina.Servicios.DHCP){ InstalarDHCP }
Unregister-ScheduledTask -TaskName "ConfigurarServicios"
#Remove-Item -Path "C:\sources\`$OEM`$" | Out-Null