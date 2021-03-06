#Se importan los catalogos
. ".\Recursos\Validaciones\catalogos.ps1"

function ValidarAdministracionRemota { param ($servicio = "AdministracionRemota", $adminRemota, $so)
$adminRemotaCheck = ValidarCatalogos -catalogo $tiposAdminRemota -campo $servicio -valor $adminRemota
    if(-not $adminRemotaCheck){
        if($so.Contains("Windows")){
            $adminRemotaCheck = "RDP"
        }else{
            $adminRemotaCheck = "SSH"
        }
    }else{
        if(($so.Contains("Windows") -and $adminRemotaCheck -ne "RDP") -or (-not ($so.Contains("Windows")) -and $adminRemotaCheck -ne "SSH")){
            Write-Host "No se puede configurar el servicio $adminRemota en el campo $servicio debido a que se ingreso el sistema operativo $so"
            exit
        }
    }
    return $adminRemotaCheck
}

function ValidarActiveDirectory { param ($servicio = "ActiveDirectory", $activeDirectory)
    if($activeDirectory){
        $dominioCheck = ValidarCadenas -campo "$servicio.Domain" -valor $activeDirectory.Domain -validacionCaracter "dominio" -obligatorio $true
        $NetBIOSCheck = ValidarCadenas -campo "$servicio.NetBIOS" -valor $activeDirectory.NetBIOS -validacionCaracter "alfaNum1" -validacionLongitud "longitud6"
        if(-not $NetBIOSCheck){
            $NetBIOSCheck = ValidarCadenas -campo "$servicio.NetBIOS" -valor  $dominioCheck.Split(".")[0].ToUpper() -validacionCaracter "alfaNum1" -validacionLongitud "longitud6"
        }
        $domainModeCheck = ValidarCatalogos -catalogo $forestModes.keys -campo "$servicio.DomainMode" -valor $activeDirectory.DomainMode -obligatorio $true
        $forestModeCheck = ValidarCatalogos -catalogo $forestModes.keys -campo "$servicio.ForestMode" -valor $activeDirectory.ForestMode
        if(-not $forestModeCheck){
            $forestModeCheck = $domainModeCheck
        }
        if($forestModes[$domainModeCheck] -lt $forestModes[$forestModeCheck]){
            Write-Host "El nivel funcional del campo DomainMode no puede menor al nivel funcional del campo ForestMode"
            exit
        }
        $activeDirectoryCheck = [Ordered] @{"Dominio" = $dominioCheck; "NetBIOS" = $NetBIOSCheck; "DomainMode" = $domainModeCheck; "ForestMode" = $forestModeCheck}
        return $activeDirectoryCheck 
    }else{
        return ""
    }
}

