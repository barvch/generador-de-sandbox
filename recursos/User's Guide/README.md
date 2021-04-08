# User's Guide

This documentation guides sandbox generator tool's users through several topics in the system.

## About tool

### Tool structure
### The input file

## Instalation and Configuration

### Requirements installation

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

Once configured Windows Subsystem for Linux it's necesary install the following packages:

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

### Post-Installation instructions

## Tutorials and examples

### Demos

### Blueprints

[Download the Linux kernel update package]: <https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi>
