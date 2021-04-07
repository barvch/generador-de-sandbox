# Sandbox Generator

## Description of the tool

* This tool is a sandox generator for Hyper-V that allows you to create, configure and replicate a wide range of VMs in an unattended manner. The goal behind this project is to automate the process of creating and configuring both virtual machines and services using an input file that provides data for each VM indicated indicated within it. This way, mouting an infraestructure to create test enviroments for malware analisys or any other task, becomes really easy.

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

    - **whois** - To create valid hashed password values for Unix
    - **dos2unix** - To remove EOL issues with Windows/Unix

* In order to be an Hyper-V Host, first you need to **install the Hyper-V role** in order to run this tool; if the tool detects that the role is not present in the Server, it will install it for you and reboot the server in order to apply changes.

* In order to be able to **install any packages in any VM running RHEL 8**, you neeed to **supply the credentials used in your Red Hat account in the crediantial section of the input file**. This is importart for a correct service install and configuration in the post-install section.


### Default Values in the tool

* The timezone used for all the kickstart files used in Linux, the XML used in Windows and services configuration, is **America/Mexico_City**

* The default OS language for all the VMs is **English**

* The default keyboard layout for all the VMs is **Latin American**



## The input file

This tool works from an input file in JSON format, which contains the following data:

* **Root** - This is the root folder of the project. This is the place in the system where all the files of the virtual machines will reside.
* **VMs** - This is the list and specifications of VMs that will be created.

This tool provides some [examples of valid input files], which can serve as a reference and can be loaded directly into the tool by making the corresponding modifications for the environment you want to create. You can find templates to create VMs specifically of each supported operating system, as well as other templates creating a whole infrastructure of VMs.

In the VMs section, there are a number of values required by the tool to work, which are detailed below:

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

Extensive documentation on the values expected by the tool for proper installation and configuration foreach service can be found [here][servicios].

* **NOTE**: The RDP or SSH service is installed by default within all windows and Linux machines, respectively.


## Finish & post-install Instructions

In some cases, in order to get the full configuration ready in the VMs, human interaction i
s needed. The list is the following:

* Debian 10 Buster
* Kali Linux 20.04
* Ubuntu Family

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

## Videos

* Create a valid JSON input file:

    * https://drive.google.com/file/d/1F-kv7awZ0BfdEEHCnjH5ICOtm8Yp7JoA/view?usp=sharing

* Run the tool to test the JSON file created:

    * https://drive.google.com/file/d/1rf91jSrD6FEsrO-s-RIStoBLzxlkfeel/view?usp=sharing



[here]: <https://docs.google.com/spreadsheets/d/13qQsPp08ocH_j-whSafJKate7DskU9h4aBCn-lr3qTU/edit#gid=0s>
[Linux Subsystem for Windows]: <https://docs.microsoft.com/en-us/windows/wsl/install-win10> 
[examples of valid input files]: <https://github.com/barvch/generador-de-sandbox/tree/main/Configuracion/Plantillas>
[servicios]: <https://docs.google.com/spreadsheets/d/13qQsPp08ocH_j-whSafJKate7DskU9h4aBCn-lr3qTU/edit#gid=492063908>