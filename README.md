# Sandbox Generator

## Description of the tool

* This tool is a sandox generator for Hyper-V that allows you to create, configure and replicate a wide range of VMs in an unattended manner. The goal behind this project is to automate the process of creating and configuring both virtual machines and services using an input file that provides data for each VM indicated indicated within it. This way, mouting an infraestructure to create test enviroments for malware analisys or any other task, becomes really easy.

* In the **[User Guide]** you can find a much longer and detailed documentation about how this tool works. Please read the guide in order to understand the requirements and workflow of the tool, as well of more relevant information of what you can do with this tool.

* In the **[Technical Guide]** you can find detailed documentation about how this tool is structured and it's recommended to all people with technical knowledge about PowerShell and bash scripting as well as the [services] and OS Pool implemented.

### OS Pool

This is the list of current OS supported by the tool:

* Windows 10
* Windows Server 2019
* Ubuntu 16.04 
* Ubuntu 18.04 
* Ubuntu 20.04 
* Debian 10 (Buster)
* Kali Linux 2020.04
* CentOS 8
* RHEL 8
* FortiOS

### Requirements by the tool

* Any flavor of the [Linux Subsystem for Windows] installed and running on the Hyper-V host with the following packages installed:

    - **whois** - To download *mkpasswd* package which allows create valid hashed password values for Unix
    - **dos2unix** - To remove EOL issues with Windows/Unix

* In order to be an Hyper-V Host, first you need to **install the Hyper-V role** in order to run this tool; if the tool detects that the role is not present in the Server, it will install it for you and reboot the server in order to apply changes.

* In order to be able to **install any packages in any VM running RHEL 8**, you neeed to **supply the credentials used in your Red Hat account in the crediantial section of the input file**. This is importart for a correct service install and configuration in the post-install section.


### Default Values in the tool

* The **timezone** used for all the kickstart files used in Linux, the XML used in Windows and services configuration, is **America/Mexico_City**

* The default **OS language** for all the VMs is **English**

* The default **keyboard layout** for all the VMs is **Latin American**



## The input file

Briefly, this tool works reading a JSON file located at **/Configuracion/configuracion.json**, which contains the following data:

* **Root** - The root folder of the project. This is the place in the Hyper-V host where all the files of the virtual machines and files needed by this tool will reside.
* **VMs** - The list and specifications foreach VM that will be created.

> You can find some [examples of valid input files], which can serve as a reference and can be loaded directly into the tool by making the corresponding modifications for the environment you want to create. 
> You'll find templates to create VMs specifically of each supported operating system, as well as other templates creating a whole infrastructure of VMs.

In the VMs section, there are a number of values required by the tool to work, you need/can supply **Generic Values**, **Invidiual Values** and **Services details**. All this values which are briefly detailed below:

### Generic Values

This tool expects some mandatory and necessary values foreach VM, regardless of the operating system that you want to install inside the machine, such as:

* Credentials
* Hard Drive(s): Number & Size  
* RAM: Number & Type 
* Hostname
* Network Configuration per interface
    * Type ( DHCP / Static )
    * Virtual Switch associated

### Individual values

Depending on the operating system that is intended to be installed within the VM, the tool expects some mandatory values and other optional values that must be specified within the input file.

The full documentation and list of this individual values available per SO can be found [here].

### Services 

This tool also allows you to configure some common services within supported operating systems.

The list of services available per SO is the following:

| SO | Services |
| ------ | ------ |
| Windows Server 2019 |  <ul><li>Windows Defender</li><li>AD</li><li>Certificate Services</li><li>IIS</li><li>DHCP</li><li>DNS</li><li>Bind DNS</li></ul> |
| Linux/Unix | <ul><li>Web Server (apache/nginx)</li><li>RDBMS (SQL Server, MariaDB, MySQL, PostgreSQL)</li><li>DHCP</li><li>Bind DNS</li><li>iptables</li></ul> |

Extensive documentation on the values expected by the tool for proper installation and configuration foreach service can be found in [User Guide > The input file > Services] section.

* **NOTE**: The RDP or SSH service is installed by default within all windows and Linux machines, respectively.


## Finish & post-install Instructions

In some cases, in order to get the full configuration ready in the VMs, human interaction i
s needed. The list is the following:

* Debian 10 Buster
* Kali Linux 20.04
* Ubuntu Family
* Windows Server 2019 if IIS Service is configured.

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

### Windows Server 2019

If a site it's not configured properly, it's neccesary run the configuration script manually. Open Powershell with administrative permissions and run the following command:

```Powershell
.\C:\sources\$OEM$\$1\ConfigurarServiciosWindows.ps1
```

> The command will trigger many errors but they are normal because it will try to overwrite some settings without success.

[here]: <https://docs.google.com/spreadsheets/d/13qQsPp08ocH_j-whSafJKate7DskU9h4aBCn-lr3qTU/edit#gid=0s>
[Linux Subsystem for Windows]: <https://docs.microsoft.com/en-us/windows/wsl/install-win10> 
[examples of valid input files]: <./Configuracion/Plantillas>
[User Guide > The input file > Services]: <./recursos/UserGuide#the-input-file>
[User Guide]: <./recursos/UserGuide>
[services]: <#services>
[Technical Guide]: <./recursos/TechnicalGuide>