function ValidarCertServices { param ( $campo = "CertificateServices", $certServices )
    return ValidarArregloDato -campo $campo -valor $certServices -tipoDato "Boolean"   
}
function ValidarWindowsDefender { param ( $campo = "WindowsDefender", $windefender )
    return ValidarArregloDato -campo $campo -valor $windefender -tipoDato "Boolean"   
}
function ValidarIIS { param ($campo = "IIS.Sitios", $iis, $interfaces)
    if($iis){
        $sitiosCheck = $directorios = $nombres = @()
        foreach($sitio in $iis){
            $sitioCheck = @()
            $sitioNombreCheck = ValidarCadenas -campo "$campo.Nombre" -valor $sitio.Nombre -validacionCaracter "alfaNum4" -validacionLongitud "longitud6" -obligatorio $true
            $sitioDirectorioCheck = ValidarCadenas -campo "$campo.Directorio" -valor $sitio.Directorio -validacionCaracter "alfaNum4" -validacionLongitud "longitud6"    
            if(-not $sitioDirectorioCheck){
                $sitioDirectorioCheck = $sitioNombreCheck
            }
            $bindings = $dominiosBindings = @()
            foreach($binding in $sitio.Bindings){
                $bindingObject = @{}
                $bindingDominioCheck = ValidarCadenas -campo "$campo.Bindings.Dominio" -valor $binding.Dominio -validacionCaracter "dominio" -obligatorio $true
                $bindingInterfazCheck = ValidarCadenas -campo "$campo.Bindings.Interfaz" -valor $binding.Interfaz -validacionCaracter "alfaNum2" -validacionLongitud "longitud1" -obligatorio $true
                foreach($interfaz in $interfaces){
                    if($bindingInterfazCheck -eq $interfaz.Nombre){
                        $ipBindingCheck = $interfaz.IP
                    }
                }
                if(-not $ipBindingCheck){
                    Write-Host "El campo $campo.Bindings.Interfaz no coincide con alguna interfaz ingresada"
                    exit
                }
                $bindingProtocoloCheck = ValidarCatalogos -catalogo $protocolos -campo "$campo.Bindings.Protocolo" -valor $binding.Protocolo -obligatorio $true
                if($bindingProtocoloCheck -eq "https"){
                    $bindingCertCheck = ValidarRuta -campo "$campo.Bindings.RutaCertificado" -valor $binding.RutaCertificado -obligatorio $true
                    #Get-PfxCertificate -FilePath "E:\Proyecto Final\Windows Server 2019\certificado.pfx" -NoPromptForPassword
                }
                $bindingPuertoCheck = ValidarArregloDato -campo "$campo.Bindings.Puerto" -valor $binding.Puerto -tipoDato "Int32"
                if($bindingPuertoCheck){
                    if(($bindingProtocoloCheck -eq "http" -and $bindingPuertoCheck -eq 443) -or ($bindingProtocoloCheck -eq "https" -and $bindingPuertoCheck -eq 80)){
                        Write-Host "El puerto $bindingPuertoCheck no puede utilizarse para el protocolo $bindingProtocoloCheck"
                        exit
                    }else{
                        if($bindingPuertoCheck -ne 443){
                            if($bindingPuertoCheck -ne 80){
                                $bindingPuertoCheck = ValidarPuerto -campo "$campo.Bindings.Puerto" -puerto $bindingPuertoCheck -puertosBienConocidos $puertosBienConocidos
                            }
                        }
                    }
                }else{
                    if($bindingProtocoloCheck -eq "http"){
                        $bindingPuertoCheck = 80
                    }else{
                        $bindingPuertoCheck = 443
                    }
                }
                $WebDAVCheck = ValidarArregloDato -campo "$campo.Bindings.WebDAV" -valor $binding.WebDAV -tipoDato "Boolean" 
                $dominiosBindings += $bindingDominioCheck
                ValidarNombreUnico -campo "$campo.Bindings.Dominio" -arreglo $dominiosBindings
                $bindingObject = [ordered] @{"Dominio" = $bindingDominioCheck; "Interfaz" = $ipBindingCheck; "Protocolo" = $bindingProtocoloCheck; "Puerto" = $bindingPuertoCheck; "RutaCertificado" = $bindingCertCheck; "WebDAV" = $WebDAVCheck}
                $bindings += $bindingObject
            }
            $nombres += $sitioNombreCheck
            $directorios += $sitioDirectorioCheck
            $sitioCheck = [ordered] @{"Nombre" = $sitioNombreCheck; "Directorio" = $sitioDirectorioCheck; "Bindings" = $bindings}
            $sitiosCheck += $sitioCheck
        }
        ValidarNombreUnico -campo "$campo.Nombre" -arreglo $nombres
        ValidarNombreUnico -campo "$campo.Directorio" -arreglo $directorios
        return $sitiosCheck
    }else{
        return ""
    }
}

