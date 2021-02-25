
function Validar-JSON {
    param ([string]$rutaJSON)
    if (Test-Path -Path $rutaJSON) {
        try {
            $contenido = Get-Content -Raw -Path $rutaJSON | ConvertFrom-Json
            return $contenido
        } catch {
            Write-Host "El archivo $rutaJSON no cuenta con un formato JSON correcto."
            exit
        } 
    } else { 
        Write-Host "No se ha encontrado el archivo: $rutaJSON"
        exit
    }
}

function Crear-VSwitch {
    param ([string]$nombre)
    $tiposVirtualSwitch = @("Interno", "Privado", "Externo")
    "`tNo se ha encontrado el Virtual Switch $nombre dentro del Host`n`t"
    "`tTipos de Virtual Switch Disponibles: "
    do {
        for ($i = 0; $i -le ($tiposVirtualSwitch.Count-1); $i++) {
            Write-Host -NoNewline $tiposVirtualSwitch[$i]
            Write-Host " -> Opcion [$i]"
        }
        $tipo = Read-Host -Prompt "`t`tPor favor, ingrese el tipo de VSwitch para $nombre"
    } until ($tipo -in 0..2)
     # Se crea un nuevo virtual Switch del tipo seleccionado por el usuario
    if($tipo -eq 0){
        New-VMSwitch -name $nombre -SwitchType "Internal"
    } elseif($tipo -eq 1) {
        New-VMSwitch -name $nombre -SwitchType "Private"
    } else {
        # Se obtienen los adaptadores de red del equipo
        $adaptadores = Get-NetAdapter
        if($adaptadores.Count -ge 2){
            do {
                for ($i = 0; $i -le ($adaptadores.Count-1); $i++) {
                    Write-Host $adaptadores[$i].Name " -> Opcion [$i]"
                }
                $tipo = Read-Host -Prompt "`t`tPor favor, ingrese el adaptador del VSwitch"
            } until ($tipo -in 0..($adaptadores.Count-1))
            Write-Host  $adaptadores[$tipo].Name
            New-VMSwitch -name $nombre  -NetAdapterName $adaptadores[$tipo].Name | Out-Null
        }
        if($adaptadores.Count -eq 1){
            New-VMSwitch -name $nombre  -NetAdapterName $adaptadores.Name
        }
    }
    "`tSe ha creado satisfactoriamente el VSwitch $nombre"
    return $true
}
function Validar-Raiz {
    param ([string]$rutaRaiz)
    if (Test-Path -Path $rutaRaiz) {
        "Raiz del ambiente: $rutaRaiz"
        return $rutaRaiz
    } else {
        $ficheroAnterior = Split-Path -Path $rutaRaiz
        $leaf = Split-Path -Path $rutaRaiz -Leaf
        if (Test-Path -Path $ficheroAnterior) {
            $respuesta = Read-Host -Prompt "Desea crear el fichero $leaf dentro de $ficheroAnterior y usarlo como raiz para el ambiente? [S/N]"
            if ($respuesta -eq "S" -or $respuesta -eq "s") {
                New-Item -Path $rutaRaiz -ItemType "directory"
                "Se ha creado la carpeta $leaf.`nRaiz del ambiente: $rutaRaiz"
                return $rutaRaiz
            }
        } else {
            "Error en el path ingresado como raiz del proyecto.`nNo existe el padre de la ruta proporcionada o no se tienen los permisos suficientes para poder crear el proyecto dentro de $ficheroAnterior. Revisar archivo JSON"
            exit
        }
    }
}
# Función para consultar los Virtual Switches existentes dentro del Host Hyper-V
function Consultar-VSwitchDisponibles {
    param ([string]$nombreVirtualSwitch)
    $existentes = Get-VMSwitch
    $encontrados = @()
    foreach ($switch in $existentes) {
        $encontrados += $switch.Name        
    }
    if ($encontrados -contains $nombreVirtualSwitch) {
        return $true
    } else {
        Crear-VSwitch -nombre $nombreVirtualSwitch
    }
}

