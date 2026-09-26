# MXGuide Backend

API REST para **MXGuide**, la app de guía turística de México. Construida
con **NestJS + Prisma + PostgreSQL (extensión PostGIS)**. Expone lugares
turísticos, categorías, estados, favoritos, reseñas y autenticación con
roles (`user` / `admin`), pensada para que el front (Flutter) consuma todo
vía JSON.

---

## Índice

1. [Stack](#stack)
2. [Cómo levantarlo en local](#cómo-levantarlo-en-local)
3. [Variables de entorno](#variables-de-entorno)
4. [Arquitectura y estructura de carpetas](#arquitectura-y-estructura-de-carpetas)
5. [Modelo de datos](#modelo-de-datos)
6. [Autenticación y roles](#autenticación-y-roles)
7. [Referencia de Endpoints](#referencia-de-endpoints)
8. [Seguridad](#seguridad)
9. [Nota sobre PostGIS](#nota-sobre-postgis)
10. [Pendientes del equipo](#pendientes-del-equipo)

---

## Stack

- **NestJS 10** (Node + TypeScript)
- **Prisma 5** como ORM, con **PostgreSQL** + extensión **PostGIS** (búsquedas por cercanía)
- **JWT** (`@nestjs/jwt` + `passport-jwt`) para autenticación
- **Cloudinary** para almacenamiento de imágenes
- **class-validator / class-transformer** para validar el body de cada request
- **Helmet** + **@nestjs/throttler** (rate limiting) para seguridad básica

---

## Cómo levantarlo en local

1. Tener PostgreSQL corriendo con la extensión PostGIS disponible (local,
   Docker, o un proveedor tipo Supabase/Neon con PostGIS habilitado).
2. Copiar las variables de entorno y llenarlas:
   ```bash
   cp .env.example .env
   ```
3. Instalar dependencias:
   ```bash
   npm install
   ```
4. Habilitar PostGIS en la base (una sola vez):
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   ```
5. Generar el cliente de Prisma y correr las migraciones:
   ```bash
   npx prisma generate
   npx prisma migrate dev --name init
   ```
6. Cargar la curaduría inicial (estados, categorías y lugares de ejemplo, incluyendo las ciudades más importantes de México):
   ```bash
   npx prisma db seed
   ```
7. Levantar el servidor en modo desarrollo:
   ```bash
   npm run start:dev
   ```
   Queda escuchando en `http://localhost:3000` (sin prefijo `/api`, las rutas van directo: `http://localhost:3000/auth/login`).

Para probar los endpoints usa **Thunder Client** (extensión de VS Code) o Postman — el navegador solo sirve para los `GET` públicos, no para `POST`/`PATCH`/`DELETE`.

---

## Variables de entorno

| Variable | Descripción |
|---|---|
| `DATABASE_URL` | Cadena de conexión a Postgres, ej. `postgresql://usuario:password@host:5432/mxguide` |
| `JWT_SECRET` | Secreto para firmar los tokens. Mínimo 16 caracteres — el server **no arranca** si falta o es muy corto |
| `JWT_EXPIRES_IN` | Duración del token, default `7d` |
| `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | Credenciales de tu cuenta de Cloudinary (plan gratuito alcanza de sobra) |
| `PORT` | Puerto del servidor, default `3000` |

Todas se validan al arrancar (`app.module.ts`, con Joi). Si falta una obligatoria, el servidor rehúsa arrancar en vez de fallar a medias más adelante.

---

## Arquitectura y estructura de carpetas

Un módulo por entidad, cada uno con su `controller` / `service` / `module` — nadie del equipo toca el `service` de un módulo ajeno.

```
src/
├── auth/            # registro, login, JWT, guards de roles
├── places/          # CRUD de lugares + búsqueda por cercanía (PostGIS)
├── categories/       # catálogo de categorías (solo lectura)
├── states/           # catálogo de estados de México (solo lectura)
├── favorites/         # favoritos del usuario logueado
├── reviews/           # reseñas de un lugar
├── uploads/           # subida de imágenes a Cloudinary (solo admin)
├── prisma/            # PrismaService (cliente de base de datos)
├── common/            # decorador @Roles, filtro global de excepciones
└── main.ts            # bootstrap: Helmet, ValidationPipe, CORS
```

---

## Modelo de datos

Entidades principales (ver `prisma/schema.prisma` para el detalle completo):

- **State** — los 32 estados de México.
- **Category** — categorías de lugares (Histórico, Cultural, Natural, Religioso, Arqueológico).
- **Place** — un lugar turístico: nombre, descripciones, coordenadas (`latitude`/`longitude`), dirección, estado, municipio, costo de entrada, `relevanceScore` (para destacados), `isPublished`.
- **PlaceImage** — imágenes de un lugar (URL de Cloudinary + orden).
- **PlaceCategory** — tabla intermedia lugar↔categoría (muchos a muchos).
- **User** — email, password hasheado (bcrypt), nombre, `role` (`user` | `admin`).
- **Favorite** — relación usuario↔lugar (un usuario no puede repetir el mismo lugar).
- **Review** — reseña de un usuario sobre un lugar (rating 1-5 + comentario opcional).

> **Nota:** las coordenadas se guardan como `Float` normales (no como tipo `geography` nativo), porque Prisma no lo modela de forma directa. La búsqueda por cercanía se calcula al vuelo con `ST_MakePoint`/`ST_DWithin` en una consulta raw (`places.service.ts`, método `findNearby`). Ver la sección [Nota sobre PostGIS](#nota-sobre-postgis).

---

## Autenticación y roles

- Login/registro regresan `{ "accessToken": "..." }` (JWT).
- Mándalo en cada request protegida como header:
  ```
  Authorization: Bearer <accessToken>
  ```
- Hay dos roles: `user` (default al registrarse) y `admin`. El registro **no** deja elegir rol — para volver admin a un usuario hay que cambiarlo directo en la base de datos (Prisma Studio: `npx prisma studio`, tabla `User`, campo `role`) o con SQL:
  ```sql
  UPDATE "User" SET role = 'admin' WHERE email = 'correo@ejemplo.com';
  ```
  Después del cambio, ese usuario debe volver a hacer login para obtener un token nuevo con el rol actualizado (el token viejo no se actualiza solo).
- Rutas de solo-admin: crear/editar/borrar lugares, y ambos endpoints de `uploads`.

---

## Referencia de Endpoints

**Base URL:** `http://localhost:3000`. Errores siempre con esta forma: `{ statusCode, path, timestamp, message }`. El `ValidationPipe` global rechaza (400) cualquier campo que mandes y no esté en el DTO — solo manda los campos exactos.

### Auth (`/auth`)

| Método | Ruta | Acceso | Body |
|---|---|---|---|
| POST | `/auth/register` | Público | `{ email, password (mín. 6), name }` → `{ accessToken }` |
| POST | `/auth/login` | Público | `{ email, password }` → `{ accessToken }` |
| GET | `/auth/me` | Logueado | — → `{ id, email, name, role, createdAt }` |

### Lugares (`/places`)

| Método | Ruta | Acceso | Detalle |
|---|---|---|---|
| GET | `/places/nearby?lat=&lng=&radius=&limit=` | Público | `lat`/`lng` obligatorios; `radius` en km (default 25); `limit` (default 20). Regresa `distanceKm` |
| GET | `/places/featured?limit=` | Público | Los de mayor `relevanceScore` |
| GET | `/places?category=&stateId=&page=&limit=` | Público | Filtros opcionales; `page` default 1, `limit` default 20 (sin metadata de paginación) |
| GET | `/places/:id` | Público | Incluye `images`, `categories`, `state` |
| POST | `/places` | Admin | `{ name, shortDescription, longDescription, latitude, longitude, address, stateId, municipality, openingHours?, entryCost?, relevanceScore?, isPublished?, categoryIds? }` |
| PATCH | `/places/:id` | Admin | Mismo body, todo opcional |
| DELETE | `/places/:id` | Admin | — |

### Categorías (`/categories`)

| Método | Ruta | Acceso |
|---|---|---|
| GET | `/categories` | Público — `[{ id, name, icon }]` |

### Estados (`/states`)

| Método | Ruta | Acceso |
|---|---|---|
| GET | `/states` | Público — `[{ id, name }]`, orden alfabético |

### Favoritos (`/favorites`) — todas requieren estar logueado

| Método | Ruta | Detalle |
|---|---|---|
| GET | `/favorites` | Array de favoritos con su `place` (incluye `images`) |
| POST | `/favorites` | Body `{ placeId }` — 409 si ya existía |
| DELETE | `/favorites/:placeId` | — |

### Reseñas

| Método | Ruta | Acceso | Detalle |
|---|---|---|---|
| GET | `/places/:id/reviews` | Público | Más reciente primero, incluye `user { id, name }` |
| POST | `/reviews` | Logueado | Body `{ placeId, rating (1-5), comment? }` |

### Subida de imágenes (`/uploads`) — todas requieren rol `admin`

Van como **`multipart/form-data`** (no JSON), con el archivo en un campo llamado exactamente **`file`**.

| Método | Ruta | Detalle |
|---|---|---|
| POST | `/uploads/image` | Sube una imagen suelta a Cloudinary, regresa su URL |
| POST | `/uploads/places/:placeId/image` | Sube la imagen y crea el `PlaceImage` asociado a ese lugar |

---

## Seguridad

Pensando en que la app de Flutter que consume esto puede pasar por revisión de tiendas (Google Play/App Store) — el backend no lo escanean directo, pero un backend inseguro sí puede ser motivo de rechazo o reporte después:

- **Helmet** — cabeceras HTTP de seguridad estándar.
- **Rate limiting** (`@nestjs/throttler`) — 100 requests por IP cada 60 segundos por default (ajustable en `app.module.ts`).
- **Filtro global de excepciones** — cualquier error no controlado regresa un mensaje genérico (sin stack traces ni detalles internos). Los errores esperados (400/401/403/404/409) sí regresan su mensaje normal.
- **Validación de variables de entorno al arrancar** — si falta `DATABASE_URL` o `JWT_SECRET` (o es muy corto), el servidor no arranca.
- **`whitelist` + `forbidNonWhitelisted`** — cualquier campo extra en el body rechaza el request completo.
- **Passwords con bcrypt** — nunca se guardan en texto plano.

Fuera del alcance de este repo (depende de dónde lo despliegues):
- Servir por **HTTPS** en producción (Railway, Render, Fly.io lo dan gratis con certificado automático).
- Usar un `JWT_SECRET` largo y aleatorio real en producción (no el de `.env.example`).
- Confirmar que `.env` esté en `.gitignore` (ya lo está) y nunca se suba por accidente.

---

## Nota sobre PostGIS

El diseño original proponía un campo `location Geography(Point, 4326)`. Prisma no mapea nativamente el tipo `geography`, así que aquí se guardan `latitude`/`longitude` como columnas `Float` normales, y la distancia se calcula al vuelo con `ST_MakePoint(...)` / `ST_DWithin(...)` dentro de una consulta raw en `places.service.ts` (`findNearby`). Funciona igual, pero si el equipo quiere una columna `geography` real generada/indexada, hay que agregar una migración manual (columna calculada + índice `GIST`) después de `prisma migrate dev`.

---

## Pendientes del equipo

- Definir si `relevanceScore` se captura a mano o se calcula.
- Decidir si habrá panel admin web o la carga se sigue haciendo solo vía `prisma/seed.ts` / Thunder Client.
- Terminar de subir las fotos restantes de los lugares del seed vía `POST /uploads/places/:placeId/image`.
