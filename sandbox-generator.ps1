function Validar-JSON {
    param ([string]$rutaJSON)
    if (Test-Path -Path $rutaJSON) {
        try {
            $contenido = Get-Content -Raw -Path $rutaJSON | ConvertFrom-Json
            return $contenido
        } catch {
            Write-Host "El archivo $rutaJSON no cuenta con un formato JSON correcto."
            exit
        } 
    } else { 
        Write-Host "No se ha encontrado el archivo: $rutaJSON"
        exit
    }
}

function Validar-Raiz {
    param ([string]$rutaRaiz)
    if (Test-Path -Path $rutaRaiz) {
        "Raiz del ambiente: $rutaRaiz"
        return $rutaRaiz
    } else {
        $ficheroAnterior = Split-Path -Path $rutaRaiz
        $leaf = Split-Path -Path $rutaRaiz -Leaf
        if (Test-Path -Path $ficheroAnterior) {
            $respuesta = Read-Host -Prompt "Desea crear el fichero $leaf dentro de $ficheroAnterior y usarlo como raiz para el ambiente? [S/N]"
            if ($respuesta -eq "S" -or $respuesta -eq "s") {
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

$rutaJSON = $args[0] # Se lee la ruta donde esta el archivo de entrada
$archivoEntrada = Validar-JSON -rutaJSON $rutaJSON # Se lee y valida que exista el archivo y que esté en formato JSON
$raiz = Validar-Raiz -rutaRaiz $archivoEntrada[0].Root # Se lee y valida la ruta raiz del proyecto a ser creado.
Write-Host ":)"