@echo off 

REM ###################################################################################################
REM # Purpose: Script que realiza un apagado remoto de PCs de la sede de SEDE01, ubicados en VLAN LAN #
REM #  		Los equipos a apagar se definen con las variables IP_RANGO IP_INICIAL y IP_FINAL. 		  #
REM #  		Se realizan 2 'pasadas' por el rango definido, y se lanza el comando SHUTDOWN	 		  #
REM # Version: 1.0 											                                          #
REM # Created Date: Wed May 17 2023 				                 		                          #
REM # Modified Date:				                 		                          				  #
REM # website: https://github.com/jopizmed/TFG_GII-E_PER5784-2022-2023		                          #
REM # Author: José Pizarro Medina			 				                                          #
REM ###################################################################################################

REM ###################################################################################################
REM #### Variables globales
SET RUTASCRIPT="C:\Program Files\NSClient++\scripts"
REM Fichero log resumen del estado
SET LOG=C:\temp\lanza_apagado_pcs_LAN_SEDE01.log
REM Fichero plano con dir. IP excluidas de Apagado
SET EXCLUSIONES="%RUTASCRIPT%\lanza_apagado_pcs_LAN_SEDE01.exc"
REM Define las ips a apagar
	REM Segmento LAN
	SET IP_RANGO=172.16.38
	SET IP_INICIAL=31
	SET IP_FINAL=254
REM Usuario con permisos elevados en PCs
SET USUADM="dominio.com\UsuarioAdmin"
SET USUADMPWD="**********"
REM Mensaje corporativo a recibir en PC encendido antes de apagado
SET MSGPC="El Equipo se va a apagar automaticamente por aplicacion de politica de ahorro de energia"
REM ###################################################################################################

:Lanza
echo. 

echo ################################################################################################################# > %LOG%
echo. >> %LOG%
echo INICIO EJECUCION %date% - %time% > %LOG%
echo. >> %LOG%

echo. >> %LOG%
echo **** Se lanza apagado de maquinas ... >> %LOG%
echo. >> %LOG%

REM Comprobar los equipos encendidos, y se lanza apagado, 1a 'Pasada'
REM Reseteo de contadores
SET /A contador_on=0
SET /A contador_off=0
SET /A contador_excluidos=0

for /l %%a in (%IP_INICIAL%,1,%IP_FINAL%) do ( 
	REM Ver si es una ip de las excluidas en fichero %EXCLUSIONES%
	FINDSTR /X /C:"%IP_RANGO%.%%a" %EXCLUSIONES%
	if errorlevel 1 (
		REM Comprueba que esté encendido haciendole ping a la IP
		ping -n 1 %IP_RANGO%.%%a |find " TTL=" >nul 
		if errorlevel 1 (
			echo %IP_RANGO%.%%a APAGADO >> %LOG%
			SET /A contador_off+=1
		) else ( 
			echo %IP_RANGO%.%%a ***** ENCENDIDO >> %LOG%
			SET /A contador_on+=1
			REM Fuerza el cierre de Outlook/Thunderbird si está el proceso remoto para evitar ficheros PRF*.TMP. en el Perfil Roaming
			%RUTASCRIPT%\pslist \\%IP_RANGO%.%%a | findstr /i "OUTLOOK" && Taskkill /S %IP_RANGO%.%%a /U %USUADM% /P %USUADMPWD% /T /FI "imagename eq OUTLOOK*" >> %LOG%
			%RUTASCRIPT%\pslist \\%IP_RANGO%.%%a | findstr /i "thunderbird" && Taskkill /S %IP_RANGO%.%%a /U %USUADM% /P %USUADMPWD% /T /FI "imagename eq thunderbird*" >> %LOG%
			REM Se lanza SHUTDOWN localmente en el equipo, usando la utilidad PSTools 'psexec', usando credenciales elevadas
			%RUTASCRIPT%\psexec -d -i -u %USUADM% -p %USUADMPWD% \\%IP_RANGO%.%%a -e -h "shutdown" -s -f -t 30 -c %MSGPC%
		)
	) else (
		echo %IP_RANGO%.%%a EXCLUIDO >> %LOG%
		SET /A contador_excluidos+=1
	)
) 

echo. >> %LOG%
echo TOTAL Equipos encendidos: %contador_on% >> %LOG%
echo TOTAL Equipos apagados: %contador_off% >> %LOG%
echo TOTAL Equipos excluidos: %contador_excluidos% >> %LOG%
echo. >> %LOG% 

REM Se otorga tiempo a que se apaguen los equipos
echo Esperamos 120 segundos a que los equipos se apaguen >> %LOG%
timeout /T 120

REM #############################################################################################################

echo. >> %LOG%
echo. >> %LOG%
echo. >> %LOG%
echo **** Se vuelve a chequear el estado de las maquinas ... >> %LOG%
echo. >> %LOG%

REM Comprobrar que todos los equipos se hayan apagado, 2a 'Pasada'
REM Reseteo de contadores
SET /A contador_on=0
SET /A contador_off=0
SET /A contador_excluidos=0

for /l %%a in (%IP_INICIAL%,1,%IP_FINAL%) do ( 
	REM Ver si es una ip de las excluidas en fichero %EXCLUSIONES%
	FINDSTR /X /C:"%IP_RANGO%.%%a" %EXCLUSIONES%
	if errorlevel 1 (
		REM Comprueba que esté encendido haciendole ping a la IP
		ping -n 1 %IP_RANGO%.%%a |find " TTL=" >nul 
		if errorlevel 1 (
			echo %IP_RANGO%.%%a APAGADO >> %LOG%
			SET /A contador_off+=1
		) else ( 
			echo %IP_RANGO%.%%a ***** ENCENDIDO >> %LOG%
			SET /A contador_on+=1
			REM Fuerza apagado 'matando winlogon' y posteriormente de nuevo 'shutdown'
			%RUTASCRIPT%\pslist \\%IP_RANGO%.%%a | findstr /i "winlogon" && Taskkill /S %IP_RANGO%.%%a /U %USUADM% /P %USUADMPWD% /IM winlogon.exe /T /F
			REM Se lanza SHUTDOWN localmente en el equipo, usando la utilidad PSTools 'psexec', usando credenciales elevadas
			%RUTASCRIPT%\psexec -d -i -u %USUADM% -p %USUADMPWD% \\%IP_RANGO%.%%a -e -h "shutdown" -s -f -t 30 -c %MSGPC%
		)
	) else (
		echo %IP_RANGO%.%%a EXCLUIDO >> %LOG%
		SET /A contador_excluidos+=1
	)
) 

echo. >> %LOG%
echo TOTAL Equipos encendidos: %contador_on% >> %LOG%
echo TOTAL Equipos apagados: %contador_off% >> %LOG%
echo TOTAL Equipos excluidos: %contador_excluidos% >> %LOG%
echo. >> %LOG%

echo. >> %LOG%
echo. >> %LOG%
echo FIN EJECUCION %date% - %time% >> %LOG%
echo. >> %LOG%

:fin
exit