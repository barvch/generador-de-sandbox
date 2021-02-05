# C:\ProgramData\Microsoft\Windows\Hyper-V

# Funcion que instala IIS
function Install-IIS {
    param([string]$vname, [PSCredential]$cred)
    
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ 
        Install-WindowsFeature -Name Web-Server –IncludeManagementTools
    }
    #Realiza la creación de sitios con sus respectivos bindings
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio)
            $numeroSitios = ($servicio.Sites | Measure-Object).Count # Numero de sitios por configurar
            for($i=0; $i -le $numeroSitios-1;$i++){
                Write-Host "Creando sitio " $servicio.Sites[$i].Name
                $bindings = $servicio.Sites[$i].Bindings #Array de objetos
                $siteName = $servicio.Sites[$i].Name
                $sitePath = $servicio.Sites[$i].SitePath
                #Creacion el directorio del sitio
                while(-not (Test-Path -Path $sitePath)){
                    Write-Host "Creando directorio " $sitePath
                    mkdir $sitePath
                }
                #Revisa todos los binding declarados
                foreach($bind in $bindings){
                    $ip = $bind.IP
                    $protocol = $bind.Protocol
                    if($ip -eq "" -or $ip -eq $null){
                        $ip = "*"
                    }
                    $binding = $ip + ":" + $bind.Port + ":" + $bind.Host
                    if($protocol -eq "https"){
                        #Crea sitio con bindig https
                        if($bind -eq $bindings[0]){
                            New-IISSite -Name $siteName -PhysicalPath $sitePath -BindingInformation $binding -Protocol https  -Force
                        }
                        #Agrega binding http al sitio
                        else{
                            New-IISSiteBinding -Name $siteName -BindingInformation $binding -Protocol https
                        }
                    }
                    elseif($protocol -eq "http"){
                        #Crea sitio con bindig http
                        if($bind -eq $bindings[0]){
                            New-IISSite -Name $siteName -PhysicalPath $sitePath -BindingInformation $binding -Protocol http  -Force
                        }
                        #Agrega binding http al sitio
                        else{
                            New-IISSiteBinding -Name $siteName -BindingInformation $binding  -Protocol http -Force
                        }
                    }
                }
            }
        } -args $service
}

#Funcion instala DHCP
function Install-DHCP {
    param([string]$vname, [PSCredential]$cred, [string]$os)
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
            Install-WindowsFeature DHCP -IncludeManagementTools
            Add-DhcpServerSecurityGroup
        }
        #Crea los diferentes scopes declarados
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio, [string]$domain)
            
            foreach($scope in $servicio.Scope){
                #Scope IPv4
                if($scope.Type -eq "IPv4"){
                    if($scope.State -eq "Active"){
                        Add-DhcpServerv4Scope -name $scope.Name -StartRange $scope.Start -EndRange $scope.End -SubnetMask $scope.Mask -State Active
                    }
                    else{
                        Add-DhcpServerv4Scope -name $scope.Name -StartRange $scope.Start -EndRange $scope.End -SubnetMask $scope.Mask -State Inactive
                    }
                    foreach($exclude in $scope.Exclude){
                        Add-DhcpServerv4ExclusionRange -ScopeID $exclude.ID -StartRange $exclude.Start -EndRange $exclude.End
                    }
                    if($scope.DNSHost -ne "" -and $scope.DNSHost -ne $null){
                        $dns = $scope.DNSHost + "." + $domain
                        Set-DhcpServerv4OptionValue -ScopeID $exclude.ID -DnsDomain $dns -DnsServer $scope.DNSIP -Router $scope.Router
                    }
                } 
                #Scope IPv6
                elseif($scope.Type -eq "IPv6"){
                    if($scope.State -eq "Active"){
                            Add-DhcpServerv6Scope -name $scope.Name -Prefix $scope.Prefix -State Active
                        }
                        else{
                            Add-DhcpServerv6Scope -name $scope.Name -Prefix $scope.Prefix -State Inactive
                        }
                        foreach($exclude in $scope.Exclude){
                            Add-DhcpServerv6ExclusionRange -Prefix $scope.Prefix -StartRange $exclude.Start -EndRange $exclude.End
                        }
                    }
            }
        } -ArgumentList $service.Config,$domain
}


