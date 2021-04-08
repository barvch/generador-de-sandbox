function CrearBackup {
    param ([string ]$username, [string] $password,[string]$hostname, [string]$seed_file, [string]$directorio, [string]$os, $interfaces, [string]$vhdpath, [string]$vname)

    Copy-Item ".\Recursos\unattend\FortiOS\FortiOS.conf" "$directorio" -Force
    (Get-Content "$directorio\FortiOS.conf").replace('{{hostname}}', $hostname) | Set-Content "$directorio\FortiOS.conf"
    $cadena = ""
    foreach ($i in 1..$interfaces.Count){
        if($interfaces[$i-1].Administrativa -or $interfaces.Count -eq 1){
            $cadena = $cadena + "edit `"port$i`"`n`tset vdom `"root`"`n`tset mode static`n`tset ip " + $interfaces[$i-1].IP + " "+ $interfaces[$i-1].MascaraRed + "`n`tset allowaccess ping https ssh http`n`tset type physical`n`tset snmp-index $i`nnext`n"
        }
        else{
            $cadena = $cadena + "edit `"port$i`"`n`tset vdom `"root`"`n`tset mode static`n`tset ip " + $interfaces[$i-1].IP + " "+ $interfaces[$i-1].MascaraRed + "`n`tset type physical`n`tset snmp-index $i`nnext`n"
        }
    }
    (Get-Content "$directorio\FortiOS.conf").replace('{{interfaces}}', $cadena) | Set-Content "$directorio\FortiOS.conf"
    (Get-Content "$directorio\FortiOS.conf").replace('{{username}}', $username) | Set-Content "$directorio\FortiOS.conf"
    (Get-Content "$directorio\FortiOS.conf").replace('{{password}}', $password) | Set-Content "$directorio\FortiOS.conf"

    MoverBackup -backup "$directorio\$seed_file" -directorio $directorio -vhdpath $vhdpath -vname $vname
}

function MoverBackup{
    param ([string]$backup, [string]$directorio, [string]$vhdpath, [string]$vname)

    New-Item "$directorio\cloudinit\openstack" -itemtype directory
    New-Item "$directorio\cloudinit\openstack\content" -itemtype directory
    New-Item "$directorio\cloudinit\openstack\latest" -itemtype directory

    Add-Content -Path "$directorio\cloudinit\openstack\latest\user_data" -Value "config system admin"
    Add-Content -Path "$directorio\cloudinit\openstack\latest\user_data" -Value "`trename admin to admin_old"
    Add-Content -Path "$directorio\cloudinit\openstack\latest\user_data" -Value "`tdelete admin_old"
    Add-Content -Path "$directorio\cloudinit\openstack\latest\user_data" -Value "end"  
    
    Add-Content -Path "$directorio\cloudinit\openstack\latest\user_data" -Value "config system interface"
    Add-Content -Path "$directorio\cloudinit\openstack\latest\user_data" -Value "`tedit `"port1`""
    Add-Content -Path "$directorio\cloudinit\openstack\latest\user_data" -Value "`tclear allowaccess"
    Add-Content -Path "$directorio\cloudinit\openstack\latest\user_data" -Value "end"  
    (Get-Content $backup) | Add-Content -Path "$directorio\cloudinit\openstack\latest\user_data"

    $repo = (Get-Location).Path
    Set-Location "$directorio"
    bash -c "mkisofs -R -r -o  fgt-bootstrap.iso cloudinit &> /dev/null" | Out-Null
    Set-Location $repo

    Set-VMDvdDrive -VMName $vname -Path "$directorio\fgt-bootstrap.iso"
}
