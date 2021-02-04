# C:\ProgramData\Microsoft\Windows\Hyper-V

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
        New-VMSwitch -name $nombre -SwitchType Internal
    } elseif($tipo -eq 1) {
        New-VMSwitch -name $nombre -SwitchType Private
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
            New-VMSwitch -name $nombre  -NetAdapterName $adaptadores[$tipo].Name
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

# Función para crear un Virtual Switch cuando se ingresa el nombre de un VS que no está presente dentro del equipo


# Funcion para revisar el almacenamiento disponible en disco y validar que exista suficiente espacio para crear el VHD 

function Almacenamiento-Disponible {
    param ([int]$diskSize)
    #Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = '3'" | Select-Object -Property DeviceID, DriveType, VolumeName, @{L='FreeSpaceGB';E={"{0:N2}" -f ($_.FreeSpace /1GB)}}
    $arrayDiscosDisponibles = Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = '3'" | Select-Object -ExpandProperty  FreeSpace @{L='FreeSpace';E={"{0:0}" -f ($_.FreeSpace /1GB)}}
    for ($i=0; $i -le ($arrayDiscosDisponibles.Count-1); $i++) {
        $libre = ($arrayDiscosDisponibles[$i]/1GB)
        $libre = [math]::Round($libre,2)
        if (($libre - $diskSize) -le 0) {
            "`tNo se cuenta con el suficiente espacio de almacenamiento disponible para crear el VHD solicitado."
            "`tAlmacenamiento disponible: $libre GB | Tama�o del disco solicitado: $diskSize GB XXXX"
            exit
        }
        return ($libre - $diskSize)
    }
}

# Funcion para revisar el m�ximo de memoria RAM dentro del host de Hyper-V
function Consultar-Memoria {
    $ram = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $ram = $ram.Sum/1GB
    return $ram
}

function Validar-SistemaOperativo {
    param ([string]$SOPorRevisar)
    $poolSistemas = @("Windows Server 2019","Windows10", "Ubuntu", "CentOS","CentOS Stream", "FortiOS", "RHEL", "Kali")
    if ($poolSistemas -contains $SOPorRevisar) { 
        return $SOPorRevisar 
    } else {
        "ERROR: Ingresa el nombre de alguno de los siguientes sistemas operativos disponibles para la herramienta: "
        foreach ($item in $poolSistemas) { Write-Host "$item" }
        exit
    }
}

function Validar-VHDX {
    param ([array]$listaDiscosPorCrear)
    Write-Host "Discos Virtuales"
    if ($listaDiscosPorCrear.Count -ne 0) { # Si se encuetra al menos un valor especificado dentro del arreglo de VHDs
        if ($listaDiscosPorCrear.Count -eq 1) {
             Write-Host "`tVHD encontrado: $listaDiscosPorCrear GB"
             $postCreacionDisco = Almacenamiento-Disponible -diskSize $listaDiscosPorCrear[0]
             return $listaDiscosPorCrear
        } else {
            for ($i=0; $i -le ($postCreacionDisco.Count-1); $i++) {
                $temp = $postCreacionDisco[$i]
                if ($i -eq 0) {
                    Write-Host "`tVHDX encontrado: $temp GB"
                    $postCreacionDisco = Almacenamiento-Disponible -diskSize $temp
                } else {
                     Write-Host "`t VHD encontrado: $temp GB"
                     $libre = $postCreacionDisco - $temp
                     if ($libre -le 0) {
                        "`tNo se cuenta con el suficiente espacio de almacenamiento disponible para crear el VHD solicitado."
                        "`tAlmacenamiento disponible: $libre GB | Tama�o del disco solicitado: $temp GB"
                        exit
                    }
                    $postCreacionDisco = $libre
               }
            }
            Write-Host "`t`tEspacio libre dentro del disco seleccionado como raiz al crear los VHDX: $postCreacionDisco GB"
            return $listaDiscosPorCrear
        }
    } else {
        "ERROR: No se ha especificado el tamaño del disco virtual (VHDX) a crear para el equipo."
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
                    "`tNo se ha ingresado una m�scara v�lida para la red '$name'. Revisa archivo de entrada"
                    exit
                }
            } else {
                "`tNo se ha ingresado una IP v�lida para la red '$name'. Revisa archivo de entrada"
                exit
            }
            Write-Host "`tConfiguracion encontrada y validada para la red '$name': "
            Write-Host "`t`tDireccion IP: $ip, Mascara: $mascara, Gateway: $gateway, DNS: $dns"
            $nombresInterfacesEncontradas += $name
        }
    } else {
        "`tNo se han encontrado interfaces de red para el equipo."
        exit
    }

    
}

