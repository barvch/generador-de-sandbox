# User's Guide

This documentation guides sandbox generator tool's users through several topics in the system.

## About tool

This tool is a sandox generator for Hyper-V that allows you to create, configure and replicate a wide range of VMs in an unattended manner. The goal behind this project is to automate the process of creating and configuring both virtual machines and services using an input file that provides data for each VM indicated indicated within it. This way, mouting an infraestructure to create test enviroments for malware analisys or any other task, becomes really easy.

This tool is built according to following flow:

* **Hyper-V Rol Check**. The tool validate if tool is running in a Windows Server 2019 environment and Hyper-V Role is installed in host, otherwise, it is installed and the host is rebooted, is necessary run the tool a second time.

* **Data validation**. Before virtual machine creation the tool validate every single field according following requirements:
    
    - Generic values. Data related with host machine available resources and file storage.
    - Dependent values. Specific data for each operating system.
    - Services. Specific data per service.

> There are several values that are set over the validation flow, those values and specific information about each field are documented in [The input file] section.

* **Data printing and confirmation**. The tool allow to check all data for each or all virtual machines before create them.
* **Hyper-V machine creation**. Once one or all virtual machines are validated, hardware requirements are set with virtual hard drive exception.

> Hardware that is set:
> * Amount and size of virtual disks.
> * Number of processors.
> * RAM memory:
>   - Static:
>       + Total memory.
>   - Dynamic:
>       + Minimum memory.
>       + Maximum memory.
> * Network interfaces
>   - Virtual Switches:
>       + Name.
>       + Type.
>       + Network adapter.
>   - Type.
>   - Name.

* **Custom ISO creation**. In this step, the ISO file specified by user is mounted in host and unattended files are customized and loaded within. The tool for ISO creation depends of each operating system:

    - Windows. DISM.
    - Linux/Unix. mkisofs.
 
> Data that are set within unattended files:
> * General data:
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

* **Operating system installation**. The hard drive with major capacity and ISO file are mounted, then, the virtual machine is started. The following operating systems needs user interaction because desktop environment is selected in this step:

    - Debian 10 (Buster).
    - Kali Linux 2020.04.

> The interfaces are set in this process with Ubuntu exception.

* **Post-Installation running script**. This script installs and configures all services required and it is executed automatically after OS installation.

> Exceptions: 
> * Debian 10 Buster.
> * Kali Linux 20.04.
> * Ubuntu Family.
> 
> For those OS check [Post-Installation instructions] section.

**This flow repeats itself for every single virtual machine to create.**

## The input file

The **generador-de-sandbox/Configuracion/configuracion.json** file is the core of the tool and works in JSON format which contains the following data for virtual machines customization:

* **Root**. This is the root folder of the project. This is the place in the system where all the files of the virtual machines will reside.
* **MaquinasVirtuales**. This is the list and specifications of virtual machines that will be created. This field is built by three sections:

    - **Generic values**. Data related with host machine available resources and file storage. This section contains the following fields:
        
        + SistemaOperativo:
            - Windows 10.
            - Windows Server 2019.
            - Ubuntu 16.04.
            - Ubuntu 18.04.
            - Ubuntu 20.04.
            - Debian 10 (Buster).
            - Kali Linux 2020.04.
            - CentOS 8.
            - CentOS Stream.
            - RHEL 8.
            - FortiOS 6.
        + Hostname.
        + TipoAmbiente:
            - Windows. The accepted values are obtaining by mounting the ISO file in the host and reading the **install.wim** file. 
        
        **Example:**

        ```JSON
        {
            "Root": "C:\\Sanbox",
            "MaquinasVirtuales": [
                {
                    "SistemaOperativo": "Windows 10",
                    "Hostname": "Contoso",
                    "TipoAmbiente": "Windows 10 Home",
                    "DiscosVirtuales": [20, 15],
                    "Procesadores": 4,
                    "RutaISO": "C:\\Sanbox\\Win10_1909_English_x64.iso",
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
    
    - **Dependent values**. Specific data for each operating system.
        
        + ssdsd
        
        **Example:**
    
    - **Services**. Specific data per service.

        + ssdsd
        
        **Example:**

This tool provides some examples of valid [input files], which can serve as a reference and can be loaded directly into the tool by making the corresponding modifications for the environment you want to create. You can find templates to create VMs specifically of each supported operating system, as well as other templates creating a whole infrastructure of VMs.

> Technical specs about every single value can be found [here].

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

* **whois**

The **whois command** lists the information about the domain owner of the given domain, it's needed for **mkpasswd** package installation.

```Bash
apt-get install whois
```

* **dos2unix**

The **dos2unix command** converts plain text files in Windows to Linux format.

```Bash
apt-get install dos2unix
```

## Instalation and Configuration

### Post-Installation instructions

## Tutorials and examples

### Demos

[Download the Linux kernel update package]: <https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi>
[minimun system requirements]: <#minimun-system-requirements>
[The input file]: <#the-input-file>
[here]: <>
[Post-Installation instructions]: <#post-installation-instructions>
[input files]: </Configuracion/Plantillas>