function Almacenamiento-Disponible {
    param ([int]$diskSize, [string]$letterRoot)
    $espacioDisponible = (Get-WmiObject -Class Win32_logicaldisk -Filter "DeviceID = '$letterRoot'" | Select-Object -ExpandProperty  FreeSpace @{L='FreeSpace';E={"{0:0}" -f ($_.FreeSpace /1GB)}}) / 1GB
    $libre = [math]::Round($espacioDisponible,2)
    if (($libre - $diskSize) -le 0) {
        "`tNo se cuenta con el suficiente espacio de almacenamiento disponible para crear el siguiente VHDX solicitado."
        "`tAlmacenamiento disponible: $libre GB | Tamanio del disco solicitado: $diskSize GB"
        exit
    }
    return ($libre - $diskSize)
}

# Funcion para revisar el maximo de memoria RAM dentro del host de Hyper-V
function Consultar-Memoria {
    $ram = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $ram = $ram.Sum/1GB
    return $ram
}

function Validar-SistemaOperativo {
    param ([string]$SOPorRevisar)
    $poolSistemas = @("Windows Server 2019","Windows 10", "Ubuntu", "CentOS","CentOS Stream", "FortiOS", "RHEL", "Kali")
    if ($poolSistemas -contains $SOPorRevisar) { 
        return $SOPorRevisar 
    } else {
        "ERROR: Ingresa el nombre de alguno de los siguientes sistemas operativos disponibles para la herramienta: "
        foreach ($item in $poolSistemas) { Write-Host "$item" }
        exit
    }
}

function Validar-VHDX {
    param ([array]$listaDiscosPorCrear, [string]$letterRoot)
    Write-Host "Discos Virtuales"
    if ($listaDiscosPorCrear.Count -ne 0) { # Si se encuetra al menos un valor especificado dentro del arreglo de VHDs
        if ($listaDiscosPorCrear.Count -eq 1) {
             Write-Host "`tVHD encontrado: $listaDiscosPorCrear GB"
             $postCreacionDisco = Almacenamiento-Disponible -diskSize $listaDiscosPorCrear[0] -letterRoot $letterRoot
             return $listaDiscosPorCrear
        } else {
            for ($i=0; $i -lt ($listaDiscosPorCrear.Count); $i++) {
                $temp = $listaDiscosPorCrear[$i]
                if ($i -eq 0) {
                    $postCreacionDisco = Almacenamiento-Disponible -diskSize $listaDiscosPorCrear[0] -letterRoot $letterRoot
                    Write-Host "`tVHDX encontrado: $temp GB"
                } else {
                     $libre = $postCreacionDisco - $temp
                     if ($libre -le 0) {
                        "`tNo se cuenta con el suficiente espacio de almacenamiento disponible para crear el siguiente VHDX solicitado."
                        "`tAlmacenamiento disponible: $($libre+$temp)  GB | Tamanio del disco solicitado: $temp GB"
                        exit
                    }
                    Write-Host "`tVHDX encontrado: $temp GB"
                    $postCreacionDisco = $libre
               }
            }
            Write-Host "`t`tQuedara el siguiente espacio libre dentro del disco seleccionado como raiz al crear los VHDX solicitados: $postCreacionDisco GB"
            return $listaDiscosPorCrear
        }
    } else {
        "Se debe especificar el tamaño de al menos un disco virtual (VHDX) a crear para el equipo."
        exit
    }
}

function Validar-Redes {
    param ($interfaces)
    Write-Host "Interfaces de red y VSwitches" 
    if ($interfaces.Count -ne 0) {
        $regexIPValida = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
        $nombresInterfacesEncontradas = @()
        $switchesVirtualesAsociados = @()
        foreach ($configuracion in $interfaces) {
            $vsAsociado = $configuracion.VirtualSwitch
            if ( -not (Consultar-VSwitchDisponibles -nombreVirtualSwitch $vsAsociado)) {
                Crear-VSwitch -nombre $vsAsociado
            }
            $switchesVirtualesAsociados += $vsAsociado
            $name = $configuracion.Nombre
            $ip = $configuracion.IP
            if ($ip -match $regexIPValida) {
                $mascara = $configuracion.Mask
                if ($mascara -match $regexIPValida) {
                    $gateway = $configuracion.Gateway
                    $dns = $configuracion.DNS
                } else{
                    "`tNo se ha ingresado una mascara valida para la red '$name'. Revisa archivo de entrada"
                    exit
                }
            } else {
                "`tNo se ha ingresado una IP valida para la red '$name'. Revisa archivo de entrada"
                exit
            }
            Write-Host "`tConfiguracion encontrada y validada para la red '$name': "
            Write-Host "`t`tDireccion IP: $ip, Mascara: $mascara, Gateway: $gateway, DNS: $dns"
            return $interfaces
            $nombresInterfacesEncontradas += $name
        }
    } else {
        "`tNo se han encontrado interfaces de red para el equipo."
        exit
    }
}

