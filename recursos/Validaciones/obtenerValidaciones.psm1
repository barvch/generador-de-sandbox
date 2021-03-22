function DatoObligatorio { param ( $obligatorio=$false, $campo, $valor)
    if($obligatorio -and -not $valor){
        Write-Host "El campo $campo es obligatorio"
        exit
    }
}

function ObtenerValidaciones { param ($validacionCaracter, $validacionLongitud= "", $inicioFin = "^[A-Za-z].*[A-Za-z]$")
    $consecutivos = "^[a-zA-Z0-9]+([-. ][a-zA-Z0-9]+)*$"
    if(-not($validacionCaracter.Contains("alfaNum"))){
        $inicioFin = $consecutivos = ".*"
    }
    switch ($validacionCaracter) {
        alfaNum1 { $caracteres = "^[a-zA-Z0-9-]+$"; $mensajeCaracteres =  "alfanumericos y guion medio (-)"; break}
        alfaNum2 { $caracteres = "^[a-zA-Z0-9 -]+$"; $mensajeCaracteres =  "alfanumericos, guion medio (-) y espacio ( )"; break}
        alfaNum3 { $caracteres = "^[a-zA-Z0-9 \.-]+$"; $mensajeCaracteres =  "alfanumericos, guion medio (-), punto (.) y espacio ( )"; break}
        alfaNum4 { $caracteres = "^[a-zA-Z0-9\.-]+$"; $mensajeCaracteres =  "alfanumericos, guion medio (-) y punto (.)"; break}
        alfaNum5 { $caracteres = "^[a-zA-Z0-9]+$"; $mensajeCaracteres =  "alfanumericos"; break}

        password {$caracteres = "[\x20-\x7E]"; $mensajeCaracteres = "ASCII imprimibles" ; break}
        ip { $caracteres = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"; $mensajeCaracteres =  "numericos y punto (.) con un formato de IP valida:`nxxx.xxx.xxx.xxx"; $validacionLongitud = "longitud3"; break}
        llaveActivacion { $caracteres = "^([A-Za-z0-9]{5}-){4}[A-Za-z0-9]{5}$"; $mensajeCaracteres = "alfanumericos y guion medio (-) con el siguiente formato:`nxxxxx-xxxxx-xxxxx-xxxxx-xxxxx"; $validacionLongitud = "longitud4"; break}
        dominio { $caracteres = "([a-zA-Z0-9]{5,15}\.){1,3}"; $mensajeCaracteres = "alfanumericos, guion medio (-) y espacio con el siguiente formato:`ncontoso.local"; $validacionLongitud = "longitud5"; $inicioFin = "^[A-Za-z].*[A-Za-z]$";break}
        netID { $caracteres = "(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}0\/(24|16|8)$"; $mensajeCaracteres =  "numericos y punto (.) con un formato de NetID valida:`nxxx.xxx.xxx.0/(24|16|8)"; break}
        host {$caracteres = "^([1-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"; $mensajeCaracteres = "entre 1 y 255"; break}

    }
    switch ($validacionLongitud) {
       longitud1 {$longitud = "5,20"; break }
       longitud2 {$longitud = "10,30"; break }
       longitud3 {$longitud = "7,15"; break }
       longitud4 {$longitud = "29"; break }
       longitud5 {$longitud = "5,30"; break }
       longitud6 {$longitud = "5,15"; break }
       default {$longitud = "1,"}
    }
    if($longitud.Contains(",")){
        $longitud = $longitud -split ","
        $mensajeLongitud = "entre $($longitud[0]) y $($longitud[1]) caracteres"
        $longitud = [String]::join(",", $longitud)
    }else{
        $mensajeLongitud = "de $longitud caracteres"
    }
    return $caracteres, $longitud, $mensajeCaracteres, $mensajeLongitud, $inicioFin, $consecutivos
}


function ValidarCadenas { param ($campo, $valor, $validacionCaracter, $validacionLongitud, $obligatorio)
    try{
        DatoObligatorio -obligatorio $obligatorio -campo $campo -valor $valor  
        if($valor.GetType().Name -eq "String"){
            $caracteres, $longitud, $mensajeCaracteres, $mensajeLongitud, $inicioFin, $consecutivos = ObtenerValidaciones -validacionCaracter $validacionCaracter -validacionLongitud $validacionLongitud
            if($valor -match "^.{$longitud}$"){
                if($valor -match $caracteres){
                    if ($valor -match $inicioFin){
                        if(-not ($valor -match $consecutivos)){
                            Write-Host "El campo $campo no debe contener caracteres no alfanumericos consecutivos"
                            exit
                        }
                    }else{
                        Write-Host "El campo $campo debe empezar y terminar con una letra"
                        exit
                    }
                }else{
                    Write-Host "El campo $campo solo debe contener caracteres $mensajeCaracteres"
                    exit
                }
            }else{
                Write-Host "El campo $campo debe tener una longitud $mensajeLongitud"
                exit
            }       
        }else{
            Write-Host "El campo $campo solo permite el ingreso de cadenas"
            exit
        }
        return $valor
    }catch{return ""}
}   

function ValidarCatalogos { param ($catalogo, $campo, $valor, $obligatorio, $so = "")
    DatoObligatorio -obligatorio $obligatorio -campo $campo -valor $valor
    if(-not $valor){
        return ""
    }else{
        if(-not ($valor -in $catalogo)){
            if($so){
                Write-Host "El campo $campo solo permite el ingreso de los siguientes valores para el Sistema Operativo $($so):"
            }else{
                Write-Host "El campo $campo solo permite el ingreso de los siguientes valores:"
            }
            foreach($elemento in $catalogo){Write-Host "`t> $elemento"}
            exit
        }
    }
     return $valor
}

function ValidarRuta{ param ($campo, $valor, $obligatorio)
    DatoObligatorio -obligatorio $obligatorio -campo $campo -valor $valor
    if(-not $valor){
        return ""
    }
    foreach($ruta in $valor){
        if(-not (Test-Path $ruta)){
        Write-Host "No se encontro el archivo ingresado en el campo $($campo):`n$ruta"
        exit
        }
    }
    return $valor
}

function ValidarArregloDato { param ($campo, $valor, $obligatorio, $arreglo=$false, $tipoDato)
    DatoObligatorio -obligatorio $obligatorio -campo $campo -valor $valor
    if(-not $valor){
        return ""
    }else{
        if($arreglo){
            if($valor.GetType().Name -ne "Object[]"){
                Write-Host "El campo $campo solo permite arreglos con valores de tipo $tipoDato"
                exit
            }
            foreach ($elemento in $valor){
                if($elemento.GetType().Name -ne $tipoDato){
                    Write-Host "El campo $campo solo permite arreglos con valores de tipo $tipoDato"
                    exit
                }
            }
        }else{
            if($valor.GetType().Name -ne $tipoDato){
                Write-Host "El campo $campo solo permite el ingreso de valores de tipo $tipoDato"
                exit
            }
        }
        return $valor
    }
}

function ValidarNombreUnico { param ($campo, $arreglo, $imprimeIP = $false)
    if ($arreglo | group | ?{$_.Count -gt 1}){
        if($imprimeIP){
            Write-Host "Las direcciones IP ingresadas en la seccion $campo deben ser unicas"
            exit
        }else{
            Write-Host "Los valores ingresados en la seccion $campo deben ser unicos:`n$(($arreglo | group).values)"
            exit
        }
    }
}

function ValidarPuerto { param ($campo, $puerto, $puertosBienConocidos)
    if($puerto -in $puertosBienConocidos){
        Write-Host "El campo $campo no permite el ingreso de un puerto bien conocido"
        exit
    }elseif(($puerto -gt 65535) -or ($puerto -le 0)){
        Write-Host "El campo $campo debe contener un puerto valido"
        exit
    }
}

function ValidarRango { param ( $ipInicio, $ipFin = "", $mascara, $campo, $unico = $false)
    $ipInicioSplit = $ipInicio.Split(".")
    $ipFinSplit = $ipFin.Split(".")
    switch -regex ($mascara) {
        ("24|255.255.255.0") { $rango = 0,1,2 ; break}
        ("16|255.255.0.0") { $rango = 0,1 ; break}
        ("8|255.0.0.0") { $rango = 0 ; break}
    }
    if($unico){
        return ($ipInicioSplit[$rango] -join ".")
    }
    $ipInicio = (-join $ipInicioSplit)
    $ipFin = (-join $ipFinSplit)
    if((-join $ipInicioSplit[$rango]) -ne (-join $ipFinSplit[$rango])){
        Write-Host "El campo $campo debe tener un rango valido para la mascara $mascara"
        exit
    }
    if([Double]$ipInicio -ge [Double]$ipFin){
        Write-Host "Los campos $campo.Inicio y $campo.Fin deben tener un rango valido"
        exit
    }
    return [Double]$ipInicio, [Double]$ipFin
}
function ValidarTiempo { param ($campo, $tiempo, $obligatorio=$false)
    DatoObligatorio -obligatorio $obligatorio -campo $campo -valor $tiempo
    if($tiempo -match "[0-9]{3}\.([0-1][0-9]|2[0-3]):[0-5][0-9]"){
        if($tiempo -match "000.00.*" ){
            Write-Host "El campo $campo debe tener un valor minimo de 000.01:00"
            exit
        }
        return $tiempo
    }else{
        Write-Host "El formato para el campo $campo debe ser DDD:HH:MM`nValores Maximos 999.23:59"
        exit
    }
}
function ValidarInterfaz { param ($interfaces, $nombre, $campo)
    foreach($interfaz in $interfaces){
        if($nombre -eq $interfaz.Nombre){
            if ($interfaz.Tipo -eq "DHCP") {
                Write-Host "La interfaz ingresada en el campo $campo debe de ser del tipo Static"
                exit
            }
            return $interfaz.IP, $interfaz.MascaraRed
        }else{
            Write-Host "El campo $campo no coincide con alguna interfaz ingresada"
            exit
        }
    }
}

function ObtenerPuertoDefault { param ($puerto, $protocolo, $campo)
    if($puerto){
        if(($protocolo -eq "http" -and $puerto -eq 443) -or ($protocolo -eq "https" -and $puerto -eq 80)){
            Write-Host "El puerto $puerto no puede utilizarse para el protocolo $protocolo"
            exit
        }else{
            if($puerto -ne 443){
                if($puerto -ne 80){
                    ValidarPuerto -campo $campo -puerto $puerto -puertosBienConocidos $puertosBienConocidos
                }
            }
        }
    }else{
        if($protocolo -eq "http"){ $puerto = 80 }else{ $puerto = 443 }
    }
    return $puerto
}
function ObtenerMascaraRed { param ($mascaras, $campo, $valor)
    $mascaraCheck = ValidarCatalogos -catalogo $mascaras -campo $campo -valor $valor -obligatorio $true
    switch ($mascaraCheck) {
        "8"  { $mascaraCheck = "255.0.0.0"; break}
        "16" { $mascaraCheck = "255.255.0.0"; break}
        "24" { $mascaraCheck = "255.255.255.0"; break}
        Default { $mascaraCheck = $mascaraCheck }
    }
    return $mascaraCheck
}