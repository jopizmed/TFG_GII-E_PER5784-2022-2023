set @1 = 'Pepe'

SELECT DISTINCT CONCAT(h.NAME, ',', n.MACADDR, ',', n.IPADDRESS)
FROM hardware h, networks n
WHERE h.WINOWNER like '@1'  -- Filtra por Usuario
and h.id = n.HARDWARE_ID  -- Enlaza el Computer con las Networks en Inventario
and UPPER(h.NAME) not like 'CHG%'  -- Excluye por Hostname a demanda
and n.TYPEMIB like 'ethernet%'  -- Filtra los interfaces físicos
and h.LASTDATE > TO_DAYS(NOW())-180  -- Filtra por equipo Inventariado los últimos 6meses
/