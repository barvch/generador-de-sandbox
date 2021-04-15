# Technical Guide

Welcome to the technical guide of this tool!. The intention of this guide is guide developers through several topics related to the tool, such as tool structure, workflow and validations.

## Main Structure

```Bash
    main.ps1
├───Configuracion
|       configuracion.json
│   └───Plantillas
├───Modulos
│   ├───1. Validaciones
│   └───2. CreacionMaquinas
└───recursos
    ├───exe
    ├───unattend
    │   ├───CentOS
    │   ├───Debian
    │   ├───FortiOS
    │   ├───Kali
    │   ├───ServiciosLinux
    │   │   └───ArchivosConfiguracion
    │   ├───Ubuntu
    │   └───Windows
    └───Validaciones
``` 

## Workflow 

Every step will describe its own functions, for information about step's behavior please check [About Tool] section.

<p><img src=./Files/GenericValues.png></p>

[About Tool]: <../UserGuide#about-tool>
