#Variables del Script
baseNumeros="$1" # archivo donde se encuentra la base de numeros de todos los socios 
idDispositivo="$2" # identificar de dispositivo adb devices -l
listafiltradaNumerosVigentes="numeros$(date +"%d%m%Y_%H%M%S").txt" # Archivo donde se encuentran los destinatarios (numeros de clientes)

#
# Función para desbloquear el dispositivo
#
function desbloqueoBloqueoDispositivo(){
 if [[ "$(adb -s "$idDispositivo" shell dumpsys power | grep "Display Power" | cut -d '=' -f 2 | tr -d '[:space:]')" == 'ON' ]]
 then
  #Boton redondo o central
  adb -s "$idDispositivo" shell input tap 282 1240
  sleep 3
  #Boton cuadrado o el de la derecha
  adb -s "$idDispositivo" shell input tap 432 1240
  sleep 2
  #Boton eliminar o borrar (Basurero)
  adb -s "$idDispositivo" shell input tap 353 1080
  sleep 2
  adb -s "$idDispositivo" shell input keyevent 26
  return 1
 else
  adb -s "$idDispositivo" shell input keyevent 26
  sleep 2
  adb -s "$idDispositivo" shell input swipe 100 900 100 100
  sleep 2
  return 0
 fi
}


function contNumVigentes(){ 
    #-v cont="$contadorVigentes" \
    awk -F "," \
    -v descripcion="VIGENTE" \
    -v fechaComparacion="$(date +"%d/%m/%Y" --date="+2 day")" \
    -v archivoNumerosFiltrados="$listafiltradaNumerosVigentes" \
    ' \
    BEGIN{contvig=0} 
        { 
            if ($3==fechaComparacion && $2==descripcion) 
            { 
                contvig++; 
                print $1 >> archivoNumerosFiltrados;
                
            } 
        } 
    END{print contvig" "descripcion" "fechaComparacion } \
    ' "$baseNumeros" 
}

# Funcion que compra SMS de Entel 

# 1) 4 SMS x 0.5 Bs
# 2) 30 SMS x 2 Bs
# 3) 60 SMS x 4 Bs
# 4) 75 SMS x 5 Bs

# Asi mismo considerar la codificacion en porcentaje segun RFC 3986 donde:
# *	%2A
# #	%23
# ?	%3F
# /	%2F
# :	%3A
# =	%3D

function comprarSmsDivice(){
    cantidadSMS="$1"
    estadoCredito="$2"
    opcionSmsCompra=0

    if [[ "$(echo $estadoCredito | tr '[:upper:]' '[:lower:]')" == "vigente" ]]
    then
        # SIM VIGENTE
        coordenadaXsim=242 #coordenada x para realizar la peticion con el SIM Z
        coordenadaYsim=1127 #coordenada y para realizar la peticion con el SIM Z
    else
        # SIM VENCIDO
        coordenadaXsim=542 #coordenada x para realizar la peticion con el SIM Z
        coordenadaYsim=1132 #coordenada y para realizar la peticion con el SIM Z
    fi

    if [[ "$cantidadSMS" -ge 1 && "$cantidadSMS" -le 4 ]]
    then
        opcionSmsCompra=1
    else
        if [[  "$cantidadSMS" -ge 5 && "$cantidadSMS" -le 30 ]]
        then
            opcionSmsCompra=2
        else
            if [[ "$cantidadSMS" -ge 31 && "$cantidadSMS" -le 60 ]]
            then
                opcionSmsCompra=3
            else
                if [[ "$cantidadSMS" -ge 61 && "$cantidadSMS" -le 75 ]]
                then
                    opcionSmsCompra=4
                fi
            fi
        fi
    fi

    if [[ "$opcionSmsCompra" -gt 0 ]]
    then 
        # esta lina de codigo marca el *10*5*1*1 en el telefono
        adb -s "$idDispositivo" shell service call phone 1 s16 "%2A10%2A5%2A1%2A$opcionSmsCompra%2A1%23" > /dev/null 2>&1
        sleep 4
        adb -s "$idDispositivo" shell input tap "$coordenadaXsim" "$coordenadaYsim"
        # echo 'adb -s ' "$idDispositivo" ' shell input tap ' "$coordenadaXsim" "$coordenadaYsim"
        sleep 15
    else
        printf "\nNo se compraron SMS's porque la cantidad de SMS es igual a %s\n\n" "$opcionSmsCompra"
    fi
}

function principal(){
    lineaCompleta=$(contNumVigentes) # lineaCompleta: "5 VIGENTE 20/11/2024"
    
    contadorNumerosVigentes=$(echo $lineaCompleta | cut -d " " -f 1) # 5
    descripcionCredito=$(echo $lineaCompleta | cut -d " " -f 2) # VIGENTE
    fechaProximoPago=$(echo $lineaCompleta | cut -d " " -f 3) # 20/11/2024

    desbloqueoBloqueoDispositivo
    comprarSmsDivice "$contadorNumerosVigentes" "$descripcionCredito"

    if [[ "$(echo "$descripcionCredito" | tr '[:upper:]' '[:lower:]')" == "vigente" ]]
    then
        mensajeSMS="Estimado socio su proxima fecha de pago de su credito es el $fechaProximoPago atte: Cooperativa USAMA R.L. que tenga buen dia."
    else
        mensajeSMS="Estimado socio su credito se encuentra en mora, favor comuniquese con el siguiente contacto: 71534345 atte. Cooperativa USAMA R.L., que tenga buen dia."
    fi

    if [[ "$contadorNumerosVigentes" -gt "0" ]]
    then
        zsh ia_envioMasivoSms.sh \
        "$idDispositivo" \
        "password" \
        "4" \
        "$listafiltradaNumerosVigentes" \
        "$mensajeSMS" \
        "$descripcionCredito" \
        "$fechaProximoPago"
    else
        echo "No existe destinatarios con fecha proxima de pago $fechaProximoPago"
    fi

    desbloqueoBloqueoDispositivo
}

# Ejecucion del programa principal
principal

