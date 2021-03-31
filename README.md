# generador-de-sandbox

## Description

This tool is a sandox generator for Hyper-V that allows you to create, configure and replicate a wide range of VMs in an unattended manner. The list of current supported OS by the tool is the next one:

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

The goal behind this project is to automate the process of creating and configuring virtual machines using an input file in which you can provide generic and individual data for each VM, for example:

* Credentials
* Number and Size of Hard Drives 
* RAM number and RAM type 
* Hostname
* Network Configuration per interface
    * DHCP
    * Static

In the input file, relevant data can be set depending of the OS you want to install. The list of this particular values foreach SO, aswell as the data type and lenght can be found [here].

## Requirements by the tool:

* The [LinuxSubsystem] for Windows with the following packages:

    - *whois* - To create hashed password values
    - *dos2unix* - To remove EOL issues

## Post-Instalación

jeje

## Defaults

For all the kickstart files used in Linux, the XML used in Windows and services configuration, the timezone used is *America/Mexico_City* 

## Powershell madafaka, do you speak it?



[here]: <https://docs.google.com/spreadsheets/d/13qQsPp08ocH_j-whSafJKate7DskU9h4aBCn-lr3qTU/edit#gid=492063908>
[LinuxSubsystem]: <https://docs.microsoft.com/en-us/windows/wsl/install-win10> 