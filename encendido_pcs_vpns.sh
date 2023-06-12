#!/bin/sh

###########################################################################################
#
# Purpose: Lanza encendido remoto por Wake on Lan de los usuarios conectados por VPN SSL
# Version:1.0
# Created Date: Wed May 17 2023
# Modified Date:
# website: https://github.com/jopizmed/TFG_GII-E_PER5784-2022-2023
# Author: Jose Pizarro Medina
#
###########################################################################################

#### Variables globales
# Firewall a consultar VPN SSL
FIREWALL="FWNAME"
RUTA="/root/bin"
NOMBRE_SCRIPT="encendido_pcs_vpns"
FICHANT="$RUTA/${NOMBRE_SCRIPT}.txt"
FICHDES="$RUTA/${NOMBRE_SCRIPT}.txt.new"
SALFILE="$RUTA/${NOMBRE_SCRIPT}.tmp"
HORAFICH="$RUTA/${NOMBRE_SCRIPT}.hor"
HORAFICHANT="$RUTA/${NOMBRE_SCRIPT}.horant"
FICHGLOBAL="$RUTA/${NOMBRE_SCRIPT}.global"
USUARIOS_CONECTADOS=0
USUARIOS_PROCESADOS=0
DEBUG=0
ERROR_WOL=0
# Establecer horario de Teletrabajo
HORA_INICIO_TELETRABAJO=7
MINUTO_INICIO_TELETRABAJO=30
HORA_FINAL_TELETRABAJO=19

#### Variables necesarias para lanzar script Oracle
####	requiere instalación Oracle InstantClient
####	por ejemplo v.18.5 (ver Anexo)
export ORACLE_HOME=/usr/lib/oracle/18.5/client64
export TNS_ADMIN=/usr/lib/oracle/18.5/client64
export SQLPATH=/usr/lib/oracle/18.5/client64/bin
export LD_LIBRARY_PATH="$ORACLE_HOME/lib"
export PATH="$ORACLE_HOME/bin:$PATH"


##############################################################################################
# Funcion que devuelve 1 si es horario extendido 24x7 y 0 si es horario normal de teletrabajo
##############################################################################################
function es_24x7() {

FECHA_HORA=`date +%H`
FECHA_DSEM=`date +%w`

# Si es sabado o domingo ...
if [ $FECHA_DSEM -eq 6 ] || [ $FECHA_DSEM -eq 0 ];
then
        echo 1
else
	# Comprobamos si el horario es el permitido o extendido
        if [ $FECHA_HORA -lt $HORA_INICIO_TELETRABAJO ] || [ $FECHA_HORA -gt $HORA_FINAL_TELETRABAJO ];
        then
                echo 1 
        else
                echo 0
        fi
fi
}

#########################################################################################################
# Funcion que devuelve 1 si es el inicio de horario de teletrabajo entre lunes y viernes y 0 si no lo es
#########################################################################################################
function es_hora_inicio() {

FECHA_HORA=`date +%H`
FECHA_MIN=`date +%M`
FECHA_DSEM=`date +%w`

if [ $FECHA_DSEM -ge 1 ] && [ $FECHA_DSEM -le 5 ] && [ $FECHA_HORA -eq $HORA_INICIO_TELETRABAJO ] && [ $FECHA_MIN -eq $MINUTO_INICIO_TELETRABAJO ];
then
	echo 1
else
	echo 0
fi

}

##############################################################################################################
# Funcion que recibe usuario como parametro y devuelve 1 si tiene autorizado horario extendido 24x7 y 0 si no
##############################################################################################################
function permitido_24x7() {
	# Pasamos variable que recibimos con usuario a la variable 'user'
	user=$1

	# Lanzar script SQL para saber si el usuario tiene autorizado el acceso extendido 24x7 (ORACLESID definido en TNSNAMES.ora)
	usuario_24x7=`$SQLPATH/sqlplus -S -L usuarioOracle/*******@ORACLESID @$RUTA/Usu_Tele_24x7.sql $user`
	if [ "$usuario_24x7" == "" ]; then
		echo 0
	elif [ $usuario_24x7 -ge 1 ]; then
		echo 1
	else
		echo 0
	fi
}
##############################################################################################################

