# Instrucciones persistentes del proyecto

Estas reglas aplican a toda tarea nueva o retomada dentro de este repositorio.

1. Antes de analizar, editar, probar o desplegar, leer completo
   `PROJECT_MEMORY.md`.
2. Revisar `git status` antes de modificar archivos. El arbol puede contener
   cambios de Jeff o de sesiones anteriores; no descartarlos ni sobrescribirlos.
3. Usar `PROJECT_MEMORY.md` como memoria operativa, pero verificar en el codigo
   cualquier dato que pueda haber cambiado. Si codigo y memoria difieren,
   corregir la memoria en la misma tarea.
4. Al terminar cualquier cambio funcional, tecnico, de configuracion,
   infraestructura o despliegue, actualizar `PROJECT_MEMORY.md`:
   - fecha;
   - solicitud y resultado;
   - archivos relevantes;
   - pruebas y builds ejecutados;
   - despliegues realizados;
   - decisiones y pendientes.
5. Registrar tambien hallazgos importantes aunque no requieran cambiar codigo.
6. Nunca escribir secretos, PIN, contrasenas, tokens, claves privadas ni cuentas
   de servicio en la memoria o en Git.
7. Mantener las entradas nuevas concisas y conservar el historial anterior.
8. El proyecto activo es la aplicacion Flutter de `ee_flutter/`. Las carpetas
   `app/` y `web/` de la raiz son implementaciones historicas y no deben
   reemplazar Flutter salvo peticion expresa.
