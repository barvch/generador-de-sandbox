# User's Guide

This documentation guides sandbox generator tool's users through several topics in the system.

## About tool

This tool is a sandox generator for Hyper-V that allows you to create, configure and replicate a wide range of VMs in an unattended manner. The goal behind this project is to automate the process of creating and configuring both virtual machines and services using an input file that provides data for each VM indicated indicated within it. This way, mouting an infraestructure to create test enviroments for malware analisys or any other task, becomes really easy.

This tool is built according to following flow:

1. **Data validation**. Before virtual machine creation the tool validate every single field according minimun system requirements and services requirements. This section is blabla in three groups:

* General data. 
* Dependent data.
* Services. 

2. **Data printing and confirmation**.
3. **Hyper-V machine creation**.
4. **Custom ISO creation**.
5. **Operating system installation**.
6. **Post-Installation running script**.

Technical specs can be found here.

### The input file


## Before Start

There are several considerations before install process:

### Minimun System Requirements

### Pre-Installation Requirements

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

### Blueprints

[Download the Linux kernel update package]: <https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi>
[minimun system requirements]: <https://github.com/barvch/generador-de-sandbox/tree/main/recursos/User's%20Guide#minimun-system-requirements>
