# Seguridad y roles

## Roles

- operator: crea registros, consulta mantenimientos y actualiza su seguimiento.
- provider: solo entra al modulo de trampas; crea registros y edita unicamente
  los propios. Puede consultar/exportar registros propios y los de su empresa.
  El acceso vence por `credentialExpiresAt`, validado por reglas de Firestore.
- admin: lectura global para dashboard y autorizacion de revisiones.

El registro publico esta deshabilitado. Las cuentas se provisionan por invitacion
con Firebase Admin SDK; cuentas autenticadas sin perfil/rol asignado no acceden a
modulos. `companyId` define el grupo de lectura y no otorga permiso de edicion.

## PIN y cedula

- PIN solo viaja por HTTPS hacia Firebase Authentication.
- Firebase Authentication almacena la credencial protegida.
- Cedula como texto para conservar ceros.
- PIN no se guarda en SharedPreferences, Firestore cliente ni logs.

La credencial tecnica se deriva de cedula+PIN dentro de la app para usar el
proveedor correo/contrasena en Spark. Por tratarse de un PIN corto, no equivale
a una contrasena corporativa de alta seguridad.

El campo historico operatorPin se limpia localmente al leer. El script remoto es
simulacion por defecto y requiere respaldo mas --apply.

## Sesion

Firebase Auth conserva la sesion en Android/web. El usuario puede cerrar sesion
o cambiar de usuario. El dashboard usa cookie firmada, HttpOnly, SameSite=Lax
y Secure en produccion, y revalida el rol admin en Firestore.

## Reglas

- Escritura solo autenticada.
- createdByUid y updatedByUid deben coincidir con auth.uid.
- Timestamps de servidor deben coincidir con request.time.
- Operador lee sus registros energeticos. Los reportes de fugas y tuberia son
  visibles a todos los operadores autenticados para el flujo de mantenimiento.
- Los levantamientos de bombas son visibles a usuarios autenticados para poder
  escoger una linea base en registros de mejora y verificacion.
- Admin puede leer globalmente.
- Cliente no borra registros criticos. En fugas y tuberia solo puede actualizar
  estado de OT, trabajo ejecutado y campos de auditoria asociados.
- user_private_credentials nunca es legible por cliente.
- audit_logs solo es legible por admin y escrito por backend.
- operatorPin esta prohibido en lecturas nuevas.

Las reglas tienen pruebas con Firebase Emulator Suite.

En `steam_trap_records`, proveedores leen por `ownerUid`, `companyId` o una
comparticion DEMO explicita; editar sigue limitado al propietario. Internos
autorizados conservan su acceso y admin puede leer globalmente. El TAG, ID,
propietario, empresa, marca DEMO y fecha de creacion son inmutables para el
cliente. Solo admin puede corregir la seccion dejando historial. Ningun cliente
puede borrar registros o alterar consecutivos fuera de incrementos unitarios.

## Secretos

Variables/secretos:

- FIREBASE_WEB_API_KEY para login del dashboard contra Firebase Auth.
- DASHBOARD_SESSION_SECRET.
- GOOGLE_APPLICATION_CREDENTIALS solo para dashboard/scripts.
- FIREBASE_PROJECT_ID.

No se versionan .env, cuentas de servicio ni claves privadas. Firebase client
API keys y google-services.json identifican la app, pero no sustituyen reglas.

## Cloudinary

El preset unsigned no contiene una clave privada, pero debe configurarse en
Cloudinary con restricciones de formato, tamano y carpeta. El cliente registra
provider=cloudinary, URL segura y public ID.

Cloudinary conserva actualmente activos publicos con URL HTTPS. Firestore evita
que un proveedor descubra URLs de otro proveedor, pero una URL ya conocida no
queda protegida por reglas de Firebase. Para control estricto de descarga se
requieren activos autenticados y URLs firmadas por un backend que mantenga el
API secret fuera del cliente. Esto no requiere migrar de proveedor.

Los ejemplos DEMO usan las mismas dos imagenes genericas (cercana y general)
para todos los registros; se identifican como demostracion y se comparten por
UID explicito, sin mezclarlos con registros reales de las empresas.
