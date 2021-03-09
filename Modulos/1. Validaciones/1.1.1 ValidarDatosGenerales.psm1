#Se importan los catalogos
. ".\Recursos\Validaciones\catalogos.ps1"

function ValidarSistemaOperativo { param ($campo = "SistemaOperativo", $sistemaOperativo)
    return ValidarCatalogos -catalogo $SOPermitidos.keys -campo $campo -valor $sistemaOperativo -obligatorio $true
}

function ValidarHostname { param ($campo = "Hostname", $hostname, $so)
    if($so.Contains("Windows")){
        return ValidarCadenas -campo $campo -valor $hostname -validacionCaracter "alfaNum5" -validacionLongitud "longitud1" -obligatorio $true
    }else{
        return ValidarCadenas -campo $campo -valor $hostname -validacionCaracter "alfaNum1" -validacionLongitud "longitud1" -obligatorio $true
    }
}

function ValidarDiscosVirtuales { param ($campo = "DiscosVirtuales", $discosVirtuales , $rutaRaiz)
    $discosVirtualesCheck = ValidarArregloDato -campo $campo -valor $discosVirtuales -obligatorio $true -arreglo $true -tipoDato "Int32"
    $letterRoot = (-join $rutaRaiz[0,1])
    $espacioDisponible = (Get-WmiObject -Class Win32_logicaldisk -Filter "DeviceID = '$letterRoot'" | Select-Object -ExpandProperty  FreeSpace @{L='FreeSpace';E={"{0:0}" -f ($_.FreeSpace /1GB)}}) / 1GB
    $espacioDisponible = [math]::Round($espacioDisponible,2)
    foreach($disco in $discosVirtualesCheck){
        if($disco -ge 15){
            if (($espacioDisponible - $disco) -le 0) {
                Write-Host "No se cuenta con el suficiente espacio para crear el disco de $disco GB"
                exit
            }else{
                $espacioDisponible -= $disco 
                #$tamanoOcupado += $disco
            }
        }else{
            Write-Host "Cada disco del campo $campo de tener un tamano minimo de 15 GB"
            exit
        }
    }
    return $discosVirtualesCheck
    #[math]::Round($espacioDisponible - $tamanoOcupado,2)
}

function ValidarProcesadores { param ($campo = "Procesadores", $procesadores )
    $procesadoresCheck = ValidarArregloDato -campo $campo -valor $procesadores -obligatorio $true -tipoDato "Int32"
    $totalProcesadores = (Get-WmiObject win32_processor).NumberOfLogicalProcessors
    if($procesadoresCheck -le 0){
        Write-Host "Se debe ingresar al menos 1 procesador"
        exit
    }
    if($procesadoresCheck -gt $totalProcesadores){
        Write-Host "El campo $campo solo permite hasta un maximo de $totalProcesadores procesadores"
        exit
    }
    return $procesadoresCheck
}

function ValidarRutaISO { param ($campo = "RutaISO", $rutaISO, $so)
    $isoCheck = ValidarArregloDato -campo $campo -valor $rutaISO -obligatorio $true -tipoDato "String"
    $isoCheck = ValidarRuta -campo $campo -valor $rutaISO -obligatorio $true
    #$hash = (Get-FileHash -Algorithm MD5 $isoCheck).Hash
    #if($hash -ne $SOPermitidos[$so]){
    #    Write-Host "El campo $campo debe contener un ISO valido para el Sistema Operativo $so"
    #    exit
    #}
    return $isoCheck
}

function ValidarMemoriaRAM { param ($campo = "MemoriaRAM", $memoriaRAM)
    $tiposMemoriaRAMV = ValidarCatalogos -catalogo $tiposMemoriaRAM -campo "MemoriaRAM.Tipo" -valor $memoriaRAM.Tipo -obligatorio $true
    $memoriaRAMCheck = [ordered] @{"Tipo" = $tiposMemoriaRAMV}
    if($tiposMemoriaRAMV -eq "Static"){
        $memoria = ValidarArregloDato -campo "MemoriaRAM.Memoria" -valor $memoriaRAM.Memoria -obligatorio $true -tipoDato "Decimal"
        if($memoria -lt 0.5){
            Write-Host "El campo MemoriaRAM.Memoria debe ser mayor a 0.5 GB"
            exit
        }
        $memoriaRAMCheck.Add("Memoria", $memoria)
        $memoriaSolicitada = $memoria
    }else{
        $minima = ValidarArregloDato -campo "MemoriaRAM.Minima" -valor $memoriaRAM.Minima -obligatorio $true -tipoDato "Decimal"
        $maxima = ValidarArregloDato -campo "MemoriaRAM.Maxima" -valor $memoriaRAM.Maxima -obligatorio $true -tipoDato "Decimal"
        if($minima -lt 0.5){
            Write-Host "El campo MemoriaRAM.Minima debe ser mayor a 0.5 GB"
            exit
        }
        if(-not ($minima -lt $maxima)){
            Write-Host "El campo MemoriaRAM.Minima no puede ser mayor al campo MemoriaRAM.Maxima"
            exit
        }
        $memoriaRAMCheck.Add("Minima", $minima)
        $memoriaRAMCheck.Add("Maxima", $maxima)
        $memoriaSolicitada = $maxima
    }
    $RAMDisponible = (gwmi Win32_OperatingSystem | Select FreePhysicalMemory).FreePhysicalMemory / 1MB
    $RAMDisponible = [math]::Round($RAMDisponible,2)
    if($memoriaSolicitada -gt $RAMDisponible){
        Write-Host "La memoria maxima permitida es de $RAMDisponible GB"
        exit
    }
    return $memoriaRAMCheck
   # 
    #ValidarArregloDato -campo $campo -valor $memoriaRAM.Tipo

}

