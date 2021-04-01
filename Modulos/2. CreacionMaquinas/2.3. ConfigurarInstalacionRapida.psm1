function ConfigurarInstalacionRapida { param ($maquina, $rutaRaiz)
    function CrearDirectorioTrabajo {
        Write-Host "Creando carpetas de trabajo para la creacion del ISO..." -ForegroundColor Yellow
        if (-not (Test-Path $rutaRaiz)) {
            Write-Host "Creando directorio: $directorio" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path "$directorio" | Out-Null
            Write-Host "Directorio creado: $directorio" -ForegroundColor Green
        } else {
            Write-Host "La carpeta de trabajo ya existe" -ForegroundColor Green
            if (-not (Test-Path "$directorio")) {
                Write-Host "Creating Folder $directorio" -ForegroundColor Yellow
                    New-Item -ItemType Directory -Path "$directorio" | Out-Null
                Write-Host "Directorio creado: $directorio" -ForegroundColor Green
            } else {
                Write-Host "El directorio $directorio ya existe dentro de la ruta de trabajo." -ForegroundColor Green
            }
        }
    } 
    $os = $maquina.SistemaOperativo
    $hostname = $maquina.Hostname 
    $username = $maquina.Credenciales.Usuario
    $password = $maquina.Credenciales.Contrasena
    $isoFile = $maquina.RutaISO
    $interfaces = $maquina.Interfaces
    $vname = "$($maquina.Hostname)-$($maquina.SistemaOperativo)"
    switch -regex ($os) {
        "(Ubuntu .*|Debian .*|Kali.*|CentOS .*|RHEL .*)" { 
            $directorio = "$rutaRaiz\$vname\iso_org"
            CrearDirectorioTrabajo
            switch -regex ($os) {
                "Ubuntu.*" { $seedfile = "ks.preseed"
                    CrearISODebianFlavor -os $os -hostname $hostname -username $username -password $password -isoFile $isoFile -directorio $directorio -seed_file $seedfile -ambiente $ambiente -interfaces $interfaces| Out-Null
                    break 
                }
                "(CentOS.*|RHEL .*)" {$seedfile = "ks.cfg"
                    CrearISOCentos -username $username -password $password -hostname $hostname -isoFile $isoFile -seed_file $seedfile -directorio $directorio -interfaces $interfaces -ambiente $ambiente -os $os| Out-Null
                    break
                }
                Default { 
                    $seedfile = "preseed.cfg"
                    CrearISODebianFlavor -os $os -hostname $hostname -username $username -password $password -isoFile $isoFile -directorio $directorio -seed_file $seedfile -ambiente $ambiente -interfaces $interfaces| Out-Null
                }
            }
                
                # Se mueve al directorio de trabajo para crear el ISO con todo el contenido actual del directorio de trabajo
                Write-Host "Creando ISO Unattended..."
                $pwdrepo = [string](Get-Location)
                $mkisofs = $pwdrepo + "\Recursos\exe\mkisofs.exe"
                Set-location $directorio
                $rutaIsoSalida = ("..\unattendedISO.iso")
                if($so -match "(CentOS.*|RHEL .*)"){
                    (Invoke-Expression -Command "$mkisofs -D -r -V 'linux-auto' -duplicates-once -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $rutaIsoSalida ." | Invoke-Expression) | Out-Null
                }else{
                    (Invoke-Expression -Command "$mkisofs -D -r -V 'ubuntu-auto' -duplicates-once -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $rutaIsoSalida ." | Invoke-Expression) | Out-Null

                }
                Add-VMDvdDrive -VMName $vname -Path $rutaIsoSalida
                Set-Location $pwdrepo
                break
            }
        "Windows .*" { 
            #Se obtiene el disco de mayor tamano para realizar la instalacion del Sistema Operativo
            $discoMayorTamano = ((Get-VM -VMName $vname | Select-Object -Property VMId | Get-VHD).Size | Measure-Object -Maximum).Maximum
            foreach($disco in (Get-VM -VMName $vname | Select-Object -Property VMId | Get-VHD)){
                if($disco.Size -eq $discoMayorTamano){
                    $pathDisco = $disco.Path
                }
            }
            CrearVHDWindows -WinISO $isoFile -VhdFile $pathDisco -maquina $maquina
            $boot = (Get-VMFirmware $vname).BootOrder
            for($index = 0; $index -le $boot.Count; $index++){
                if($boot[$index].Device.Path -eq $pathDisco -and $boot[$index].BootType -eq "Drive"){
                    $firstBoot = $boot[$index]
                    break
                }
            }
            Set-VMFirmware $vname -FirstBootDevice $firstBoot
            break
        }
    }
}
