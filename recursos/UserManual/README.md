# User Guide

**Welcome to the user guide of this tool!**. The intention of this guide is guide users through several topics related to the tool, such as  workflow, validations, templates, examples, videos and more.

## About tool

This tool is a sandox generator for Hyper-V that allows you to create, configure and replicate a wide range of VMs in an unattended manner. The goal behind this project is to automate the process of creating and configuring both virtual machines and services using an input file that provides data for each VM indicated indicated within it. This way, mouting an infraestructure to create test enviroments for malware analisys or any other task, becomes really easy.

The workflow of the tool is the following:

* **Hyper-V Rol Check**: The tool validate if tool is running in a Windows Server 2019 environment and checks that the Hyper-V Role is installed in host, if not, it will be installed in the host and a reboot is necessary in order to apply changes. Once it boots, you must run the tool a second time.

* **Data validation**: Before any VM is created, the tool validates every single field according following requirements:
    
    - **Generic values**: Data related with host machine available resources and file storage.
    
    - **Dependent values**: Specific data for each operating system.
    
    - **Services**: Specific data per service.

    > There are several values that are set over the validation flow, those values and specific information about each field are documented in [The input file] section.

* **Data printing and confirmation**. The tool allow to check all data for each or all virtual machines before create them.
* **Hyper-V machine creation**. Once one or all virtual machines are validated, hardware requirements are set. The only exception is the hard drive, which is attached later during creation of the VM.

    <details>
        <summary>Hardware that is set</summary>

    ###
    >   * Amount and size of virtual disks.
    >   * Number of processors.
    >   * RAM memory:
    >       - Static:
    >           + Total memory.
    >       - Dynamic:
    >          + Minimum memory.
    >           + Maximum memory.
    >   * Network interfaces
    >       - Virtual Switches:
    >           + Name.
    >           + Type.
    >           + Network adapter.
    >       - Type.
    >       - Name.
    </details>

* **Custom ISO creation**. In this step, the ISO file specified by user is mounted in host and unattended files are customized and loaded within. The tool for the ISO creation depends of each operating system:

    - *Windows*: DISM.
    
    - *Linux/Unix and FortiOS*: mkisofs.
    
    <details>
        <summary>Data that are set within unattended files</summary>
    
    ###
    > * Generic values:
    >    - Hostname.
    >    - Desktop Environment (Exceptions: Debian 10 and Kali Linux 2020.04).
    >    - Credentials:
    >        + User.
    >        + Password.
    >    - Network interfaces:
    >        + IP addresses.
    >        + Netmasks.
    >        + Gateways.
    >        + DNS's.
    > * Dependent Data:
    >    - Activation Key (Windows Distributions).
    >    - Administrative interface (FortiOS 6).
    >    - Backup file (FortiOS 6).
    > * Default Values:
    >    - Timezone. America/Mexico_City.
    >    - OS language. English.
    >    - Keyboard layout. Latin American.
    </details>

* **Operating system installation**.The higher capacity hard disk and ISO file are mounted inside the virtual machine, and then the machine is initialized and booted. The following operating systems need user interaction to enter the type of environment you want within the machine:

    - Debian 10 (Buster).

    - Kali Linux 2020.04.

    > **NOTE**: At this point, the interface config is also set within the VM, but in the particular case of any VM running an Ubuntu flavor, the config is set during the post-install section. For more information, please read [Post-Installation instructions].

* **Post-Installation running script**. A series of scripts and other files are created depending of the configuration of serivices and so on that has been entered within the input file. These scripts run automatically after the installation is complete and install and take care of installing and configuring all the services that have been specified for the machine.

    > Exceptions: 
    > 
    > * Debian 10 Buster.
    > 
    > * Kali Linux 20.04.
    > 
    > Please check [Post-Installation instructions] for more information.

**This flow repeats itself for every single virtual machine to create.**

> For technical specifications about workflow functions please check [Workflow] section.

## The input file

The **/Configuracion/configuracion.json** file is the core of the tool and works in JSON format which contains the following data for virtual machines customization:

```JSON
{
    "Root": "C:\\Sandbox",
    "MaquinasVirtuales": [
        {
            "Generic Values": "Data",
            "Dependent Values": "Data",
            "Servicios": {
                "Service": "Data"
            }
        }
    ]
}
```
        
