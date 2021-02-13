function Crear-ISOUbuntu {
    param ([string ]$username, [string] $password,[string]$hostname, [string] $isoFile, [string]$seed_file, [string]$tmp)
    $timezone = 'America/Mexico_City'
    $rootPassword = $password
    $pwhash = bash -c "echo $password | mkpasswd -s -m sha-512"
    $rootPwdHash = bash -c "echo $rootPassword | mkpasswd -s -m sha-512"
    
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

    # Se copia el preseed base al directorio de trabajo y al archivo copiado, se hacen las modificaciones de las especificaciones para el equipo
    Copy-Item ".\recursos\ks.preseed" "$tmp\iso_org" -Force
    (Get-Content "$tmp\iso_org\ks.preseed").replace('{{username}}', $username) | Set-Content "$tmp\iso_org\$seed_file"
    (Get-Content "$tmp\iso_org\ks.preseed").replace('{{pwhash}}', $pwhash) | Set-Content "$tmp\iso_org\$seed_file"
    #(Get-Content "$tmp\iso_org\ks.preseed").replace('{{postinstall}}', "apt install vim apache2 whois git") | Set-Content "$tmp\iso_org\$seed_file"
    (Get-Content "$tmp\iso_org\ks.preseed").replace('{{hostname}}', $hostname) | Set-Content "$tmp\iso_org\$seed_file"
    (Get-Content "$tmp\iso_org\ks.preseed").replace('{{timezone}}', $timezone) | Set-Content "$tmp\iso_org\$seed_file"

    # Se le agrega extension a algunos archivos necesarios para crear el ISO
    Rename-Item -Path "$tmp\iso_org\casper\initrd" -NewName "initrd.lz"
    Rename-Item -Path "$tmp\iso_org\casper\vmlinuz" -NewName "vmlinuz.efi"

    # Se modifica el archivo txt.cfg, el cual contiene las respuestas que instalación y se indican detalles de la instalación desatendida:
    #$rep = Get-Location
    #$install_lable="default install`nlabel install`n  menu label ^Automatically install Ubuntu`n  kernel /install/vmlinuz`n  append file=/cdrom/ks.preseed  auto=true priority=critical debian-installer/locale=en_US keyboard-configuration/layoutcode=us ubiquity/reboot=true languagechooser/language-name=English countrychooser/shortlist=US localechooser/supported-locales=en_US.UTF-8 automatic-ubiquity initrd=/install/initrd.gz quiet splash noprompt noshell ---"
    $install_lable="default live-install`nlabel live-install`n  menu label ^Install Ubuntu`n  kernel /casper/vmlinuz.efi`n  append  file=/cdrom/ks.preseed auto=true priority=critical debian-installer/locale=en_US keyboard-configuration/layoutcode=us ubiquity/reboot=true languagechooser/language-name=English countrychooser/shortlist=US localechooser/supported-locales=en_US.UTF-8 boot=casper automatic-ubiquity initrd=/casper/initrd.lz quiet splash noprompt noshell ---"
    Clear-Content "$tmp\iso_org\isolinux\txt.cfg"
    $install_lable | Set-Content "$tmp\iso_org\isolinux\txt.cfg"
    
    # Se establece el orden de booteo para ver reflejados todos los cambios 
    (Get-Content "$tmp\iso_org\isolinux\isolinux.cfg").replace('timeout 0', 'timeout 1') | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"
    (Get-Content "$tmp\iso_org\isolinux\isolinux.cfg").replace('prompt 0', 'prompt 1') | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"

    # Se mueve al directorio de trabajo para crear el ISO con todo el contenido actual del directorio de trabajo
    Write-Host "Creando ISO Unattended..."
    $mkisofs = [string](Get-Location) + "\recursos\exe\mkisofs.exe"
    Set-location $tmp\iso_org
    $rutaIsoSalida = ($tmp+"\"+$hostname+"unattendedISO.iso")
    Write-Host "Ruta mkiso: " $mkisofs
    Invoke-Expression -Command "$mkisofs -D -r -V 'ubuntu-auto' -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $rutaIsoSalida ." | Invoke-Expression
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