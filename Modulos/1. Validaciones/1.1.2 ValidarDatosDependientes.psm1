#Se importan los catalogos
. ".\Recursos\Validaciones\catalogos.ps1"

function ValidarLlaveActivacion{ param ($campo = "LlaveActivacion", $llave)
    if($llave){
        return ValidarCadenas -campo $campo -valor $llave -validacionCaracter "llaveActivacion" -obligatorio $true
    }
}

function ValidarRutaMSI{ param ($campo = "RutaMSI", $rutaMSI)
    if($rutaMSI){
        $rutaMSICheck = ValidarArregloDato -campo $campo -valor $rutaMSI -arreglo $true -tipoDato "String"
        return ValidarRuta -campo $campo -valor $rutaMSICheck
    }
}
function ValidarXML { param ($rutaXML)
    try{
        if (-not(Test-Path -Path $rutaXML)){
            Write-Host "No se encotro el archivo XML $rutaXML"
            exit
        }
        [XML] $xml = Get-Content $rutaXML
        return $rutaXML
    }catch{
        Write-Host "El archivo $rutaXML no cuenta con un fromato XML valido"
        exit
    }
}

function ValidarTipoAmbiente { param ($campo = "TipoAmbiente", $tipoAmbiente, $sistemaOperativo, $WinIso)
    #$tipoAmbiente = ValidarArregloDato -campo $campo -valor $tipoAmbiente -tipoDato "String" -obligatorio $true
    switch -regex ($sistemaOperativo) {
        "Windows.*" { 
            $MountResult = Mount-DiskImage -ImagePath $WinIso -StorageType ISO -PassThru
            $DriveLetter = ($MountResult | Get-Volume).DriveLetter
            #Write-Host "Obteniendo versiones de Windows" -ForegroundColor Yellow
            $WimFile = "$($DriveLetter):\sources\install.wim"
            $WimOutput = dism /get-wiminfo /wimfile:"$WimFile" | Out-String
            $WimInfo = $WimOutput | Select-String "(?smi)Index : (?<Id>\d+).*?Name : (?<Name>[^`r`n]+)" -AllMatches
            $Items = @{ }
            $tipoAmbienteWindows = @()
            $WimInfo.Matches | ForEach-Object { 
              $Items.Add([int]$_.Groups["Id"].Value, $_.Groups["Name"].Value)
              $tipoAmbienteWindows += $_.Groups["Name"].Value
              if ($tipoAmbiente -eq $_.Groups["Name"].Value ) {
                $WimIdx = [int]$_.Groups["Id"].Value
              }
            }
            Dismount-DiskImage -ImagePath $WinIso | Out-Null
            return "[$WimIdx] "+(ValidarCatalogos -catalogo $tipoAmbienteWindows -campo $campo -valor $tipoAmbiente -obligatorio $true -so $sistemaOperativo)
         }
        "(CentOS.*|RHEL.*)" { return ValidarCatalogos -catalogo $ambientesRHELCentOS -campo $campo -valor $tipoAmbiente -obligatorio $true -so $sistemaOperativo }
        "Ubuntu.*" { return ValidarCatalogos -catalogo $ambientesUbuntu -campo $campo -valor $tipoAmbiente -obligatorio $true -so $sistemaOperativo }
    }
}

function ValidarBackup{ param ($campo = "RutaBackup", $rutaBackup)
    $backupCheck = ValidarArregloDato -campo $campo -valor $rutaBackup -obligatorio $false -tipoDato "String"
    $backupCheck = ValidarRuta -campo $campo -valor $rutaBackup -obligatorio $false

    return $backupCheck
}

function ValidarRutaVHD{ param ($campo = "RutaVHD", $rutaVHD)
    $VHDCheck = ValidarArregloDato -campo $campo -valor $rutaVHD -obligatorio $true -tipoDato "String"
    $VHDCheck = ValidarRuta -campo $campo -valor $rutaVHD -obligatorio $true

    return $VHDCheck
}

function ValidarLicencia{ param ($campo = "RutaLicencia", $rutaLic)
    $LicCheck = ValidarArregloDato -campo $campo -valor $rutaLic -obligatorio $false -tipoDato "String"
    $LicCheck = ValidarRuta -campo $campo -valor $rutaLic -obligatorio $false

    return $LicCheck
}