function ValidarDHCP { param ($campo = "DHCP.Scopes", $dhcp)
    if($dhcp){
        $dhcpCheck = $rangoUnico = $nombres = @()
        foreach($scope in $dhcp){
            $nombreCheck = ValidarCadenas -campo "$campo.Nombre" -valor $scope.Nombre -validacionCaracter "alfaNum1" -validacionLongitud "longitud1" -obligatorio $true
            $ipInicioCheck = ValidarCadenas -campo "$campo.Rango.Inicio" -valor $scope.Rango.Inicio -validacionCaracter "ip" -obligatorio $true
            $ipFinCheck= ValidarCadenas -campo "$campo.Rango.Fin" -valor $scope.Rango.Fin -validacionCaracter "ip" -obligatorio $true
            $mascaraCheck = ValidarCatalogos -catalogo $mascaras -campo "$campo.Rango.MascaraRed" -valor $scope.Rango.MascaraRed -obligatorio $true
            $rangoInicio, $rangoFin = ValidarRango -ipInicio $ipInicioCheck -ipFin $ipFinCheck -mascara $mascaraCheck -campo "$campo.Rango"
            $exclusiones = $scope.Exclusiones
            if($exclusiones){
                $tipoExclusion = ValidarCatalogos -catalogo $tiposExclusiones -campo "$campo.$($nombreCheck).Exclusiones.Tipo" -valor $exclusiones.Tipo -obligatorio $true
                if($tipoExclusion -eq "Unica"){
                    $ipExCheck = ValidarCadenas -campo "$campo.$($nombreCheck).Exclusiones.IP" -valor $exclusiones.IP -validacionCaracter "ip" -obligatorio $true
                    $ip = [Double](-join $ipExCheck.Split("."))
                    if(($ip -le $rangoInicio) -or ($ip -ge $rangoFin)){
                        Write-Host "El valor ingresado en $campo.$($nombreCheck).Exclusiones debe encontrarse en el rango $ipInicioCheck - $ipFinCheck"
                        exit
                    }
                }else{
                    $ipInicioExCheck = ValidarCadenas -campo "$campo.$($nombreCheck).Exclusiones.Inicio" -valor $exclusiones.Inicio -validacionCaracter "ip" -obligatorio $true
                    $ipFinExCheck = ValidarCadenas -campo "$campo.$($nombreCheck).Exclusiones.Fin" -valor $exclusiones.Fin -validacionCaracter "ip" -obligatorio $true
                    $ipInicioEx = [Int](-join $ipInicioExCheck.Split("."))
                    $ipFinEx = [Int](-join $ipFinExCheck.Split("."))
                    if(($ipInicioEx -le $rangoInicio) -or ($ipFinEx -ge $rangoFin)){
                        Write-Host "El valor ingresado en $campo.$($nombreCheck).Exclusiones debe encontrarse en el rango $ipInicioCheck - $ipFinCheck"
                        exit
                    }
                    if($ipInicioEx -ge $ipFinEx){
                        Write-Host "El rango ingresado en la seccion $campo.$($nombreCheck).Exclusiones no es valido $ipInicioExCheck - $ipFinExCheck"
                        exit
                    }
                }
            }
            ValidarTiempo -campo "$campo.$($nombreCheck).Lease" -tiempo $scope.Lease -obligatorio $true | Out-Null
            ValidarCadenas -campo "$campo.$($nombreCheck).Gateway" -valor $scope.Gateway -validacionCaracter "ip" | Out-Null
            ValidarCadenas -campo "$campo.$($nombreCheck).DNS" -valor $scope.DNS -validacionCaracter "ip" | Out-Null
            $nombres += $nombreCheck
            $rangoUnico += (ValidarRango -ipInicio $ipInicioCheck -mascara $mascaraCheck -campo "$campo.Rango" -unico $true) 
            $scopeCheck = ([ordered] @{})
            $scope.psobject.properties | Foreach-Object { $scopeCheck[$_.Name] = $_.Value }
            $rangoCheck = [ordered] @{}
            $scope.Rango.psobject.properties | Foreach-Object { $rangoCheck[$_.Name] = $_.Value }
            $scopeCheck["Rango"] = $rangoCheck
            $exclusionesCheck = [ordered] @{}
            $scope.Exclusiones.psobject.properties | Foreach-Object { $exclusionesCheck[$_.Name] = $_.Value }
            $scopeCheck["Exclusiones"] = $exclusionesCheck
            $dhcpCheck += $scopeCheck
        }
        ValidarNombreUnico -campo "$campo.Nombre" -arreglo $nombres
        ValidarNombreUnico -campo "$campo.Rango" -arreglo $rangoUnico -imprimeIP $true
        return $dhcpCheck
    }else{
        return ""
    }
}