* **Root**. This is the root folder of the project. This is the place in the system where all the files of the virtual machines will reside.
* **MaquinasVirtuales**. This is the list and specifications of virtual machines that will be created. This field is built by three sections:

    - <details>
        <summary>Generic values. Data related with host machine available resources and file storage.</summary>

        ###
        + <details>
            <summary>SistemaOperativo.</summary>
            
            ###
            > - Windows 10.
            > - Windows Server 2019.
            > - Ubuntu 16.04.
            > - Ubuntu 18.04.
            > - Ubuntu 20.04.
            > - Debian 10 (Buster).
            > - Kali Linux 2020.04.
            > - CentOS 8.
            > - CentOS Stream.
            > - RHEL 8.
            > - FortiOS 6.
    
        + Hostname.
        
        + <details>
            <summary>TipoAmbiente. Desktop environment,the accepted values depends of each OS.</summary>
            
            ###
            > - Windows. Reading of **install.wim** file by mounting the ISO file in the host.
            > - Ubuntu family. Ubuntu Desktop. 
            > - Debian 10 (Buster) and Kali Linux 2020.04. This value is provided until SO installation process.
            > - CentOS 8/Stream and RHEL 8:
            >   + Core
            >   + Gnome
            >   + KDE
        
        + DiscorVirtuales. Total amount and size, the values are set into an array.
        
            > **NOTE**: The minimum value is 15.
        
        + Procesadores. Total amount of virtual processors, it depends by virtual processors available in host.
        
        + RutaISO. ISO file location.
        
        + <details>
            <summary>MemoriaRAM.</summary>
            
            ###
            > - Tipo. A value must be set which has its own dependent fields:
            >    + Static.
            >       - Memoria.
            >   + Dynamic.
            >       - Minima.
            >       - Maxima.
            >       
            > **NOTE**: The minimum value is 0.5.
    
        + <details>
            <summary>Credenciales.</summary>

            ###
            > - Usuario.
            > - Contrasena.
        
        + <details>
            <summary>Interfaces. Multiple interfaces are allowed.</summary>

            ###
            - <details>
                <summary>VirtualSwitch. Each interface have a virtual switch, it can be unique or shared.</summary>
                
                ###
                + Nombre.

                + Tipo:

                    > - External. Bridges the virtual switch to physic network adapter.
                    > - Internal. Create a virtual LAN.
                    > - Private. Isolates the virtual switch from network.

                + ApadaptadorRed. Name of physical network adapter.

                > This field only is requiered if Tipo is set as External.
                > To know the physical network adapters available open Powershell and run the following command:
                > ```Powershell
                > Get-NetAdapter -Physical
                > ```
                > The physical network adapter must be in *Up* state.

            
            - Nombre.

            - Tipo. A value must be set which has its own dependent fields:

                >   + Static:
                >       - IP.
                >       - MascaraRed. Allow an IP format (255.255.255.255) or prefix value (24).
                >       - Gateway. Optional.
                >       - DNS. Optional.
                >   + DHCP.
                >
                > If a service is required at least one interface must be set as static, please check [Services] in this very section for more information about this requirement.
        
        **Example:**

        ```JSON
        {
            "Root": "C:\\Sandbox",
            "MaquinasVirtuales": [
            {
                "SistemaOperativo": "Windows 10",
                "Hostname": "Contoso",
                "TipoAmbiente": "Windows 10 Home",
                "DiscosVirtuales": [20, 15],
                "Procesadores": 4,
                "RutaISO": "C:\\Sandbox\\Win10_1909_English_x64.iso",
                "MemoriaRAM": {
                    "Tipo": "Dynamic",
                    "Minima": 1.0,
                    "Maxima": 2.0
                },
                "Credenciales": {
                    "Usuario": "Usertest",
                    "Contrasena": "5uperS3cretP4ssw0rd"
                },
                "Interfaces": [
                {
                    "VirtualSwitch": {
                        "Nombre": "InternetSwitch",
                        "Tipo": "External",
                        "AdaptadorRed": "Ethernet"
                    },
                    "Tipo": "Static",
                    "Nombre": "Internet",
                    "IP": "192.168.100.210",
                    "MascaraRed": "24",
                    "Gateway": "192.168.100.1",
                    "DNS": "8.8.8.8"
                }
            ]
        }
        ```
    </details>

    - <details>
        <summary>Dependent values. Specific data for each operating system.</summary>
        
        ###
        + <details>
            <summary>Windows 10 and Windows Server 2019.</summary>
            
            - LlaveActivacion. Windows activation key.
            
            - RutaMSI. MSI file location, the values are set into an array.

                > This field only is required by Windows 10.
            
            **Example:**

            ```JSON
            {
                "Root": "C:\\Sandbox",
                "MaquinasVirtuales": [
                    {
                        "Generic Values": "Data",
                        "LlaveActivacion": "xxxx-xxxx-xxxx-xxxx-xxxx",
                        "RutaMSI": ["C:\\Sandbox\\firefox.msi", "C:\\Sandbox\\chrome.msi"]
                    }
                ]
            }
            ```
        
        + <details>
            <summary>FortiOS 6.</summary>
            
            - InterfazAdministrativa. Static interface name. 
                
                > **NOTE**: The interface must be set into *Generic Values* section. Data such as IP address, netmask, DNS and gateway are consulted from the interface's name. 

            - ArchivoBackup. FortiOS backup file location.

            **Example:**

            ```JSON
            {
                "Root": "C:\\Sandbox",
                "MaquinasVirtuales": [
                    {
                        "Generic Values": "Data",
                        "InterfazAdministrativa": "Internet",
                        "ArchivoBackup": "C:\\Sandbox\\fortios.qcow2"
                    }
                ]
             }
             ```
        
    </details>

    - <details>
        <summary>Services. Specific data per service.</summary>
    
        ###              

        + <details>
            <summary>Remote Administration.</summary>
            
            ###
            * Windows. RDP.
            ####
            **Example:**

            ```JSON
            "Servicios": {
                "AdministracionRemota": "RDP",
            }
            ```
            
            * Linux/Unix. 
            
                > - AdministracionRemota. SSH.
                > - Puerto. It doesn´t allow well known ports.
            
            **Example:**

            ```JSON
            "Servicios": {
                "AdministracionRemota": "SSH",
                "Puerto": "1234"
            }
            ```
            
            > If not data is provide for remote administration, this is automatically configured for each SO.
        
        + <details>
            <summary>Only-Installation Services.</summary>
        
            ###
            This services only are installed in host with non configuration.
            
            * **Windows Server 2019**.
             
                - Windows Defender.

                - Active Directory Certificate Services.
                
                > Both services only allow a true or false value.
            
                **Example:**
                
                ```JSON
                "Servicios": {
                    "WindowsDefender": true,
                    "CertificateServices": true
                }
                ```
             
            * **Ubuntu family**.
             
                - SQL Server.
                
                **Example:**
                
                ```JSON
                "Servicios": {
                    "ManejadorDB": {
                        "Manejador": "SQLServer"
                }
                ```
                
                > More information about *ManejadorDB* service check **Relational Database Management System  > Linux/Unix** section.
            
        + <details>
            <summary>Active Directory.</summary>
            
            ###
            This service is only available for Windows Server 2019.
            
            - Domain.
            
            - NetBIOS. Optional.
            
                > The default value is set by prefix of *Domain* field.
            
            - DomainMode. The functional level cannot be less than *ForestMode* field.
                
                > + Win2008.
                > + Win2008R2.
                > + Win2012.
                > + Win2012R2.
                > + Win2016.

            - ForestMode. Optional.
                
                > The default value is set by *DomainMode* field.

            **Example:**
            
            ```JSON
            "Servicios:" {
                "ActiveDirectory": {
                    "Domain": "example.local",
                    "NetBIOS": "EXAMPLE",
                    "DomainMode": "Win2016",
                    "ForestMode": "Win2012"
                }
             }
             ```

        + <details>
            <summary>Relational Database Management System.</summary>
        
            ###
            This service is only avaible for Linux/Unix distributions.
            * ManejadorBD. Only is allowed one RDBMS to avoid compatibility issues. 
            
                - Manejador.
                    
                    > + PostgresQL
                    > + MySQL
                    > + MariaDB
                    > + SQL Server. Only available for installation in Ubuntu family.
                
                - NombreBD.
                
                - Script. Optional. Database script location.

             **Example:**
             
            ```JSON
            Servicios": {
                "ManejadorBD": {
                    "Manejador": "PostgresQL",
                    "NombreBD":"mydatabase",
                    "Script": "C:\\SandBox\\script.sql"
                }
            }
            ```

        + <details>
            <summary>Web Server.</summary>
        
            ###
            - <details>
                <summary>Windows Server 2019.</summary>
                
                ###
                - IIS. Multiple sites are allowed, the values are set into an array.
                    
                    + Nombre.
                    
                    + Directorio. Optional. Name of root folder.

                    > The default value is set by *Nombre* field.
                    
                    + Bindings. Multiple bindings are allowed, the values are set into an array.
                        
                        - Dominio.
                        
                        - Interfaz. Static interface name. 
                
                        > **NOTE**: The interface must be set into *Generic Values* section. Data such as IP address, netmask, DNS and gateway are consulted from the interface's name. This field is used to configure IIS's bindings.
                    
                        - Puerto. Optional.
                            
                            > **NOTE**: The default value is set by *Protocolo* field (80 for http and 443 for https) and it's allowed to set explicity that value. If different port is set, the tool doesn´t allow use well-know ports.

                        - Protocolo.
                            > - http.
                            > - https.
                        
                        - WebDAV. Optional.
                            > - true.
                            > - false.

                **Example:**
                
                ```JSON
                "Servicios:" {
                    "IIS":  [
                        {
                            "Nombre": "exampleSite.local",
                            "Directorio": "exampleSite",
                            "Bindings": [
                                {
                                    "Dominio": "example.local",
                                    "Interfaz": "Iternet",
                                    "Protocolo": "https",
                                    "Puerto": 443,
                                    "WebDAV": false
                                }
                            ]
                        }
                    ]
                }
                ```

            - <details>
                <summary>Linux/Unix.</summary>
                
                ###
                * ServidorWeb. Only is allowed one web server to avoid compatibility issues. 
                    
                    + Servidor.

                        > - apache2.
                        > - nginx.

                    + Sitios. Multiple sites are allowed, the values are set into an array.

                        - Nombre.

                        - Dominio.

                        - Interfaz. Static interface name. 

                        > **NOTE**: The interface must be set into *Generic Values* section. Data such as IP address, netmask, DNS and gateway are consulted from the interface's name. This field is used to configure Web Server's sites.

                        - Puerto. Optional.

                            > **NOTE**: The default value is set by *Protocolo* field (80 for http and 443 for https) and it's allowed to set explicity that value. If different port is set, the tool doesn´t allow use well-know ports.

                        - Protocolo.
                            > - http.
                            > - https.

                        - Drupal. Optional. Only sets the web installer, the content manager is not configured. 
                            > - true.
                            > - false.

                    **Example:**

                     ```JSON
                     "Servicios": {
                        "ServidorWeb": {
                            "Servidor": "apache2",
                            "Sitios": [
                                {
                                    "Nombre": "exampleSite",
                                    "Dominio": "example.local",
                                    "Interfaz": "Internet",
                                    "Protocolo": "https",
                                    "Puerto": "443",
                                    "Drupal": true
                                }
                            ]
                        }
                    }
                    ```
        + <details>
            <summary>DHCP.</summary>
            
            ###
            - <details>
                <summary>Windows Server 2019.</summary>
        
                ###
                Multiple scopes are allowed, the values are set into an array.

                - Nombre.
                    
                - Rango.
                        
                    > + Inicio.
                    > + Fin.
                    > + MascaraRed. Scope netmask. Allow an IP format (255.255.255.255) or prefix value (24).
                     
                - Exclusiones. Optional.
                        
                    + Tipo. A value must be set which has its own dependent fields:
                     
                        > + Rango.
                        >   - Inicio.
                        >   - Fin.
                        > + Unica. IP.
                     
                  - Lease.
                        
                    > + Dias.
                    > + Horas.
                    > + Minutos.
                        
                    > **NOTE**: The input format and minimum value is **000.01:00**.

                 - Gateway. Optional.
                    
                 - DNS. Optional.
                    
                 **Example:**
                    
                 ```JSON
                 "Servicios": {
                    "DHCP": [
                        {
                            "Nombre": "ScopeOne",
                            "Rango": {
                                "Inicio": "192.168.0.150",
                                 "Fin": "192.168.0.170",
                                 "MascaraRed": "24"
                             },
                             "Exclusiones": {
                                "Tipo": "Unica",
                                "IP": "192.168.0.167"
                            },
                            "Lease": "000.01:00",
                            "Gateway": "192.168.0.255",
                            "DNS": "8.8.8.8"
                        }
                    ]
                 }
                 ```
                    
            - <details>
                <summary>Linux/Unix.</summary>
                
                ###
                + Interfaz. Static interface name. 

                    > **NOTE**: The interface must be set into *Generic Values* section. Data such as IP address, netmask, DNS and gateway are consulted from the interface's name. This field is only used to configure the DHCP server.
                
                + Scopes. Multiple scopes are allowed, the values are set into an array.
                    
                    > - Rangos. Multiple ranges are allowed, the values are set into an array.
                    >   + Inicio.
                    >   + Fin.
                    > - MascaraRed. Scope netmask. Allow an IP format (255.255.255.255) or prefix value (24).
                    > - Gateway. Optional.
                    > - DNS. Optional.
                
                **Example:**
                
                ```JSON
                "Servicios": {
                    "DHCP": {
                        "Interfaz": "Internet",
                        "Scopes": [
                            {
                                "Rangos": [
                                    {
                                    "Inicio": "192.168.0.100",
                                    "Fin": "192.168.0.120"
                                    }
                                ],
                                "MascaraRed": "255.255.255.0",
                                "Gateway": "192.168.0.255",
                                "DNS": "8.8.8.8"
                            }
                        ]
                    }
                }
                ```
        + <details>
            <summary>DNS.</summary>
    
            ###
            
            * Interfaz. Static interface name. 

                > **NOTE**: The interface must be set into *Generic Values* section. Data such as IP address, netmask, DNS and gateway are consulted from the interface's name. This field is only used to configure the DNS server.
                > 
                > This field only is required by Linux/Unix distributions.    
            
            * Zonas. Multiple zones are allowed, the values are set into an array.
                
                - Tipo. Sets *Primary zones*. Every DNS zone has its own dependent fields.
                
                    + Forward.
 
                        - Nombre.
                        
                        - Registros. Multiple registers are allowed, the values are set into an array.

                        - Tipo. Every DNS record has its own dependent fields.
                          
                            >   + A.
                            >       - Hostname.
                            >       - IP.
                            >   + CNAME
                            >       - Alias.
                            >       - FQDN.
                            >   + MX
                            >       -ChildDomain.
                            >       - FQDN.
                    
                    + Reverse.
                    
                        - NetID. It must be with the following format NetworkID/Prefix (192.168.1.**0/24**).
                        
                        - Registros. Multiple registers are allowed, the values are set into an array.
                           
                        - Tipo. Every DNS record has its own dependent fields.
                              
                            >   + PTR.
                            >       - IP.
                            >       - Hostname.
                            >   + CNAME.
                            >       - Alias.
                            >       - FQDN.
                
                - Backup. Optional.

                    > This field only is required by Windows Server 2019. If value is provided, the tool ignores *Nombre* field.
            
            Windows Server 2019
            
            **Example:**
            
            ```JSON
            "DNS": [
                {
                    "Tipo": "Forward",
                    "Nombre": "MyForwardZone",
                    "Backup": "",
                    "Registros": [
                        {
                            "Tipo": "A",
                            "Hostname": "example.local",
                            "IP": "10.23.1.2"
                        },
                        {
                            "Tipo": "CNAME",
                            "Alias": "alias",
                            "FQDN": "example2.local"
                        },
                        {
                            "Tipo": "MX",
                            "ChildDomain": "example2.local",
                            "FQDN": "test.example2.local"
                        }
                    ]
                }
            ]
            ```
            
            Linux/Unix Distributions
            
            **Example:**
            
            ```JSON
            "DNS": { 
                "Interfaz": "Internet",
                "Zonas": [
                    {
                        "Tipo": "Forward",
                        "Nombre": "MyForwardZone",
                        "Registros": [
                            {
                                "Tipo": "A",
                                "Hostname": "example.local",
                                "IP": "10.23.1.2"
                            },
                            {
                                "Tipo": "CNAME",
                                "Alias": "siteOne",
                                "FQDN": "test.example.local"
                            },
                            {
                                "Tipo": "MX",
                                "ChildDomain": "example2.local",
                                "FQDN": "test.example2.local"
                            }
                        ]
                    },
                    {
                        "Tipo": "Reverse",
                        "Nombre": "MyReverseZone",
                        "NetID": "12.11.13.0/24",
                        "Registros": [
                            {
                                "Tipo": "PTR",
                                "Hostname": "example3.local",
                                "Host": "2"
                            },
                            {
                                "Tipo": "CNAME",
                                "Alias": "siteOne",
                                "FQDN": "test.example.local"
                            }
                        ]
                    }
                ]
            }
            ```
                
        + <details>
            <summary>IPTables.</summary>
    
            ###
            This service is only avaible for Linux/Unix distributions.
           
            * IPTables. IPTables backup file location.
            
            **Example:**
            
            ```JSON
            "Servicios": {
                "IPTables": "C:\\Sandbox\\iptables.txt"
            }
            ```
