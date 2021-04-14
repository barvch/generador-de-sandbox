# Technical Guide

Welcome to the technical guide of this tool!. The intention of this guide is guide developers through several topics related to the tool, such as tool structure, workflow and validations.

## Main Structure

```Bash
├───main.ps1
├───Configuracion
|   ├───configuracion.json
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

* **main.ps1**. Main function, it calls 
* **configuracion.json**.
* ****.
For detailed information please check the section below. 

## Workflow 

Every step will describe its own functions, for information about step's behavior please check [About Tool] section.

<div class="tg-wrap"><table style="undefined;table-layout: fixed; width: 1324px; overflow-x: scroll;"><colgroup><col style="width: 134px"><col style="width: 166px"><col style="width: 185px"><col style="width: 543px"><col style="width: 170px"><col style="width: 126px"></colgroup><thead><tr><th>Workflow</th><th>Modules</th><th>Functions</th><th>Description</th><th>Called modules</th><th>Called functions</th></tr></thead><tbody><tr><td rowspan="2">Hyper-V Rol Check</td><td rowspan="2">main.ps1</td><td>main</td><td>Handles flow control of creation of each virtual machine.</td><td>ConfirmarDatos.psm1</td><td>ConfirmarDatos</td></tr><tr><td>VerificarHyperV</td><td>Checks if tool is running in a Windows Server 2019 environment and if Hyper-V Role is installed.</td><td>ValidarJSON.psm1</td><td>ValidarJSON</td></tr><tr><td>Data Validation</td><td rowspan="3">ValidarSecciones.psm1</td><td>ValidarDatosGenerales</td><td>Checks if generic data has valid values and returns a valid data structure from configuracion.json file with generic and dependent values as well as each service.</td><td></td><td></td></tr><tr><td></td><td>ValidarDatosDependientes</td><td>Checks if dependent data has valid values.</td><td></td><td></td></tr><tr><td></td><td>ValidarServicios</td><td>Checks if each services has valid values and sets the default values for each service.</td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td></td><td></td><td></td><td></td><td></td><td></td></tr></tbody></table></div>
[About Tool]: <../UserGuide#about-tool>
