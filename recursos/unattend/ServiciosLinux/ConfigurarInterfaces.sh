echo "Realizando cambios dentro del archivo de configuracion de las interfaces..."
cat /servicios/interfaces.txt > /etc/network/interfaces
echo "Aplicando cambios..."
systemctl restart networking
echo "Prendiendo las interfaces de nuevo"
{{ifup}}
reboot