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
           catalogos.ps1
           obtenerValidaciones.psm1
``` 

* **Configuracion**. the Contains configuration file (*configuracion.json*) and virtual machines's templates. 
* **Modulos**. Powershell modules.
    - *1. Validaciones*. Data validation.  
    - *2. CreacionMaquinas*. Hyper-V's machine creation and custom ISO file creation.
* **recursos**. Files used for data validation and virtual machines creation.
    - **unattend**. Templates used for each OS ISO file creation.
        + *ServiciosLinux*. Services installation and configuration script and templates used for Linux/Unix services.
    - **Validaciones**. Files used for data validation.
        + *catalogos.ps1*. System catalogs.
        + *obtenerValidaciones.psm1*. Data type validations.

## Workflow 

Every step will describe its own functions, for information about step's behavior please check [About Tool] section.

## Input Data

* [Generic and Dependent Values].
* [Services].

[About Tool]: <../UserGuide#about-tool>
[Generic and Dependent Values]: <./Files/InputValues.pdf>
[Services]: <./Files/Services.pdf>