#Funcion instala DNS
function Install-DNS {
    param([string]$vname, [PSCredential]$cred, [string]$os)
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
            Install-WindowsFeature DNS -IncludeManagementTools
        }
        Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio)
            #Se agregan las zonas Reverse para poder crear los registros PTR en las zonas Forward
            foreach($zone in $servicio.Zone){
                if($zone.Type -eq "Reverse"){
                    Add-DnsServerPrimaryZone -NetworkID $zone.Network -ZoneFile $zone.File
                    foreach($record in $zone.Records){
                        if($record.Type -eq "PTR"){
                             Add-DnsServerResourceRecordPtr -Name $record.Name -ZoneName $zone.Name -AllowUpdateAny -PtrDomainName $record.PtrDomain
                        }
                    }
                }
            }
            #Se agregan las zonas Forward y sus respectivos registros A, AAAA, CNAME, con sus respectivos PTR
            foreach($zone in $servicio.Zone){
                if($zone.Type -eq "Forward"){
                    Add-DnsServerPrimaryZone -Name $zone.Name -ZoneFile $zone.File
                    foreach($record in $zone.Records){
                        if($record.Type -eq "A"){
                            Add-DnsServerResourceRecordA -Name $record.Name -ZoneName $zone.Name -AllowUpdateAny -IPv4Address $record.IP -CreatePtr
                        }
                        elseif($record.Type -eq "AAAA"){
                            Add-DnsServerResourceRecordAAAA -Name $record.Name -ZoneName $zone.Name -AllowUpdateAny -IPv6Address $record.IP -CreatePtr
                        }
                        elseif($record.Type -eq "CNAME"){
                             Add-DnsServerResourceRecordCName -Name $record.Name -HostNameAlias $record.Alias -ZoneName $zone.Name
                        }
                    }
                }
            }
        } -ArgumentList $service.Config
}

#Funcion instala RDP
function Install-RDP {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    }
}

#Funcion instala AD Certificate Services
function Install-Certificate {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{
        Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools
    }
}

#Funcion instala AD Domain Services
function Install-ADDS {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio,[SecureString]$safePass)
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
        $modes = @{ "Windows Server 2008" = "Win2008"; "Windows Server 2008 R2" = "Win2008R2"; "Windows Server 2012" = "Win2012"; "Windows Server 2012 R2" = "Win2012R2"; "Windows Server 2016" = "Win2016"}
        #Revisa el modo de dominio y de bosque
        foreach($mode in $modes.keys){
            Write-Host $mode $servicio.ForestMode $servicio.DomainMode
            if($mode -eq $servicio.DomainMode){
                $domainMode = $modes[$mode]
            }
            if($mode -eq $servicio.ForestMode){
                $forest = $modes[$mode]
            }
        }
        #Agrega el bosque en el dominio
        if($forest -ne $null -and $domainMode -ne $null){
            Install-ADDSForest -DomainName $servicio.Domain -DomainNetbiosName $servicio.Netbios -ForestMode $forest -DomainMode $domainMode -Force -SafeModeAdministratorPassword $safePass
        }
    } -ArgumentList ($service.Config,$password)
}

#Funcion instala Windows Defender
function Install-Defender {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio)
        Install-WindowsFeature -Name Windows-Defender -IncludeManagementTools
        #Habilita el analisis de archivos como .rar y .zip
        Set-MpPreference -DisableArchiveScanning 0
        #Excluye rutas para analizar
        foreach($pathEx in $servicio.ExclusionPath){
            if(Test-Path -Path $pathEx){
                Add-MpPreference -ExclusionPath $pathEx
            }
            else{
                mkdir $pathEx
                Add-MpPreference -ExclusionPath $pathEx
            }
        }
        #Excluye procesos para analizar
        foreach($processEx in $servicio.ExclusionProcess){
            Add-MpPreference -ExclusionProcess $processEx
        }
        #Excluye extensiones para analizar
        foreach($extensionEx in $servicio.ExclusionExtension){
            Add-MpPreference -ExclusionExtension $extensionEx
        }
    } -args $service.Config
}

