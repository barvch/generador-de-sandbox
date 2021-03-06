#Funcion instala RDP
function ConfigurarServicios { param ($maquina)
    $usuario = $maquina.Credenciales.Usuario
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
}
$maquina = Get-Content -Raw -Path "C:\Windows\Temp\tmp.json" | ConvertFrom-Json
ConfigurarServicios -maquina $maquina