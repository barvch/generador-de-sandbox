function ValidarDatosGenerales { param ($maquinaVirtual, $rutaRaiz)
    $SOCheck = ValidarSistemaOperativo -sistemaOperativo $maquinaVirtual.SistemaOperativo
    $hostnameCheck = ValidarHostname -hostname $maquinaVirtual.Hostname -so $SOCheck
    $discosVirtualesCheck = ValidarDiscosVirtuales -discosVirtuales $maquinaVirtual.DiscosVirtuales -rutaRaiz $rutaRaiz
    $procesadoresCheck = ValidarProcesadores -procesadores $maquinaVirtual.Procesadores
    $rutaISOCheck = ValidarRutaISO -rutaISO $maquinaVirtual.RutaISO -so $SOCheck
    $memoriaRAMCheck = ValidarMemoriaRAM -memoriaRAM $maquinaVirtual.MemoriaRAM
    $credencialesCheck = ValidarCredenciales -credenciales $maquinaVirtual.Credenciales -os $SOCheck
    $interfacesCheck = ValidarInterfaces -interfaces $maquinaVirtual.Interfaces -hostname $hostnameCheck
    $datosdepCheck = ValidarDatosDependientes -sistemaOperativo $SOCheck -llaveActivacion $maquina.LlaveActivacion -rutaMSI $maquinaVirtual.RutaMSI -tipoAmbiente $maquinaVirtual.TipoAmbiente -WinIso $rutaISOCheck
    $serviciosCheck = ValidarServicios -sistemaOperativo $SOCheck -maquinaVirtual $maquinaVirtual -interfaces $interfacesCheck
    $datosValidados = [ordered] @{"SistemaOperativo" = $SOCheck; "Hostname" = $hostnameCheck; "DiscosVirtuales" = $discosVirtualesCheck; `
        "Procesadores" = $procesadoresCheck; "RutaISO" = $rutaISOCheck; "MemoriaRAM" = $memoriaRAMCheck; `
        "Credenciales" = $credencialesCheck; "Interfaces" = @($interfacesCheck); "DatosDependientes" = $datosdepCheck; "Servicios" = $serviciosCheck}
    return $datosValidados
}

function ValidarDatosDependientes { param ($sistemaOperativo, $llaveActivacion, $rutaMSI, $tipoAmbiente, $WinIso)
    $tipoAmbienteCheck = ValidarTipoAmbiente -tipoAmbiente $tipoAmbiente -sistemaOperativo $sistemaOperativo -WinIso $WinIso
    switch -regex ($sistemaOperativo) {
        "Windows 10" { $rutaMSICheck = ValidarRutaMSI -rutaMSI $rutaMSI }
        "Windows .*" { 
            $llaveActivacionCheck = ValidarLlaveActivacion -llave $llaveActivacion
            $rutaXML = ValidarXML -rutaXML "$(Get-Location)\Recursos\Unattend\Windows\unattend.xml"
        }
        Default { }
        }
    $datosDependientes = [ordered] @{"TipoAmbiente" = $tipoAmbienteCheck; "LlaveActivacion" = $llaveActivacionCheck; "RutaMSI" = $rutaMSICheck; "ArchivoXML" = $rutaXML}
    return $datosDependientes
}

function ValidarServicios { param ( $sistemaOperativo, $maquinaVirtual, $interfaces = "")
    $adminRemotaCheck, $puertoCheck = ValidarAdministracionRemota -adminRemota $maquinaVirtual.Servicios.AdministracionRemota -so $sistemaOperativo -puerto $maquinaVirtual.Servicios.PuertoSSH
    switch -regex ($sistemaOperativo) {
        "Windows Server 2019" { 
            $activeDirectoryCheck = ValidarActiveDirectory -activeDirectory $maquinaVirtual.Servicios.ActiveDirectory
            $certServicesCheck = ValidarCertServices -certServices $maquinaVirtual.Servicios.CertificateServices
            $winDefenderCheck = ValidarWindowsDefender -winDefender $maquinaVirtual.Servicios.WindowsDefender
            $IISCheck = ValidarIIS -iis $maquinaVirtual.Servicios.IIS -interfaces $interfaces
            $DHCPCheck = ValidarDHCP -dhcp $maquinaVirtual.Servicios.DHCP
            $DNSCheck = ValidarDNS -dns $maquinaVirtual.Servicios.DNS
            if($activeDirectoryCheck -and ($certServicesCheck -or $IISCheck -or $DHCPCheck -or $DNSCheck)){
                Write-Host "Si se configura el servicio de AD-DS el equipo no puede tener los servicios: CertificateServices, IIS, DNS o DHCP"
                exit
            }
            if ($IISCheck -or $DHCPCheck -or $DNSCheck) {
                foreach ($interfaz in $interfaces) {
                    if ($interfaz.Tipo -eq "Static") {$staticFlag = $true}
                }
                if (-not $staticFlag) {
                    Write-Host "Se debe ingresar al menos una interfaz del tipo Static para los servicios: IIS, DHCP y/o DNS"
                    exit
                }
            }
        }
        Default { 
            $servidorWebCheck = ValidarServidorWeb -servidorWeb $maquinaVirtual.Servicios.ServidorWeb -interfaces $interfaces
            $manejadorbdCheck = ValidarManejadorBD -manejadorbd $maquinaVirtual.Servicios.ManejadorBD -so $sistemaOperativo
            $DHCPCheck = ValidarISCDHCP -dhcp $maquinaVirtual.Servicios.DHCP -interfaces $interfaces
            $DNSCheck = ValidarBindDNS -dns $maquinaVirtual.Servicios.DNS -interfaces $interfaces
        }
    }
    $servicios = [ordered] @{"AdministracionRemota" = $adminRemotaCheck; "PuertoSSH" = $puertoCheck; "CertificateServices" = $certServicesCheck; `
    "WindowsDefender" = $winDefenderCheck; "ActiveDirectory" = $activeDirectoryCheck; "IIS" = $IISCheck; "DHCP" = $DHCPCheck; `
    "DNS" = $DNSCheck; "ServidorWeb" = $servidorWebCheck; "ManejadorBD" = $manejadorbdCheck}
    return $servicios
}