####################################################################################
# Funcion que recibe usuario como parametro y lanzar encendido de sus PC habituales
####################################################################################
function lanza_encendido() {

	# Pasamos variable que recibimos con usuario a la variable 'user'
	user=$1
	# Registrar la conexion del usuario en el fichero de conexiones horaria
	echo "`date +"%d/%m/%Y %H:%M"` - $user" >> $HORAFICH
	# Lanzar script SQL para obtener variable con los PCs habituales de ese usuario (ORACLESID definido en TNSNAMES.ora)
	datospc=`$SQLPATH/sqlplus -S -L usuarioOracle/*******@ORACLESID @$RUTA/PC_hab_MACs_ORACLE-PAN.sql $user`
	# Limpiamos nombres de espacios para ver si ha devuelvo que no ha encontrado filas
	datospc_nospaces="$(echo -e "${datospc}" | tr -d '[:space:]')"
	# Si el usuario no tiene datos de PCs habituales, no lo procesamos y terminamos ejecucion de la funcion
	if [ "$datospc_nospaces" == "norowsselected" ]; then
		return
	fi
	# Establacer el salto de linea como separador de las distintas lineas con los datos de los pcs
	IFS=$'\n'
	# Recorrer cada linea, que contiene un PC habitual
	for linea in $datospc
	do
		# Separar datos de la linea, el nombre del PC, sus MACs, sus IPs, y su sede
		pc=`echo $linea | cut -d',' -f1`
		macs=`echo $linea | cut -d',' -f2`
		ips=`echo $linea | cut -d',' -f3`
		sede=`echo $linea | cut -d',' -f4`
		echo "DETECTADO": $user - $pc - $macs - $sede
		# Lanzar PING al nombre del PC para ver si ya esta arrancado
		ping -c 2 -q $pc
		# Si no responde a PING, en funcion de su Sede, establecemos el servidor Remoto en VLAN LAN correspondiente	
		# 	indicar en el 'case' tantas opciones como servidores Remotos haya, con el Hostname de este
		if [ $? -ne 0 ]; then
			case $sede in
			SEDE01)
				servidor="hostnameSEDE01.dominio.com"
				;;
			SEDE02)
				servidor="hostnameSEDE02.dominio.com"
				;;
			SEDE03)
				servidor="hostnameSEDE03.dominio.com"
				;;
			SEDE04)
				servidor="hostnameSEDE04.dominio.com"
				;;
			esac
			# Establecemos ; como separador para las distintas MACs
			IFS=$';'
			# Recorremos las MACs del PC
			for mac in $macs
			do
				echo $user - $pc - $mac - $sede
				# Establecemos formato correcto de MAC con XX:XX:XX:XX:XX:XX
				mac=`echo $mac | sed -e 's/\([0-9A-Fa-f]\{2\}\)/\1:/g' -e 's/\(.*\):$/\1/'`
				# Llamamos al servidor Remoto de su sede con la MAC para que le lance encendido
				/usr/local/nagios/libexec/check_nrpe -H $servidor -t 60 -c check_wol_pc -a $user $pc $mac
                # Si hay fallos en la llamada activamos flag para luego enviar aviso
                if [ $? -ne 0 ]; then
                    ERROR_WOL=1
                fi
				echo
			done	
			# Volvemos a establece el salto de linea para las distintas lienas con los datos de los pcs
			IFS=$'\n'
		fi
	done
}
####################################################################################

############
### MAIN ###
############
# Comprobar si ya esta el mismo script ejecutandose antes de continuar, si es asi se finaliza y se envia correo con 'mailx'
for pid in $(pidof -x ${NOMBRE_SCRIPT}.sh ); do
    if [ $pid != $$ ]; then
	echo "### ATENCION ###"
        echo "[$(date)] : EL SCRIPT YA ESTA CORRIENDO, REVISAR POSIBLES ERRORES DE EJECUCION"
	echo "################"
 	echo "Se ha detectado que el script ya estaba ejecutandose, es necesario revisar si ha tardado demasiado tiempo en ejecutarse por alguna razon." | mailx -s "Error: script de encendido Wol ya ejecutadose `date +"%d/%m/%Y %H:%M"`" -r "hostnameServidorCentral@dominio.com" AVISOS@dominio.com	
        exit 1
    fi
done

echo "------------------------------------------------------------------------------------"
echo "INICIANDO EJECUCION: `date`"

# Comprobar si el horario es extendido 24x7 o es horario normal de teletrabajo y si es el inicio de la jornada de teletrabajo
horario_24x7=$(es_24x7)
horario_inicio=$(es_hora_inicio)

# Si el fichero con usuarios conetados anteriormente no existe, se crea
if [ ! -f $FICHANT ]; then
	touch $FICHANT
fi

# Usando llamadas RANCID, se obtiene listado de usuarios conectados por VPN SSL
/usr/local/rancid/bin/hlogin -c "execute vpn sslvpn list tunnel;exit" -f /usr/local/rancid/.cloginrc $FIREWALL > $SALFILE

