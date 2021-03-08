function CrearVHDWindows { param ([string]$WinIso, [string]$VhdFile, $maquina)
    function ModificarUnattend {
      $rutaOriginalXML = $maquina.DatosDependientes.ArchivoXML
      $rutaXML = "$((Get-Item $rutaOriginalXML).Directory.Parent.FullName)\tmp.xml"
      Copy-Item $rutaOriginalXML -Destination $rutaXML
      [string] $hostname = $maquina.Hostname
      [string] $passwd = $maquina.Credenciales.Contrasena
      [string] $username = $maquina.Credenciales.Usuario
      [string] $llaveActivacion = $maquina.DatosDependientes.LlaveActivacion
      (Get-Content "$rutaXML").replace('{{hostname}}', $hostname) | Set-Content "$rutaXML"
      (Get-Content "$rutaXML").replace('{{autoUsername}}', $username) | Set-Content "$rutaXML"
      (Get-Content "$rutaXML").replace('{{autoPassword}}', $passwd) | Set-Content "$rutaXML"
      (Get-Content "$rutaXML").replace('{{displayUsername}}', $username) | Set-Content "$rutaXML"
      (Get-Content "$rutaXML").replace('{{localUsername}}', $username) | Set-Content "$rutaXML"
      (Get-Content "$rutaXML").replace('{{localPassword}}', $passwd) | Set-Content "$rutaXML"
      (Get-Content "$rutaXML").replace('{{llaveActivacion}}', $llaveActivacion) | Set-Content "$rutaXML"
      return $rutaXML
    }

    #$MountResult = Mount-DiskImage -ImagePath $WinIso -StorageType ISO -PassThru
    #$DriveLetter = ($MountResult | Get-Volume).DriveLetter
    $DriveLetter = "J"
    $WimFile = "$($DriveLetter):\sources\install.wim"
    #$tipoAmbiente = $maquina.DatosDependientes.TipoAmbiente
    #if($tipoAmbiente[2] -match "[0-9]"){
    #    $WimIdx = -join ($tipoAmbiente[1..2])
    #}else{
    #    $WimIdx = $tipoAmbiente[1]
    #}
    $WimIdx = 2
    [char] $VirtualWinLetter = $DriveLetter
    $VirtualWinLetter = [byte] $VirtualWinLetter + 1
    Mount-DiskImage -ImagePath $VhdFile | Out-Null
    $disknumber = (Get-DiskImage -ImagePath $VhdFile | Get-Disk).Number
    [char] $EfiLetter = [byte] $VirtualWinLetter + 1
    "select disk $disknumber`nconvert gpt`nselect partition 1`ndelete partition override`ncreate partition primary size=300`nformat quick fs=ntfs `
    create partition efi size=100`nformat quick fs=fat32`nassign letter=$EfiLetter`ncreate partition msr size=128`ncreate partition primary`nformat quick fs=ntfs `
    assign letter=$VirtualWinLetter`nexit`n" | diskpart | Out-Null
    $UnattendFile = ModificarUnattend
    Invoke-Expression "dism /apply-image /imagefile:`"$WimFile`" /index:$WimIdx /applydir:$($VirtualWinLetter):\" 
    Invoke-Expression "$($VirtualWinLetter):\Windows\System32\bcdboot.exe $($VirtualWinLetter):\Windows /f uefi /s $($EfiLetter):" | Out-Null
    Invoke-Expression "bcdedit /store $($EfiLetter):\EFI\Microsoft\Boot\BCD" | Out-Null
    New-Item -ItemType "directory" -Path "$($VirtualWinLetter):\Windows\Panther\" | Out-Null
    
    # Se crean los folders de trabajo dentro la VM:
    New-Item -ItemType "Directory" -Path "$($VirtualWinLetter):\sources\`$OEM`$" | Out-Null
    New-Item -ItemType "Directory" -Path "$($VirtualWinLetter):\sources\`$OEM`$\`$1" | Out-Null

    # Se copia el JSON  con el objeto máquina y el script para instalar servicios dentro ded los folders de trabajo:
    Copy-Item -Path ".\Recursos\unattend\tmp.json" "$($VirtualWinLetter):\sources\`$OEM`$\`$1" | Out-Null
    Copy-Item -Path ".\Recursos\unattend\Windows\InstalarServiciosWindows.ps1" "$($VirtualWinLetter):\sources\`$OEM`$\`$1" | Out-Null

    # Se copian los .msi y creación del script para inslaralos al bootear:
    if($maquina.SistemaOperativo -eq "Windows 10"){
        New-Item -ItemType "Directory" -Path "$($VirtualWinLetter):\sources\`$OEM`$\`$`$" | Out-Null
        New-Item -ItemType "Directory" -Path "$($VirtualWinLetter):\sources\`$OEM`$\`$`$\Setup" | Out-Null
        New-Item -ItemType "Directory" -Path "$($VirtualWinLetter):\sources\`$OEM`$\`$`$\Setup\Scripts" | Out-Null
        $comandoMSI = "@echo off`n"
        $cont = 0
        $msi = $maquina.DatosDependientes.RutaMSI
        foreach ($ruta in $msi) {
            Copy-Item $ruta "$($VirtualWinLetter):\sources\`$OEM`$\`$`$\Setup\Scripts\paquete-$cont.msi"
            $comandoMSI += "msiexec /passive /i C:\sources\`$OEM`$\`$`$\Setup\Scripts\paquete-$cont.msi`n"
            $cont++
        }
        
        Set-Content -Path "$($VirtualWinLetter):\sources\`$OEM`$\`$`$\Setup\Scripts\SetupComplete.cmd" -Value $comandoMSI | Out-Null
        $SetupComplete = "<SynchronousCommand wcm:action=`"add`"> `
            <CommandLine>C:\sources\`$OEM`$\`$`$\Setup\Scripts\SetupComplete.cmd</CommandLine> `
            <Order>3</Order> `
            <RequiresUserInput>false</RequiresUserInput> `
        </SynchronousCommand>"
        (Get-Content "$UnattendFile").replace('{{MSI}}', $SetupComplete) | Set-Content "$UnattendFile"
        (Get-Content "$UnattendFile").replace('{{AdminAccount}}', "") | Set-Content "$UnattendFile"
    }else{
        [string] $passwd = $maquina.Credenciales.Contrasena
        $adminAcc = "<AdministratorPassword> `
        <Value>$passwd</Value>`
        <PlainText>true</PlainText>`
        </AdministratorPassword>"
        (Get-Content "$UnattendFile").replace('{{MSI}}', "") | Set-Content "$UnattendFile"
        (Get-Content "$UnattendFile").replace('{{AdminAccount}}', $adminAcc) | Set-Content "$UnattendFile"
        Copy-Item -Path ".\Recursos\unattend\Windows\ConfigurarServiciosWindows.ps1" "$($VirtualWinLetter):\sources\`$OEM`$\`$1" | Out-Null
        if($maquina.Servicios.DNS){foreach($zona in $maquina.Servicios.DNS){if($zona.Backup){Copy-Item -Path $zona.Backup "$($VirtualWinLetter):\sources\`$OEM`$\`$1"}}}
    }
    # Se aplican los cambios dentro del xml 
    Copy-Item $UnattendFile "$($VirtualWinLetter):\Windows\Panther\unattend.xml" | Out-Null
    Remove-Item $UnattendFile
    
    # Se aplican cambios al vdhx y se desmotan los discos/ISO montados:
    "select disk $disknumber`nselect partition 2`nremove letter=$EfiLetter`nselect partition 4`nremove letter=$VirtualWinLetter`nexit`n" | diskpart | Out-Null
    Dismount-DiskImage -ImagePath $VhdFile | Out-Null
    Dismount-DiskImage -ImagePath $WinIso | Out-Null
}