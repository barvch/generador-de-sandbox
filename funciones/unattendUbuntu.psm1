function Crear-ISOUbuntu {
    param ([string ]$username, [string] $password,[string]$hostname, [string] $isoFile, [string]$seed_file, [string]$tmp)
    $timezone = 'America/Mexico_City'
    $rootPassword = $password
    $pwhash = bash -c "echo $password | mkpasswd -s -m sha-512"
    $rootPwdHash = bash -c "echo $rootPassword | mkpasswd -s -m sha-512"
    
    # Creating / Verifying Required Folder Structure is available to work
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
    
    # Mounting C:\LabSources\ISOs\ubuntu-16.04.1-server-amd64.iso file and copy content locally
    Write-Host "Montando ISO de Ubuntu..." -ForegroundColor Yellow
    $ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
    if(! $ISODrive){
        Mount-DiskImage -ImagePath $isoFile -StorageType ISO
    }
    $ISODrive = (Get-DiskImage $isoFile | Get-Volume).DriveLetter
    Write-Host ("El drive asignado al Host para el ISO $isoFile es: " + $ISODrive)
    
    Write-Host "Copiando el contenido del ISO al directorio de trabajo: $temp\iso_org" -ForegroundColor Yellow
    $ISOSource = ("$ISODrive" + ":\*.*")
    xcopy $ISOSource "$tmp\iso_org\" /e
    
    try {
        # Copy baseline Kickstart Configuration File To Working Folder
        Copy-Item ".\recursos\ksUbuntu16.cfg" -Destination "$tmp\iso_org" -Force
        
        # Copy baseline Seed File (answers for unattended setup) To Working Folder
        Copy-Item ".\recursos\semilla.seed" "$tmp\iso_org" -Force
    } catch {
        ":("
    }
   
    
    # Update the ks.cfg file to reflect encrypted root password hash
    (Get-Content "$tmp\iso_org\ksUbuntu16.cfg").replace("rootpw --disabled","rootpw --iscrypted $rootPwdHash" ) | Set-Content "$tmp\iso_org\ksUbuntu16.cfg"
    
    # Update the seed file to reflect the users' choices
    (Get-Content "$tmp\iso_org\semilla.seed").replace('{{username}}', $username) | Set-Content "$tmp\iso_org\$seed_file"
    (Get-Content "$tmp\iso_org\semilla.seed").replace('{{pwhash}}', $pwhash) | Set-Content "$tmp\iso_org\$seed_file"
    (Get-Content "$tmp\iso_org\semilla.seed").replace('{{hostname}}', $hostname) | Set-Content "$tmp\iso_org\$seed_file"
    (Get-Content "$tmp\iso_org\semilla.seed").replace('{{timezone}}', $timezone) | Set-Content "$tmp\iso_org\$seed_file"
    
    # Update the isolinux.cfg file to reflect boot time choices
    #(Get-Content "$tmp\iso_org\isolinux\isolinux.cfg").replace('timeout 0', 'timeout 1') | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"
    #(Get-Content "$tmp\iso_org\isolinux\isolinux.cfg").replace('prompt 0', 'prompt 1') | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"
    
    # Building installer menu choice to make it default and use ks.cfg and mshende.seed files
    #$install_lable = "default autoinstall`nlabel autoinstall`nmenu label ^Automatically install Ubuntu`nkernel /install/vmlinuz`nappend file=/cdrom/preseed/ubuntu-server.seed vga=788 initrd=/install/initrd.gz ks=cdrom:/ksUbuntu16.cfg preseed/file=/cdrom/semilla.seed quiet --"
    $install_lable="default autoinstall`nlabel autoinstall`nmenu label ^Automatically install Ubuntu`nkernel /install/vmlinuz`nappend  ks=/cdrom/semilla.seed auto=true priority=critical debian-installer/locale=en_US keyboard-configuration/layoutcode=us ubiquity/reboot=true languagechooser/language-name=English countrychooser/shortlist=US localechooser/supported-locales=en_US.UTF-8 boot=casper automatic-ubiquity initrd=/install/initrd.gz quiet splash noprompt noshell ---"
    Clear-Content "$tmp\iso_org\isolinux\isolinux.cfg"
    #(Get-Content "$tmp\iso_org\isolinux\isolinux.cfg").replace('*', $install_lable) | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"
    $install_lable | Set-Content "$tmp\iso_org\isolinux\isolinux.cfg"
    
    # Creating new ISO file at C:\LabSources\ISOs\ubuntu-16.04.1-server-amd64-unattended.iso
    Write-Host " Creating the remastered iso"
    Set-location "$tmp\iso_org"
    C:\Users\Administrator\Downloads\mkisofs-md5-2.01-Sample\Binary\Sample\mkisofs.exe -D -r -V "UBUNTU1604SRV" -duplicates-once -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ($tmp+"\"+$hostname+"unattendedISO.iso") .
   #C:\Users\Administrator\Downloads\mkisofs-md5-2.01-Sample\Binary\Sample\mkisofs.exe -D -r -V "ATTENDLESS_UBUNTU" -duplicates-once -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $tmp+"\"+$hostname+"unattendedISO.iso" .
    #vmconnect.exe localhost $hostname
}