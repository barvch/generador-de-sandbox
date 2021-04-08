# User's Guide

This documentation guides sandbox generator tool's users through several topics in the system.

## Requirements

The tool needs the following packages to run properly.

### Linux Subsystem for Windows 

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
Open the Microsoft Store and select Ubuntu Distribution.

<p align="center"><img src=./Images/Ubuntu.png height="60%" width="60%"></p>


### Whois
### dos2unix

## Instalation and Configuration
Tool Download


## Tutorials and examples

### Demos

### Blueprints

[Download the Linux kernel update package]: <https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi>