#Funcion instala WebDAV
function Install-WebDAV {
    param ([string]$vname, [PSCredential]$cred)
    Invoke-Command -VMName $vname -Credential $cred -ScriptBlock{ param([Object[]]$servicio,[string]$domain)
        Install-WindowsFeature -Name Web-DAV-Publishing
        Restart-Service W3SVC 
        foreach($group in $servicio.Groups){
            #Crecion de grupos
            New-LocalGroup -Name $group.Name
            foreach($member in $group.Members){
                #Agrega los miembros al grupo
                $memUser = $doman +"/" +$member
                Add-LocalGroupMember -Group $group.Name -Member $memUser
            }
            #Agrega las locaciones del directorio virtual
            foreach($location in $group.Locations){
                if(Test-Path -Path $location.Path){
                    New-WebVirtualDirectory -Site $location.Site -Name $location.Name -PhysicalPath $location.Path 
                }
                else{
                    mkdir $location.Path
                    New-WebVirtualDirectory -Site $location.Site -Name $location.Name -PhysicalPath $location.Path
                }
                # habilitar webDAV
                Set-WebConfigurationProperty -Filter '/system.webServer/webdav/authoring' -Location $location.Site -Name enabled -Value True
                foreach($folder in $location["Site"].Folders){
                    #deshabilitar autenticacion anonima
                    $f=$location.Site+"/"+$folder
                    Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/anonymousAuthentication' -Location $f -Name enabled -Value False
                    #habilitar autenticacion basica
                    Set-WebConfigurationProperty -Filter '/system.webServer/security/authentication/basicAuthentication' -Location $f -Name enabled -Value True
                    #otorgar persmisos a grupo
                    Add-WebConfiguration -Filter "/system.webServer/webdav/authoringRules" -Location $f -Value @{path="*";roles=$group.Name;access=$location.Permiso}
                    #habilitar Directory Browse
                    Set-WebConfigurationProperty -Filter '/system.webServer/directoryBrowse' -Location $f -Name enabled -Value True
                }
            }
        }
    } -args $service.Config,$domain
}

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
            "`tAlmacenamiento disponible: $libre GB | Tamanio del disco solicitado: $diskSize GB XXXX"
            exit
        }
        return ($libre - $diskSize)
    }
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
                        "`tAlmacenamiento disponible: $libre GB | Tamanio del disco solicitado: $temp GB"
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
    param ([string]$WinIso, [string]$VhdFile)
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

    Mount-DiskImage -ImagePath $VhdFile
    $disknumber = (Get-DiskImage -ImagePath $VhdFile | Get-Disk).Number

    $EfiLetter = [byte] $VirtualWinLetter + 1
    
    Write-Host "Montando discos..."

    "select disk $DiskNumber`nconvert gpt`nselect partition 1`ndelete partition override`ncreate partition primary size=300`nformat quick fs=ntfs `
    create partition efi size=100`nformat quick fs=fat32`nassign letter=$EfiLetter`ncreate partition msr size=128`ncreate partition primary`nformat quick fs=ntfs `
    assign letter=$VirtualWinLetter`nexit`n" | diskpart | Out-Null

    Invoke-Expression "dism /apply-image /imagefile:`"$WimFile`" /index:$WimIdx /applydir:$($VirtualWinLetter):\"

    Write-Host "Preparando la instalacion..."

    #Invoke-Expression $VirtualWinLetter":\Windows\System32\bcdboot.exe "$VirtualWinLetter":\Windows /f uefi /s "$EfiLetter":"
    Invoke-Expression $VirtualWinLetter":\Windows\System32\bcdboot.exe" #$VirtualWinLetter":\Windows /f uefi /s "$EfiLetter":"
    Invoke-Expression "bcdedit /store "$EfiLetter":\EFI\Microsoft\Boot\BCD"

    $UnattendFile = ".\unattend.xml"

    if($UnattendFile) {
        Write-Host "Copying unattend.xml"
        New-Item -ItemType "directory" -Path $VirtualWinLetter+":\Windows\Panther\" | Out-Null
        Copy-Item $UnattendFile $VirtualWinLetter+":\Windows\Panther\unattend.xml" | Out-Null
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
    $serviciosDisponibles = @("Apache", "DHCP") # Se definen todos los servicios disponibles para este tipo de SO
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
            if(($servicio.Name -eq "Certificate Services" -or $servicio.Name -eq "Active Directory") -and $existeAD){
                Write-Host "`tNo se pueden instalar los servicios de Certificate Service y Active Directory en el mismo equipo"
                exit
            }
        }
        "`tLista de servicios a intalar dentro del equipo:"
        foreach ($servicioValidado in $serviciosPorInstalar) {
            Write-Host "`t`t$servicioValidado"
        }
    } else {
        Write-Host "`tNo se han encontrados servicios a instalar para este equipo"
    }

    # Confirmacion de los datos que han sido leidos para la VM
    Do {
       $confirmacion = Read-Host -Prompt "¿Son los datos presentados correctos para el equipo $hostname? (S/N)"
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
                New-VHD -Path $pathDisk -SizeBytes $disk
                Add-VMHardDiskDrive -VMName $vname -Path $pathDisk 
                if (($disk/1GB) -eq [int]$discoRaizVM.Maximum -and $vhdFlag -eq $false) {
                    if ($sistemaOperativo -eq "Windows 10") {
                        "Presentando Versiones de Windows Disponibles dentro de ISO:"
                        Obtener-VersionesDeWindows -WinIso $imagen -VhdFile $pathDisk
                        $vhdFlag = $true
                    }
                }
            }
            "Se ha creado satisfactoriamente la VM: $vmname"
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
    Consultar-RolHyperV # Revisar si está o no el rol de Hyper-V dentro del Host Hyper-V. Lo instala en caso de que no este presente
    $rutaJSON = $args[0] # Se lee la ruta donde esta el archivo de entrada
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
    exit
}