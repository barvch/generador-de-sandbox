function InstalarServicios { param ($maquina, $rutaRaiz)
    $hostname = $maquina.Hostname
    $so = $maquina.SistemaOperativo
    $vname = "$($hostname)-$($so)"
    $servicio = $maquina.Servicios
    $winDefender = $servicio.WindowsDefender
    $activeDirectory = $servicio.ActiveDirectory
    $certServices = $servicio.CertificateServices
    $iis = servicio.IIS
    
    switch -regex ($so) {
        "Windows*" { InstalarRDP }
        "Windows Server 2019" { 
            if($winDefender){ InstalarWindowsDefender}
            if($activeDirectory){ InstalarActiveDirectory -activeDirectory $activeDirectory }
            if($certServices){ InstalarCertificateServices }
            if($iis){ InstalarIIS -iis $iis }
         }
        Default {}
    }
}