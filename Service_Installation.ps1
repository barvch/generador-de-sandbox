# Funcion para obtener parametros de las maquinas virtuales que desean ser creadas  
function Datos-VM {
    param ([int]$contador)
    # Se recuperan los datos obligatorios independientemente del tipo de SO y se valida que sean correctos
    $raiz = $archivoEntrada.Root
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
    }else{
        "Los unicos tipos de memorias aceptadas son 'Dynamic' y 'Static'.`nRevise archivo JSON."
        exit
    }
    $discos = Validar-VHDX -listaDiscosPorCrear $archivoEntrada.VMs[$contador].DiskSize -letterRoot (-join $raiz[0,1])
    $imagen = Validar-ISO -imagen $archivoEntrada.VMs[$contador].ImagePath
    $interfaces = Validar-Redes -interfaces $archivoEntrada.VMs[$contador].InterfaceConfig # Se validan las configuraciones de red para todas las interfaces
    $numeroProcesadores = Validar-Procesadores -numeroProcesadores $archivoEntrada.VMs[$contador].ProcessorNumber
    $rutaUnattend = ".\recursos\unattend.xml"
    
    
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
                $num = Read-Host -Prompt "`t`tPor favor, ingresa el numero de la interfaz administrativa a usar"
                $interfazAdministrativa = $num
            } until ($interfazAdministrativa -in 0..($nombresInterfacesEncontradas.Count-1))
            "`tSe usara la interfaz $interfazAdministrativa como interfaz administrativa"
        } elseif ($interfazAdministrativa -eq "" -and $nombresInterfacesEncontradas.Count -eq 1){
            "`tNo se ha indicado una interfaz administrativa dentro del archivo de entrada, por lo que se tomara como administrativa, la unica interfaz que ha sido encontrada ($nombresInterfacesEncontradas[0])"
        } elseif ($interfazAdministrativa -in 0..$nombresInterfacesEncontradas-1) {
            "`tSe usara la interfaz $interfazAdministrativa como interfaz administrativa"
        } elseif ($interfazAdministrativa -gt $nombresInterfacesEncontradas-1) {
            "`tHa indicado el numero de una interfaz que no existe. Ha seleccionado la interfaz $interfazAdministrativa de un total de $nombresInterfacesEncontradas.Count"
            do {
                for ($i = 0; $i -le ($nombresInterfacesEncontradas.Count-1); $i++) {
                    Write-Host -NoNewline $nombresInterfacesEncontradas[$i]
                    Write-Host " -> Opcion [$i]"
                }
                $interfazAdministrativa = Read-Host -Prompt "`t`tPor favor, ingresa el numero de la interfaz administrativa a usar"
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
                Write-Host "`tSe usara el siguiente archivo de respaldo para este equipo: $respaldo"
            } else {
                Write-Host "`tNo se ha podido acceder a la ruta de la imagen dentro del archivo de entrada. Revisar el archivo JSON."
                exit
            }
        } else {
            Write-Host "`tNo se ha indicado un archivo de respaldo para este equipo"
        }
    }
#>
    
    # Para obtener los servicios a instalar dentro del equipo  
    Write-Host "Servicios a instalar dentro del equipo"

