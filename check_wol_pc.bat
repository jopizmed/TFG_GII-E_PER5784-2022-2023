@echo off
CD "C:\Program Files\NSClient++\scripts"
echo. >> c:\temp\wol.txt
echo [%date%, %time%] >> c:\temp\wol.txt
echo "Lanzando encendido WoL del PC %2 del usuario %1 con MAC %3" >> c:\temp\wol.txt
wol.exe %3 >> c:\temp\wol.txt