function ValidarDNS { param ($campo = "DNS.Zonas", $dns)
    if($dns){
        $registros = $nombres = $backups = @()
        foreach($zona in $dns){
            $tipoZonaCheck = ValidarCatalogos -catalogo $tiposZonas -campo "$campo.Zonas.Tipo" -valor $zona.Tipo -obligatorio $true
            if(-not $zona.Backup){
                if($tipoZonaCheck -eq "Forward"){
                    $nombreZonaCheck = ValidarCadenas -campo "$campo.Nombre" -valor $zona.Nombre -validacionCaracter "alfaNum1" -validacionLongitud "longitud1" -obligatorio $true
                }else{
                    ValidarCadenas -campo "$campo.NetID" -valor $zona.NetID -validacionCaracter "netID" -obligatorio $true
                }
            }else{
                $backupZonaCheck =  ValidarRuta -campo "$campo.Backup" -valor $zona.Backup
            }
            foreach($registro in $dns.Registros){
                if($tipoZonaCheck -eq "Forward"){
                    $tipoRegistroCheck = ValidarCatalogos -catalogo $forwardRecords -campo "$campo.Forward.Registros.Tipo" -valor $registro.Tipo -obligatorio $true
                    if($tipoRegistroCheck -eq "A"){
                        ValidarCadenas -campo "$campo.Forward.Registros.A.Hostname" -valor $registro.Hostname -validacionCaracter "dominio" -obligatorio $true
                        ValidarCadenas -campo "$campo.Forward.Registros.A.IP" -valor $registro.IP -validacionCaracter "ip" -obligatorio $true
                        ValidarArregloDato -campo "$campo.Forward.Registros.A.PTR" -valor $registro.PTR -tipoDato "Boolean"
                    }elseif($tipoRegistroCheck -eq "MX"){
                        ValidarCadenas -campo "$campo.Forward.Registros.MX.ChildDomain" -valor $registro.ChildDomain -validacionCaracter "dominio" -obligatorio $true
                        ValidarCadenas -campo "$campo.Forward.Registros.MX.FQDN" -valor $registro.FQDN -validacionCaracter "dominio" -obligatorio $true
                    }
                }else{
                    $tipoRegistroCheck = ValidarCatalogos -catalogo $reverseRecords -campo "$campo.Reverse.Registros.Tipo" -valor $registro.Tipo -obligatorio $true
                    if($tipoRegistroCheck -eq "PTR"){
                        ValidarCadenas -campo "$campo.Reverse.Registros.PTR.IP" -valor $registro.IP -validacionCaracter "ip" -obligatorio $true
                        ValidarCadenas -campo "$campo.Reverse.Registros.PTR.Hostname" -valor $registro.Hostname -validacionCaracter "dominio" -obligatorio $true
                    }
                }
                if($tipoRegistroCheck -eq"CNAME"){
                    ValidarCadenas -campo "$campo.Registros.CNAME.Alias" -valor $registro.Alias -validacionCaracter "alfaNum1" -validacionLongitud "longitud1" -obligatorio $true
                    ValidarCadenas -campo "$campo.Registros.CNAME.FQDN" -valor $registro.FQDN -validacionCaracter "dominio" -obligatorio $true
                }
                $registroCheck = [ordered] @{}
                $registro.psobject.properties | Foreach-Object { $registroCheck[$_.Name] = $_.Value }
                $registros += $registroCheck
            }
            $nombres += $nombreZonaCheck
            $backups += $backupZonaCheck
            $zonaCheck = [ordered] @{}
            $zona.psobject.properties | Foreach-Object { $zonaCheck[$_.Name] = $_.Value }
            $zonaCheck["Registros"] = $registros
        }
        ValidarNombreUnico -campo "$campo.Nombre" -arreglo $nombres
        ValidarNombreUnico -campo "$campo.Backup" -arreglo $backups
        return $zonaCheck
    }else{
        return ""
    }
}