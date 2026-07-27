# Dashboard de eficiencia energetica

Dashboard independiente de la aplicacion Flutter. Usa FastAPI, Jinja2,
Plotly.js y Firebase Admin exclusivamente en el servidor.

## Seguridad

- Acceso solo para usuarios activos con rol admin.
- Cedula y PIN se validan contra Firebase Authentication mediante su API REST.
- El dashboard revalida que el perfil Firestore tenga rol admin y este activo.
- La sesion usa cookie firmada, HttpOnly y SameSite=Lax.
- La cuenta de servicio y los secretos se cargan por entorno.
- Nunca colocar JSON de cuenta de servicio ni secretos en Git.

## Ejecucion local

1. Crear un entorno virtual.
2. Instalar requirements.txt.
3. Crear .env a partir de .env.example.
4. Configurar GOOGLE_APPLICATION_CREDENTIALS.
5. Ejecutar:

    uvicorn app.main:app --reload --port 8080

Abrir http://127.0.0.1:8080.

Para desarrollo HTTP local, SESSION_COOKIE_SECURE debe ser false. En despliegue
HTTPS debe permanecer true.

## Docker

    docker build -t ee-dashboard .
    docker run --rm -p 8080:8080 --env-file .env \
      -v /ruta/segura/service-account.json:/run/secrets/firebase-service-account.json:ro \
      ee-dashboard

## Consultas

Las consultas se limitan por rango temporal y se leen en lotes paginados. El
limite maximo se controla con DASHBOARD_QUERY_LIMIT. Los documentos historicos
con fecha ISO y los nuevos con Timestamp se consultan por separado y se
deduplican por ID.

Las lecturas acumuladas de calderas nunca se suman. Se usan consumos de
intervalo almacenados o deltas positivos validados; reinicios y negativos se
marcan como faltantes.

## Pruebas

    pytest

Las pruebas cubren autenticacion de sesion, mapeo de credenciales, deltas acumulados, reinicios
de medidor y separacion entre kW y kWh.