# -----------------------------------------------------------------------------CAMBIO-------------------------------------------------------------------------------------
    $serviciosDisponibles = @("Apache", "DHCP","DNS","IIS","Certificate Services","Active Directory","Windows Defender","WebDAV","RDP") # Se definen todos los servicios disponibles para este tipo de SO
    $serviciosPorInstalar = @() # Aca se almacenan los servicios que sean validados
    $servicios = $archivoEntrada.VMs[$contador].Services
    if ($servicios.Count -ne 0) {
        foreach ($servicio in $servicios) {
            if ($serviciosDisponibles.Contains($servicio.Name)) {
                if($servicio.Name -eq "Active Directory"){
                    $config = $servicio.Config
                    if($dominiosExistentes.Contains($config.Domain)){
                       Write-Host "`tEl dominio ingresado ya existe, modifique el nombre de dominio"
                       exit
                    }
                    else{
                        $dominiosExistentes += $config.Name
                    }

                }
                $serviciosPorInstalar += $servicio
            }
        }
        $existeRDP = $false
        foreach($service in $serviciosPortInstalar){
            if($service -eq "RDP"){
                $existeRDP = $true
            }
        }
        if(-not $existeRDP){
            $serviciosPorInstalar += @{"Name"="RDP"}
        }
        $existeAD = $false
        foreach ($servicio in $serviciosPorInstalar) {
            if(($servicio.Name -eq "Certificate Services" -or $servicio.Name -eq "Active Directory") -and -not $existeAD){
                $existeAD = $true
            }
            elseif(($servicio.Name -eq "Certificate Services" -or $servicio.Name -eq "Active Directory") -and $existeAD){
                Write-Host "`tNo se pueden instalar los servicios de Certificate Service y Active Directory en el mismo equipo"
                exit
            }
        }
       "`tLista de servicios a intalar dentro del equipo:"
        foreach ($servicioValidado in $serviciosPorInstalar) {
            Write-Host "`t`t"$servicioValidado.Name
        }
# -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
    } else {
        Write-Host "`tNo se han encontrados servicios a instalar para este equipo"
    }

    # Confirmacion de los datos que han sido leidos para la VM
    Do {
       $confirmacion = Read-Host -Prompt "Los datos presentados son correctos para el equipo $hostname? (S/N)"
       if ($confirmacion.toUpper().Equals("S")) {
            $vname = $sistemaOperativo + $hostname
            $switchesVirtualesAsociados = @()
            $nombreInterfazAsociada = @()
            foreach ($interfaz in $interfaces) {
                $nombreVSwitch = $interfaz.VirtualSwitch
                $nombreInterfazAsociada += $interfaz.Nombre
                if (Consultar-VSwitchDisponibles -nombreVirtualSwitch $nombreVSwitch) {
                    $switchesVirtualesAsociados += $nombreVSwitch  
                }
            }
            $crearVM = New-VM -VMName $vname -Generation 2 -Force
            [string] $adaptador = Get-VMNetworkAdapter -VMName $vname
            $eliminarInterfazDefault = Remove-VMNetworkAdapter -VMName $vname -VMNetworkAdapterName $adaptador.Name
            $agregarISO = Add-VMDvdDrive -VMName $vname -Path $imagen
            for ($i = 0;$i -le ($switchesVirtualesAsociados.Count-1); $i++) {Add-VMNetworkAdapter -VMName $vname -SwitchName $switchesVirtualesAsociados[$i] -Name $nombreInterfazAsociada[$i]}
            Set-VMProcessor -VMName $vname -Count $numeroProcesadores

            ## Si se establece memoria dinamica se obtienen los valores maximos y minimos
            $tamanioMemoria = [int]$tamanioMemoria * 1GB
            if($tipoDeMemoria -eq "Dynamic"){
                $minMemoria = $minMemoria * 1GB
                $maxMemoria = $maxMemoria * 1GB
                Set-VMMemory -VMName $vname -DynamicMemoryEnabled $True -MaximumBytes $maxMemoria -MinimumBytes $minMemoria -StartupBytes 1024MB
            }else{
                Set-VMMemory -VMName $vname -DynamicMemoryEnabled $false -StartupBytes $tamanioMemoria
            }                  
            $discoRaizVM = ($discos | Measure-Object -Maximum) # Se obtiene el disco de mayor tamaño para instalar el SO
            $vhdFlag = $false
            foreach ($disk in $discos){
                $pathDisk = $raiz+'\'+$vname+$disk+'.vhdx'
                # Se revisa que la ruta del disco virtual no exista, en el caso de existir se genera un numero random para nombrarlo
                if (Test-Path -Path $pathDisk) {
                    $random = Get-Random
                    $pathDisk = $raiz+'\'+$vname+$disk+$random+'.vhdx'
                }
                $disk = [int]$disk * 1GB
                New-VHD -Path $pathDisk -SizeBytes $disk | Out-Null
                Add-VMHardDiskDrive -VMName $vname -Path $pathDisk 
                if (($disk/1GB) -eq [int]$discoRaizVM.Maximum -and $vhdFlag -eq $false) {
                    if ($sistemaOperativo -eq "Windows 10") {
                        Modificar-Unattend  -username $usuario -passwd $passwd -rutaXML $rutaUnattend
                        "Presentando Versiones de Windows Disponibles dentro de ISO:`n"
                        Obtener-VersionesDeWindows -WinIso $imagen -VhdFile $pathDisk -UnattendFile $rutaUnattend
                        Get-VMDvdDrive -VMName $vname -ControllerNumber 0 | Remove-VMDvdDrive
                        Set-VMFirmware -VMName $vname -FirstBootDevice (Get-VMHardDiskDrive -VMName $vname)
                        Start-VM -Name $vname 
                        $vhdFlag = $true
                    }
                }
            }
            "Se ha creado satisfactoriamente la VM: $vmname"
# --------------------------------------------------------------------------CAMBIO---------------------------------------------------------------------------------------
            <#
            $password = ConvertTo-SecureString $passwd -AsPlainText -Force
            $cred= New-Object System.Management.Automation.PSCredential ($usuario, $password)
            foreach ($service in $serviciosPorInstalar) {
                if($service.Name -eq "Active Directory"){
                    Write-Host "Servicio | Active Directory Domain Services"
                    Install-ADDS -vname $vname -cred $cred
                }
            }
            foreach ($service in $serviciosPorInstalar) {
                if($service.Name -eq "IIS"){
                    Write-Host "Servicio | IIS"
                    Install-IIS -vname $vname -cred $cred
                }
                elseif($service.Name -eq "DHCP"){
                    Write-Host "Servicio | DHCP"
                    Install-DHCP -vname $vname -cred $cred -os $os
                }
                elseif($service.Name -eq "DNS"){
                    Write-Host "Servicio | DNS"
                    Install-DNS -vname $vname -cred $cred -os $os
                }
                elseif($service.Name -eq "Certificate Services"){
                    Write-Host "Servicio | AD Certificate Services"
                    Install-Certificate -vname $vname -cred $cred
                }
                elseif($service.Name -eq "Windows Defender"){
                    Write-Host "Servicio | Windows Defender"
                    Install-Defender -vname $vname -cred $cred
                }
                elseif($service.Name -eq "WebDAV"){
                    Write-Host "Servicio | WebDAV"
                    Install-WebDAV -vname $vname -cred $cred
                }
                elseif($service.Name -eq "RDP"){
                    Write-Host "Servicio | RDP"
                    Install-RDP -vname $vname -cred $cred
                }
            }
            #>
# -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
        } 
        break
       if ($confirmacion.ToUpper().Equals("N")) {
           Write-Host "Aplique los cambios necesarios sobre el archivo de entrada y ejecute el script de nuevo."
           exit
       }
       
    } while ($true)
}