function Obtener-VersionesDeWindows {
    param ([string]$WinIso)
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
        Write-Host "`tN�mero de procesadores: $numeroProcesadores" 
        return $numeroProcesadores
    } else {
        Write-Host "`tIngrese un n�mero v�lido de procesadores para el equipo '$hostname'. Revisar archivo JSON."
        exit
    }
}

function Validar-Credenciales {
    param ($usuario, $passwd)
    Write-Host "Credenciales Administrativas"
    if (($usuario -or $passwd) -ne "") {
        if($usuario -match "^[a-zA-Z0-9]{5,20}[a-zA-Z]$"){
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
           Write-Host "`tSe usar� la siguiente imagen para este equipo: $imagen"
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

# Funci�n para obtener par�metros de las m�quinas virtuales que desean ser creadas  
function Datos-VM {
    param ([int]$contador)
  
    # Se recuperan los datos obligatorios independientemente del tipo de SO y se valida que sean correctos
    $hostname = Validar-Hostname -hostname $archivoEntrada.VMs[$contador].Hostname # String
    $sistemaOperativo = Validar-SistemaOperativo -SOPorRevisar $archivoEntrada.VMs[$contador].SO # String
    Write-Host "DATOS DEL EQUIPO  $sistemaOperativo | $hostname :"
    $usuario, $passwd = Validar-Credenciales -usuario $archivoEntrada.VMs[$contador].User -passwd $archivoEntrada.VMs[$contador].Password
    $tipoDeMemoria = $archivoEntrada.VMs[$contador].MemoryType
    if($tipoDeMemoria -eq "Static"){
        $tamanioMemoria = Validar-RAM -tamanioMemoria $archivoEntrada.VMs[$contador].MemorySize
        Write-Host "$tamanioMemoria`n$tipoDeMemoria"
    }elseif($tipoDeMemoria -eq "Dynamic"){
        $minMemoria, $maxMemoria = Validar-RAM -minMemoria $archivoEntrada.VMs[$contador].MemoryMin -maxMemoria $archivoEntrada.VMs[$contador].MemoryMax
        #Write-Host "$maxMemoria - $minMemoria`n$tipoDeMemoria"
    }else{
        #Write-Host "Se debe especificar alguno de los siguientes tipos de memoria:`nStatic`nDynamic"
        exit
    }
    $discos = Validar-VHDX -listaDiscosPorCrear $archivoEntrada.VMs[$contador].DiskSize
    $imagen = Validar-ISO -imagen $archivoEntrada.VMs[$contador].ImagePath
    $interfaces = Validar-Redes -interfaces $archivoEntrada.VMs[$contador].InterfaceConfig # Se validan las configuraciones de red para todas las interfaces
    $numeroProcesadores = Validar-Procesadores -numeroProcesadores $archivoEntrada.VMs[$contador].ProcessorNumber
    # Se recuperan los datos individuales dependiendo del tipo de SO
 
    ########
    

    # Validaciones de los datos individuales ingresados 

    # Apartado para seleccionar la interfaz administrativa para el equipo
    <#
    if ($sistemaOperativo -eq "FortiOS") {
        $interfazAdministrativa = $archivoEntrada.VMs[$contador].InterfazAdministrativa
        if ($interfazAdministrativa -eq "" -and $nombresInterfacesEncontradas.Count -ge 2) {
            "`tNo se ha indicado una interfaz administrativa dentro del archivo de entrada"
            do {
                for ($i = 0; $i -le ($nombresInterfacesEncontradas.Count-1); $i++) {
                    Write-Host -NoNewline "`t`t"
                    Write-Host -NoNewline $nombresInterfacesEncontradas[$i]
                    Write-Host " -> Opcion [$i]"
                }
                $num = Read-Host -Prompt "`t`tPor favor, ingresa el n�mero de la interfaz administrativa a usar"
                $interfazAdministrativa = $num
            } until ($interfazAdministrativa -in 0..($nombresInterfacesEncontradas.Count-1))
            "`tSe usar� la interfaz $interfazAdministrativa como interfaz administrativa"
        } elseif ($interfazAdministrativa -eq "" -and $nombresInterfacesEncontradas.Count -eq 1){
            "`tNo se ha indicado una interfaz administrativa dentro del archivo de entrada, por lo que se tomar� como administrativa, la �nica interfaz que ha sido encontrada ($nombresInterfacesEncontradas[0])"
        } elseif ($interfazAdministrativa -in 0..$nombresInterfacesEncontradas-1) {
            "`tSe usar� la interfaz $interfazAdministrativa como interfaz administrativa"
        } elseif ($interfazAdministrativa -gt $nombresInterfacesEncontradas-1) {
            "`tHa indicado el n�mero de una interfaz que no existe. Ha seleccionado la interfaz $interfazAdministrativa de un total de $nombresInterfacesEncontradas.Count"
            do {
                for ($i = 0; $i -le ($nombresInterfacesEncontradas.Count-1); $i++) {
                    Write-Host -NoNewline $nombresInterfacesEncontradas[$i]
                    Write-Host " -> Opcion [$i]"
                }
                $interfazAdministrativa = Read-Host -Prompt "`t`tPor favor, ingresa el n�mero de la interfaz administrativa a usar"
            } until ($interfazAdministrativa -in 0..$nombresInterfacesEncontradas.Count-1)
            "`tSe usará la interfaz $interfazAdministrativa como interfaz administrativa"
        }
    }



    # Para obtener y validar el path del archivio de respaldo (en caso de existir)
    if ($os -eq "FortiOS") { 
        Write-Host "Archivo de Respaldo"
        $respaldo = $archivoEntrada.VMs[$contador].ArchivoRespaldo
        if ($respaldo -ne "") {
            if (Test-Path -Path $respaldo) {
                Write-Host "`tSe usar� el siguiente archivo de respaldo para este equipo: $respaldo"
            } else {
                Write-Host "`tNo se ha podido acceder a la ruta de la imagen dentro del archivo de entrada. Revisar el archivo JSON."
                exit
            }
        } else {
            Write-Host "`tNo se ha indicado un archivo de respaldo para este equipo"
        }
    }
#>

    # Para obtener las credenciales administrativas del equipo 
    
    
    # Para obtener los servicios a instalar dentro del equipo  
    Write-Host "Servicios a instalar dentro del equipo"
    $serviciosDisponibles = @("Apache", "DHCP") # Se definen todos los servicios disponibles para este tipo de SO
    $serviciosPorInstalar = @() # Ac� se almacenan los servicios que sean validados
    $servicios = $archivoEntrada.VMs[$contador].Services
    if ($servicios.Count -ne 0) {
        foreach ($servicio in $servicios) {
            if ($serviciosDisponibles.Contains($servicio)) {
                $serviciosPorInstalar += $servicio
            }
        }
        "`tLista de servicios a intalar dentro del equipo:"
        foreach ($servicioValidado in $serviciosPorInstalar) {
            Write-Host "`t`t$servicioValidado"
        }
    } else {
        Write-Host "`tNo se han encontrados servicios a instalar para este equipo"
    }



    # Confirmaci�n de los datos que han sido le�dos para la VM
    #Do {
       $confirmacion = Read-Host -Prompt "¿Son los datos presentados correctos para el equipo $hostname? (S/N)"
       if ($confirmacion.Equals("S") -or $confirmacion.Equals("s")) {
            $instalados = Get-WindowsFeature -Name  Hyper-V | Where-Object { $_.InstallState -eq "Installed"}
            if($instalados.Count -ge 1) {
                $vname = $sistemaOperativo + $hostname
                $switchesVirtualesAsociados = @()
                foreach ($interfaz in $interfaces) {
                    $nombreVSwitch = $interfaz.VirtualSwitch
                    if (Consultar-VSwitchDisponibles -nombreVirtualSwitch $nombreVSwitch) {
                        $switchesVirtualesAsociados += $nombreVSwitch
                    }
                }
                "Creando VM..."
                try {
                    New-VM -VMName $vname -Generation 1 -Force
                    "Se ha creado la VM"
                    #Start-Sleep -s 2
                } catch{
                    "No c puede bro"
                }
                foreach ($vs in $switchesVirtualesAsociados) {Add-VMNetworkAdapter -VMName $vname -SwitchName $vs}
                "VSwitches asociados"
                Set-VMProcessor -VMName $vname -Count $numeroProcesadores
                "Se ha asignado el procesador"
                ## Si se establece memoria dinamica se obtienen los valores maximos y minimos
                #$tamanioMemoria = $tamanioMemoria * 1GB
                #if($tipoDeMemoria -eq "Dynamic"){
                #    $minMemoria = $minMemoria * 1GB
                #    $maxMemoria = $maxMemoria * 1GB
                #    Set-VMMemory -VMName $vname -DynamicMemoryEnabled $True -MaximumBytes $maxMemoria -MinimumBytes $minMemoria -StartupBytes [int]$tamanioMemoria
                #}else{
                #    Set-VMMemory -VMName $vname -DynamicMemoryEnabled $false -StartupBytes $tamanioMemoria
                #}
#
                #$discoRaizVM = ($discos | Measure-Object -Maximum) # Se obtiene el disco de mayor tamaño para instalar el SO
                #foreach ($disk in $discos){
                #    if ($disk -eq $discoRaizVM) {
                #        if ($sistemaOperativo -eq ("Windows Server 2019" -or "Windows 10")) {
                #            Obtener-VersionesDeWindows -WinIso $imagen
                #        }
                #    } else {
                #        $pathDisk = $raiz+'\'+$vname+$disk+'.vhdx'
                #        # Se revisa que la ruta del disco virtual no exista, en el caso de existir se genera un numero random para nombrarlo
                #        while(Test-Path -Path $pathDisk){
                #            $random = Get-Random
                #            $pathDisk = $raiz+'\'+$vname+$disk+$random+'.vhdx'
                #        }
                #        $disk = [int]$disk * 1Gb
                #        New-VHD -Path $pathDisk -SizeBytes $disk
                #        Add-VMHardDiskDrive -VMName $vname -Path $pathDisk
                #    }
                #}
                Set-VMDvdDrive -VMName $vname -Path $imagen
            } else {
                # En caso de no encontrar el rol de Hyper-V procede a su instalacion
                $computer = hostname
                Write-Host "`tNo se encuentra instalado el rol de Hyper-V, el rol sera instalado y el equipo se reiniciara. Ejecute nuevamente el programa al iniciar."
                Install-WindowsFeature -Name Hyper-V -ComputerName $computer -IncludeManagementTools -Restart
            }
            break
       }
       if ($confirmacion.Equals("N") -or $confirmacion.Equals("n")) {
           Write-Host "Aplique los cambios necesarios sobre el archivo de entrada y ejecute el script de nuevo."
           exit
       }
    #} while ($true)
    Write-Host "`n`n"


}

if ($args.Count -eq 1) {
    $rutaJSON = $args[0] # Se lee la ruta donde est� el archivo de entrada
    $archivoEntrada = Validar-JSON -rutaJSON $rutaJSON # Se lee y valida que exista el archivo y que esté en formato JSON
    $raiz = Validar-Raiz -rutaRaiz $archivoEntrada[0].Root # Se lee y valida la ruta raiz del proyecto a ser creado.
    
    # Revision de las especificaciones de las maquinas virtuales
    $numeroMaquinas = ($ArchivoEntrada[0].VMs | Measure-Object).Count # Numero de Maquinas por instalar
    for($i=0; $i -le $numeroMaquinas-1;$i++) {
        Write-Host $archivoEntrada.VMs[$i].Type
        Datos-VM -contador $i -os $archivoEntrada.VMs[$i].SO
    }
} else {
    "Sólo se debe de ingrear como algumento, la ruta donde se encuentre el archivo de entrada en formato JSON"
}