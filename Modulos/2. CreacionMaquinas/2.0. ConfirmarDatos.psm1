function ConfirmarDatos { param ($maquinas = $maquinas)
    function IteraArreglo { param ($arreglo, $sangria = 0)
        foreach($diccionario in $arreglo){
            IteraDiccionario -diccionario $diccionario -sangria $sangria
        }
    }
    function IteraDiccionario { param ($diccionario, $sangria = 0)
        foreach($llave in $diccionario.keys){
            $valor = $diccionario[$llave]
            if($valor){
                Write-Host -NoNewline $("`t" * $sangria)
                switch -regex ($valor.GetType().Name){
                    ".*Object.*" {
                        Write-Host "$($llave):"
                        IteraArreglo -arreglo $valor -sangria ($sangria+1)
                        break
                    }
                    OrderedDictionary {
                        Write-Host "$($llave):"
                        IteraDiccionario -diccionario $valor -sangria ($sangria+1)
                        break
                    }
                    Default {
                        Write-Host "$($llave): $valor"
                    }
                }
            }
        }
    }
    function MuestraMaquinas { 
        for($index = 0;  $index -lt $maquinas.Count; $index++){
            Write-Host "$($index+1)) $($maquinas[$index]["Hostname"])-$($maquinas[$index]["SistemaOperativo"])"
        }
        Write-Host "$($index+1)) Regresar"
        return $maquinas.Count
    }
    function ConfirmarCreacion { param ($maquina = $maquinas, $flag = $false)
        if($flag){$mensaje = "Crear todas las maquinas virtuales?"}else{$mensaje = "Crear maquina virtual?"}
        $confirmacion = Read-Host "$mensaje (S/N)"
        switch ($confirmacion.ToUpper()) {
            S { If($flag){ return $maquinas }else{ return $maquina } }
            N { if($flag){ ConfirmarDatos } else { SeleccionaMaquina }; break }
            Default { ConfirmarCreacion -flag $flag}
        }
    }
    function SeleccionaMaquina { 
        $totalMaquinas = MuestraMaquinas
        $maquinaIndex = Read-Host -Prompt "Selecciona una maquina"
            if($maquinaIndex -in 1..$totalMaquinas) {
                IteraDiccionario -diccionario $maquinas[$maquinaIndex-1]
                ConfirmarCreacion -maquina $maquinas[$maquinaIndex-1]
            }elseif($maquinaIndex -eq $totalMaquinas+1){
                ConfirmarDatos
            }else{
                SeleccionaMaquina
            }
    }
    $opcion = Read-Host -Prompt "1) Mostrar datos por maquina`n2) Mostrar todos los datos`n3) Terminar`nSelecciona una opcion"
    switch ($opcion) {
        1 { SeleccionaMaquina ; break}
        2 { IteraArreglo -arreglo @($maquinas); ConfirmarCreacion -flag $true; break }
        3 { Write-Host "Programa terminado exitosamente"; break }
        Default { ConfirmarDatos }
    }
}