function Obtener-VersionesDeWindows {
    param ([string]$WinIso, [string]$VhdFile, [string]$UnattendFile)
    Write-Progress "Mounting $WinIso ..."
    $MountResult = Mount-DiskImage -ImagePath $WinIso -StorageType ISO -PassThru
    $DriveLetter = ($MountResult | Get-Volume).DriveLetter
    if (-not $DriveLetter) {
      Write-Error "ISO file not loaded correctly" -ErrorAction Continue
      Dismount-DiskImage -ImagePath $WinIso | Out-Null
      return
    }
    Write-Progress "Mounting $WinIso ... Done"

    $WimFile = "$($DriveLetter):\sources\install.wim"
    Write-Host "Inspecting $WimFile"
    $WimOutput = dism /get-wiminfo /wimfile:"$WimFile" | Out-String

    $WimInfo = $WimOutput | Select-String "(?smi)Index : (?<Id>\d+).*?Name : (?<Name>[^`r`n]+)" -AllMatches
    if (!$WimInfo.Matches) {
      Write-Error "Images not found in install.wim`r`n$WimOutput" -ErrorAction Continue
      Dismount-DiskImage -ImagePath $WinIso | Out-Null
      return
    }

    $Items = @{ }
    $Menu = ""
    $DefaultIndex = 1
    $WimInfo.Matches | ForEach-Object { 
      $Items.Add([int]$_.Groups["Id"].Value, $_.Groups["Name"].Value)
      $Menu += $_.Groups["Id"].Value + ") " + $_.Groups["Name"].Value + "`r`n"
      if ($_.Groups["Name"].Value -eq $WinEdition) {
        $DefaultIndex = [int]$_.Groups["Id"].Value
      }
    }

    Write-Output $Menu
    do {
      try {
        $err = $false
        $WimIdx = if (([int]$val = Read-Host "Please select version [$DefaultIndex]") -eq "") { $DefaultIndex } else { $val }
        if (-not $Items.ContainsKey($WimIdx)) { $err = $true }
      }
      catch {
        $err = $true;
      }
    } while ($err)
    Write-Output $Items[$WimIdx]

    [char] $VirtualWinLetter = $DriveLetter
    $VirtualWinLetter = [byte] $VirtualWinLetter + 1

    Mount-DiskImage -ImagePath $VhdFile | Out-Null
    $disknumber = (Get-DiskImage -ImagePath $VhdFile | Get-Disk).Number

    [char] $EfiLetter = [byte] $VirtualWinLetter + 1
    
    Write-Host "Montando discos..."

    "select disk $DiskNumber`nconvert gpt`nselect partition 1`ndelete partition override`ncreate partition primary size=300`nformat quick fs=ntfs `
    create partition efi size=100`nformat quick fs=fat32`nassign letter=$EfiLetter`ncreate partition msr size=128`ncreate partition primary`nformat quick fs=ntfs `
    assign letter=$VirtualWinLetter`nexit`n" | diskpart | Out-Null

    Invoke-Expression "dism /apply-image /imagefile:`"$WimFile`" /index:$WimIdx /applydir:$($VirtualWinLetter):\"

    Write-Host "Preparando la instalacion..."

    Invoke-Expression "$($VirtualWinLetter):\Windows\System32\bcdboot.exe $($VirtualWinLetter):\Windows /f uefi /s $($EfiLetter):"
    #Invoke-Expression $VirtualWinLetter":\Windows\System32\bcdboot.exe" #$VirtualWinLetter":\Windows /f uefi /s "$EfiLetter":"
    Invoke-Expression "bcdedit /store $($EfiLetter):\EFI\Microsoft\Boot\BCD"

    #$UnattendFile = ".\unattend.xml"

    if($UnattendFile) {
        Write-Host "Copying unattend.xml"
        New-Item -ItemType "directory" -Path "$($VirtualWinLetter):\Windows\Panther\" | Out-Null
        Copy-Item $UnattendFile "$($VirtualWinLetter):\Windows\Panther\unattend.xml" | Out-Null
      }

    "select disk $disknumber`nselect partition 2`nremove letter=$EfiLetter`nselect partition 4`nremove letter=$VirtualWinLetter`nexit`n" | diskpart | Out-Null
    Dismount-DiskImage -ImagePath $VhdFile | Out-Null
    Dismount-DiskImage -ImagePath $WinIso | Out-Null
}

function Validar-RAM {
    param ($tamanioMemoria=1024, $minMemoria=0, $maxMemoria=0)
    Write-Host "Memoria RAM"
    if(($tamanioMemoria -or ($minMemoria -and $maxMemoria)) -in 1..(Consultar-Memoria)){
        if($PSBoundParameters.Count -eq 1){
            Write-Host "`tTamano de memoria $tamanioMemoria GB."
            return $tamanioMemoria
        }else{
            if($minMemoria -lt $maxMemoria){
                Write-Host "`tMemoria maxima $maxMemoria GB."
                Write-Host "`tMemoria minima $minMemoria GB."
                return $minMemoria, $maxMemoria
            }else{
                Write-Host "La memoria minima debe ser menor a la memoria maxima ingresada`nMemoria minima: $minMemoria`nMemoria maxima: $maxMemoria"
                exit
            }
        }
    }else{
        "Se debe ingresar un tamanio menor al de la memoria RAM disponible"
        exit
    }
}

