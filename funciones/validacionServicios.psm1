function Validar-ServiciosWindowsServer {
    param ([array]$servicios, [array]$dominiosExistentes)
    $serviciosDisponibles = @("DHCP","DNS","IIS","Certificate Services","Active Directory","Windows Defender","WebDAV","RDP") # Se definen todos los servicios disponibles para este tipo de SO
    $serviciosPorInstalar = @() # Aca se almacenan los servicios que sean validados
    if ($servicios.Count -ne 0) {
        foreach ($servicio in $servicios) {
            if ($serviciosDisponibles.Contains($servicio.Name)) {
                if($servicio.Name -eq "Active Directory"){
                    $config = $servicio.Config
                    if($dominiosExistentes.Contains($config.Domain)){
                       Write-Host "`tEl dominio ingresado ya existe, modifique el nombre de dominio"
                       exit
                    }
                    else{
                        $dominiosExistentes += $config.Name
                    }

                }
                $serviciosPorInstalar += $servicio
            }
        }
        $existeRDP = $false
        foreach($service in $serviciosPorInstalar){
            if($service -eq "RDP"){
                $existeRDP = $true
            }
        }
        if(-not $existeRDP){
            $serviciosPorInstalar += @{"Name"="RDP"}
        }
        $existeAD = $false
        foreach ($servicio in $serviciosPorInstalar) {
            if(($servicio.Name -eq "Certificate Services" -or $servicio.Name -eq "Active Directory") -and -not $existeAD){
                $existeAD = $true
            }
            elseif(($servicio.Name -eq "Certificate Services" -or $servicio.Name -eq "Active Directory") -and $existeAD){
                Write-Host "`tNo se pueden instalar los servicios de Certificate Service y Active Directory en el mismo equipo"
                exit
            }
        }
       "`tLista de servicios a intalar dentro del equipo:"
        foreach ($servicioValidado in $serviciosPorInstalar) {
            Write-Host "`t`t"$servicioValidado.Name
        }
        return $serviciosPorInstalar
    } else {
        Write-Host "`tNo se han encontrados servicios a instalar para este equipo"
    }
}