# Psedo Main
if ($args.Count -eq 1) {
    # Se cargan todos los módulos necesarios por el programa 
    foreach ($modulo in (Get-ChildItem -Path ".\funciones" -Name)) {
        $lol = ".\funciones\"+$modulo
        Import-Module -Name $lol -Force -DisableNameChecking # Se leen las funciones que utiliza este archivo
    }
    Consultar-RolHyperV # Revisar si está o no el rol de Hyper-V dentro del Host Hyper-V. Lo instala en caso de que no este presente

    $rutaJSON = $args[0] # Se lee la ruta donde esta el archivo de entrada
    $archivoEntrada = Validar-JSON -rutaJSON $rutaJSON # Se lee y valida que exista el archivo y que esté en formato JSON
    $raiz = Validar-Raiz -rutaRaiz $archivoEntrada[0].Root # Se lee y valida la ruta raiz del proyecto a ser creado.
    $dominiosExistentes=@{}

    # Revision de las especificaciones de las maquinas virtuales    
    $numeroMaquinas = ($ArchivoEntrada[0].VMs | Measure-Object).Count # Numero de Maquinas por instalar
    for($i=0; $i -le $numeroMaquinas-1;$i++) {
        Write-Host $archivoEntrada.VMs[$i].Type
        Datos-VM -contador $i -os $archivoEntrada.VMs[$i].SO
    }
} else {
    "Sólo se debe de ingrear como algumento, la ruta donde se encuentre el archivo de entrada en formato JSON"
    exit
}
