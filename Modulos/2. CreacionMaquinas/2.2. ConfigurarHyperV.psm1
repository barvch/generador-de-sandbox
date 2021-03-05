function ConfigurarMaquinaHyperV { param ($maquina, $rutaRaiz)
    $hostname = $maquina.Hostname
    $so = $maquina.SistemaOperativo
    $vname = "$($hostname)-$($so)"
    $memoriaRAM = $maquina.MemoriaRAM
    $numeroProcesadores = $maquina.Procesadores
    $interfaces = $maquina.Interfaces
    $discosVirtuales = $maquina.DiscosVirtuales
    if ($so -match "Windows .*") { $generacion = 2 } else { $generacion = 1 }
    New-VM -VMName $vname -Generation $generacion -Path $rutaRaiz -Force | Out-Null
    if($memoriaRAM.Tipo -eq "Static"){
        Set-VMMemory -VMName $vname -DynamicMemoryEnabled $false -StartupBytes ($memoriaRAM.Memoria*1GB)
    }else{
        Set-VMMemory -VMName $vname -DynamicMemoryEnabled $True -MinimumBytes ($memoriaRAM.Minima*1GB) -StartupBytes ($memoriaRAM.Minima*1GB) -MaximumBytes ($memoriaRAM.Maxima*1GB)
    }
    $adaptador = Get-VMNetworkAdapter -VMName $vname
    Remove-VMNetworkAdapter -VMName $vname -VMNetworkAdapterName $adaptador.Name | Out-Null
    Set-VMProcessor -VMName $vname -Count $numeroProcesadores    
    foreach($interfaz in $interfaces){
        $nombreInterfaz = $interfaz.Nombre
        $nombreVS = $interfaz.VirtualSwitch.Nombre
        $tipoVS = $interfaz.VirtualSwitch.Tipo
        $adaptadorRed = $interfaz.VirtualSwitch.AdaptadorRed
        Add-VMNetworkAdapter -VMName $vname -Name $nombreInterfaz
        $switches = Get-VMSwitch 
        foreach($VSwitch in $switches){
            if($nombreVS -eq $VSwitch.Name -and $tipoVS -eq $VSwitch.SwitchType){
                $switchExistente = $true
                break;
            }
        }
        if(-not $switchExistente){
            if($tipoVS -eq "External"){
                New-VMSwitch -Name $nombreVS -NetAdapterName $adaptadorRed
            }else{
                New-VMSwitch -Name $nombreVS -SwitchType $tipoVS
            }
        }
        Connect-VMNetworkAdapter -Name $nombreInterfaz -VMName $vname -SwitchName $nombreVS
    }
    $contador = 1
    foreach ($tamanoDisco in $discosVirtuales) {
        $rutaDisco = "$($rutaRaiz)\$($vname)\DiscosVirtuales\$vname-$contador.vhd"
        New-VHD -Path $rutaDisco -SizeBytes ($tamanoDisco*1GB) | Out-Null
        Add-VMHardDiskDrive -VMName $vname -Path $rutaDisco | Out-Null
        $contador++
    }
}