function ValidarCredenciales { param ($credenciales, $os)
    if(-not($os -match "Windows.*")){
        $inicioFin = "^[a-z].*[a-z]$"
    }
        $usuarioCheck = ValidarCadenas -campo "Credenciales$($os).Usuario" -valor $credenciales.Usuario -validacionCaracter "alfaNum3" -validacionLongitud "longitud1" -obligatorio $true -inicioFin $inicioFin
        $contrasenaCheck = ValidarCadenas -campo "Credenciales$($os).Contrasena" -valor $credenciales.Contrasena -validacionCaracter "password" -validacionLongitud "longitud2" -obligatorio $true
        $credencialesCheck = [ordered] @{"Usuario" = $usuarioCheck; "Contrasena" = $contrasenaCheck}
        return $credencialesCheck
}

function ValidarInterfaces { param ($interfaces, $hostname)
    if($interfaces){
        $interfacesCheck = $ips = $nombres = @()
        foreach($interfaz in $interfaces){
            $interfazCheck = @{}
            $tipoInterfazCheck = ValidarCatalogos -campo "Interfaces.Tipo" -valor $interfaz.Tipo -obligatorio $true -catalogo $tipoInterfazConfig
            $VSNombreCheck = ValidarCadenas -campo "$interfacesNombreCheck.VirtualSwitch.Nombre" -valor $interfaz.VirtualSwitch.Nombre -validacionCaracter "alfaNum2" -validacionLongitud "longitud1"
            if(-not $VSNombreCheck){
                $VSNombreCheck = ValidarCadenas -campo "$interfacesNombreCheck.VirtualSwitch.Nombre" -valor (Read-Host -Prompt "`t> [$interfacesNombreCheck] Nombre del VirtualSwitch: ") -validacionCaracter "alfaNum2" -validacionLongitud "longitud1"
            }
            $VSTipoCheck = ValidarCatalogos -catalogo $tiposInterfaces -campo "$interfacesNombreCheck.VirtualSwitch.Tipo" -valor $interfaz.VirtualSwitch.Tipo
            if(-not $VSTipoCheck){
                $VSTipoCheck = ValidarCatalogos -catalogo $tiposInterfaces -campo "$interfacesNombreCheck.VirtualSwitch.Tipo" -valor (Read-Host -Prompt "`t> [$interfacesNombreCheck] Tipo del VirtualSwitch: ")
            }
            if($VSTipoCheck -eq "External"){
                $adaptadores = (Get-NetAdapter -Physical | Select-Object -Property Name, Status)
                $adaptadorRedCheck = ValidarCatalogos -catalogo $adaptadores.Name -campo "$interfacesNombreCheck.VirtualSwitch.AdaptadorRed" -valor $interfaz.VirtualSwitch.AdaptadorRed -obligatorio $true
                foreach($adaptador in $adaptadores){
                    if(-not($adaptadorRedCheck -eq $adaptador.Name -and $adaptador.Status -eq "Up")){
                        Write-Host "El adaptador de red igresado no se encuentra activo"
                        exit
                    }
                }
            }
            if($tipoInterfazCheck -eq "Static") {
                $ipCheck = ValidarCadenas -campo "$interfacesNombreCheck.IP" -valor $interfaz.IP -validacionCaracter "ip" -obligatorio $true
                $mascaraCheck = ValidarCatalogos -catalogo $mascaras -campo "$interfacesNombreCheck.MascaraRed" -valor $interfaz.MascaraRed -obligatorio $true
                switch ($mascaraCheck) {
                    "8"  { $mascaraCheck = "255.0.0.0"; break}
                    "16" { $mascaraCheck = "255.255.0.0"; break}
                    "24" { $mascaraCheck = "255.255.255.0"; break}
                    Default { $mascaraCheck = $mascaraCheck }
                } 
                $gatewayCheck = ValidarCadenas -campo "$interfacesNombreCheck.Gateway" -valor $interfaz.Gateway -validacionCaracter "ip"
                $dnsCheck = ValidarCadenas -campo "$interfacesNombreCheck.DNS" -valor $interfaz.DNS -validacionCaracter "ip" 
            }
            $interfacesNombreCheck = ValidarCadenas -campo "Interfaces.Nombre" -valor $interfaz.Nombre -validacionCaracter "alfaNum2" -validacionLongitud "longitud1" -obligatorio $true
            $nombres += $interfacesNombreCheck
            $interfazCheck = [ordered] @{"VirtualSwitch" = [ordered] @{"Nombre" = $VSNombreCheck; "Tipo" = $VSTipoCheck; "AdaptadorRed" = $adaptadorRedCheck}; "Tipo" = $tipoInterfazCheck;"Nombre" = $interfacesNombreCheck; "IP" = $ipCheck; "MascaraRed" = $mascaraCheck;"Gateway" = $gatewayCheck; "DNS" = $dnsCheck}
            $interfacesCheck += $interfazCheck
            $ips += (ValidarRango -ipInicio $ipCheck -mascara $mascaraCheck -campo "$interfacesNombreCheck.IP" -unico $true)
        }
        ValidarNombreUnico -campo "Interfaces.Nombre" -arreglo $nombres
        ValidarNombreUnico -campo "Interfaces.IP" -arreglo $ips -imprimeIP $true
        return $interfacesCheck
    }else{
        Write-Host "El equipo $hostname debe tener al menos una interfaz"
        exit
    }
}
    