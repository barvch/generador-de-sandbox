#Se importan los catalogos
. ".\Recursos\Validaciones\catalogos.ps1"

function ValidarServidorWeb { param ($servicio = "ServidorWeb", $servidorWeb, $interfaces)
    if($servidorWeb){
        $servidorCheck = ValidarCatalogos -catalogo $servidoresWeb -campo "$servicio.Servidor" -valor $servidorWeb.Servidor -obligatorio $true
        $sitiosCheck = $nombres = $dominios = @()
        foreach($sitio in $servidorWeb.Sitios){
            #$sitioNombreCheck = ValidarCadenas -campo "$servicio.Nombre" -valor $sitio.Nombre -validacionCaracter "alfaNum4" -validacionLongitud "longitud5" -obligatorio $true
            $sitioDominioCheck = ValidarCadenas -campo "$servicio.$sitioNombreCheck.Dominio" -valor $sitio.Dominio -validacionCaracter "dominio" -obligatorio $true
            $interfazNombre = ValidarCadenas -campo "$servicio.$sitioNombreCheck.Interfaz" -valor $sitio.Interfaz -validacionCaracter "alfaNum2" -validacionLongitud "longitud1" -obligatorio $true
            $ipCheck, $mascaraCheck = ValidarInterfaz -interfaces $interfaces -nombre $interfazNombre -campo "$servicio.$sitioNombreCheck.Interfaz"
            $puertoCheck = ValidarArregloDato -campo "$servicio.$sitioNombreCheck.Puerto" -valor $sitio.Puerto -tipoDato "Int32"
            $protocoloCheck = ValidarCatalogos -catalogo $protocolos -campo "$servicio.$sitioNombreCheck.Protocolo" -valor $sitio.Protocolo -obligatorio $true
            $puertoCheck = ObtenerPuertoDefault -puerto $puertoCheck -protocolo $protocoloCheck -campo "$servicio.$sitioNombreCheck.Puerto"
            $drupalCheck = ValidarArregloDato -campo "$servicio.$sitioNombreCheck.Drupal" -valor $sitio.Drupal -tipoDato "Boolean"
            $sitioCheck = [ordered] @{"Nombre" = $sitioNombreCheck; "Dominio" = $sitioDominioCheck; "Interfaz" = $ipCheck; "Puerto" = $puertoCheck; "Protocolo" = $protocoloCheck; "Drupal" = $drupalCheck}
            $nombres += $sitioNombreCheck
            $dominios += $sitioDominioCheck
            $sitiosCheck += $sitioCheck 
        }
        ValidarNombreUnico -campo "$servicio.Nombre" -arreglo $nombres
        ValidarNombreUnico -campo "$servicio.Nombre" -arreglo $dominios
        $servidorWebCheck = [ordered] @{"Servidor" = $servidorCheck; "Sitios" = $sitiosCheck}
        return $servidorWebCheck
    }
}
function ValidarManejadorBD { param ($servicio = "ManejadorBD", $manejadorbd, $so)
    if($manejadorbd){
        $manejadorCheck = ValidarCatalogos -catalogo $manejadoresbd -campo "$servicio.Manejador" -valor $manejadorbd.Manejador -obligatorio $true
        if(-not ($so.Contains("Ubuntu") -and $manejadorCheck -eq "SQLServer")){
            $nombreCheck = ValidarCadenas -campo "$servicio.NombreBD" -valor $manejadorbd.NombreBD.ToLower() -validacionCaracter "alfaNum4" -validacionLongitud "longitud5" -obligatorio $true
            $script = ValidarRuta -campo "$servicio.Script" -valor $manejadorbd.Script
        }
        if(-not $so.Contains("Ubuntu") -and $manejadorCheck -eq "SQLServer"){
            Write-Host "El manejador SQLServer solo se permite para sistemas Ubuntu x.04"
            exit
        }
        $manejadorbdCheck = [ordered] @{"Manejador" = $manejadorCheck; "NombreBD" = $nombreCheck; "Script" = $script}
        return $manejadorbdCheck
    }
}
function ValidarISCDHCP { param ($servicio = "DHCP", $dhcp, $interfaces)
    if($dhcp){
        $interfazNombre = ValidarCadenas -campo "$servicio.Interfaz" -valor $dhcp.Interfaz -validacionCaracter "alfaNum2" -validacionLongitud "longitud1" -obligatorio $true
        $ipCheck, $mascaraRedCheck = ValidarInterfaz -interfaces $interfaces -nombre $interfazNombre -campo "$servicio.Interfaz"
        $rangoUnico = $rangosCheck = $scopesCheck = @()
        foreach($scope in $dhcp.Scopes){
            $scopeMask = ObtenerMascaraRed -mascaras $mascaras -campo "$servicio.MascaraRed" -valor $scope.MascaraRed
            foreach($rango in $scope.Rangos){
                $ipInicioCheck = ValidarCadenas -campo "$servicio.Scope.Rango.Inicio" -valor $rango.Inicio -validacionCaracter "ip" -obligatorio $true
                $ipFinCheck= ValidarCadenas -campo "$servicio.Scope.Rango.Fin" -valor $rango.Fin -validacionCaracter "ip" -obligatorio $true
                $rangoUnico += (ValidarRango -ipInicio $ipInicioCheck -ipFin $ipFinCheck -mascara $scopeMask -campo "$servicio.Scope.Rango") 
                $rangoCheck = [ordered] @{"Inicio" = $ipInicioCheck; "Fin" = $ipFinCheck}
                $rangosCheck += $rangoCheck
            }
            ValidarNombreUnico -campo "$servicio.Scope.Rango" -arreglo $rangoUnico -imprimeIP $true
            $scopeDNS = ValidarCadenas -campo "$servicio.Scope.DNS" -valor $scope.DNS -validacionCaracter "ip" 
            $scopeGateway = ValidarCadenas -campo "$servicio.Scope.Gateway" -valor $scope.Gateway -validacionCaracter "ip"            
            $scopeCheck = [ordered] @{"Rangos" = $rangosCheck; "MascaraRed" = $scopeMask; "DNS" = $scopeDNS; "Gateway" = $scopeGateway}
            $scopesCheck += $scopeCheck
        }
        $dhcpCheck = [ordered] @{"Interfaz" = $ipCheck; "MascaraRed" = $mascaraRedCheck; "Scopes" = $scopesCheck}
        return $dhcpCheck
    }
}

function ValidarBindDNS { param ($servicio = "DNS", $dns, $interfaces)
    if($dns){
        $interfazNombre = ValidarCadenas -campo "$servicio.Interfaz" -valor $dns.Interfaz -validacionCaracter "alfaNum2" -validacionLongitud "longitud1" -obligatorio $true
        $ipCheck, $mascaraCheck = ValidarInterfaz -interfaces $interfaces -nombre $interfazNombre -campo "$servicio.Interfaz"
        $zonas = ValidarDNS -campo $servicio -dns $dns.Zonas
        $dnsCheck = [ordered] @{"Interfaz" = $ipCheck; "Zonas" = $zonas}
        return $dnsCheck
    }
}