</details>

This tool provides some examples of valid [input files], which can serve as a reference and can be loaded directly into the tool by making the corresponding modifications for the environment you want to create. You can find templates to create VMs specifically of each supported operating system, as well as other templates creating a whole infrastructure of VMs.

> Technical specifications about every single value can be found in [Input Values] section.

## Pre-Installation Requirements

* **Linux Subsystem for Windows**

Enable the **Windows Subsystem for Linux** before installing any Linux Distribution for Windows. Open Powershell and running the following command:

```Powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
```

**Update to the latest Windows version** in the Settings menu.

<p align="center"><img src=./Images/WindowsUpdate.png height="60%" width="60%"></p>

[Download the Linux kernel update package].

Open PowerShell and run this command to set Windows Subsystem for Linux 2 as the default version when installing a new Linux distribution:

```Powershell
wsl --set-default-version 2
```
Open the Microsoft Store and get the Ubuntu Distribution.

<p align="center"><img src=./Images/Ubuntu.png height="60%" width="60%"></p>

Open an Ubuntu console and create a new user. 

<p align="center"><img src=./Images/UbuntuShell.png height="60%" width="60%"></p>

Once configured Windows Subsystem for Linux it's necessary install the following packages:

* **whois**. Lists the information about the domain owner of the given domain, it's needed for *mkpasswd* package installation.

