#Variables de Script 
idDivice="$1"
contraseniaDispositivo="$2"
idFuncionEjecutar="$3"
archivoNumeros="$4"
mensajeSMS="$5"

#Variables Credito
descripcionCredito="$6"
fechaProximoPago="$7"

#coordenadas para el boton de envio de SIM en SMS
coordenadaXsim=0
coordenadaYsim=0

if [[ "$(echo $descripcionCredito | tr '[:upper:]' '[:lower:]')" == "vigente" ]]
then
  coordenadaXsim=242
  coordenadaYsim=1127
else
  coordenadaXsim=542 
  coordenadaYsim=1132
fi

#teclado="$6"

# Variables para contadores
declare -a numerosEnviados=()   # Lista de números enviados correctamente
declare -a numerosInvalidos=()   # Lista de números inválidos
declare -a numerosConErrores=()  # Lista de números con errores

# Contadores
contadorEnviados=0
contadorInvalidos=0
contadorErrores=0

# Variables para el nombre del reporte, fecha y hora de inicio y final del envio del sms's
nombre_archivo_reporte="reporte_sms_"
fechaHoraInicioCampania=""
fechaHoraFinalCampania=""

#
#Instrucciones de Script
#
function instruccionesScript(){
 printf "\nConsidere los siguientes parámetros para ejecutar el siguiente script\n"
 printf " 1er parámetro: Identificador del dispositivo\n\
  2do parámetro: Contraseña del dispositivo\n\
  3er parámetro: Identificador de la función a ejecutar\n\
  4to parámetro: Archivo de texto con los números a enviar\n\
  5to parámetro: Mensaje de SMS a enviar\n\
  Ej.: zsh \"$0\" 7XXXX121SSH password 4 numeros.txt 'mensaje de prueba'\n\n"
}


#
# Función para desbloquear el dispositivo
#
function desbloqueoBloqueoDispositivo(){
 if [[ "$(adb shell dumpsys power | grep "Display Power" | cut -d '=' -f 2 | tr -d '[:space:]')" == 'ON' ]]
 then
  #Boton redondo o central
  adb -s "$idDivice" shell input tap 282 1240
  sleep 3
  #Boton cuadrado o el de la derecha
  adb -s "$idDivice" shell input tap 432 1240
  sleep 2
  #Boton eliminar o borrar (Basurero)
  adb -s "$idDivice" shell input tap 353 1080
  sleep 2
  adb -s "$idDivice" shell input keyevent 26
  return 1
 else
  adb -s "$idDivice" shell input keyevent 26
  sleep 2
  adb -s "$idDivice" shell input swipe 100 900 100 100
  sleep 2
  return 0
 fi
}

#
# Función para insertar texto
#
function insertarTexto(){
    textoAlterado="${1//\/\\\\}"  # Escapar '\'
    textoAlterado="${textoAlterado//\*/\*}"   # Escapar '*'
    textoAlterado="${textoAlterado//&/\&}"   # Escapar '&'
    textoAlterado="${textoAlterado//\(/\\(}"   # Escapar '('
    textoAlterado="${textoAlterado//\)/\\)}"   # Escapar ')'
    textoAlterado="${textoAlterado// /\ }"     # Espacios en blanco
    echo "$textoAlterado"
}

#
# Función para cambiar de teclado
#
function cambiarTeclado(){
 if [[ $1 -eq 1 ]]
 then
  adb -s "$idDivice" shell ime set com.android.adbkeyboard/.AdbIME &> /dev/null
 else
  adb -s "$idDivice" shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME &>/dev/null
 fi
 printf "\nSe cambio el teclado correctamente \n\n"
}

#
# Función para verificar número
#
function verificarNumero() {
  local numero="$1"
  if [[ "$numero" =~ ^[76][0-9]{7}$ ]]; then
    return 0
  else
    #echo "El número $numero no es válido."
    return 1
  fi
}

#
# Función para enviar un SMS y mostrar confirmación
#

function enviarYConfirmar(){
  local numero="$1"
  local mensaje="$2"
  local fechaHora=$(date +"%d/%m/%Y %H:%M:%S")

  # Verificación de número antes de enviar
  if verificarNumero "$numero"; then
    
    # Comandos de ADB para enviar SMS sin salida en la terminal
    if adb -s "$idDivice" shell am start -a android.intent.action.SENDTO -d sms:"$numero" --ez exit_on_sent true > /dev/null 2>&1 && \
       sleep 3 && \
       adb -s "$idDivice" shell input tap 447 1117 > /dev/null 2>&1 && \
       sleep 3 && \
       adb -s "$idDivice" shell am broadcast -a ADB_INPUT_TEXT --es msg "$(insertarTexto "$mensaje")" > /dev/null 2>&1 && \
       sleep 2 && \
       adb -s "$idDivice" shell input tap $coordenadaXsim $coordenadaYsim && \
       #echo "Se hizo un click en las coordenadas 658 1127" estas coordenadas son cuando solo hay un chip
       sleep 2; then

      echo "\e[32m[+]\e[0m Mensaje enviado a $numero a las $fechaHora."
      numerosEnviados+=("$numero|$fechaHora")  # Añadir número y fecha/hora a la lista de enviados
      ((contadorEnviados++))
    else
      echo -e "\e[41m[-]\e[0m Error al enviar mensaje a $numero."
      numerosConErrores+=("$numero|$fechaHora")  # Añadir número y fecha/hora a la lista de errores
      ((contadorErrores++))
    fi
  else
    echo "\e[41m[-]\e[0m El número $numero no es válido, se omitirá."
    numerosInvalidos+=("$numero|$fechaHora")  # Añadir número inválido con fecha/hora
    ((contadorInvalidos++))
  fi
}

