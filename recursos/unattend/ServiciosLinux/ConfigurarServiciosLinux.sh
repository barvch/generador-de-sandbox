#!/bin/bash

function creaCertificado (){
	domain=$1
	password=$2
	file=$3
	commonname=$domain
	country=MX
	state=CDMX
	locality=Coyoacan
	organization=UNAM-CERT
	organizationalunit=DGTIC
	email=""
	openssl genrsa -des3 -passout pass:$password -out $domain.key 2048
	openssl rsa -in $domain.key -passin pass:$password -out $domain.key
	openssl req -new -key $domain.key -out $domain.csr -passin pass:$password -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
	openssl x509 -req -days 365 -in $domain.csr -signkey $domain.key -out $domain.crt
	mv $domain.key /etc/ssl/private/$domain.key
	mv $domain.crt /etc/ssl/certs/$domain.crt
}

apt-get update -y
apt-get install jq -y
usuario=$(jq ".Credenciales.Usuario" archivo.json | sed -r 's/\"//g')
contrasena=$(jq ".Credenciales.Contrasena" archivo.json | sed -r 's/\"//g')
sistemaOperativo=$(jq ".SistemaOperativo" archivo.json | sed -r 's/\"//g')
ipBase=$(jq -r ".Interfaces[0].IP" archivo.json | sed -r 's/\"//g')
if [[ $sistemaOperativo = "Debian 10" ]]
then
	interfaz=$(ip a | grep $ipBase | cut -d " " -f13)
elif [[ $sistemaOperativo = "Kali Linux 2020.04" ]]
then
	interfaz=$(ip a | grep $ipBase | cut -d " " -f11)
