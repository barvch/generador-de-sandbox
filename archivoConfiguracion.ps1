# Get-VMSwitch



# Función para revisar el almacenamiento disponible en disco y validar que exista suficiente espacio para crear el VHD 

function Almacenamiento-Disponible {
    param ([int]$diskSize)
    #Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = '3'" | Select-Object -Property DeviceID, DriveType, VolumeName, @{L='FreeSpaceGB';E={"{0:N2}" -f ($_.FreeSpace /1GB)}}
    $arrayDiscosDisponibles = Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = '3'" | Select-Object -ExpandProperty  FreeSpace @{L='FreeSpace';E={"{0:0}" -f ($_.FreeSpace /1GB)}}
    for ($i=0; $i -le ($arrayDiscosDisponibles.Count-1); $i++) {
        $libre = ($arrayDiscosDisponibles[$i]/1GB)
        $libre = [math]::Round($libre,2)
        if (($libre - $diskSize) -le 0) {
            "`tNo se cuenta con el suficiente espacio de almacenamiento disponible para crear el VHD solicitado."
            "`tAlmacenamiento disponible: $libre GB | Tamaño del disco solicitado: $diskSize GB XXXX"
            exit
        }
        return ($libre - $diskSize)
    }
}

# Función para revisar el máximo de memoria RAM dentro del host de Hyper-V
function Consultar-Memoria {
    $ram = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $ram = $ram.Sum/1GB
    return $ram
}