function Validar-Procesadores {
    param ($numeroProcesadores)
    Write-Host "Procesadores"
    if ($numeroProcesadores -ne 0 -and $numeroProcesadores -ge 1) {
        Write-Host "`tNumero de procesadores: $numeroProcesadores" 
        return $numeroProcesadores
    } else {
        Write-Host "`tIngrese un numero valido de procesadores para el equipo '$hostname'. Revisar archivo JSON."
        exit
    }
}

function Validar-Credenciales {
    param ($usuario, $passwd)
    Write-Host "Credenciales Administrativas"
    if (($usuario -or $passwd) -ne "") {
        if($usuario -match "^[a-zA-Z0-9]{4,19}[a-zA-Z]$"){
            if($passwd -match "^[\x20-\x7E]{10,30}$"){
                Write-Host "`tSe usaron las siguientes credenciales para el equipo:"
                Write-Host "`t`tUsername: $usuario"
                Write-Host "`t`tPassword: $passwd"
                return $usuario, $passwd
            }else{
                Write-Host "La contrasena  debe tener una longitud de entre 10 y 30 caracteres"
                exit
            }
        }else{
            Write-Host "El usuario debe: `nContener solo letras y numeros `nTener una longitud de entre 5 y 20 caracteres"
            exit
        }
    }else{
        Write-Host "`tEl campo no debe estar vacio, ingresan credenciales validas"
        exit
    }
}

function Validar-ISO {
    param ([string]$imagen)
    Write-Host "Imagen a instalar dentro del equipo"
    if ($imagen -ne "") {
       if (Test-Path -Path $imagen) {
           Write-Host "`tSe usara la siguiente imagen para este equipo: $imagen"
           return $imagen
       } else {
           Write-Host "`tNo se ha podido acceder a la ruta de la imagen dentro del archivo de entrada. Revisar el archivo JSON."
           exit
       }
    } else {
       Write-Host "`tIngrese una ruta para la imagen del SO a instalar dentro del equipo"
       exit
    }
}

function Validar-Hostname {
    param ($hostname)
    if($hostname -match "^([a-zA-z]+[0-9]*[.-]?)+[a-zA-Z]+$"){
        return $hostname
    }else{
        Write-Host 'El hostname solamente puede contener letras, numeros y los siguientes caracteres especiales: "." (punto) y "-" (guion)'
        exit
    }
}

