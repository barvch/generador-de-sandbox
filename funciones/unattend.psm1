function Crear-DirectorioTrabajo {
    param ([string]$tmp)
    Write-Host "Creando carpetas de trabajo para la creacion del ISO..." -ForegroundColor Yellow
    if (-not (Test-Path $tmp)) {
        Write-Host "`tCreando directorio: $tmp" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $tmp | Out-Null
        Write-Host "`tDirectorio de trabajo creado" -ForegroundColor Green
        
        Write-Host "Creando directorio: $tmp\iso_org" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path "$tmp\iso_org" | Out-Null
        Write-Host "Directorio creado: $tmp\iso_org" -ForegroundColor Green
    } else {
        Write-Host "La carpeta de trabajo ya existe" -ForegroundColor Green
        if (-not (Test-Path "$tmp\iso_org")) {
            Write-Host "Creating Folder $tmp\iso_org" -ForegroundColor Yellow
                New-Item -ItemType Directory -Path "$tmp\iso_org" | Out-Null
            Write-Host "Directorio creado: $tmp\iso_org" -ForegroundColor Green
        } else {
            Write-Host "El directorio $tmp\iso_org ya existe dentro de la ruta de trabajo." -ForegroundColor Green
        }
    }
}
function Crear-ISOUbuntu {
    param ([string ]$username, [string] $password,[string]$hostname, [string] $isoFile, [string]$seed_file, [string]$tmp, [string]$os)
    $timezone = 'America/Mexico_City'
    $pwhash = bash -c "echo $password | mkpasswd -s -m sha-512"
    Crear-DirectorioTrabajo -tmp $tmp
 
    # Se monta el disco y se obtiene la letra que ha sido asignada al disco
    Write-Host "Montando ISO de Ubuntu..." -ForegroundColor Yellow
    $ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
    if(! $ISODrive){
        Mount-DiskImage -ImagePath $isoFile -StorageType ISO
    }
    $ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
    Write-Host ("El drive asignado al Host para el ISO $isoFile es: " + $ISODrive)
    
    # Se copia el contenido del ISO al directorio de trabajo
    Write-Host "Copiando el contenido del ISO al directorio de trabajo: $temp\iso_org" -ForegroundColor Yellow
    $ISOSource = ("$ISODrive" + ":\*.*")
    xcopy $ISOSource "$tmp\iso_org\" /e

    if (@("Ubuntu 16.04", "Ubuntu 18.04", "Ubuntu 20.04") -contains $os) {
        # Se copia el preseed base al directorio de trabajo y al archivo copiado, se hacen las modificaciones de las especificaciones para el equipo
        Copy-Item ".\recursos\unattend\Ubuntu\ks.preseed" "$tmp\iso_org" -Force
        (Get-Content "$tmp\iso_org\ks.preseed").replace('{{username}}', $username) | Set-Content "$tmp\iso_org\$seed_file"
        (Get-Content "$tmp\iso_org\ks.preseed").replace('{{pwhash}}', $pwhash) | Set-Content "$tmp\iso_org\$seed_file"
        (Get-Content "$tmp\iso_org\ks.preseed").replace('{{hostname}}', $hostname) | Set-Content "$tmp\iso_org\$seed_file"
        (Get-Content "$tmp\iso_org\ks.preseed").replace('{{timezone}}', $timezone) | Set-Content "$tmp\iso_org\$seed_file"

        # Se le agrega extension a algunos archivos necesarios para crear el ISO
        Rename-Item -Path "$tmp\iso_org\casper\initrd" -NewName "initrd.lz"
        Rename-Item -Path "$tmp\iso_org\casper\vmlinuz" -NewName "vmlinuz.efi"

        # Se modifica el archivo txt.cfg, el cual contiene las respuestas que instalación y se indican detalles de la instalación desatendida:    
        $install_lable="default live-install`nlabel live-install`n  menu label ^Install Ubuntu`n  kernel /casper/vmlinuz.efi`n  append file=/cdrom/ks.preseed auto=true priority=critical debian-installer/locale=en_US keyboard-configuration/layoutcode=us ubiquity/reboot=true languagechooser/language-name=English countrychooser/shortlist=US localechooser/supported-locales=en_US.UTF-8 boot=casper automatic-ubiquity initrd=/casper/initrd.lz quiet splash noprompt noshell ---"
        Clear-Content "$tmp\iso_org\isolinux\txt.cfg"
        $install_lable | Set-Content "$tmp\iso_org\isolinux\txt.cfg"
    } elseif (@("Kali Linux 2020.04", "Debian 10") -contains $os) {
        # Se copia el preseed base al directorio de trabajo y al archivo copiado, se hacen las modificaciones de las especificaciones para el equipo
        if ($os -eq "Debian 10"){
            Copy-Item ".\recursos\unattend\Debian\preseed.cfg" "$tmp\iso_org" -Force
            (Get-Content "$tmp\iso_org\preseed.cfg").replace('{{paquetes}}', "tree vim git") | Set-Content "$tmp\iso_org\$seed_file"
        } else {
            Copy-Item ".\recursos\unattend\Kali\preseed.cfg" "$tmp\iso_org" -Force
        }
        (Get-Content "$tmp\iso_org\preseed.cfg").replace('{{username}}', $username) | Set-Content "$tmp\iso_org\$seed_file"
        (Get-Content "$tmp\iso_org\preseed.cfg").replace('{{pwhash}}', $pwhash) | Set-Content "$tmp\iso_org\$seed_file"
        (Get-Content "$tmp\iso_org\preseed.cfg").replace('{{hostname}}', $hostname) | Set-Content "$tmp\iso_org\$seed_file"
        (Get-Content "$tmp\iso_org\preseed.cfg").replace('{{timezone}}', $timezone) | Set-Content "$tmp\iso_org\$seed_file"

        # Se copia el preseed del GRUB base al directorio de trabajo y al archivo copiado, se hacen las modificaciones de las especificaciones para el equipo
        Clear-Content "$tmp\iso_org\boot\grub\grub.cfg"
        Copy-Item ".\recursos\unattend\grub.cfg" "$tmp\iso_org\boot\grub\grub.cfg" -Force
        (Get-Content "$tmp\iso_org\boot\grub\grub.cfg").replace('{{hostname}}', $hostname) | Set-Content "$tmp\iso_org\boot\grub\grub.cfg"

        # Se hacen modificaciones al archivo txt.cfg del directorio isolinux, para indicar que se lea el archivo de configuración agregado a la imagen 
        (Get-Content "$tmp\iso_org\isolinux\txt.cfg").replace('label install', 'label unattended') | Set-Content "$tmp\iso_org\isolinux\txt.cfg"
        (Get-Content "$tmp\iso_org\isolinux\txt.cfg").replace('menu label ^Install', 'menu label ^Unattended Install') | Set-Content "$tmp\iso_org\isolinux\txt.cfg"
        $lol = "append preseed/file=/cdrom/preseed.cfg locale=en_US keymap=es hostname=$hostname domain=local.lan vga=788 initrd=/install.amd/initrd.gz --- quiet"
        if ($os -eq "Debian 10") {
            (Get-Content "$tmp\iso_org\isolinux\txt.cfg").replace('append desktop=xfce vga=788 initrd=/install.amd/initrd.gz --- quiet', $lol) | Set-Content "$tmp\iso_org\isolinux\txt.cfg"
        } else {
            (Get-Content "$tmp\iso_org\isolinux\txt.cfg").replace('append preseed/file=/cdrom/simple-cdd/default.preseed simple-cdd/profiles=kali,offline desktop=xfce vga=788 initrd=/install.amd/initrd.gz --- quiet ', $lol) | Set-Content "$tmp\iso_org\isolinux\txt.cfg"
        }
    }
    
    # Se establece el orden de booteo para ver reflejados todos los cambios 
    (Get-Content "$tmp\iso_org\isolinux\isolinux.cfg").replace('timeout 0', 'timeout 60') | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"
    (Get-Content "$tmp\iso_org\isolinux\isolinux.cfg").replace('prompt 0', 'prompt 60') | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"

    # Se mueve al directorio de trabajo para crear el ISO con todo el contenido actual del directorio de trabajo
    Write-Host "Creando ISO Unattended..."
    $pwdrepo = [string](Get-Location)
    $mkisofs = $pwdrepo + "\recursos\exe\mkisofs.exe"
    Set-location $tmp\iso_org
    $rutaIsoSalida = ($tmp+"\"+$hostname+"unattendedISO.iso")
    Invoke-Expression -Command "$mkisofs -D -r -V 'ubuntu-auto' -duplicates-once -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $rutaIsoSalida ." | Invoke-Expression
    Set-Location $pwdrepo
    # Se crea la VM 
    $vmFolder = "E:\SanboxTest\tempUbuntu\vhd"
    New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null
    $vmSwitch = Get-VMSwitch | Where-Object {$_.Name -eq 'SalidaInternet'}
    New-VM -Name $hostname -NewVHDPath "$vmFolder\$hostname.vhdx" -NewVHDSizeBytes 15gb -MemoryStartupBytes 2GB
    Add-VMDvdDrive -VMName $hostname -Path $rutaIsoSalida
    $vmActiveSwitch = Get-VM -Name $hostname -ErrorAction SilentlyContinue | Get-VMNetworkAdapter -ErrorAction SilentlyContinue
    if (! $vmActiveSwitch.SwitchName){
        Write-Host "Adding Switch"
        Get-VM -Name $hostname | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $vmSwitch.Name
    }
    Start-VM -Name $hostname
}
function Crear-ISOCentos {
    param ([string]$password,[string]$hostname, [string] $isoFile, [string]$seed_file, [string]$tmp)
    $timezone = 'America/Mexico_City'
    $pwhash = bash -c "echo $password | mkpasswd -s -m sha-512"
    Crear-DirectorioTrabajo -tmp $tmp
    
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
    xcopy $ISOSource "$tmp\iso_org\" /e

    # Se copia el preseed base al directorio de trabajo y al archivo copiado, se hacen las modificaciones de las especificaciones para el equipo
    Copy-Item ".\recursos\unattend\CentOS\ks.cfg" "$tmp\iso_org" -Force
    (Get-Content "$tmp\iso_org\ks.cfg").replace('{{passwd}}', $pwhash) | Set-Content "$tmp\iso_org\$seed_file"
    (Get-Content "$tmp\iso_org\ks.cfg").replace('{{timezone}}', $timezone) | Set-Content "$tmp\iso_org\$seed_file"
    #(Get-Content "$tmp\iso_org\ks.cfg").replace('{{username}}', $username) | Set-Content "$tmp\iso_org\$seed_file"
    #(Get-Content "$tmp\iso_org\ks.cfg").replace('{{hostname}}', $hostname) | Set-Content "$tmp\iso_org\$seed_file"
    #(Get-Content "$tmp\iso_org\ks.preseed").replace('{{postinstall}}', "apt install vim apache2 whois git") | Set-Content "$tmp\iso_org\$seed_file"
    
    # Dentro del directorio de trabajo, se elimina la configuracion por defecto del ISO y se copia la modificada 
    Remove-Item $tmp\iso_org\isolinux\isolinux.cfg
    Copy-Item ".\recursos\unatted\CentOS\isolinux.cfg" "$tmp\iso_org\isolinux\isolinux.cfg" -Force
    
    # Se establece el orden de booteo para ver reflejados todos los cambios 
    $cambio = "linuxefi /images/pxeboot/vmlinuz  inst.stage2=hd:sr0 inst.ks=cdrom:/ks.cfg quiet"
    (Get-Content "$tmp\iso_org\EFI\BOOT\grub.cfg").replace("menuentry 'Install CentOS Linux 8' --class fedora --class gnu-linux --class gnu --class os", "menuentry 'Kickstart Installation of CentOS 8 PAPIRRI' --class fedora --class gnu-linux --class gnu --class os") | Set-Content "$tmp\iso_org\EFI\BOOT\grub.cfg"
    (Get-Content "$tmp\iso_org\EFI\BOOT\grub.cfg").replace('linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=CentOS-8-3-2011-x86_64-dvd quiet', $cambio) | Set-Content "$tmp\iso_org\EFI\BOOT\grub.cfg"
    (Get-Content "$tmp\iso_org\EFI\BOOT\grub.cfg").replace('set default="1"', 'set default="0"') | Set-Content "$tmp\iso_org\EFI\BOOT\grub.cfg"

    # Se mueve al directorio de trabajo para crear el ISO con todo el contenido actual del directorio de trabajo
    Write-Host "Creando ISO Unattended..."
    $pwdrepo = [string](Get-Location)
    $mkisofs =  $pwdrepo + "\recursos\exe\mkisofs.exe"
    Set-location $tmp\iso_org
    $rutaIsoSalida = ($tmp+"\"+$hostname+"unattendedISO.iso")

    Invoke-Expression -Command "$mkisofs -D -r -V 'linux-auto' -duplicates-once -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $rutaIsoSalida ." | Invoke-Expression
    Set-Location $pwdrepo

    # Se crea la VM 
    $vmFolder = "E:\SanboxTest\tempUbuntu\vhd"
    New-Item -ItemType Directory -Path $vmFolder -Force | Out-Null
    $vmSwitch = Get-VMSwitch | Where-Object {$_.Name -eq 'SalidaInternet'}
    New-VM -Name $hostname -NewVHDPath "$vmFolder\$hostname.vhdx" -NewVHDSizeBytes 24gb -MemoryStartupBytes 1GB
    Add-VMDvdDrive -VMName $hostname -Path $rutaIsoSalida
    $vmActiveSwitch = Get-VM -Name $hostname -ErrorAction SilentlyContinue | Get-VMNetworkAdapter -ErrorAction SilentlyContinue
    if (! $vmActiveSwitch.SwitchName){
        Write-Host "Adding Switch"
        Get-VM -Name $hostname | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $vmSwitch.Name
    }
    Start-VM -Name $hostname
}