* **dos2unix**. Converts plain text files in Windows to Linux format.

* **mkisofs**. Create an hybrid ISO9660/JOLIET/HFS filesystem.

```Bash
apt-get install -y whois dos2unix mkisofs
```

## Instalation and Configuration

Once all the requirements mentioned in the previous section are satisfied, we can start using the tool following the next steps:

1. Download the tool repository in the Hyper-V Host.
2. Open a Powershell session where the root of the tool is located.
3. Create or load into the input file (located at /Configuracion/configuracion.json) the configuration corresponding to the infrastructure to be mounted and save the file.
4. Execute the following command in order to start the validation of the input file:
    ```Powershell
    .\main.ps1
    ```
5. If the entered input file passes validation of all entered fields, the following menu will be presented:
    
    <p align="center"><img src=./Images/menu1.png height="60%" width="60%"></p>
    
    > If the tools finds an error in the input file, it will stop the execution and print the error found in the file. You must fix the error and then, repeat step 3.

    In the first option in the menu presented, you can list all the VMs passed in the input file and select one to see details of it and install that VM in particular:

    <p align="center"><img src=./Images/menu2.png height="60%" width="60%"></p>

    <p align="center"><img src=./Images/menu3.png height="60%" width="60%"></p>

    If the second option is selected, details from all the VMs are displayed and after the confirmation, the installation of all the VMs will start:

    <p align="center"><img src=./Images/menu4.png height="60%" width="60%"></p>

    <p align="center"><img src=./Images/menu5.png height="60%" width="60%"></p>

