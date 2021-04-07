function CrearBackup {
    param ([string ]$username, [string] $password,[string]$hostname, [string]$seed_file, [string]$directorio, [string]$os, $interfaces, [string]$vhdpath)

    Copy-Item ".\Recursos\unattend\FortiOS\FortiOS.conf" "$directorio" -Force
    (Get-Content "$directorio\FortiOS.conf").replace('{{hostname}}', $hostname) | Set-Content "$directorio\FortiOS.conf"
    $cadena = ""
    foreach ($i in 1..$interfaces.Count){
        if($interfaces[$i-1].Administrativa -or $interfaces.Count -eq 1){
            $cadena = $cadena + "edit `"port$i`"`n`tset vdom `"root`"`n`tset ip " + $interfaces[$i-1].IP + " "+ $interfaces[$i-1].MascaraRed + "`n`tset allowaccess ping https ssh http`n`tset type physical`n`tset snmp-index $i`nnext`n"
        }
        else{
            $cadena = $cadena + "edit `"port$i`"`n`tset vdom `"root`"`n`tset ip " + $interfaces[$i-1].IP + " "+ $interfaces[$i-1].MascaraRed + "`n`tset type physical`n`tset snmp-index $i`nnext`n"
        }
    }
    (Get-Content "$directorio\FortiOS.conf").replace('{{interfaces}}', $cadena) | Set-Content "$directorio\FortiOS.conf"
    (Get-Content "$directorio\FortiOS.conf").replace('{{username}}', $username) | Set-Content "$directorio\FortiOS.conf"
    (Get-Content "$directorio\FortiOS.conf").replace('{{password}}', $password) | Set-Content "$directorio\FortiOS.conf"

    MoverBackup -backup $seed_file -directorio $directorio -vhdpath $vhdpath
}

function MoverBackup{
    param ([string]$backup, [string]$directorio, [string]$vhdpath)

}
