function CrearMaquinas { param ($maquinas, $rutaRaiz)
    function Write-ProgressHelper { param ($currentOperation, $StepNumber)
        Write-Progress -Activity "Creando Maquinas Virtuales" -CurrentOperation "$hostname-$($so): $currentOperation" -Status "$([int](($StepNumber / $steps) * 100))% Completado:" -PercentComplete (($StepNumber / $steps) * 100)
    }
    #Se identifica cada referencia de la llamada a la funcion Write-ProgressHelper en el codigo
    $steps = ([System.Management.Automation.PsParser]::Tokenize($MyInvocation.MyCommand.Definition, [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Write-ProgressHelper' }).Count * $maquinas.Count
    $stepCounter = 0
    foreach($maquina in $maquinas){
        $maquina | ConvertTo-Json -depth 5 | Set-Content -Path ".\Recursos\unattend\tmp.json"
        $maquina = New-Object PSCustomObject -Property $maquina
        $hostname = $maquina.Hostname
        $so = $maquina.SistemaOperativo
        $vname = "$($hostname)-$($so)"
        Write-ProgressHelper -currentOperation "Configurando Maquina En Hyper-V" -StepNumber ($stepCounter++)
        ConfigurarMaquinaHyperV -maquina $maquina -rutaRaiz $rutaRaiz
        Write-ProgressHelper -currentOperation "Creando Disco De Instalacion Rapida" -StepNumber ($stepCounter++)
        ConfigurarInstalacionRapida -maquina $maquina -rutaRaiz $rutaRaiz
        #Write-ProgressHelper -currentOperation "Instalando Sistema Operativo y Configurando Servicios" -StepNumber ($stepCounter++)
        #InstalarServicios $maquina, $rutaRaiz
        Write-ProgressHelper -currentOperation "Iniciando Maquina" -StepNumber ($stepCounter++)
        Start-VM -Name $vname
    }
    Write-Progress -Activity "Creando Maquinas Virtuales" -Completed
    #ConfirmarDatos -maquinas $maquinas
}