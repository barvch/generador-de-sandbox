# Technical Guide

Welcome to the technical guide of this tool!. The intention of this guide is guide developers through several topics related to the tool, such as tool structure, workflow and validations.

## Main Structure

```Bash
    main.ps1
├───Configuracion
│       configuracion.json
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

* **Configuracion**. Contains the configuration file (*configuracion.json*) and virtual machines's templates. 
* **Modulos**. Powershell modules.
    - *1. Validaciones*. Data validation.  
    - *2. CreacionMaquinas*. Hyper-V's machine creation and custom ISO file creation.
* **recursos**. Files used for data validation and virtual machines creation.
    - **unattend**. Templates used for each OS ISO file creation.
        + *ServiciosLinux*. Services installation and configuration script and templates used for Linux/Unix services.
    - **Validaciones**. Files used for data validation.
        + *catalogos.ps1*. System catalogs.
        + obtenerValidaciones.psm1. Data type validation.

## Workflow 

Every step will describe its own functions, for information about step's behavior please check [About Tool] section.

* [Workflow].

## Input Data

There are two types of validations: 

1. **Attribute**. They are all virtual machines and services properties.
    
    * [Generic and Dependent Values].
    * [Services]. 
    
    **Example:**
    
    > * *Hostname*. Mandatory:
    >   - Must start and end with an alphabetic character.
    > * *DiscosVirtuales*. Mandatory:
    >   - The minumum value accepted must be 15.
    >   - The host must validate that there is enough available space.
    > * *LlaveActivacion*. Optional. The field must have the following format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX.
    > * *ActiveDirectory*. Optional. This service is only available for Windows Server 2019 and if is set, the tool doesn't allow configure other service.
    >   - Domain. The field must have the following format: contoso.domain.local.
    >   - NetBIOS. If no data is provided, the value is set by Domain prefix.
    >   - DomainMode. 
    >       + The functional level of the DomainMode field cannot be lower than the functional level of the ForestMode field.
    >       + Values: Win2008, Win2008R2, Win2012, Win2012R2, Win2016.
    >   - ForestMode. 
    >       + If no data is provided, the value is set by DomainMode field.
    >       + Same values as DomainMode.

2. **Data type**. They are all validations related with all virtual machines and services properties:

    * [Data Type Validation].

    **Example:**
        
    > * *Hostname*:
    >   - String: alfaNum1. Non-Windows distributions, longitud1 (5 to 20 characters length).
    >   - String: alfaNum5. Windows distributions, longitud1 (5 to 20 characters length).
    >   - In case of containing non-alphanumeric characters, these must not be consecutive.
    > * *DiscosVirtuales*. Int array.
    > * *LlaveActivacion*. String: llaveActivacion (Windows Activation Key format validation), longitud4 (29 characters length).
    > * *ActiveDirectory*:
    >   - Domain. String: dominio (domain format validation).
    >   - NetBIOS. String: alfaNum1, longitud6 (5 to 15 characters length).
    >   - DomainMode and ForestMode. String.

[About Tool]: <../UserGuide#about-tool>
[Generic and Dependent Values]: <./Files/InputValues.pdf>
[Services]: <./Files/Services.pdf>
[Workflow]: <./Files/Workflow.pdf>
[Data Type Validation]: <./Files/DataTypeValidation.pdf>