#
# Función para recorrer un archivo y enviar SMS
#
function enviarMensajesDesdeArchivo(){
  if [[ -f "$archivoNumeros" ]]; then
    if [[ -f "$archivoNumeros" ]]; then
        numeros=($(cat "$archivoNumeros"))  # Leer todo el archivo en un array
        for numero in "${numeros[@]}"; do
            enviarYConfirmar "$numero" "$mensajeSMS"
        done
    else
        echo "El archivo $archivoNumeros no existe."
    fi
  else
    echo "El archivo $archivoNumeros no existe."
  fi
}

#
# Función para generar un reporte de los mensajes enviados
#

function generarReporte(){
  local archivoReporte="${1:-reporte_envio_sms.txt}"  # Archivo de reporte predeterminado si no se especifica uno
  {
    echo "================= REPORTE DE ENVÍO DE SMS ================="
    echo "Fecha de generación del reporte: $fechaHoraFinalCampania"
    echo
    echo "Mensajes enviados correctamente:"
    for registro in "${numerosEnviados[@]}"; do
      IFS='|' read -r numero fechaHora <<< "$registro"
      echo " - Número: $numero, Enviado el: $fechaHora"
    done
    echo
    echo "Números inválidos detectados:"
    for registro in "${numerosInvalidos[@]}"; do
      IFS='|' read -r numero fechaHora <<< "$registro"
      echo " - Número: $numero, Detectado como inválido el: $fechaHora"
    done
    echo
    echo "Errores al enviar mensajes:"
    for registro in "${numerosConErrores[@]}"; do
      IFS='|' read -r numero fechaHora <<< "$registro"
      echo " - Número: $numero, Error el: $fechaHora"
    done
    echo
    echo "=========================== RESUMEN ============================="
    echo "Fecha y Hora de Finalización de la Campania: $fechaHoraFinalCampania"
    echo "Total de mensajes enviados: $contadorEnviados"
    echo "Total de números inválidos: $contadorInvalidos"
    echo "Total de errores al enviar mensajes: $contadorErrores"
    echo "Estado de los Creditos: $descripcionCredito"
    echo "Fecha Proxima de Pago de los Creditos: $fechaProximoPago"
    echo "================================================================="
  } > "$archivoReporte"  # Redirigir toda la salida al archivo de reporte

  echo "Reporte generado y guardado en: $archivoReporte"
}

#
# Envio de Correo de Confirmcion
#
function enviarCorreoDeConfirmacion(){
  #-s "¡Reporte de la Campania ${2:0:9} culminada con exito!" \
  echo -e "Estimados,\nNos complace informarte que el envío de SMS ha finalizado con éxito.\n\n A continuación, te compartimos un breve resumen del envio:\n\n $(cat $1 | tail -n 8)\n\nGracias por confiar en nuestro servicio.\nPara más detalles sobre este envío o cualquier consulta adicional, no dudes en ponerte en contacto con nosotros.\n\nTe agradecemos tu confianza y esperamos continuar apoyándote en el futuro.\n\n¡Que tengas un excelente día!" | mutt \
  -s "¡Reporte de la Campania $descripcionCredito con fecha proxima de pago $fechaProximoPago culminada con exito!" \
  -a "$1" -- \
  mm.helio009@gmail.com xmendoza@cooperativausama.com.bo wbaina@cooperativausama.com.bo fquisbert@cooperativausama.com.bo
}


#
# Funcion para borrar todo y bloquear el telefono
#
function bloquearDispositivo(){
}


#
# Función Principal
#
function funcionPrincipal(){
 #instruccionesScript

 if [[ $idFuncionEjecutar -eq 1 ]]; then
    desbloqueoDispositivo
    cambiarTeclado 1
 elif [[ $idFuncionEjecutar -eq 2 ]]; then
    insertarTexto "Prueba"
 elif [[ $idFuncionEjecutar -eq 3 ]]; then
    enviarSMS "77633453" "CLC-ASFI Te invita a participar en la Encuesta ENSF 2021 del 22/Nov al 22/Dic Haz clic en: https://encuesta2021.asfi.gob.bo (Tu respuesta es confidencial)"
 elif [[ $idFuncionEjecutar -eq 4 ]]; then
     #desbloqueoBloqueoDispositivo
    #  if [[ "$?" -eq 0 ]]
    #  then 
        printf "================= Empezando la Campania ========================\n\n"
        sleep 2
        cambiarTeclado 1 #Se cambia el teclado a ADBKeyBoard
        sleep 2
        nombre_archivo_reporte="reporteSmsEnviado$(date +"%d%m%Y_%H%M%S").txt"
        fechaHoraInicioCampania="$(date +"%d/%m/%Y %H:%M")"
        enviarMensajesDesdeArchivo
        fechaHoraFinalCampania="$(date +"%d/%m/%Y %H:%M")"
        sleep 3
        generarReporte "$nombre_archivo_reporte"
        sleep 10
        enviarCorreoDeConfirmacion "$nombre_archivo_reporte" "$fechaHoraInicioCampania" "$fechaHoraFinalCampania"
        sleep 10
        cambiarTeclado 0 #Se cambia el teclado a Gboard
        # desbloqueoBloqueoDispositivo
      # else
      #   echo -e "********Se bloqueo el Celular***********"
      # fi
 else
    verificarNumero "+59177211717"
 fi
}

funcionPrincipal
