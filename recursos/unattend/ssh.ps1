# Script para conectarse a una máquina virtual mediante SSH, copiar el archivo .sh de configuracion de servicios y ejecutarlo

# Módulos
#Install-Module -Name "Posh-SSH"

# Datos 
$password = "hola12345.,"
$user = "prueba"
$computerName = "192.168.0.35"

Write-Host "Generando creenciales seguras..."
$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

# Conexion por SSH a la VM
Write-Host "Estableciendo comunicacion SSH con ($computerName) ..."
try {
    New-SSHSession -ComputerName $computerName -Credential $credentials
} catch {
    "No se ha podido conectar por SSH al equipo. Revisar datos"
    exit
}

# Se copia el archivo post.sh al home del usuario
Write-Host "Copiando archivo a la máquina ..."
#bash -c "sudo apt update" | Out-Null

#bash -c "sudo apt install -y sshpass" | Out-Null
$cmd = "sshpass -p `"$password`" scp post.sh $user@$computerName`:/home/$user/post.sh"
$cmd2 = "sshpass -p `"$password`" scp archivo.json $user@$computerName`:/home/$user/archivo.json"
try  {
    bash -c $cmd
    bash -c $cmd2
    Write-Host "Archivos copiados exitosamente..."
} catch {
    Write-Host "No se la logrado copiar el archivo!"
    exit
}

# Ejecutando el archivo copiado 
Write-Host "Ejecutando el archivo copiado dentro del equipo..."
try  {
    Invoke-SSHCommand -ComputerName $computerName -Command "echo $password | sudo -S chmod +x /home/$user/post.sh"
    Invoke-SSHCommand -ComputerName $computerName -Command "echo $password | sudo -S /bin/bash /home/$user/post.sh"
    Write-Host ":)"
} catch {
    Write-Host "No se la logrado ejecutar el archivo copiado"
    exit
}

# Se termina la comunicación por SSH entre ambos equipos
Remove-SshSession -ComputerName $computerName 