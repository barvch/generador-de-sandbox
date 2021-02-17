function Linux-DHCP{
        "#!/bin/bash" | Out-File -FilePath dhcp.sh

        #Funcion para la creacion de scopes por subred y Hosts
        'create_dhcp(){' | Add-Content -Path dhcp.sh
        '	if [ -e /etc/dhcp/dhcpd.conf ]' | Add-Content -Path dhcp.sh
        '	then' | Add-Content -Path dhcp.sh
        '		sudo mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.back' | Add-Content -Path dhcp.sh
        '	fi' | Add-Content -Path dhcp.sh
        '       sudo touch /etc/dhcp/dhcpd.conf' | Add-Content -Path dhcp.sh
        if($servicio.DomainName -ne $null -and $servicio.DomainName -ne ""){
            "       sudo bash -c 'echo `"option domain-name \`"" | Add-Content -Path dhcp.sh -NoNewline
            $servicio.DomainName | Add-Content -Path dhcp.sh -NoNewline
            "\`";`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
        }
        foreach($domainServer in $servicio.DomainServer){
            if($servicio.DomainServer[0] -eq $domainServer){
                "       sudo bash -c 'echo `"option domain-name-servers " | Add-Content -Path dhcp.sh -NoNewline
            }
            $domainServer | Add-Content -Path dhcp.sh -NoNewline
            if($domainServer -ne $servicio.DomainServer[-1]){
                ", " | Add-Content -Path dhcp.sh -NoNewline
            }
        }
        ";`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
        foreach($scope in $servicio.Scope){
            if($scope.Type -eq "IPv4"){
                "       sudo bash -c 'echo `"subnet " | Add-Content -Path dhcp.sh -NoNewline
                $scope.ID | Add-Content -Path dhcp.sh -NoNewline
                ' netmask ' | Add-Content -Path dhcp.sh -NoNewline
                $scope.Mask | Add-Content -Path dhcp.sh -NoNewline
                 " {`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
                "       sudo bash -c 'echo `"range " | Add-Content -Path dhcp.sh -NoNewline
                $scope.Start | Add-Content -Path dhcp.sh -NoNewline
                " " | Add-Content -Path dhcp.sh -NoNewline
                $scope.End | Add-Content -Path dhcp.sh -NoNewline
                ";`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
                "       sudo bash -c 'echo `"option broadcast-address " | Add-Content -Path dhcp.sh -NoNewline
                $scope.Broadcast  | Add-Content -Path dhcp.sh -NoNewline
                ";`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
                if($scope.Router -ne $null -and $scope.Router -ne ""){
                    "       sudo bash -c 'echo `"option routers " | Add-Content -Path dhcp.sh -NoNewline
                    $scope.Router  | Add-Content -Path dhcp.sh -NoNewline
                    ";`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
                }
                "       sudo bash -c 'echo `"}`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
                " " | Add-Content -Path dhcp.sh
            }
        }
        foreach($hostDHCP in $servicio.Hosts){
            "       sudo bash -c 'echo `"host " | Add-Content -Path dhcp.sh -NoNewline
            $hostDHCP.Name | Add-Content -Path dhcp.sh -NoNewline
            " {`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
            "       sudo bash -c 'echo `"hardware ethernet " | Add-Content -Path dhcp.sh -NoNewline
            $hostDHCP.MAC | Add-Content -Path dhcp.sh -NoNewline
            ";`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
            "       sudo bash -c 'echo `"fixed-address " | Add-Content -Path dhcp.sh -NoNewline
            $hostDHCP.IP  | Add-Content -Path dhcp.sh -NoNewline
            ";`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
            "       sudo bash -c 'echo `"}`" >> /etc/dhcp/dhcpd.conf'" | Add-Content -Path dhcp.sh
            " " | Add-Content -Path dhcp.sh
        }
        "}" | Add-Content -Path dhcp.sh

        #Funcion para obtener el listado de interfaces
        'list_interface(){' | Add-Content -Path dhcp.sh
        "       string=`$(sudo ifconfig | cut -d `" `" -f 1 | cut -d `":`" -f 1 | tr -s `"\n`" `" `")" | Add-Content -Path dhcp.sh
        "       IFS=' ' read -r -a interfaces <<< `"`$string`"" | Add-Content -Path dhcp.sh
        "       echo `"Elige una interfaz para dhcp`"" | Add-Content -Path dhcp.sh
        "       for element in `"`${!interfaces[@]}`"" | Add-Content -Path dhcp.sh
        "       do" | Add-Content -Path dhcp.sh
        "       if [[ `${interfaces[element]} != `"lo`" ]]" | Add-Content -Path dhcp.sh
	    "       then" | Add-Content -Path dhcp.sh
		"              echo `"[`$element] -> `${interfaces[element]}`"" | Add-Content -Path dhcp.sh
	    "       fi" | Add-Content -Path dhcp.sh
        "       done" | Add-Content -Path dhcp.sh
        "       read opcion"  | Add-Content -Path dhcp.sh
        "       if [ -e /etc/sysconfig/dhcpd ]" | Add-Content -Path dhcp.sh
        "       then" | Add-Content -Path dhcp.sh
        "           sudo sed `"s/INTERFACES=\`"/&`${interfaces[opcion]}/`" -i /etc/sysconfig/dhcpd" | Add-Content -Path dhcp.sh
        "       elif [ -e /etc/default/isc-dhcp-server ]" | Add-Content -Path dhcp.sh
        "       then" | Add-Content -Path dhcp.sh
        "           sudo sed `"s/INTERFACESv4=\`"/&`${interfaces[opcion]}/`" -i /etc/default/isc-dhcp-server" | Add-Content -Path dhcp.sh
        "       fi" | Add-Content -Path dhcp.sh
        "}" | Add-Content -Path dhcp.sh

        'instalacion_descarga(){' | Add-Content -Path dhcp.sh
        '	so=$(hostnamectl | grep -i "operating system" | cut -d " " -f 5,6,7)' | Add-Content -Path dhcp.sh
        '	wget https://downloads.isc.org/isc/dhcp/4.4.2/dhcp-4.4.2.tar.gz' | Add-Content -Path dhcp.sh
        "	if [ -e dhcp-4.4.2.tar.gz ]" | Add-Content -Path dhcp.sh
        "	then" | Add-Content -Path dhcp.sh
        "		tar -xzvf dhcp-4.4.2.tar.gz" | Add-Content -Path dhcp.sh
        "		cd dhcp-4.4.2" | Add-Content -Path dhcp.sh
        '       if [[ $so == *"Ubuntu"* ]]' | Add-Content -Path dhcp.sh
	    '       then' | Add-Content -Path dhcp.sh
		'       res=$(sed ' | Add-Content -Path dhcp.sh -NoNewline
        "'y/1/0/' /etc/apt/apt.conf.d/20auto-upgrades)" | Add-Content -Path dhcp.sh 
        '		echo -e "' | Add-Content -Path dhcp.sh -NoNewline
        "$passwd" | Add-Content -Path dhcp.sh -NoNewline
		'\n" | sudo -S bash -c "echo ' | Add-Content -Path dhcp.sh -NoNewline
        "'" | Add-Content -Path dhcp.sh -NoNewline
        '$res' | Add-Content -Path dhcp.sh -NoNewline
        "' > /etc/apt/apt.conf.d/20auto-upgrades`"" | Add-Content -Path dhcp.sh
        '       sudo apt-get install build-essential make net-tools -y' | Add-Content -Path dhcp.sh
        '       elif [[ $so == *"CentOS"*  || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path dhcp.sh
        '       then' | Add-Content -Path dhcp.sh
        '		echo -e "' | Add-Content -Path dhcp.sh -NoNewline
        "$passwd" | Add-Content -Path dhcp.sh -NoNewline
        '\n" | sudo -S dnf install gcc make redhat-lsb -y' | Add-Content -Path dhcp.sh
        '		else'  | Add-Content -Path dhcp.sh 
        '		echo -e "' | Add-Content -Path dhcp.sh -NoNewline
        "$passwd" | Add-Content -Path dhcp.sh -NoNewline
        '\n" | sudo -S apt-get install build-essential make net-tools -y' | Add-Content -Path dhcp.sh
        '		fi'  | Add-Content -Path dhcp.sh 
        '		( export CFLAGS="$CFLAGS -Wall -fno-strict-aliasing \' | Add-Content -Path dhcp.sh
        '		 -D_PATH_DHCLIENT_SCRIPT=' | Add-Content -Path dhcp.sh -NoNewline
        "'" | Add-Content -Path dhcp.sh -NoNewline
        '\"/sbin/dhclient-script\"' | Add-Content -Path dhcp.sh -NoNewline
        "'\" | Add-Content -Path dhcp.sh
        ' 		 -D_PATH_DHCPD_CONF=' | Add-Content -Path dhcp.sh -NoNewline
        "'" | Add-Content -Path dhcp.sh -NoNewline
        '\"/etc/dhcp/dhcpd.conf\"' | Add-Content -Path dhcp.sh -NoNewline
        "'\" | Add-Content -Path dhcp.sh

        ' 		 -D_PATH_DHCLIENT_CONF=' | Add-Content -Path dhcp.sh -NoNewline
        "'" | Add-Content -Path dhcp.sh -NoNewline
        '\"/etc/dhcp/dhclient.conf\"' | Add-Content -Path dhcp.sh -NoNewline
        "'`" &&" | Add-Content -Path dhcp.sh
        '		 ./configure --prefix=/usr \' | Add-Content -Path dhcp.sh
        ' 		 --sysconfdir=/etc/dhcp \' | Add-Content -Path dhcp.sh
        ' 		 --localstatedir=/var \' | Add-Content -Path dhcp.sh
        ' 		 --with-srv-lease-file=/var/lib/dhcpd/dhcpd.leases \' | Add-Content -Path dhcp.sh
        ' 		 --with-srv6-lease-file=/var/lib/dhcpd/dhcpd6.leases \' | Add-Content -Path dhcp.sh
        '		 --with-cli-lease-file=/var/lib/dhclient/dhclient.leases \' | Add-Content -Path dhcp.sh
        ' 		 --with-cli6-lease-file=/var/lib/dhclient/dhclient6.leases \' | Add-Content -Path dhcp.sh
        '		) &&' | Add-Content -Path dhcp.sh
        '		make -j1' | Add-Content -Path dhcp.sh
        '		cd dhcp-4.4.2' | Add-Content -Path dhcp.sh
        '		sudo make -C server install' | Add-Content -Path dhcp.sh
        '		create_dhcp'  | Add-Content -Path dhcp.sh
        '		sudo install -v -dm 755 /var/lib/dhcpd' | Add-Content -Path dhcp.sh
        '	wget  http://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-20210122.tar.xz' | Add-Content -Path dhcp.sh
        "	if [ -e blfs-systemd-units-20210122.tar.xz ]" | Add-Content -Path dhcp.sh
        "	then" | Add-Content -Path dhcp.sh
        "		tar -Jxvf blfs-systemd-units-20210122.tar.xz" | Add-Content -Path dhcp.sh
        "       cd blfs-systemd-units-20210122" | Add-Content -Path dhcp.sh
        "       sudo make install-dhcpd" | Add-Content -Path dhcp.sh
        "       sudo touch /var/lib/dhcpd/dhcpd.leases" | Add-Content -Path dhcp.sh
        "       list_interface" | Add-Content -Path dhcp.sh
        '       if [[ $so == *"CentOS"*  || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path dhcp.sh
        "       then" | Add-Content -Path dhcp.sh
        "          sudo setenforce 0"  | Add-Content -Path dhcp.sh
        "          sudo /usr/sbin/dhcpd" | Add-Content -Path dhcp.sh
        '	       sudo systemctl enable --now dhcpd' | Add-Content -Path dhcp.sh
        '	       sudo firewall-cmd --add-port=67/udp --permanent' | Add-Content -Path dhcp.sh
        '	       sudo firewall-cmd --reload' | Add-Content -Path dhcp.sh 
        '       else'  | Add-Content -Path dhcp.sh
        "          sudo /usr/sbin/dhcpd" | Add-Content -Path dhcp.sh
        '	    fi' | Add-Content -Path dhcp.sh
        '	else' | Add-Content -Path dhcp.sh
        '		echo "No existe el archivo"' | Add-Content -Path dhcp.sh
        '	fi' | Add-Content -Path dhcp.sh
        '	else' | Add-Content -Path dhcp.sh
        '		echo "No existe el archivo"' | Add-Content -Path dhcp.sh
        '	fi' | Add-Content -Path dhcp.sh
        "}" | Add-Content -Path dhcp.sh

        'so=$(hostnamectl | grep -i "operating system" | cut -d " " -f 5,6,7)' | Add-Content -Path dhcp.sh
        'if [[ $so == *"Kali"* ]]' | Add-Content -Path dhcp.sh
        "then" | Add-Content -Path dhcp.sh
        '	echo -e "' | Add-Content -Path dhcp.sh -NoNewline
        "$passwd" | Add-Content -Path dhcp.sh -NoNewline
        '\n" | sudo -S apt-get install isc-dhcp-server -y' | Add-Content -Path dhcp.sh
        '	create_dhcp'  | Add-Content -Path dhcp.sh
        "       list_interface" | Add-Content -Path dhcp.sh
        'else' | Add-Content -Path dhcp.sh
        '	instalacion_descarga' | Add-Content -Path dhcp.sh
        'fi' | Add-Content -Path dhcp.sh
}

function Linux-DNS{
        $networks = @()
        $serialF = 3
        $serialR = 3
        "#!/bin/bash" | Out-File -FilePath dns.sh
        
        #Funcion crea los archivos de las zonas
        'create_zone_files(){' | Add-Content -Path dns.sh
        '    if [[ $so == *"CentOS"* || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path dns.sh
        '    then' | Add-Content -Path dns.sh
        "        dir=/var/named" | Add-Content -Path dns.sh
        '    elif [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path dns.sh
	    '    then' | Add-Content -Path dns.sh
        "        dir=/etc/bind/" | Add-Content -Path dns.sh
        '    fi' | Add-Content -Path dns.sh
        foreach($zone in $servicio.Zone){
            $archivo = $zone.Name + "." + $zone.Type
            "    sudo bash -c 'echo `"\`$TTL    604800`" >> $archivo'" | Add-Content -Path dns.sh
            "    sudo bash -c 'echo `"@       IN      SOA     ns1." | Add-Content -Path dns.sh -NoNewline
            $zone.Name | Add-Content -Path dns.sh -NoNewline
            ". root." | Add-Content -Path dns.sh -NoNewline
            $zone.Name | Add-Content -Path dns.sh -NoNewline
            ". (`" >> $archivo'" | Add-Content -Path dns.sh
            if($zone.Type -eq "Forward"){
                "    sudo bash -c 'echo `"$serialF  ; Serial`" >> $archivo'"  | Add-Content -Path dns.sh
                $serialF += 1
            }
            elseif($zone.Type -eq "Reverse"){
                "    sudo bash -c 'echo `"$serialR  ; Serial`" >> $archivo'"  | Add-Content -Path dns.sh
                $serialR += 1
            }
            "    sudo bash -c 'echo `"604800 ; Refresh`" >> $archivo'"  | Add-Content -Path dns.sh
            "    sudo bash -c 'echo `"86400 ; Retry`" >> $archivo'"  | Add-Content -Path dns.sh
            "    sudo bash -c 'echo `"2419200 ; Expire`" >> $archivo'"  | Add-Content -Path dns.sh
            "    sudo bash -c 'echo `"604800 ) ; Negative Cache TTL`" >> $archivo'"  | Add-Content -Path dns.sh
            "    sudo bash -c 'echo `"@   IN   NS   ns1." | Add-Content -Path dns.sh -NoNewline
            $zone.Name | Add-Content -Path dns.sh -NoNewline
            ".`" >> $archivo'"  | Add-Content -Path dns.sh
            if($zone.Type -eq "Forward"){
                foreach($record in $zone.Records){
                    "    sudo bash -c 'echo `"" | Add-Content -Path dns.sh -NoNewline
                    $record.NameServer | Add-Content -Path dns.sh -NoNewline
                    "   IN   " | Add-Content -Path dns.sh -NoNewline
                    $record.Type  | Add-Content -Path dns.sh -NoNewline
                    " " | Add-Content -Path dns.sh -NoNewline
                    if($record.Type -eq "CNAME"){
                        $serverName = $record.Alias + "." + $zone.Name
                        $serverName | Add-Content -Path dns.sh -NoNewline
                        ".`" >> $archivo'"  | Add-Content -Path dns.sh
                    }
                    else{
                        $record.IP | Add-Content -Path dns.sh -NoNewline
                        "`" >> $archivo'"  | Add-Content -Path dns.sh
                    }
                }
            }
            elseif($zone.Type -eq "Reverse"){
                $reverse = $zone.Network
                $reverse = $reverse.Split(".")
                foreach($record in $zone.Records){
                    $serverIP = $null
                    $server = $record.IP
                    $server = $server.Split(".")
                    for ($i = 0; $i -lt $server.Count; $i++){
                        if($server[$i] -eq $reverse[$i] -and $reverseIP -eq $null){
                            continue
                        }
                        $serverIP = $serverIP + $server[$i]
                        if($i -ne $reverse.Count-1){
                            $serverIP = $serverIP + "."
                        }
                    }
                    $serverName = $record.NameServer + "." + $zone.Name
                    "    sudo bash -c 'echo `"" | Add-Content -Path dns.sh -NoNewline
                    $serverIP | Add-Content -Path dns.sh -NoNewline
                    "   IN   PTR   " | Add-Content -Path dns.sh -NoNewline
                    $serverName | Add-Content -Path dns.sh -NoNewline
                    ".`" >> $archivo'"  | Add-Content -Path dns.sh
                }
            }
            "    sudo mv $archivo `$dir" | Add-Content -Path dns.sh
        }
        "}" | Add-Content -Path dns.sh

        # Funcion para permitir consultas DNS de la red especificada
        'allow_query(){' | Add-Content -Path dns.sh
        '    if [[ $so == *"CentOS"* || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path dns.sh
        '    then' | Add-Content -Path dns.sh
        "        archivo=/etc/named.conf" | Add-Content -Path dns.sh
        '    elif [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path dns.sh
	    '    then' | Add-Content -Path dns.sh
        "        archivo=/etc/bind/named.conf.options" | Add-Content -Path dns.sh
        '    fi' | Add-Content -Path dns.sh
        foreach($zone in $servicio.Zone){
            if(-not ($networks -contains $zone.Network)){
                "    sudo sed `"s/allow-query.*{ /&" | Add-Content -Path dns.sh -NoNewline
                $zone.Network | Add-Content -Path dns.sh -NoNewline
                "\/" | Add-Content -Path dns.sh -NoNewline
                $zone.Prefix | Add-Content -Path dns.sh -NoNewline
                "; /`" -i `$archivo" | Add-Content -Path dns.sh
                $networks += $zone.Network
            }
        }
        "}" | Add-Content -Path dns.sh
        
        #Funcion que agrega las zonas a usar en el archivo de configuracion
        'create_zone(){' | Add-Content -Path dns.sh
        '    if [[ $so == *"CentOS"* || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path dns.sh
        '    then' | Add-Content -Path dns.sh
        "        archivo=/etc/named.conf" | Add-Content -Path dns.sh
        foreach($zone in $servicio.Zone){
            $reverseIP = $null
            if($zone.Type -eq "Forward"){
                "    sudo bash -c 'echo `"zone \`"" | Add-Content -Path dns.sh -NoNewline
                $zone.Name | Add-Content -Path dns.sh -NoNewline
                "\`" IN {`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"type master;`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"file \`"" | Add-Content -Path dns.sh -NoNewline
                $zone.Name | Add-Content -Path dns.sh -NoNewline
                "." | Add-Content -Path dns.sh -NoNewline
                $zone.Type | Add-Content -Path dns.sh -NoNewline
                "\`";`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"allow-update { none; };`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"allow-query { any; };`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"};`" >> `/etc/named.conf'"  | Add-Content -Path dns.sh
            }
            elseif($zone.Type -eq "Reverse"){
                $reverse = $zone.Network
                $reverse = $reverse.Split(".")
                [array]::Reverse($reverse)
                foreach ($num in $reverse){
                    if($num -eq "0" -and $reverseIP -eq $null){
                        continue
                    }
                    $reverseIP = $reverseIP + $num
                    if($num -ne $reverse[$reverse.Length - 1]){
                        $reverseIP = $reverseIP + "."
                    }
                }
                "    sudo bash -c 'echo `"zone \`"$reverseIP.in-addr.arpa\`" IN {`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"type master;`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"file \`"" | Add-Content -Path dns.sh -NoNewline
                $zone.Name | Add-Content -Path dns.sh -NoNewline
                "." | Add-Content -Path dns.sh -NoNewline
                $zone.Type | Add-Content -Path dns.sh -NoNewline
                "\`";`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"allow-update { none; };`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"allow-query { any; };`" >> `/etc/named.conf'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"};`" >> `/etc/named.conf'"  | Add-Content -Path dns.sh
            }
        }
        '    elif [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path dns.sh
	    '    then' | Add-Content -Path dns.sh
        "        archivo=/etc/bind/named.conf.local" | Add-Content -Path dns.sh
        foreach($zone in $servicio.Zone){
            $reverseIP = $null
            if($zone.Type -eq "Forward"){
                "    sudo bash -c 'echo `"zone \`"" | Add-Content -Path dns.sh -NoNewline
                $zone.Name | Add-Content -Path dns.sh -NoNewline
                "\`" IN {`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"type master;`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"file \`"" | Add-Content -Path dns.sh -NoNewline
                $zone.Name | Add-Content -Path dns.sh -NoNewline
                "." | Add-Content -Path dns.sh -NoNewline
                $zone.Type | Add-Content -Path dns.sh -NoNewline
                "\`";`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"allow-update { none; };`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"allow-query { any; };`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"};`" >> `/etc/bind/named.conf.local'"  | Add-Content -Path dns.sh
            }
            elseif($zone.Type -eq "Reverse"){
                $reverse = $zone.Network
                $reverse = $reverse.Split(".")
                [array]::Reverse($reverse)
                foreach ($num in $reverse){
                    if($num -eq "0" -and $reverseIP -eq $null){
                        continue
                    }
                    $reverseIP = $reverseIP + $num
                    if($num -ne $reverse[$reverse.Length - 1]){
                        $reverseIP = $reverseIP + "."
                    }
                }
                "    sudo bash -c 'echo `"zone \`"$reverseIP.in-addr.arpa\`" IN {`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"type master;`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"file \`"" | Add-Content -Path dns.sh -NoNewline
                $zone.Name | Add-Content -Path dns.sh -NoNewline
                "." | Add-Content -Path dns.sh -NoNewline
                $zone.Type | Add-Content -Path dns.sh -NoNewline
                "\`";`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"allow-update { none; };`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"allow-query { any; };`" >> `/etc/bind/named.conf.local'" | Add-Content -Path dns.sh
                "    sudo bash -c 'echo `"};`" >> `/etc/bind/named.conf.local'"  | Add-Content -Path dns.sh
            }
        }
        '    fi' | Add-Content -Path dns.sh
        "}" | Add-Content -Path dns.sh

        #Intalacion paquetes DNS
        '    so=$(hostnamectl | grep -i "operating system" | cut -d " " -f 5,6,7)' | Add-Content -Path dns.sh
        '    if [[ $so == *"CentOS"* || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path dns.sh
	    '    then' | Add-Content -Path dns.sh
        '		echo -e "' | Add-Content -Path dns.sh -NoNewline
        "$passwd" | Add-Content -Path dns.sh -NoNewline
        '\n" | sudo -S dnf install bind bind-utils -y' | Add-Content -Path dns.sh
        '    elif [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path dns.sh
	    '    then' | Add-Content -Path dns.sh
        '		echo -e "' | Add-Content -Path dns.sh -NoNewline
        "$passwd" | Add-Content -Path dns.sh -NoNewline
        '\n" | sudo -S apt-get install bind9 bind9utils -y' | Add-Content -Path dns.sh
        '    fi' | Add-Content -Path dns.sh
        '	 allow_query'  | Add-Content -Path dns.sh
        '	 create_zone'  | Add-Content -Path dns.sh
        '	 create_zone_files'  | Add-Content -Path dns.sh
}

# Instalacion SQL Server en Ubuntu, versiones 16.04 y 18.04
function Linux-SQL{
    "#!/bin/bash" | Out-File -FilePath sql.sh
    'so=$(hostnamectl | grep -i "operating system" | cut -d " " -f 5)' | Add-Content -Path sql.sh
    'if [[ $so == *"Ubuntu"* ]]' | Add-Content -Path sql.sh
    "then" | Add-Content -Path sql.sh
    '	echo -e "' | Add-Content -Path sql.sh -NoNewline
    "$passwd" | Add-Content -Path sql.sh -NoNewline
    '\n" | sudo -S apt-get update' | Add-Content -Path sql.sh
    "    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -" | Add-Content -Path sql.sh
    '    version=$(hostnamectl | grep -i "operating system" | cut -d " " -f 6)' | Add-Content -Path sql.sh
    "    if [[ `$version == *`"18.04`"* ]]" | Add-Content -Path sql.sh
    "    then" | Add-Content -Path sql.sh
    '        sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/18.04/mssql-server-2019.list)"' | Add-Content -Path sql.sh
    "    elif [[ `$version == *`"16.04`"* ]]" | Add-Content -Path sql.sh
    "    then" | Add-Content -Path sql.sh
    '        sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/16.04/mssql-server-2019.list)"' | Add-Content -Path sql.sh
    "    else" | Add-Content -Path sql.sh
    "        exit" | Add-Content -Path sql.sh
    "    fi" | Add-Content -Path sql.sh
    "    sudo apt-get update" | Add-Content -Path sql.sh
    "    sudo apt-get install curl mssql-server -y" | Add-Content -Path sql.sh
    if($servicio.Version -eq "evaluation" -or $servicio.Version -eq "developer" -or $servicio.Version -eq "express" -or $servicio.Version -eq "web" -or $servicio.Version -eq "standard" -or $servicio.Version -eq "enterprise" -or $servicio.Version.Length -eq 25){
        $version = $servicio.Version
    }
    else{
        $version = "developer"
    }
    "    sudo MSSQL_SA_PASSWORD=" | Add-Content -Path sql.sh -NoNewline
    $servicio.Passwd | Add-Content -Path sql.sh -NoNewline
    " \" | Add-Content -Path sql.sh
    "     MSSQL_PID=$version \"| Add-Content -Path sql.sh
    "/opt/mssql/bin/mssql-conf -n setup accept-eula" | Add-Content -Path sql.sh
    "    curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -"  | Add-Content -Path sql.sh
    "    curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list"  | Add-Content -Path sql.sh
    "    sudo apt-get update" | Add-Content -Path sql.sh
    "    sudo ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev" | Add-Content -Path sql.sh
    "    echo 'export PATH=`"`$PATH:/opt/mssql-tools/bin`"' >> ~/.bashrc" | Add-Content -Path sql.sh
    "    source ~/.bashrc" | Add-Content -Path sql.sh
    "fi" | Add-Content -Path sql.sh
}

function Linux-Apache{
        "#!/bin/bash" | Out-File -FilePath apache.sh

        'config(){' | Add-Content -Path apache.sh
            '    if [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path apache.sh
	        '    then' | Add-Content -Path apache.sh
            "        sudo sed -e 's/ServerTokens OS/ServerTokens ProductOnly/' \"  | Add-Content -Path apache.sh
            "            -e 's/ServerSignature On/#&/'  \"  | Add-Content -Path apache.sh
            "            -e 's/#ServerSignature Off/ServerSignature Off/' \"  | Add-Content -Path apache.sh
            "            -i /etc/apache2/conf-available/security.conf"  | Add-Content -Path apache.sh
            '    fi' | Add-Content -Path apache.sh

        "}" | Add-Content -Path apache.sh

        'virtual_hosts(){' | Add-Content -Path apache.sh
        foreach($virtual in $servicio.VHosts){
            $name = $virtual.Name + ".conf"
            $admin = $virtual.ServerAdmin
            $root = $virtual.DocumentRoot
            $serverName = $virtual.ServerName
            $alias = $virtual.ServerAlias

            if($virtual.IP -eq $null -or $virtual.IP -eq ""){
                $dirIP = "*"
            }
            else{
                $dirIP = $virtual.IP
            }

            "    sudo mkdir $root" | Add-Content -Path apache.sh
            if($virtual.Protocol -eq "http"){
                "    sudo bash -c 'echo `"<VirtualHost $dirIP`:80>`" >> $name'" | Add-Content -Path apache.sh
            }
            if($virtual.Protocol -eq "https"){
                "    sudo bash -c 'echo `"<IfModule mod_ssl.c>`" >> $name'" | Add-Content -Path apache.sh
                "    sudo bash -c 'echo `"<VirtualHost $dirIP`:443>`" >> $name'" | Add-Content -Path apache.sh 
            }
                "    sudo bash -c 'echo `"    ServerAdmin $admin`" >> $name'" | Add-Content -Path apache.sh 
                "    sudo bash -c 'echo `"    DocumentRoot $root`" >> $name'" | Add-Content -Path apache.sh 
                "    sudo bash -c 'echo `"    ServerName $name`" >> $name'" | Add-Content -Path apache.sh 
                "    sudo bash -c 'echo `"    ServerAlias $alias`" >> $name'" | Add-Content -Path apache.sh 
                "    sudo bash -c 'echo `"    <Directory $root>`" >> $name'" | Add-Content -Path apache.sh 
                "    sudo bash -c 'echo `"        Options -Indexes`" >> $name'" | Add-Content -Path apache.sh
                "    sudo bash -c 'echo `"        AllowOverride none`" >> $name'" | Add-Content -Path apache.sh
                "    sudo bash -c 'echo `"        Require all granted`" >> $name'" | Add-Content -Path apache.sh
                "    sudo bash -c 'echo `"    </Directory>`" >> $name'" | Add-Content -Path apache.sh

            if($virtual.Protocol -eq "http"){
                '    if [[ $so == *"CentOS"* || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path apache.sh
                '    then' | Add-Content -Path apache.sh
                "        sudo bash -c 'echo `"    ErrorLog $root/Login-error.log`" >> $name'" | Add-Content -Path apache.sh
                "        sudo bash -c 'echo `"    CustomLog $root/Login-Access.log combined`" >> $name'" | Add-Content -Path apache.sh
                '    elif [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path apache.sh
	            '    then' | Add-Content -Path apache.sh
                "        sudo bash -c 'echo `"    ErrorLog \`${APACHE_LOG_DIR}/Login-error.log`" >> $name'" | Add-Content -Path apache.sh
                "        sudo bash -c 'echo `"    CustomLog \`${APACHE_LOG_DIR}/Login-Access.log combined`" >> $name'" | Add-Content -Path apache.sh
                '    fi' | Add-Content -Path apache.sh
                "    sudo bash -c 'echo `"</VirtualHost>`"  >> $name'" | Add-Content -Path apache.sh
            }
            if($virtual.Protocol -eq "https"){
                $certFile  = $virtual.CertFile
                $certKey = $virtual.CertKey
                "    sudo bash -c 'echo `"    SSLEngine on`" >> $name'" | Add-Content -Path apache.sh
                "    sudo bash -c 'echo `"    SSLCertificateFile      $certFile`" >> $name'" | Add-Content -Path apache.sh
                "    sudo bash -c 'echo `"    SSLCertificateKeyFile $certKey`" >> $name'" | Add-Content -Path apache.sh

                "    sudo bash -c 'echo `"    LogLevel warn`" >> $name'" | Add-Content -Path apache.sh
                '    if [[ $so == *"CentOS"* || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path apache.sh
                '    then' | Add-Content -Path apache.sh
                "        sudo bash -c 'echo `"    ErrorLog $root/error.log`" >> $name'" | Add-Content -Path apache.sh
                "        sudo bash -c 'echo `"    CustomLog $root/access.log combined`" >> $name'" | Add-Content -Path apache.sh
                '    elif [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path apache.sh
	            '    then' | Add-Content -Path apache.sh
                "        sudo bash -c 'echo `"    ErrorLog \`${APACHE_LOG_DIR}/error.log`" >> $name'" | Add-Content -Path apache.sh
                "        sudo bash -c 'echo `"    CustomLog \`${APACHE_LOG_DIR}/access.log combined`" >> $name'" | Add-Content -Path apache.sh
                '    fi' | Add-Content -Path apache.sh
                "    sudo bash -c 'echo `"</VirtualHost>`" >> $name'" | Add-Content -Path apache.sh
                "    sudo bash -c 'echo `"</IfModule>`" >> $name'" | Add-Content -Path apache.sh
            }
            '    if [[ $so == *"CentOS"* || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path apache.sh
            '    then' | Add-Content -Path apache.sh
            "        sudo mv $name /etc/httpd/conf.d/" | Add-Content -Path apache.sh
            '    elif [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path apache.sh
	        '    then' | Add-Content -Path apache.sh
            "        sudo mv $name /etc/apache2/sites-available/" | Add-Content -Path apache.sh
            "        cd /etc/apache2/sites-available/" | Add-Content -Path apache.sh
            "        sudo a2ensite $name" | Add-Content -Path apache.sh
            '    fi' | Add-Content -Path apache.sh
        }
        "}" | Add-Content -Path apache.sh


        '   so=$(hostnamectl | grep -i "operating system" | cut -d " " -f 5,6,7)' | Add-Content -Path apache.sh
        '   if [[ $so == *"CentOS"* || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path apache.sh
        '   then' | Add-Content -Path apache.sh
        '       echo -e "' | Add-Content -Path apache.sh -NoNewline
        "$passwd" | Add-Content -Path apache.sh -NoNewline
        '\n" | sudo -S dnf install httpd httpd-tools  -y' | Add-Content -Path apache.sh
        '       sudo dnf install dnf-utils http://rpms.remirepo.net/enterprise/remi-release-8.rpm -y' | Add-Content -Path apache.sh
        '       sudo dnf module reset php' | Add-Content -Path apache.sh
        '       sudo dnf module enable php:remi-7.4 -y' | Add-Content -Path apache.sh
        '       sudo dnf install php php-opcache php-gd php-curl php-mysqlnd -y' | Add-Content -Path apache.sh
        '       sudo chcon -Rt httpd_sys_rw_content_t /var/www' | Add-Content -Path apache.sh
        '       sudo systemctl restart httpd'  | Add-Content -Path apache.sh

        '   elif [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path apache.sh
        '   then' | Add-Content -Path apache.sh
        '       echo -e "' | Add-Content -Path apache.sh -NoNewline
        "$passwd" | Add-Content -Path apache.sh -NoNewline
        '\n" | sudo -S apt-get install apache2 php libapache2-mod-php -y' | Add-Content -Path apache.sh
        '       sudo systemctl start apache2' | Add-Content -Path apache.sh
        '   fi' | Add-Content -Path apache.sh
        "   config" | Add-Content -Path apache.sh
        "   virtual_hosts" | Add-Content -Path apache.sh

        '   if [[ $so == *"CentOS"* || $so == *"Red Hat Enterprise"* ]]' | Add-Content -Path apache.sh
        '   then' | Add-Content -Path apache.sh
        "      sudo setenforce 0"  | Add-Content -Path apache.sh
        "      sudo systemctl restart httpd"  | Add-Content -Path apache.sh
        '   elif [[ $so == *"Ubuntu"* || $so == *"Kali"* || $so == *"Debian"* ]]' | Add-Content -Path apache.sh
        '   then' | Add-Content -Path apache.sh
        "      sudo a2dissite 000-default.conf" | Add-Content -Path apache.sh
        "      sudo systemctl restart apache2"  | Add-Content -Path apache.sh
        '   fi' | Add-Content -Path apache.sh
}