function Consultar-RolHyperV {
    $rol = Get-WindowsFeature -Name  Hyper-V | Where-Object { $_.InstallState -eq "Installed"}
    if ($rol.Count -ne 1) {
        # En caso de no encontrar el rol de Hyper-V procede a su instalacion
        $computer = hostname
        Write-Host "`tNo se encuentra instalado el rol de Hyper-V, el rol sera instalado y el equipo se reiniciara. Ejecute nuevamente el programa al iniciar."
        Install-WindowsFeature -Name Hyper-V -ComputerName $computer -IncludeManagementTools -Restart
        exit
    }
}

function Modificar-Unattend {
    param ([string]$username ,[string]$passwd, [string]$rutaXML)
    if (Test-Path -Path $rutaXML) {
        try {
            [XML]$xml = Get-Content $rutaXML
            $xml.unattend.settings.component.AutoLogon.Password.Value = $passwd 
            $xml.unattend.settings.component.UserAccounts.LocalAccounts.LocalAccount.Password.Value = $passwd
            $xml.unattend.settings.component.UserAccounts.LocalAccounts.LocalAccount.DisplayName = $username
            $xml.unattend.settings.component.UserAccounts.LocalAccounts.LocalAccount.Name = $username
            $xml.unattend.settings.component.AutoLogon.Username = $username
            $xml.Save($rutaXML)
            "Arhivo $rutaXML modificado correctamente"
        } catch {
            "Error al aplicar cambios dentro del XML"
            exit
        }
    } else {
        "No se encuentra la ruta del archivo XML para 'Unattend'"
        exit
    }
}

function Validar-DatosEntrada {
    param ([int]$contadorVMs, $archivoEntrada, $dominiosExistentes)
    for ($j=0;$j -le $contadorVMs;$j++) {

        # Se recuperan los datos obligatorios independientemente del tipo de SO y se valida que sean correctos
        $raiz = $archivoEntrada.Root
        $hostname = Validar-Hostname -hostname $archivoEntrada.VMs[$j].Hostname # String
        $sistemaOperativo = Validar-SistemaOperativo -SOPorRevisar $archivoEntrada.VMs[$j].SO # String
        Write-Host "DATOS DEL EQUIPO  $sistemaOperativo | $hostname :"
        $usuario, $passwd = Validar-Credenciales -usuario $archivoEntrada.VMs[$j].User -passwd $archivoEntrada.VMs[$j].Password
        $tipoDeMemoria = $archivoEntrada.VMs[$j].MemoryType
        if($tipoDeMemoria -eq "Static"){
            $tamanioMemoria = Validar-RAM -tamanioMemoria $archivoEntrada.VMs[$j].MemorySize
            Write-Host "$tamanioMemoria`n$tipoDeMemoria"
        }elseif($tipoDeMemoria -eq "Dynamic"){
            $minMemoria, $maxMemoria = Validar-RAM -minMemoria $archivoEntrada.VMs[$j].MemoryMin -maxMemoria $archivoEntrada.VMs[$j].MemoryMax
        }else{
            "Los unicos tipos de memorias aceptadas son 'Dynamic' y 'Static'.`nRevise archivo JSON."
            exit
        }
        $discos = Validar-VHDX -listaDiscosPorCrear $archivoEntrada.VMs[$j].DiskSize -letterRoot (-join $raiz[0,1])
        $imagen = Validar-ISO -imagen $archivoEntrada.VMs[$j].ImagePath
        $interfaces = Validar-Redes -interfaces $archivoEntrada.VMs[$j].InterfaceConfig # Se validan las configuraciones de red para todas las interfaces
        $numeroProcesadores = Validar-Procesadores -numeroProcesadores $archivoEntrada.VMs[$j].ProcessorNumber
        #"Se han validado los datos de entrada del equipo $hostname"
        #Datos particulares dependiendo del SO
        switch -regex  ($sistemaOperativo) {
            "Windows*" { 
                try {
                    $rutaUnattend = ".\recursos\unattend.xml"
                    Test-Path -Path $rutaUnattend | Out-Null
                    $rutasMSI = $archivoEntrada.VMs[$j].MsiPaths
                    foreach($path in $rutasMSI) {
                        if (-not (Test-Path -Path $path)) {
                            "No se encuentra el archivo .msi indicado en la ruta: $path`nRevise archivo de configuracion"
                            exit
                        }
                    }
                } catch {
                    "Error datos extra Windows."
                    exit
                }
            }
        }
    }
}