## Post-Installation instructions

In some cases, in order to get the full configuration ready in the VMs, human interaction is needed. The list is the following:

* Debian 10 Buster.
* Kali Linux 20.04.
* Ubuntu Family.

Specifications foreach system can be found bellow:

### Buster & Kali

*  In order to install and configure the services stablished in the input file for this systems, you need to execute this as root:

```sh
/bin/bash /servicios/ConfigurarServiciosLinux.sh
```

### Ubuntu X.04

* You'll need to press **"Enter"** after the install completes in order to boot to the system.

* In order to set the network configuration stablished in the input file in the VM, you need to execute this as root:

```sh
/bin/bash /servicios/ConfigurarInterfaces.sh
```

After the system reboots, by default all interfaces are down; to enable an interface, just execute the following command:

```sh
ifup eth0
```

### Tutorials and examples

[Download the Linux kernel update package]: <https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi>
[minimum system requirements]: <#minimum-system-requirements>
[The input file]: <#the-input-file>
[Input Values]: <https://github.com/barvch/generador-de-sandbox/blob/main/recursos/TechnicalManual/README.md#input-values>
[Workflow] <https://github.com/barvch/generador-de-sandbox/tree/main/recursos/TechnicalManual#workflow>
[Post-Installation instructions]: <#post-installation-instructions>
[input files]: </Configuracion/Plantillas>