# Establecer salto de linea como separador de las distintas lineas de la salida
IFS=$'\n'

# Establecer patrones para detectar inicio y fin de listado de usuarios en la salida de llamada a RANCID
regexp="(.*)Index(.*)"
regexpfin="FWNAME. # exit"

# Recorrer las lineas de salida que obtenemos de las conexiones VPN SSL
while read i
do
 	# Buscamos la linea que significa que a continuacion viene el listado de usuarios conectados
 	if [[ $i =~ $regexp ]]; then
 		read i
 		# Recorremos las lineas de los usuarios hasta marca de fin de listado
 		until [[ $i =~ $regexpfin ]]
 		do
 			usuario=`echo $i | cut -d$'\t' -f2`
 			usuario="$(echo -e "${usuario}" | tr -d '[:space:]')"
			# Si el usuario no es vacio, revisar si estaba conectado antes
 			if [ "$usuario" != "" ]; then
				# Si el Debug esta activado, mostrar conexion de todos los usuarios, se traten o no
				if [ $DEBUG -eq 1 ]; then
					echo "---- DEBUG Usuario conectado: $usuario"
				fi
				# Sumo 1 a contador de usuarios conectados
				USUARIOS_CONECTADOS=$(($USUARIOS_CONECTADOS+1))
 				# Comprobar si el usuario ya estaba conectado el minuto anterior
				CONECTADO=`grep -e "^${usuario}$" $FICHANT | wc -l`
				# Si es la hora de inicio de jornada de L a V, se lanza encendido
				if [ $horario_inicio -eq 1 ]; then
					USUARIOS_PROCESADOS=$(($USUARIOS_PROCESADOS+1))
                    echo ">>>> " `date +%a" "%d/%m/%Y" "%H:%M` " Lanzando encendido inicio jornada $usuario"
                    lanza_encendido "$usuario"
				else
					# Si se acaba de conectar, hay que revisar el horario 
 					if [ $CONECTADO -eq 0 ]; then
						# Si el horario es normal de teletrabajo, llamar encendido equipos
						if [ $horario_24x7 -eq 0 ]; then
							USUARIOS_PROCESADOS=$(($USUARIOS_PROCESADOS+1))
 							echo ">>>> " `date +%a" "%d/%m/%Y" "%H:%M` " Lanzando encendido $usuario"
 							lanza_encendido "$usuario"
						# Si es horario extendido 24x7, comprobar si esta autorizado
						else
							# Llamar a funcion para saber si tiene autorizado 24x7
							usuario_24x7=$(permitido_24x7 "$usuario")
							if [ $usuario_24x7 -eq 1 ]; then
								USUARIOS_PROCESADOS=$(($USUARIOS_PROCESADOS+1))
                                echo ">>>> " `date +%a" "%d/%m/%Y" "%H:%M` " Lanzando encendido 24x7 $usuario"
                                lanza_encendido "$usuario"
							else
								echo ">>>> " `date +%a" "%d/%m/%Y" "%H:%M` " Usuario $usuario no tiene permitido 24x7"
							fi
						fi
					fi
 				fi
 				# Escribir usuario para el nuevo fichero de usuarios ya conectados
 				echo $usuario >> $FICHDES
				# Buscar usuario en fichero global, si nunca se ha conectado se añade
				GLOBAL=`grep -e "^${usuario}$" $FICHGLOBAL | wc -l`
				if [ $GLOBAL -eq 0 ]; then
					echo $usuario >> $FICHGLOBAL
				fi			
 			fi
 			read i
 		done
 		break
 	fi
done < $SALFILE

# Borrar fichero que se ha usado temporalmente para almacenar la salida del comando RANCID
rm $SALFILE
# Renombrar el fichero con los usuarios conectados para la proxima ejecucion
mv $FICHDES $FICHANT

FECHA_HORA=`date +%M`
if [ "$FECHA_HORA" == "00" ]; then
 	if [ -f $HORAFICH ]; then
		# Se cambia el nombre al fichero horario para almacenarlo como de la hora anterior, para que lo tome el informe
		cp $HORAFICH $HORAFICHANT
		rm $HORAFICH
 	fi
fi

# Se muestra resumen de usuarios conectados y procesados
echo
echo "----- RESUMEN DE EJECUCION -----"
echo "USUARIOS CONECTADOS: $USUARIOS_CONECTADOS"
echo "USUARIOS PROCESADOS: $USUARIOS_PROCESADOS"
echo
echo "FIN DE EJECUCIOM: `date`"
echo "--------------------------------"
############