fi
servicios=$(jq ".Servicios" archivo.json)
if [ "$servicios" != "null" ]
then
	echo $servicios > servicios.json
	apt-get install openssh-server -y
	puertoSSH=$(jq ".PuertoSSH" servicios.json)
	echo "${usuario} ALL=(ALL:ALL) ALL" >> /etc/sudoers
	sed -i -e "s/^.*Port.*[0-9]*$/Port ${puertoSSH}/g" /etc/ssh/ssh_config
	sed -i -e "s/^.*Port.*[0-9]*$/Port ${puertoSSH}/g" /etc/ssh/sshd_config
	systemctl enable ssh
	systemctl restart sshd
	manejadorBD=$(jq ".ManejadorBD" servicios.json)
	if [ "$manejadorBD" != "null" ]
	then
		manejador=$(jq ".ManejadorBD.Manejador" servicios.json | sed -r 's/\"//g')
		nombreBD=$(jq ".ManejadorBD.NombreBD" servicios.json | sed -r 's/\"//g')
		case $manejador in 
			PostgreSQL)
				apt-get install postgresql postgresql-contrib -y
				su - postgres -c "psql -c \"CREATE ROLE ${usuario} WITH SUPERUSER CREATEDB CREATEROLE REPLICATION BYPASSRLS LOGIN ENCRYPTED PASSWORD '${contrasena}'\""
				su - postgres -c "psql -c \"CREATE DATABASE ${nombreBD} WITH OWNER ${usuario};\""
				sed -i "/local   all             postgres                                peer/a local all $usuario md5" $(find /etc/postgresql -name pg_hba.conf)
				systemctl enable postgresql
				systemctl restart postgresql
				nombreBD=$(echo $nombreBD | tr '[:upper:]' '[:lower:]')
				psql postgresql://${usuario}:${contrasena}@localhost:5432/${nombreBD} < script.sql
				;;
			MySQL)
				wget https://dev.mysql.com/get/mysql-apt-config_0.8.16-1_all.deb
				apt install -y dirmngr
				DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config*
				debconf-set-selections <<< "mysql-apt-config mysql-apt-config/repo-codename select buster"
				debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/repo-url string http://repo.mysql.com/apt/'
				debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/select-preview select '
				debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/select-product select  Ok'
				apt-get update
				DEBIAN_FRONTEND=noninteractive apt install mysql-community-server mysql-community-client -y
				debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password $contrasena"
				debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password $contrasena"
				debconf-set-selections <<< "mysql-community-server mysql-server/default-auth-override select Use Legacy Authentication Method (Retain MySQL 5.x Compatibility)"
				mysql -e "CREATE USER ${usuario}@localhost IDENTIFIED BY '${contrasena}';"
				mysql -e "CREATE DATABASE $nombreBD;"
				mysql -e "GRANT ALL ON ${nombreBD}.* TO ${usuario}@localhost;"
				systemctl enable mysql
				systemctl restart mysql
				echo -e "[mysql]\nuser=${usuario}\npassword=${contrasena}"> ~/.my.cnf
				chmod 0600 ~/.my.cnf
				mysql < script.sql
				rm ~/.my.cnf
				;;
			MariaDB)
				apt install mariadb-server -y
				mariadb -e "CREATE USER ${usuario}@localhost IDENTIFIED BY '${contrasena}';"
				mariadb -e "CREATE DATABASE $nombreBD;"
				mariadb -e "GRANT ALL ON ${nombreBD}.* TO ${usuario}@localhost;"
				systemctl enable mariadb
				systemctl restart mariadb
				echo -e "[mysql]\nuser=${usuario}\npassword=${contrasena}"> ~/.my.cnf
				chmod 0600 ~/.my.cnf
				mariadb < script.sql
				rm ~/.my.cnf
				;;
			SQLServer)
				version=$(echo $sistemaOperativo | cut -d " " -f2)
				wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
				add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/${version}/mssql-server-2019.list)"
				apt-get update
				apt-get install -y mssql-server
				MSSQL_SA_PASSWORD=$contrasena MSSQL_PID="developer" /opt/mssql/bin/mssql-conf -n setup accept-eula
				systemctl restart mssql-server
				echo -e "[mysql]\nuser=${usuario}\npassword=${contrasena}" > ~/.my.cnf
				chmod 0600 ~/.my.cnf
				mysql -u ${usuario} < script.sql
				;;
		esac
	fi
	DNS=$(jq ".DNS" servicios.json)
	if [ "$DNS" != "null" ]
	then
		apt-get install bind9 dnsutils -y
		mkdir -p /etc/bind/zones/master
		noElementos=$(jq -r ".Servicios.DNS[]|\"\(.Tipo)\"" archivo.json | wc -l)
		for index in $(eval echo {0..$(expr $noElementos - 1)})
		do
			dominio=$(jq ".DNS[$index].Nombre" servicios.json | sed -r 's/\"//g')
			tipo=$(jq ".DNS[$index].Tipo" servicios.json | sed -r 's/\"//g')
			case $tipo in 
				Forward)
					file=db.$dominio
					echo -e "zone \"$dominio\" IN {\ntype master;\nfile \"/etc/bind/zones/master/$file\";\nallow-update {none;};\n};" >> /etc/bind/named.conf.local
					touch /etc/bind/zones/master/$file
					zoneFwdFile=";\n\
						; BIND data file for $dominio\n\
						;\n\
						$TTL    3h\n\
						@\tIN\tSOA\tns1.$dominio. admin.$dominio. (\n\
						\t\t\t1;\t Serial\n\
						\t\t\t3h;\t Refresh after 3 hours\n\
						\t\t\t1h;\t Retry after 1 hour\n\
						\t\t\t1w;\t Expire after 1 week\n\
						\t\t\t1h );\t Negative caching TTL of 1 day\n\
						;\n\
						@\tIN\tNS\tns1.$dominio.\n\
						ns1\tIN\tA\t$ipBase\
						"
					echo -e $zoneFwdFile > /etc/bind/zones/master/$file
					noElementosReg=$(jq -r ".DNS[$index].Registros[]|\"\(.Tipo)\"" servicios.json | wc -l)
					for indexReg in $(eval echo {0..$(expr $noElementosReg - 1)})
					do
						tipoReg=$(jq -r ".DNS[$index].Registros[$indexReg].Tipo" servicios.json | sed -r 's/\"//g')
						case $tipoReg in
							A)
							hostname=$(jq -r ".DNS[$index].Registros[$indexReg].Hostname" servicios.json | sed -r 's/\"//g')
							ipDominio=$(jq -r ".DNS[$index].Registros[$indexReg].IP" servicios.json | sed -r 's/\"//g')
							echo -e "$hostname.\tIN\tA\t$ipDominio." >> /etc/bind/zones/master/$file
							;;
							CNAME)
							alias=$(jq -r ".DNS[$index].Registros[$indexReg].Alias" servicios.json | sed -r 's/\"//g')
							fqdn=$(jq -r ".DNS[$index].Registros[$indexReg].FQDN" servicios.json | sed -r 's/\"//g')
							echo -e "$alias\tIN\tCNAME\t$fqdn." >> /etc/bind/zones/master/$file
							;;
							MX)
							child=$(jq -r ".DNS[$index].Registros[$indexReg].ChildDomain" servicios.json | sed -r 's/\"//g')
							fqdn=$(jq -r ".DNS[$index].Registros[$indexReg].FQDN" servicios.json | sed -r 's/\"//g')
							echo -e "$child.\tIN\tMX\t$fqdn." >> /etc/bind/zones/master/$file
							;;
						esac
					done
				;;
				Reverse)
					netID=$(jq ".DNS[$index].NetID" servicios.json | sed -r 's/\"//g')
					mask=$(echo $netID | cut -d "/" -f2)
					case $mask in
						24)
							netName=$(echo $netID | cut -d "." -f3,2,1)
							;;
						16)
							netName=$(echo $netID | cut -d "." -f2,1)
							;;
						8)
							netName=$(echo $netID | cut -d "." -f1)
							;;
					esac
						netIDName=$(echo $netName.in-addr.arpa)
						zoneRvsFile=";\n\
							; BIND data file for $netIDName\n\
							;\n\
							$TTL    3h\n\
							$netIDName.\tIN\tSOA\tns1.$dominio. admin.$dominio. (\n\
							\t\t\t1;\t Serial\n\
							\t\t\t3h;\t Refresh after 3 hours\n\
							\t\t\t1h;\t Retry after 1 hour\n\
							\t\t\t1w;\t Expire after 1 week\n\
							\t\t\t1h );\t Negative caching TTL of 1 day\n\
							;\n\
							$netIDName.\tIN\tNS\tns1.$dominio.\n\
							$netIDName.\tIN\tPTR\t$dominio.\n\
							"
					file=db.$netName
					echo -e "zone \"$netName.in-addr.arpa\" IN {\ntype master;\nfile \"/etc/bind/zones/master/$file\";\nallow-update {none;};\n};" >> /etc/bind/named.conf.local
					echo -e $zoneRvsFile > /etc/bind/zones/master/$file
					noElementosReg=$(jq -r ".DNS[$index].Registros[]|\"\(.Tipo)\"" servicios.json | wc -l)
					for indexReg in $(eval echo {0..$(expr $noElementosReg - 1)})
					do
						tipoReg=$(jq -r ".DNS[$index].Registros[$indexReg].Tipo" servicios.json | sed -r 's/\"//g')
						case $tipoReg in
							PTR)
							hostname=$(jq -r ".DNS[$index].Registros[$indexReg].Hostname" servicios.json | sed -r 's/\"//g')
							host=$(jq -r ".DNS[$index].Registros[$indexReg].Host" servicios.json | sed -r 's/\"//g')
							echo -e "$host.$netIDName.\tIN\tPTR\t$hostname." >> /etc/bind/zones/master/$file
							;;
							CNAME)
							alias=$(jq -r ".DNS[$index].Registros[$indexReg].Alias" servicios.json | sed -r 's/\"//g')
							fqdn=$(jq -r ".DNS[$index].Registros[$indexReg].FQDN" servicios.json | sed -r 's/\"//g')
							echo -e "$alias\tIN\tCNAME\t$fqdn." >> /etc/bind/zones/master/$file
							;;
						esac
					done
				;;
			esac
		done
		named-checkconf
		if [ $sistemaOperativo = "Kali Linux 2020.04" ]; then
			systemctl named enable
			systemctl named restart
		elif [ $sistemaOperativo = "Debian 10" ]; then
			systemctl bind9 enable
			systemctl bind9 restart
		fi
	fi
	DHCP=$(jq ".DHCP" servicios.json)
	if [ "$DHCP" != "null" ]
	then
		apt-get install isc-dhcp-server -y
		noElementos=$(jq -r ".DHCP[]|\"\(.Nombre)\"" servicios.json | wc -l)
		echo -e "default-lease-time 600;\nmax-lease-time 7200;\n\n" >> /etc/dhcp/dhcpd.conf
		for index in $(eval echo {0..$(expr $noElementos - 1)})
		do
			netmask=$(jq -r ".DHCP[$index].MascaraRed" servicios.json)
			noElementosRan=$(jq -r ".DHCP[$index].Rangos[]|\"\(.Inicio)\"" servicios.json | wc -l)
			for indexRan in $(eval echo {0..$(expr $noElementosRan - 1)})
			do
				case $netmask in
				255.255.255.0)
					inicioRango=$(jq -r ".DHCP[$index].Rangos[$indexRan].Inicio" servicios.json)
					id=$(echo $inicioRango | cut -d "." -f1,2,3)
					subnet=$id.0
				;;
				255.255.0.0)
					id=$(echo $inicioRango | cut -d "." -f1,2)
					subnet=$id.0.0
				;;
				255.0.0.0)
					id=$(echo $inicioRango | cut -d "." -f1)
					subnet=$id.0.0.0
				;;
				esac
			done
			echo -e "subnet $subnet netmask $netmask {" >> /etc/dhcp/dhcpd.conf
			for indexRan in $(eval echo {0..$(expr $noElementosRan - 1)})
			do
				inicio=$(jq -r ".DHCP[$index].Rangos[$indexRan].Inicio" servicios.json)
				fin=$(jq -r ".DHCP[$index].Rangos[$indexRan].Fin" servicios.json)
				echo -e "\trange $inicio $fin;" >> /etc/dhcp/dhcpd.conf
			done
			dns=$(jq -r ".DHCP[$index].DNS" servicios.json)
			if [ "$dns" != "null" ]; then
				echo -e "\toption domain-name-servers $dns;" >> /etc/dhcp/dhcpd.conf
			fi
			gateway=$(jq -r ".DHCP[$index].Gateway" servicios.json)
			if [ "$gateway" != "null" ]; then
				echo -e "\toption routers $gateway;" >> /etc/dhcp/dhcpd.conf
			fi
		    echo "}" >> /etc/dhcp/dhcpd.conf
		done
		inetmask=$(jq -r ".Interfaces[0].MascaraRed" archivo.json)
		echo -e "allow-hotplug $interfaz\niface $interfaz inet static\naddress $ipBase\nnetmask $inetmask" >> /etc/network/interfaces
		sed -i "s/INTERFACESv4=\"\"/INTERFACESv4=\"$interfaz\"/g" /etc/default/isc-dhcp-server 
		systemctl restart networking.service
		systemctl enable isc-dhcp-server
		systemctl restart isc-dhcp-server
		fi
	servidorWeb=$(jq ".ServidorWeb" servicios.json)
	if [ "$servidorWeb" != "null" ]
	then
		instalarServidor=true
		servidor=$(jq -r ".ServidorWeb.Servidor" servicios.json | sed -r 's/\"//g')
		case $servidor in
			Apache)
				apt install apache2 -y
				noElementos=$(jq -r ".ServidorWeb.Sitios[]|\"\(.Nombre)\"" servicios.json | wc -l)
				for index in $(eval echo {0..$(expr $noElementos - 1)})
				do
					nombreSitio=$(jq -r ".ServidorWeb.Sitios[$index].Nombre" servicios.json | sed -r 's/\"//g')
					dominioSitio=$(jq -r ".ServidorWeb.Sitios[$index].Dominio" servicios.json | sed -r 's/\"//g')
					ipSitio=$(jq -r ".ServidorWeb.Sitios[$index].Interfaz" servicios.json | sed -r 's/\"//g')
					puerto=$(jq -r ".ServidorWeb.Sitios[$index].Puerto" servicios.json | sed -r 's/\"//g')
					protocolo=$(jq -r ".ServidorWeb.Sitios[$index].Protocolo" servicios.json | sed -r 's/\"//g')
					mkdir /var/www/$nombreSitio/
					echo -e "<html>\n<head>\n\t<title>$nombreSitio</title>\n</head>\n<body>\n\t<h1>$nombreSitio</h1>\n</body>\n</html>" > /var/www/$nombreSitio/index.html
					case $protocolo in
						http)
							file="/etc/apache2/sites-available/$nombreSitio.conf"
							cp /etc/apache2/sites-available/000-default.conf $file
							sed -i "s/\*:80/${ipSitio}:$puerto/g" $file
							sed -i "s/html/$nombreSitio\//g" $file
							sed -i "s/\#ServerName www.example.com/ServerName $dominioSitio/g" $file
							sed -i "/ServerName $dominioSitio/a ServerAlias www.$dominioSitio" $file
							drupal=$(jq -r ".ServidorWeb.Sitios[$index].Drupal" servicios.json)
							if [ $drupal ]
							then
								apt-get install php libapache2-mod-php php-cli php-fpm php-json php-common php-mysql php-zip php-gd php-intl php-mbstring php-curl php-xml php-pear php-tidy php-soap php-bcmath php-xmlrpc -y
								wget https://www.drupal.org/download-latest/tar.gz -O drupal.tar.gz
								tar -xf drupal.tar.gz
								nombreArchivo=$(echo drupal-*)
								mv $nombreArchivo $nombreSitio
								rm -r /var/www/$nombreSitio/
								mv $nombreSitio /var/www/
								chown -R www-data:www-data /var/www/$nombreSitio
								chmod -R 755 /var/www/$nombreSitio/
								drupalContent="
								<Directory /var/www/$nombreSitio/>;\n\
									Options FollowSymlinks\n\
									AllowOverride All\n\
									Require all granted\n\
								</Directory>\n\
								<Directory /var/www/>\n\
									RewriteEngine on\n\
									RewriteBase /\n\
									RewriteCond %{REQUEST_FILENAME} !-f\n\
									RewriteCond %{REQUEST_FILENAME} !-d\n\
									RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]\n\
								</Directory>\n\
								"
								sed -i "/<\/VirtualHost>/a $drupalContent" $file
								a2enmod rewrite
								sitioEn=$nombreSitio.conf
							fi
						;;
						https)
							file="/etc/apache2/sites-available/$nombreSitio-ssl.conf"
							cp /etc/apache2/sites-available/default-ssl.conf $file
							sed -i "s/_default_:443/${ipSitio}:$puerto/g" $file
							sed -i "s/html/$nombreSitio\//g" $file
							sed -i "/\/$nombreSitio\//a ServerName $dominioSitio" $file
							sed -i "/ServerName $dominioSitio/a ServerAlias www.$dominioSitio" $file
							domain=$dominioSitio
							commonname=$domain
							password=$contrasena
							country=MX
							state=CDMX
							locality=Coyoacan
							organization=UNAM-CERT
							organizationalunit=DGTIC
							email=""
							openssl genrsa -des3 -passout pass:$password -out $domain.key 2048
							openssl rsa -in $domain.key -passin pass:$password -out $domain.key
							openssl req -new -key $domain.key -out $domain.csr -passin pass:$password -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
							openssl x509 -req -days 365 -in $domain.csr -signkey $domain.key -out $domain.crt
							cp $domain.key /etc/ssl/private/$domain.key
							cp $domain.crt /etc/ssl/certs/$domain.crt
							sed -i "s/ssl-cert-snakeoil.pem/$domain.crt/g" $file
							sed -i "s/ssl-cert-snakeoil.key/$domain.key/g" $file
							sitioEn=$nombreSitio-ssl.conf
						;;
					esac
					chmod -R 755 /var/www/$nombreSitio/
					actual=$(pwd)
					cd /etc/apache2/sites-available
					a2ensite $sitioEn
					cd $actual
					echo -e "$ipSitio \t$dominioSitio" >> /etc/hosts
				done
				systemctl enable apache2
				systemctl restart apache2
			;;
			Nginx)
				apt install nginx -y
				noElementos=$(jq -r ".ServidorWeb.Sitios[]|\"\(.Nombre)\"" servicios.json | wc -l)
				for index in $(eval echo {0..$(expr $noElementos - 1)})
				do
					drupal=$(jq -r ".ServidorWeb.Sitios[$index].Drupal" servicios.json)
					if [ $drupal = true ] && [ $instalarServidor = true ]
					then
						apt-get install php php-fpm php-gd php-common php-mysql php-apcu php-gmp php-curl php-intl php-mbstring php-xmlrpc php-gd php-xml php-cli php-zip -y
						wget https://www.drupal.org/download-latest/tar.gz -O drupal.tar.gz
						tar -xf drupal.tar.gz
						nombreArchivo=$(echo drupal-*)
						versionPHP=$(php -v | egrep "PHP [0-9]" | cut -d " " -f2 | cut -d "." -f1,2)
						phpFile=/etc/php/$versionPHP/fpm/php.ini
						sed -i "s/.*cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g" $phpFile
						sed -i "s/.*date.timezone =.*/date.timezone = America\/Mexico_City/g" $phpFile
						instalarServidor=false
					fi
					nombreSitio=$(jq -r ".ServidorWeb.Sitios[$index].Nombre" servicios.json | sed -r 's/\"//g')
					dominioSitio=$(jq -r ".ServidorWeb.Sitios[$index].Dominio" servicios.json | sed -r 's/\"//g')
					ipSitio=$(jq -r ".ServidorWeb.Sitios[$index].Interfaz" servicios.json | sed -r 's/\"//g')
					puerto=$(jq -r ".ServidorWeb.Sitios[$index].Puerto" servicios.json | sed -r 's/\"//g')
					protocolo=$(jq -r ".ServidorWeb.Sitios[$index].Protocolo" servicios.json | sed -r 's/\"//g')
					if [ $drupal = true ] 
					then
						cp -rf $nombreArchivo $nombreSitio
						mv $nombreSitio /var/www/
					else
						mkdir /var/www/$nombreSitio
						echo -e "<html>\n<head>\n\t<title>$nombreSitio</title>\n</head>\n<body>\n\t<h1>$nombreSitio</h1>\n</body>\n</html>" > /var/www/$nombreSitio/index.html
					fi
					case $protocolo in
						http)
							file=/etc/nginx/sites-available/$nombreSitio.conf
							if [ $drupal = true ] 
							then
								configFile=ArchivosConfiguracion/ServidorWeb/Nginx/http/drupal.conf
							else
								configFile=ArchivosConfiguracion/ServidorWeb/Nginx/http/sitio.conf
							fi
						;;
						https)
							file=/etc/nginx/sites-available/$nombreSitio-ssl.conf
							creaCertificado $dominioSitio $contrasena $file
							if [ $drupal = true ] 
							then
								configFile=ArchivosConfiguracion/ServidorWeb/Nginx/https/drupal-ssl.conf
							else
								configFile=ArchivosConfiguracion/ServidorWeb/Nginx/https/sitio-ssl.conf
							fi
						;;
					esac					
					cp -f $configFile $file
					sed -i "s/{{ip}}/$ipSitio/g" $file
					sed -i "s/{{puerto}}/$puerto/g" $file
					sed -i "s/{{nombreSitio}}/$nombreSitio/g" $file
					sed -i "s/{{dominioSitio}}/$dominioSitio/g" $file
					sed -i "s/{{versionPHP}}/$versionPHP/g" $file
					ln -sf $file /etc/nginx/sites-enabled/
					sed -i "s/# server_names_hash_bucket_size 64;/server_names_hash_bucket_size 64;/g" /etc/nginx/nginx.conf
					nginx -t
					echo -e "$ipSitio \t$dominioSitio" >> /etc/hosts
				done
				systemctl restart nginx
			;;
		esac
		chmod -R 755 /var/www/$nombreSitio/
		chown -R www-data:www-data /var/www/$nombreSitio/
	fi
fi