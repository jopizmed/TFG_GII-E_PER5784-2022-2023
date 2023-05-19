REM
REM    Saca un listado de MACs y Loc del PC Habitual
REM     del Usuario dado como parametro
REM

SET PAGESIZE 0
SET VERIFY OFF
SET LINESIZE 500
SET SERVEROUTPUT ON size 1000000
SET TRIMSPOOL ON
SET TRIMOUT ON

spool PC_hab_MACs.lst

SELECT TRIM(networkhostname) || ',' || TRIM(listmacs) || ',' || TRIM(listips) || ',' || TRIM(substr(locationpath,instr(l
ocationpath,'/LOC',1)+1,9)) LOC
FROM panv3_inventory.viewallcomputers
WHERE (USERNAMEHABITUAL like 'dominio.com\&1' OR USERNAMERESPONSABLE like 'dominio.com\&1')
and OSROL = 0
--and UPPER(NETWORKHOSTNAME) not like 'PO%'
-- and UPPER(NETWORKHOSTNAME) not like 'xxx%'
and CLIENTLASTAUDITDATE > SYSDATE-180
/
spool off

exit