# Función para obtener parámetros de las máquinas virtuales que desean ser creadas  
function Datos-VM {
    param ([int]$contador, [string]$os)

    # Para obtener el hostname del equipo 
    $hostname = $archivoEntrada.VMs[$contador].Hostname # String
    if ($hostname -eq "") {
        "ERROR: Ingresa un hostname para el equipo. Revisar el archivo JSON."
        exit
    }
    Write-Host "DATOS DEL EQUIPO  $os | $hostname :"

    # Para obtener el tamaño en GB de los discos a crear y validar que se cuente con espacio sufiente para crearlos
    Write-Host "Discos Virtuales"
    $discos = $archivoEntrada.VMs[$contador].DiskSize # Array
    if ($discos.Count -ne 0) { # Si se encuetra al menos un valor especificado dentro del arreglo de VHDs
        if ($discos.Count -eq 1) {
             Write-Host "`tVHD encontrado: $discos GB"
             $postCreacionDisco = Almacenamiento-Disponible -diskSize $discos[0]
             Write-Host "`tDespués de la creación de este VHD, quedarán $postCreacionDisco GB libres dentro del equipo."
        } else {
            for ($i=0; $i -le ($discos.Count-1); $i++) {
                $temp = $discos[$i]
                if ($i -eq 0) {
                    Write-Host "`tVHD encontrado: $temp GB"
                    $postCreacionDisco = Almacenamiento-Disponible -diskSize $temp
                } else {
                     Write-Host "`t VHD encontrado: $temp GB"
                     $libre = $postCreacionDisco - $temp
                     if ($libre -le 0) {
                        "`tNo se cuenta con el suficiente espacio de almacenamiento disponible para crear el VHD solicitado."
                        "`tAlmacenamiento disponible: $libre GB | Tamaño del disco solicitado: $temp GB"
                        exit
                    }
                    $postCreacionDisco = $libre
               }
            }
            Write-Host "`t`tDespués de crear todos los discos, quedarán $postCreacionDisco GB libres dentro del equipo"
        }
    } else {
        "ERROR: No se han encontrado VHDs para el equipo $hostname. Revisar el archivo JSON"
        exit
    }
    
    # Para obtener el nombre de los VirtualSwitches a los cuales se va a conectar el equipo o, en caso de no encontrar alguno especificado, seleccionar el tipo de VSwitch a crear
    Write-Host "VSwitches"
    $virtualSwitch = $archivoEntrada.VMs[$contador].VirtualSwitch # Array
    if ($virtualSwitch.Count -ne 0) {
        foreach ($switch in $virtualSwitch) {
            Write-Host "`tVirtual Switch encontrado: $switch"
        }
    } else { # Caso cuando no se encuentran VSwitch para el equipo dentro del archivo de entrada
        $tiposVirtualSwitch = @("Interno", "Privado", "Externo")
        "`tNo se han encontrado Virtual Switches asociados al equipo $hostname...`nTipos de Virtual Switch Disponibles: "
        do {
            for ($i = 0; $i -le ($tiposVirtualSwitch.Count-1); $i++) {
                Write-Host -NoNewline $tiposVirtualSwitch[$i]
                Write-Host " -> Opcion [$i]"
            }
            $tipo = Read-Host -Prompt "`t`tPor favor, ingrese el tipo de VSwitch que desea para este equipo"
        } until ($tipo -in 0..2)
        
    }

    # Para obtener las especificaciones de todas las interfaces de red especificadas
    Write-Host "Interfaces de red"
    $interfaces = $archivoEntrada.VMs[$contador].InterfaceConfig # Array de objetos
    if ($interfaces.Count -ne 0) {
        $regexIPValida = '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
        $nombresInterfacesEncontradas = @()
        foreach ($configuracion in $interfaces) {
            $name = $configuracion.Nombre
            $ip = $configuracion.IP
            if ($ip -match $regexIPValida) {
                $mascara = $configuracion.Mask
                if ($mascara -match $regexIPValida) {
                    $gateway = $configuracion.Gateway
                    $dns = $configuracion.DNS
                } else{
                    "`tNo se ha ingresado una máscara válida para la red '$name'. Revisa archivo de entrada"
                    exit
                }
            } else {
                "`tNo se ha ingresado una IP válida para la red '$name'. Revisa archivo de entrada"
                exit
            }
            Write-Host "`tConfiguracion encontrada y validada para la red '$name': "
            Write-Host "`t`tDireccion IP: $ip, Mascara: $mascara, Gateway: $gateway, DNS: $dns"
            $nombresInterfacesEncontradas += $name
        }
    } else {
        "`tNo se han encontrado interfaces de red para el equipo $hostname"
        exit
    }

    # Apartado para seleccionar la interfaz administrativa para el equipo
    if ($os -eq "FortiOS") {
        $interfazAdministrativa = $archivoEntrada.VMs[$contador].InterfazAdministrativa
        if ($interfazAdministrativa -eq "" -and $nombresInterfacesEncontradas.Count -ge 2) {
            "`tNo se ha indicado una interfaz administrativa dentro del archivo de entrada"
            do {
                for ($i = 0; $i -le ($nombresInterfacesEncontradas.Count-1); $i++) {
                    Write-Host -NoNewline "`t`t"
                    Write-Host -NoNewline $nombresInterfacesEncontradas[$i]
                    Write-Host " -> Opcion [$i]"
                }
                $num = Read-Host -Prompt "`t`tPor favor, ingresa el número de la interfaz administrativa a usar"
                $interfazAdministrativa = $num
            } until ($interfazAdministrativa -in 0..($nombresInterfacesEncontradas.Count-1))
            "`tSe usará la interfaz $interfazAdministrativa como interfaz administrativa"
        } elseif ($interfazAdministrativa -eq "" -and $nombresInterfacesEncontradas.Count -eq 1){
            "`tNo se ha indicado una interfaz administrativa dentro del archivo de entrada, por lo que se tomará como administrativa, la única interfaz que ha sido encontrada ($nombresInterfacesEncontradas[0])"
        } elseif ($interfazAdministrativa -in 0..$nombresInterfacesEncontradas-1) {
            "`tSe usará la interfaz $interfazAdministrativa como interfaz administrativa"
        } elseif ($interfazAdministrativa -gt $nombresInterfacesEncontradas-1) {
            "`tHa indicado el número de una interfaz que no existe. Ha seleccionado la interfaz $interfazAdministrativa de un total de $nombresInterfacesEncontradas.Count"
            do {
                for ($i = 0; $i -le ($nombresInterfacesEncontradas.Count-1); $i++) {
                    Write-Host -NoNewline $nombresInterfacesEncontradas[$i]
                    Write-Host " -> Opcion [$i]"
                }
                $interfazAdministrativa = Read-Host -Prompt "`t`tPor favor, ingresa el número de la interfaz administrativa a usar"
            } until ($interfazAdministrativa -in 0..$nombresInterfacesEncontradas.Count-1)
            "`tSe usará la interfaz $interfazAdministrativa como interfaz administrativa"
        }
    }

    # Para obtener el tamaño en GB y tipo de memoria RAM que ocupará el equipo
    Write-Host "Memoria RAM"
    $tipoDeMemoria = $archivoEntrada.VMs[$contador].MemoryType # String
    if ($tipoDeMemoria -eq "") {
        "`tNo se ha encontrado el tipo de memoria a utilizar para el equipo '$hostname'. Revisar archivo JSON."
        exit
    }
    $tamanioMemoria = $archivoEntrada.VMs[$contador].MemorySize # String
    if ($tamanioMemoria -eq "") {
        "`tNo se ha encontrado el tamaño de la memoria a utilizar para el equipo '$hostname'. Revisar archivo JSON."
        exit
    }
    $totalRamDisponible = Consultar-Memoria
    if ([int]$tamanioMemoria -gt $totalRamDisponible) {
        "`tSe ha ingresado una cantidad de memoria que excede el total de RAM del equipo`n`t`tMemororia total disponible en el equipo: $totalRamDisponible.`n`t`tMemoria ingresada para el equipo: $tamanioMemoria"
        exit
    }
    if($tipoDeMemoria -eq "Dynamic"){
        $maxMemoria = $archivoEntrada.VMs[$contador].MemoryMax #Int GB
        $minMemoria = $archivoEntrada.VMs[$contador].MemoryMin #Int GB
        if ([int]$maxMemoria -gt $totalRamDisponible) {
            "`tSe ha ingresado una cantidad de memoria máxima que excede el total de RAM del equipo`n`t`tMemororia total disponible en el equipo: $totalRamDisponible.`n`t`tMemoria ingresada para el equipo: $tamanioMemoria"
            exit
        }
        if($minMemoria -gt $maxMemoria){
            "`tSe ha ingresado una cantidad de memoria minima que excede el total de RAM de memoria máxima ingresada`n`t`tMemoria máxima: $maxMemoria GB.`n`t`tMemoria mínima: $minMemoria MB"
            exit
        }
        if([int]$tamanioMemoria -gt $maxMemoria){
            $tamanioMemoria = [string]$maxMemoria
        }
        if($minMemoria -gt $tamanioMemoria ){
            $tamanioMemoria = [string]$minMemoria
        }
        Write-Host "`tSe usará una memoria del tipo $tipoDeMemoria con un tamaño de $tamanioMemoria GB."
        Write-Host "`tMemoria maxima $maxMemoria GB."
        Write-Host "`tMemoria minima $minMemoria GB."
    }
    else{
        Write-Host "`tSe usará una memoria del tipo $tipoDeMemoria con un tamaño de $tamanioMemoria GB."
    }

    # Para obtener el número de procesadores que tendrá el equipo
    Write-Host "Procesadores"
    $numeroProcesadores = $archivoEntrada.VMs[$contador].ProcessorNumber # Number
    if ($numeroProcesadores -ne 0 -and $numeroProcesadores -ge 1) {
        Write-Host "`tNúmero de procesadores: $numeroProcesadores" 
    } else {
        Write-Host "`tIngrese un número válido de procesadores para el equipo '$hostname'. Revisar archivo JSON."
        exit
    }

    # Para obtener las credenciales administrativas del equipo 
    Write-Host "Credenciales Administrativas"
    $usuario = $archivoEntrada.VMs[$contador].User
    $passwd = $archivoEntrada.VMs[$contador].Password
    if ($usuario -eq "") {
        Write-Host "`tIngrese un nombre de usuario válido. Revisar archivo JSON."
        exit
    }
    if ($passwd -eq "") {
        Write-Host "`tIngrese una contraseña válida. Revisar archivo JSON."
        exit
    }
    Write-Host "`tSe usarán las siguientes credenciales para el equipo:"
    Write-Host "`t`tUsername: $usuario"
    Write-Host "`t`tPassword: $passwd"
    
    # Para obtener los servicios a instalar dentro del equipo  
    Write-Host "Servicios a instalar dentro del equipo"
    $serviciosDisponibles = @("Apache", "DHCP") # Se definen todos los servicios disponibles para este tipo de SO
    $serviciosPorInstalar = @() # Acá se almacenan los servicios que sean validados
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

    # Para obtener y validar el path de la imagen que será instalada dentro del equipo
    Write-Host "Imagen a instalar dentro del equipo"
    $imagen = $archivoEntrada.VMs[$contador].ImagePath
    if ($imagen -ne "") {
       if (Test-Path -Path $imagen) {
           Write-Host "`tSe usará la siguiente imagen para este equipo: $imagen"
       } else {
           Write-Host "`tNo se ha podido acceder a la ruta de la imagen dentro del archivo de entrada. Revisar el archivo JSON."
           exit
       }
    } else {
       Write-Host "`tIngrese una ruta para la imagen del SO a instalar dentro del equipo"
       exit
    }

    # Para obtener y validar el path del archivio de respaldo (en caso de existir)
    if ($os -eq "FortiOS") { 
        Write-Host "Archivo de Respaldo"
        $respaldo = $archivoEntrada.VMs[$contador].ArchivoRespaldo
        if ($respaldo -ne "") {
            if (Test-Path -Path $respaldo) {
                Write-Host "`tSe usará el siguiente archivo de respaldo para este equipo: $respaldo"
            } else {
                Write-Host "`tNo se ha podido acceder a la ruta de la imagen dentro del archivo de entrada. Revisar el archivo JSON."
                exit
            }
        } else {
            Write-Host "`tNo se ha indicado un archivo de respaldo para este equipo"
        }
    }

    # Confirmación de los datos que han sido leídos para la VM
    Do {
       $confirmacion = Read-Host -Prompt "¿Son los datos presentados correctos? (S/N)"
       if ($confirmacion.Equals("S") -or $confirmacion.Equals("s")) {
            # Se verifica la instalación del rol de Hyper-V
            $instalados = Get-WindowsFeature -Name  Hyper-V | where { $_.InstallState -eq "Installed"}
            if($instalados.Count -ge 1){
                $vname  = $os + $hostname
                for ($j = 0; $j -le ($virtualSwitch.Count-1); $j++) {
                    $nombreSwitch = Get-VMSwitch -Name $virtualSwitch[$j]
                    # Se verifica la existencia del switch que se ha establecido en el archivo de configuracion
                    if($nombreSwitch.Count -eq 0){
                        $tiposVirtualSwitch = @("Interno", "Privado", "Externo")
                        do {
                            for ($i = 0; $i -le ($tiposVirtualSwitch.Count-1); $i++) {
                                Write-Host $tiposVirtualSwitch[$i] " -> Opcion [$i]"
                            }
                            $tipo = Read-Host -Prompt "`t`tPor favor, ingrese el tipo de VSwitch que desea crear"
                        } until ($tipo -in 0..2)
                        # Se crea un nuevo virtual Switch del tipo seleccionado por el usuario
                        if($tipo -eq 0){
                            New-VMSwitch -name $virtualSwitch[$j] -SwitchType Internal
                        }
                        elseif($tipo -eq 1){
                            New-VMSwitch -name $virtualSwitch[$j] -SwitchType Private
                        }
                        else{
                            # Se obtienen los adaptadores de red del equipo
                            $adaptadores = Get-NetAdapter
                            if($adaptadores.Count -ge 2){
                                do {
                                    for ($i = 0; $i -le ($adaptadores.Count-1); $i++) {
                                        Write-Host $adaptadores[$i].Name " -> Opcion [$i]"
                                    }
                                    $tipo = Read-Host -Prompt "`t`tPor favor, ingrese el adaptador del VSwitch"
                                } until ($tipo -in 0..($adaptadores.Count-1))
                                New-VMSwitch -name $virtualSwitch[$j]  -NetAdapterName $adaptadores[$tipo].Name
                            }
                            if($adaptadores.Count -eq 1){
                                New-VMSwitch -name $virtualSwitch[$j]  -NetAdapterName $adaptadores.Name
                            }
                        }
                    }
                    # Para el primer caso se crea la maquina virtual especificado el virtual switch
                    if($j -eq 0){
                        New-VM -VMName $vname -Generation 1 -SwitchName $virtualSwitch[$j]
                    }
                    # En los siguientes casos se agrega el adaptador conectado al virtual switch establecido
                    else{
                        Add-VMNetworkAdapter -VMName $vname -SwitchName $virtualSwitch[$j]
                    }
                }
                Set-VMProcessor -VMName $vname -Count $numeroProcesadores
                $tamanioMemoria = [int]$tamanioMemoria * 1Gb
                # Si se establece memoria dinamica se obtienen los valores maximos y minimos
                if($tipoDeMemoria -eq "Dynamic"){
                    $maxMemoria = $maxMemoria * 1Gb
                    $minMemoria = $minMemoria * 1Gb
                    Set-VMMemory -VMName $vname -DynamicMemoryEnabled $True -MaximumBytes $maxMemoria -MinimumBytes $minMemoria -StartupBytes $tamanioMemoria
                }else{
                    Set-VMMemory -VMName $vname -DynamicMemoryEnabled $false -StartupBytes $tamanioMemoria
                }
                foreach ($disk in $discos){
                    $pathDisk = "C:\\Users\\Administrator\\Desktop\\"+$vname+$disk+'.vhdx'
                    # Se revisa que la ruta del disco virtual no exista, en el caso de existir se genera un numero random para nombrarlo
                    while(Test-Path -Path $pathDisk){
                        $random = Get-Random
                        $pathDisk = "C:\\Users\\Administrator\\Desktop\\"+$vname+$disk+$random+'.vhdx'
                    }
                    $disk = [int]$disk * 1Gb
                    New-VHD -Path $pathDisk -SizeBytes $disk
                    Add-VMHardDiskDrive -VMName $vname -Path $pathDisk
                }
                Set-VMDvdDrive -VMName $vname -Path $imagen
            } # En caso de no encontrar el rol de Hyper-V procede a su instalacion
            else{
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
    } while ($true)

    Write-Host "`n`n"
}

# Creación del proyecto (folder raíz, características de las VMs a crear para el ambiente, validaciones).
if ($args.Count -eq 1) {
    $rutaJSON = $args[0] # Se lee la ruta donde está el archivo de entrada
    if (Test-Path -Path $rutaJSON) { # Se valida que el archivo exista
        $archivoEntrada = Get-Content -Raw -Path $rutaJSON | ConvertFrom-Json # Se lee el archivo de entrada en formato JSON
        
        # Revisión de la ruta raiz del proyecto
        $raiz = $archivoEntrada[0].Root
        if (Test-Path -Path $raiz) {
            "Raiz del ambiente: $raiz"
        } else {
            $ficheroAnterior = Split-Path -Path $raiz
            $leaf = Split-Path -Path $raiz -Leaf
            if (Test-Path -Path $ficheroAnterior) {
                $respuesta = Read-Host -Prompt "Desea crear el fichero $leaf dentro de $ficheroAnterior y usarlo como raiz para el ambiente? [S/N]"
                if ($respuesta -eq "S" -or $respuesta -eq "s") {
                    New-Item -Path $raiz -ItemType "directory"
                    "Se ha creado la carpeta $leaf.`nRaiz del ambiente: $raiz" 
                }
            } else {
                "Error en el path ingresado como raiz del proyecto.`nNo existe el padre de la ruta proporcionada o no se tienen los permisos suficientes para poder crear el proyecto dentro de $ficheroAnterior. Revisar archivo JSON"
                exit
            }
        }

        # Revisión de las especificaciones de las máquinas virtuales
        $numeroMaquinas = ($ArchivoEntrada[0].VMs | Measure-Object).Count # Numero de Máquinas por instalar
        for($i=0; $i -le $numeroMaquinas-1;$i++) {
            Write-Host $archivoEntrada.VMs[$i].Type
            Datos-VM -contador $i -os $archivoEntrada.VMs[$i].Type
        }
    } else {
        "No se ha logrado encontrar el archivo de entrada ingresado"   
    }
} else {
    "Sólo se debe de ingrear como algumento, la ruta donde se encuentre el archivo de entrada en formato JSON"
}
