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
    $MountResult = Mount-DiskImage -ImagePath $WinIso -StorageType ISO -PassThru
    $DriveLetter = ($MountResult | Get-Volume).DriveLetter
    $WimFile = "$($DriveLetter):\sources\install.wim"
    $tipoAmbiente = $maquina.DatosDependientes.TipoAmbiente

    if($tipoAmbiente[2] -match "[0-9]"){
        $WimIdx = -join ($tipoAmbiente[1..2])
    }else{
        $WimIdx = $tipoAmbiente[1]
    }

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
    Copy-Item $UnattendFile "$($VirtualWinLetter):\Windows\Panther\unattend.xml" | Out-Null
    Remove-Item $UnattendFile
    "select disk $disknumber`nselect partition 2`nremove letter=$EfiLetter`nselect partition 4`nremove letter=$VirtualWinLetter`nexit`n" | diskpart | Out-Null
    Dismount-DiskImage -ImagePath $VhdFile | Out-Null
    Dismount-DiskImage -ImagePath $WinIso | Out-Null
}