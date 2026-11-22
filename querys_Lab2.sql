--indices tablas 
SELECT table_name, index_name, index_type, uniqueness, status
FROM user_indexes
WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS')
ORDER BY table_name, index_name;

-- Consultar estado de las restricciones en las tablas EMPLOYEES y DEPARTMENT

SELECT table_name, constraint_name, constraint_type, status
FROM user_constraints
WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS')
ORDER BY table_name, constraint_type, constraint_name;

---- desactivar restricciones :

-- Desactivar claves foráneas primero
BEGIN
  FOR r IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS')
      AND constraint_type = 'R'
      AND status = 'ENABLED'
  ) LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE ' || r.table_name || ' DISABLE CONSTRAINT ' || r.constraint_name;
  END LOOP;
END;
/

-- Desactivar las demás restricciones (llaves Key, Unique, Check)
BEGIN
  FOR r IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS')
      AND constraint_type IN ('P', 'U', 'C')
      AND status = 'ENABLED'
  ) LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE ' || r.table_name || ' DISABLE CONSTRAINT ' || r.constraint_name;
  END LOOP;
END;
/


-- desactivar restricciones con CASCADE para desactivar DEPT_ID_PK
BEGIN
  FOR r IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS')
      AND constraint_type IN ('P', 'U', 'C')
      AND status = 'ENABLED'
  ) LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE ' || r.table_name || ' DISABLE CONSTRAINT ' || r.constraint_name || ' CASCADE';
  END LOOP;
END;
/


--Insertar tuplas en ambas tablas que no cumplan restricciones establecidas
-- 1. En DEPARTMENTS: usamos un department_id nuevo  998 que no duplica la PK,
-- pero ponemos location_id = 9997 (que no existe en LOCATIONS) o department_name NULL si no tiene NN activa
INSERT INTO departments (department_id, department_name, manager_id, location_id)
VALUES (998, 'Depto Prueba FK Invalidal', 202, 9997);

-- 2. En EMPLOYEES: usamos un employee_id nuevo:  997 y email único (ej. 'CPRUEBA2'),
-- pero ponemos salary negativo (-450) y department_id inexistente (9997)
INSERT INTO employees (
  employee_id, first_name, last_name, email, phone_number,
  hire_date, job_id, salary, commission_pct, manager_id, department_id
)
VALUES (
  997, 'Carol', 'Pru', 'CPRUEBA2', '553.123.4567',
  SYSDATE, 'IT_PROGRA', -450, NULL, 102, 9997
);

COMMIT;


--- Activar nuevamente las restricciones 


        --  Limpia los registros inválidos de prueba
DELETE FROM employees WHERE employee_id = 100 AND last_name = 'Prueba';
DELETE FROM departments WHERE department_id = 10 AND department_name = 'Depto Prueba Duplicado';
COMMIT;

        --  Habilitar restricciones no foráneas (P, U, C)
BEGIN
  FOR r IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS')
      AND constraint_type IN ('P', 'U', 'C')
      AND status = 'DISABLED'
  ) LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE ' || r.table_name || ' ENABLE CONSTRAINT ' || r.constraint_name;
  END LOOP;
END;
/

        --  Habilitar claves foráneas (R)
BEGIN
  FOR r IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS')
      AND constraint_type = 'R'
      AND status = 'DISABLED'
  ) LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE ' || r.table_name || ' ENABLE CONSTRAINT ' || r.constraint_name;
  END LOOP;
END;
/


----- PARTE 2--------

-- crear duplicado llamado DEPARTMENTS2 ----
CREATE TABLE departments2 AS
SELECT * FROM departments;

-- Insertar las 3 tuplas en DEPARTMENTS2

INSERT INTO departments2 (department_id, department_name, manager_id, location_id)
VALUES (300, 'Innovacion', 100, 1700);

INSERT INTO departments2 (department_id, department_name, manager_id, location_id)
VALUES (310, 'Calidad', 100, 1700);

INSERT INTO departments2 (department_id, department_name, manager_id, location_id)
VALUES (320, 'Soporte Tecnico', 100, 1700);

--- CONSULTAR TABLA DEPARTMENT2

SELECT * FROM departments2 ORDER BY department_id;


-----------------------------------------------------------------------------------------------------
--- bloque anónimo que indica el comienzo y finalización de una transacción sobre la tabla DEPARTMENTS2.

SET SERVEROUTPUT ON;

BEGIN
  DBMS_OUTPUT.PUT_LINE('--- INICIO DE TRANSACCION sobre DEPARTMENTS2 ---');

  INSERT INTO departments2 (department_id, department_name, manager_id, location_id)
  VALUES (330, 'Auditoria Interna', 100, 1700);

  UPDATE departments2
  SET department_name = 'Investigacion e Innovacion'
  WHERE department_id = 300;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('--- FIN DE TRANSACCION (COMMIT ejecutado) ---');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('--- FIN DE TRANSACCION con ROLLBACK por error: ' || SQLERRM || ' ---');
    RAISE;
END;
/


---------------------------------------------------------------------------------------------------
-----PARTE 3 PREGUNTAS

 	-- deshacer una transacción en Oracle  ejemplo práctico
    
    -- 1. Iniciamos cambios sobre DEPARTMENTS2
INSERT INTO departments2 (department_id, department_name, manager_id, location_id)
VALUES (999, 'Departamento Error', 100, 1700);

SAVEPOINT punto_seguro;

DELETE FROM departments2
WHERE department_id = 310;

-- borramos por error el departamento 310, pero queremos conservar el 999:
ROLLBACK TO punto_seguro;

-- Si queremos deshacer TODO lo hecho en la transacción actual:
ROLLBACK;

-- Verificamos que la tabla volvió a su estado anterior
SELECT * FROM departments2 WHERE department_id IN (310, 999);
    
 ---------------------------------------------------------------------------------------
    
    -- ejemplo de implementación REDO para consultar la configuración actual de la base de datos 
    
    -- Consultar el modo de archivado  y estado de FORCE LOGGING
SELECT log_mode, force_logging FROM v$database;

-- Ver los grupos y rutas de los archivos de Redo Log en línea
SELECT l.group#, l.thread#, l.sequence#, l.bytes/1024/1024 AS size_mb,
       l.status, lf.member
FROM v$log l
JOIN v$logfile lf ON l.group# = lf.group#
ORDER BY l.group#, lf.member;