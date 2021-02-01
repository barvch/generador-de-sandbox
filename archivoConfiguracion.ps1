# Remove-VMSwitch "QoS Switch"
# C:\ProgramData\Microsoft\Windows\Hyper-V

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
        return $false
    }
}

# Función para crear un Virtual Switch cuando se ingresa el nombre de un VS que no está presente dentro del equipo
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
}

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

# Funci�n para obtener par�metros de las m�quinas virtuales que desean ser creadas  
function Datos-VM {
    param ([int]$contador, [string]$os)

    # Para obtener el hostname del equipo 
    $hostname = $archivoEntrada.VMs[$contador].Hostname # String
    if ($hostname -eq "") {
        "ERROR: Ingresa un hostname para el equipo. Revisar el archivo JSON."
        exit
    }
    Write-Host "DATOS DEL EQUIPO  $os | $hostname :"

    # Para obtener el tama�o en GB de los discos a crear y validar que se cuente con espacio sufiente para crearlos
    Write-Host "Discos Virtuales"
    $discos = $archivoEntrada.VMs[$contador].DiskSize # Array
    if ($discos.Count -ne 0) { # Si se encuetra al menos un valor especificado dentro del arreglo de VHDs
        if ($discos.Count -eq 1) {
             Write-Host "`tVHD encontrado: $discos GB"
             $postCreacionDisco = Almacenamiento-Disponible -diskSize $discos[0]
             Write-Host "`tDespu�s de la creaci�n de este VHD, quedar�n $postCreacionDisco GB libres dentro del equipo."
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
                        "`tAlmacenamiento disponible: $libre GB | Tama�o del disco solicitado: $temp GB"
                        exit
                    }
                    $postCreacionDisco = $libre
               }
            }
            Write-Host "`t`tDespu�s de crear todos los discos, quedar�n $postCreacionDisco GB libres dentro del equipo"
        }
    } else {
        "ERROR: No se han encontrado VHDs para el equipo $hostname. Revisar el archivo JSON"
        exit
    }

    # Para obtener las especificaciones de todas las interfaces de redes especificadas
    Write-Host "Interfaces de red"
    $interfaces = $archivoEntrada.VMs[$contador].InterfaceConfig # Array de objetos
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

    # Para obtener el tama�o en GB y tipo de memoria RAM que ocupar� el equipo
    Write-Host "Memoria RAM"
    $tipoDeMemoria = $archivoEntrada.VMs[$contador].MemoryType # String
    if ($tipoDeMemoria -eq "") {
        "`tNo se ha encontrado el tipo de memoria a utilizar para el equipo '$hostname'. Revisar archivo JSON."
        exit
    }
    $tamanioMemoria = $archivoEntrada.VMs[$contador].MemorySize # String
    if ($tamanioMemoria -eq "") {
        "`tNo se ha encontrado el tama�o de la memoria a utilizar para el equipo '$hostname'. Revisar archivo JSON."
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
            "`tSe ha ingresado una cantidad de memoria m�xima que excede el total de RAM del equipo`n`t`tMemororia total disponible en el equipo: $totalRamDisponible.`n`t`tMemoria ingresada para el equipo: $tamanioMemoria"
            exit
        }
        if($minMemoria -gt $maxMemoria){
            "`tSe ha ingresado una cantidad de memoria minima que excede el total de RAM de memoria m�xima ingresada`n`t`tMemoria m�xima: $maxMemoria GB.`n`t`tMemoria m�nima: $minMemoria MB"
            exit
        }
        if([int]$tamanioMemoria -gt $maxMemoria){
            $tamanioMemoria = [string]$maxMemoria
        }
        if($minMemoria -gt $tamanioMemoria ){
            $tamanioMemoria = [string]$minMemoria
        }
        Write-Host "`tSe usar� una memoria del tipo $tipoDeMemoria con un tama�o de $tamanioMemoria GB."
        Write-Host "`tMemoria maxima $maxMemoria GB."
        Write-Host "`tMemoria minima $minMemoria GB."
    }
    else{
        Write-Host "`tSe usar� una memoria del tipo $tipoDeMemoria con un tama�o de $tamanioMemoria GB."
    }

    # Para obtener el n�mero de procesadores que tendr� el equipo
    Write-Host "Procesadores"
    $numeroProcesadores = $archivoEntrada.VMs[$contador].ProcessorNumber # Number
    if ($numeroProcesadores -ne 0 -and $numeroProcesadores -ge 1) {
        Write-Host "`tN�mero de procesadores: $numeroProcesadores" 
    } else {
        Write-Host "`tIngrese un n�mero v�lido de procesadores para el equipo '$hostname'. Revisar archivo JSON."
        exit
    }

    # Para obtener las credenciales administrativas del equipo 
    Write-Host "Credenciales Administrativas"
    $usuario = $archivoEntrada.VMs[$contador].User
    $passwd = $archivoEntrada.VMs[$contador].Password
    if ($usuario -eq "") {
        Write-Host "`tIngrese un nombre de usuario v�lido. Revisar archivo JSON."
        exit
    }
    if ($passwd -eq "") {
        Write-Host "`tIngrese una contrase�a v�lida. Revisar archivo JSON."
        exit
    }
    Write-Host "`tSe usar�n las siguientes credenciales para el equipo:"
    Write-Host "`t`tUsername: $usuario"
    Write-Host "`t`tPassword: $passwd"
    
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

    # Para obtener y validar el path de la imagen que ser� instalada dentro del equipo
    Write-Host "Imagen a instalar dentro del equipo"
    $imagen = $archivoEntrada.VMs[$contador].ImagePath
    if ($imagen -ne "") {
       if (Test-Path -Path $imagen) {
           Write-Host "`tSe usar� la siguiente imagen para este equipo: $imagen"
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
                Write-Host "`tSe usar� el siguiente archivo de respaldo para este equipo: $respaldo"
            } else {
                Write-Host "`tNo se ha podido acceder a la ruta de la imagen dentro del archivo de entrada. Revisar el archivo JSON."
                exit
            }
        } else {
            Write-Host "`tNo se ha indicado un archivo de respaldo para este equipo"
        }
    }

    # Confirmaci�n de los datos que han sido le�dos para la VM
    Do {
       $confirmacion = Read-Host -Prompt "¿Son los datos presentados correctos para el equipo $hostname? (S/N)"
       if ($confirmacion.Equals("S") -or $confirmacion.Equals("s")) {

            # Se verifica la instalaci�n del rol de Hyper-V
            $instalados = Get-WindowsFeature -Name  Hyper-V | Where-Object { $_.InstallState -eq "Installed"}
            if($instalados.Count -ge 1){
                $vname  = $os + $hostname
                New-VM -VMName $vname -Generation 1 # -SwitchName $virtualSwitch[$j]
                foreach ($vs in $switchesVirtualesAsociados) {Add-VMNetworkAdapter -VMName $vname -SwitchName $vs}
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
                    $pathDisk = $raiz+'\'+$vname+$disk+'.vhdx'
                    # Se revisa que la ruta del disco virtual no exista, en el caso de existir se genera un numero random para nombrarlo
                    while(Test-Path -Path $pathDisk){
                        $random = Get-Random
                        $pathDisk = $raiz+'\'+$vname+$disk+$random+'.vhdx'
                    }
                    $disk = [int]$disk * 1Gb
                    New-VHD -Path $pathDisk -SizeBytes $disk
                    Add-VMHardDiskDrive -VMName $vname -Path $pathDisk
                }
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
    } while ($true)

    Write-Host "`n`n"
}

# Creacion del proyecto (folder ra�z, caracter�sticas de las VMs a crear para el ambiente, validaciones).
if ($args.Count -eq 1) {
    $rutaJSON = $args[0] # Se lee la ruta donde est� el archivo de entrada
    if (Test-Path -Path $rutaJSON) { # Se valida que el archivo exista
        $archivoEntrada = Get-Content -Raw -Path $rutaJSON | ConvertFrom-Json # Se lee el archivo de entrada en formato JSON
        
        # Revision de la ruta raiz del proyecto
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

        # Revision de las especificaciones de las maquinas virtuales
        $numeroMaquinas = ($ArchivoEntrada[0].VMs | Measure-Object).Count # Numero de Maquinas por instalar
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
