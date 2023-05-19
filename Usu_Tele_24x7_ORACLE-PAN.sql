REM
REM    Extrae de Inventario del Usuario en PAN
REM     si tiene Autorizado Teletrabajo 24x7
REM

SET PAGESIZE 0
SET VERIFY OFF
SET LINESIZE 500
SET SERVEROUTPUT ON size 1000000
SET TRIMSPOOL ON
SET TRIMOUT ON

spool Usu_Tele_24x7.lst

SELECT SUM(A.VALUEINT)
FROM panv3_inventory.VIEWALLCUSTOMFIELDVALUES A, panv3_inventory.VIEWUSERS B
WHERE A.TYPE = 7 -- Campos Personalizados de Inventario Usuarios
and A.PANCUSTOMFIELDS_ID = '38075490-d5a4-4e4a-83c5-b4f8905a6df5' -- CustomField '24x7'
and A.PANELEMENTS_ID = B.ID
and B.USERNAME = '&1' -- Username de Inventario
and B.INACTIVE <> 1 -- Usuarios Habilitados en Inventario
/
spool off

exit
