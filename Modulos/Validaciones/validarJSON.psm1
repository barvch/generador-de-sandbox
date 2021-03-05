function ValidarRoot { param ( [string] $rutaRaiz)
    if (Test-Path -Path $rutaRaiz) {
        return $rutaRaiz
    } else {
        $ficheroAnterior = Split-Path -Path $rutaRaiz
        $leaf = Split-Path -Path $rutaRaiz -Leaf
        if (Test-Path -Path $ficheroAnterior) {
            $respuesta = Read-Host -Prompt "Desea crear el fichero $leaf dentro de $ficheroAnterior y usarlo como raiz para el ambiente? [S/N]"
            if ($respuesta.ToLower() -eq "s") {
                New-Item -Path $rutaRaiz -ItemType "directory"
                "Se ha creado la carpeta $leaf.`nRaiz del ambiente: $rutaRaiz"
                return $rutaRaiz
            }
        } else {
            "Error en el path ingresado como raiz del proyecto.`nNo existe el padre de la ruta proporcionada o no se tienen los permisos suficientes para poder crear el proyecto dentro de $ficheroAnterior. Revisar archivo JSON"
            exit
        }
    }
}
function ValidarJSON {
    $rutaJSON = ".\Configuracion\configuracion.json"
    #Se verifica que exista el archivo
    if(Test-Path -Path $rutaJSON){
        #Se verifica que el archivo cuente con un formato JSON valido
        try{
            $archivoJSON = Get-Content -Raw -Path $rutaJSON | ConvertFrom-Json
            return $archivoJSON
        }catch{
            Write-Host "El archivo $rutaJSON no cuenta con un formato JSON valido"
            exit
        }
    }else{
        Write-Host "No se ha encontrado el archivo: $rutaJSON"
        exit
    }
}