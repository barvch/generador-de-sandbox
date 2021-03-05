function CrearISODebianFlavor {
    param ([string ]$username, [string] $password,[string]$hostname, [string] $isoFile, [string]$seed_file, [string]$directorio, [string]$os, $ambiente, $interfaces)
    $timezone = 'America/Mexico_City'
    $pwhash = bash -c "echo $password | mkpasswd -s -m sha-512"
    # Se monta el disco y se obtiene la letra que ha sido asignada al disco
    Write-Host "Montando ISO de Ubuntu..." -ForegroundColor Yellow
    $ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
    if(! $ISODrive){
        Mount-DiskImage -ImagePath $isoFile -StorageType ISO
    }
    $ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
    Write-Host ("El drive asignado al Host para el ISO $isoFile es: " + $ISODrive)
    
    # Se copia el contenido del ISO al directorio de trabajo
    Write-Host "Copiando el contenido del ISO al directorio de trabajo: $directorio\iso_org" -ForegroundColor Yellow
    $ISOSource = ("$ISODrive" + ":\*.*")
    xcopy $ISOSource "$directorio\" /e | Out-Null

    if (@("Ubuntu 16.04", "Ubuntu 18.04", "Ubuntu 20.04") -contains $os) {
        # Se copia el preseed base al directorio de trabajo y al archivo copiado, se hacen las modificaciones de las especificaciones para el equipo
        Copy-Item ".\Recursos\unattend\Ubuntu\ks.preseed" "$directorio" -Force
        (Get-Content "$directorio\ks.preseed").replace('{{username}}', $username) | Set-Content "$directorio\$seed_file"
        (Get-Content "$directorio\ks.preseed").replace('{{pwhash}}', $pwhash) | Set-Content "$directorio\$seed_file"
        (Get-Content "$directorio\ks.preseed").replace('{{hostname}}', $hostname) | Set-Content "$directorio\$seed_file"
        (Get-Content "$directorio\ks.preseed").replace('{{timezone}}', $timezone) | Set-Content "$directorio\$seed_file"

        # Se le agrega extension a algunos archivos necesarios para crear el ISO
        Rename-Item -Path "$directorio\casper\initrd" -NewName "initrd.lz"
        Rename-Item -Path "$directorio\casper\vmlinuz" -NewName "vmlinuz.efi"

        # Se modifica el archivo txt.cfg, el cual contiene las respuestas que instalación y se indican detalles de la instalación desatendida:    
        $install_lable="default live-install`nlabel live-install`n  menu label ^Install Ubuntu`n  kernel /casper/vmlinuz.efi`n  append file=/cdrom/ks.preseed auto=true priority=critical debian-installer/locale=en_US keyboard-configuration/layoutcode=us ubiquity/reboot=true languagechooser/language-name=English countrychooser/shortlist=US localechooser/supported-locales=en_US.UTF-8 boot=casper automatic-ubiquity initrd=/casper/initrd.lz quiet splash noprompt noshell ---"
        Clear-Content "$directorio\isolinux\txt.cfg"
        $install_lable | Set-Content "$directorio\isolinux\txt.cfg"
    } elseif (@("Kali Linux 2020.04", "Debian 10") -contains $os) {
        # Se copia el preseed base al directorio de trabajo y al archivo copiado, se hacen las modificaciones de las especificaciones para el equipo
        if ($os -eq "Debian 10"){
            Copy-Item ".\Recursos\unattend\Debian\preseed.cfg" "$directorio" -Force
            (Get-Content "$directorio\preseed.cfg").replace('{{paquetes}}', "tree vim git") | Set-Content "$directorio\$seed_file"
        } else {
            Copy-Item ".\Recursos\unattend\Kali\preseed.cfg" "$directorio" -Force
        }
        Write-Host $ambiente
        if ($ambiente -match "Core") { $insert = "tasksel tasksel/first multiselect standard`n" } else { $insert = "tasksel tasksel/first multiselect desktop, standard`nd-i tasksel/first multiselect Debian desktop environment, Standard system utilities`ntasksel tasksel/desktop string xfce" } 
        $configInterfaces = ""
        $contador = 0
        foreach ($interfaz in $interfaces) {
            $ip = $interfaz.IP
            $netmask = $interfaz.MascaraRed
            $gateway = $interfaz.Gateway
            $dns = $interfaz.DNS
            if ($gateway) {$gateway = "" }
            if ($dns) {$dns = ""}
            $configInterfaces += "d-i netcfg/choose_interface select eth$contador`nd-i netcfg/disable_dhcp boolean true`n$dns`nd-i netcfg/get_ipaddress string $ip`nd-i netcfg/get_netmask string $netmask`n$gateway`nd-i netcfg/confirm_static boolean true`n"
            $contador++
        }
        (Get-Content "$directorio\preseed.cfg").replace('{{interfaces}}', $configInterfaces) | Set-Content "$directorio\$seed_file"
        if ($ambiente -eq "Core") { $insert = "tasksel tasksel/first multiselect standard`n" } else { $insert = "tasksel tasksel/first multiselect desktop, standard`nd-i tasksel/first multiselect Debian desktop environment, Standard system utilities`ntasksel tasksel/desktop string xfce" } 
        (Get-Content "$directorio\preseed.cfg").replace('{{ambiente}}', $insert) | Set-Content "$directorio\$seed_file"
        (Get-Content "$directorio\preseed.cfg").replace('{{username}}', $username) | Set-Content "$directorio\$seed_file"
        (Get-Content "$directorio\preseed.cfg").replace('{{pwhash}}', $pwhash) | Set-Content "$directorio\$seed_file"
        (Get-Content "$directorio\preseed.cfg").replace('{{hostname}}', $hostname) | Set-Content "$directorio\$seed_file"
        (Get-Content "$directorio\preseed.cfg").replace('{{timezone}}', $timezone) | Set-Content "$directorio\$seed_file"

        # Se copia el preseed del GRUB base al directorio de trabajo y al archivo copiado, se hacen las modificaciones de las especificaciones para el equipo
        Clear-Content "$directorio\boot\grub\grub.cfg"
        Copy-Item ".\Recursos\unattend\grub.cfg" "$directorio\boot\grub\grub.cfg" -Force
        (Get-Content "$directorio\boot\grub\grub.cfg").replace('{{hostname}}', $hostname) | Set-Content "$directorio\boot\grub\grub.cfg"

        # Se hacen modificaciones al archivo txt.cfg del directorio isolinux, para indicar que se lea el archivo de configuración agregado a la imagen 
        (Get-Content "$directorio\isolinux\txt.cfg").replace('label install', 'label unattended') | Set-Content "$directorio\isolinux\txt.cfg"
        (Get-Content "$directorio\isolinux\txt.cfg").replace('menu label ^Install', 'menu label ^Unattended Install') | Set-Content "$directorio\isolinux\txt.cfg"
        $lol = "append preseed/file=/cdrom/preseed.cfg locale=en_US keymap=es hostname=$hostname domain=local.lan vga=788 initrd=/install.amd/initrd.gz --- quiet"
        if ($os -eq "Debian 10") {
            (Get-Content "$directorio\isolinux\txt.cfg").replace('append desktop=xfce vga=788 initrd=/install.amd/initrd.gz --- quiet', $lol) | Set-Content "$directorio\isolinux\txt.cfg"
        } else {
            (Get-Content "$directorio\isolinux\txt.cfg").replace('append preseed/file=/cdrom/simple-cdd/default.preseed simple-cdd/profiles=kali,offline desktop=xfce vga=788 initrd=/install.amd/initrd.gz --- quiet ', $lol) | Set-Content "$directorio\isolinux\txt.cfg"
        }
    }
    # Se establece el orden de booteo para ver reflejados todos los cambios 
    (Get-Content "$directorio\isolinux\isolinux.cfg").replace('timeout 0', 'timeout 60') | Set-Content "$directorio\isolinux\isolinux.cfg"
    (Get-Content "$directorio\isolinux\isolinux.cfg").replace('prompt 0', 'prompt 60') | Set-Content "$directorio\isolinux\isolinux.cfg"
}
function CrearISOCentos {
    param ([string]$username, [string]$password,[string]$hostname, [string] $isoFile, [string]$seed_file, [string]$directorio, $interfaces, $ambiente)
    $timezone = 'America/Mexico_City'
    $pwhash = bash -c "echo $password | mkpasswd -s -m sha-512"   
    # Se monta el disco y se obtiene la letra que ha sido asignada al disco
    Write-Host "Montando ISO de CentOS/RHEL" -ForegroundColor Yellow
    $ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
    if(! $ISODrive){
        Mount-DiskImage -ImagePath $isoFile -StorageType ISO
    }
    $ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
    Write-Host ("El drive asignado al Host para el ISO $isoFile es: " + $ISODrive)
    
    # Se copia el contenido del ISO al directorio de trabajo
    Write-Host "Copiando el contenido del ISO al directorio de trabajo: $temp\iso_org" -ForegroundColor Yellow
    $ISOSource = ("$ISODrive" + ":\*.*")
    xcopy $ISOSource "$directorio\" /e | Out-Null
    
    $configinterfaces = ""
    $contador = 0
    foreach ($interfaz in $interfaces) {
        $ip = $interfaz.IP
        $netmask = $interfaz.MascaraRed
        $gateway = $interfaz.Gateway
        $dns = $interfaz.DNS
        if ($gateway) {$gateway = "--gateway=$gateway" }
        if ($dns) {$dns = "--nameserver=$dns"}
        $configinterfaces += "network --bootproto=static --ip=$ip --netmask=$netmask $gateway $dns --device=eth$contador`n"
        $contador++
    }
    # Se copia el preseed base al directorio de trabajo y al archivo copiado, se hacen las modificaciones de las especificaciones para el equipo
    Copy-Item ".\Recursos\unattend\CentOS\ks.cfg" "$directorio" -Force
    if ($ambiente -eq "Core") {
        (Get-Content "$directorio\ks.cfg").replace('{{gui}}', "") | Set-Content "$directorio\$seed_file"
        (Get-Content "$directorio\ks.cfg").replace('{{paqueteambiente}}', "@^minimal-environment") | Set-Content "$directorio\$seed_file"
    } else {
        (Get-Content "$directorio\ks.cfg").replace('{{gui}}', $ambiente) | Set-Content "$directorio\$seed_file"
        (Get-Content "$directorio\ks.cfg").replace('{{paqueteambiente}}', "@$($ambiente)-desktop") | Set-Content "$directorio\$seed_file"
    }
    (Get-Content "$directorio\ks.cfg").replace('{{passwd}}', $pwhash) | Set-Content "$directorio\$seed_file"
    (Get-Content "$directorio\ks.cfg").replace('{{timezone}}', $timezone) | Set-Content "$directorio\$seed_file"
    (Get-Content "$directorio\ks.cfg").replace('{{hostname}}', $hostname) | Set-Content "$directorio\$seed_file"
    (Get-Content "$directorio\ks.cfg").replace('{{username}}', $username) | Set-Content "$directorio\$seed_file"
    (Get-Content "$directorio\ks.cfg").replace('{{interfaces}}', $configinterfaces) | Set-Content "$directorio\$seed_file"
    (Get-Content "$directorio\ks.cfg").replace('{{paquetes}}', "vim`ngit") | Set-Content "$directorio\$seed_file"
    
    # Dentro del directorio de trabajo, se elimina la configuracion por defecto del ISO y se copia la modificada 
    Remove-Item $directorio\isolinux\isolinux.cfg
    Copy-Item ".\Recursos\unattend\CentOS\isolinux.cfg" "$directorio\isolinux\isolinux.cfg" -Force
    
    # Se establece el orden de booteo para ver reflejados todos los cambios 
    $cambio = "linuxefi /images/pxeboot/vmlinuz  inst.stage2=hd:sr0 inst.ks=cdrom:/ks.cfg quiet"
    (Get-Content "$directorio\EFI\BOOT\grub.cfg").replace("menuentry 'Install CentOS Linux 8' --class fedora --class gnu-linux --class gnu --class os", "menuentry 'Kickstart Installation' --class fedora --class gnu-linux --class gnu --class os") | Set-Content "$directorio\EFI\BOOT\grub.cfg"
    (Get-Content "$directorio\EFI\BOOT\grub.cfg").replace('linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=CentOS-8-3-2011-x86_64-dvd quiet', $cambio) | Set-Content "$directorio\EFI\BOOT\grub.cfg"
    (Get-Content "$directorio\EFI\BOOT\grub.cfg").replace('set default="1"', 'set default="0"') | Set-Content "$directorio\EFI\BOOT\grub.cfg"
}