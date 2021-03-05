#Importacion de modulos
foreach ($modulo in (Get-ChildItem -Path ".\" -Recurse -Include "*.psm1")) {
    Import-Module -Name $modulo -Force -DisableNameChecking
}
function VerificarHyperV {
    try{
        if((Get-WindowsFeature -Name "Hyper-V" | Where-Object { $_.InstallState -eq "Installed"}).Count -ne 1){
            # En caso de no encontrar el rol de Hyper-V procede a su instalacion
            Write-Host "No se encuentra instalado el rol Hyper-V:`n1) Instalar Rol`n2) Salir"
            $opcion = Read-Host -Prompt "Selecciona una opcion"
            switch($opcion){
                1 { 
                    Write-Host "El equipo se reiniciara una vez instalado el rol, ejecuta nuevamente al iniciar"
                    Start-Sleep 3
                    $computer = hostname
                    Install-WindowsFeature -Name "Hyper-V" -ComputerName $computer -IncludeManagementTools -Restart
                }
                2 { Write-Host "Programa terminado exitosamente"; exit }
                default{VerificarHyperV}
            }
        }
    }catch{
        Write-Host "Ejecute el programa en un ambiente Windows Server"
        exit
    }
} 
#Flujo principal
#Verificacion del Rol Hyper-V
VerificarHyperV
#Verificar subsistema linux
#Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1604 -OutFile Ubuntu.appx -UseBasicParsing

#Validacion de la existencia y correcto formato del archivo de configuracion .json
$archivoJSON = ValidarJSON
#Validacion de la existencia de la ruta donde se guardaran las maquinas virtuales
$rutaRaiz = ValidarRoot -rutaRaiz $archivoJSON.Root
#Validacion de todos los datos por maquina virtual de cada seccion del archivo de configuracion.json
$nombres = $maquinasValidadas = @()
$maquinas = $archivoJSON.MaquinasVirtuales
foreach($maquina in $maquinas){
    Write-Progress -Activity "Validando Datos" -CurrentOperation "$($maquina.Hostname)-$($maquina.SistemaOperativo)" `
    -Status "$(($porcentaje/$maquinas.Count)*100)% Completado:" -PercentComplete $(($porcentaje/$maquinas.Count)*100)
    $maquinasValidadas += ValidarDatosGenerales -maquinaVirtual $maquina -rutaRaiz $rutaRaiz
    $porcentaje++
    $nombres += $maquina.Hostname
}
ValidarNombreUnico -campo "$MaquinasVirtuales.Nombre" -arreglo $nombres
Write-Progress -Activity "Validando Datos" -Completed
CrearMaquinas -maquinas @(ConfirmarDatos -maquinas $maquinasValidadas) -rutaRaiz $rutaRaiz