# Changelog

## [1.2.0] — 2026-04-17

### Añadido
- **Pantalla de Coberturas** — listado paginado (5 en 5) con imagen de portada, descripción y badge "Cobertura"; detalle con SliverAppBar, contenido HTML renderizado y artículos relacionados paginados
- **Pantalla de Entrevistas** — sección independiente accesible desde Explorar con paginación infinita
- **Pantalla de Newsletter** — accesible desde Perfil cuando el usuario está autenticado; muestra el último boletín enviado renderizado con `flutter_html`; si el plan no incluye newsletter muestra paywall con botón "Ampliar suscripción"
- **Artículos Guardados** — pantalla de favoritos con pull-to-refresh; sincronización con el plugin Simple Favorites de WordPress vía `admin-ajax.php`; botón de bookmark en el detalle de artículo (solo visible cuando hay sesión activa); actualización optimista del estado
- **Redes sociales en Perfil** — sección "Síguenos" con logos SVG oficiales (Instagram, Twitter/X, Telegram, TikTok, Twitch, YouTube) en color acento, visibles siempre en la pantalla de perfil
- **Botón "¿No tienes cuenta? ¡Suscríbete!"** en la pantalla de perfil sin sesión, redirige a `descifrandolaguerra.es/suscribete/`
- **Reestructuración de Explorar** — nueva cuadrícula con acceso directo a Análisis, Coberturas, Entrevistas, Seminarios, Libros y Mapas

### Mejorado
- **Rendimiento del login** — reducido de ~22s a ~11s mediante paralelización de peticiones: `rest-nonce` + `/mi-cuenta/` en paralelo, y `/users/me` + `rcp_is_restricted` también en paralelo; nonce cacheado en `_lastNonce` para evitar una tercera petición redundante
- **Newsletter extraída sin coste extra** — el HTML del último boletín se extrae del mismo `/mi-cuenta/` que ya se descarga durante el login, sin petición adicional; se persiste en `flutter_secure_storage`
- **Logs de red más limpios** — el body de respuestas HTML (como `/mi-cuenta/`) ya no se vuelca completo en consola; se muestra `[HTML N bytes — omitido]`; los headers de request ya no se imprimen para reducir el ruido
- **Avatar de perfil con fallback** — si el nombre de usuario no está disponible muestra icono `person_outline` en lugar de `?`
- **Sesión con displayName vacío** — al cargar una sesión guardada sin nombre de usuario, se recupera automáticamente desde `/users/me` y se persiste para siguientes arranques

### Corregido
- Comillas simples en raw strings de Dart causaban errores de compilación en las regex de `auth_service.dart` — separadas a strings normales con escape correcto
- Tercera petición redundante al nonce REST tras login eliminada
- `notifyListeners()` durante el ciclo de build en `FavoritesService` — movido a `addPostFrameCallback`

### Seguridad
- Añadido `.gitignore` completo: `google-services.json`, `GoogleService-Info.plist`, `lib/firebase_options.dart`, keystores Android (`*.jks`, `*.keystore`, `key.properties`), certificados iOS (`*.p12`, `*.p8`, `*.mobileprovision`) y archivos de secretos genéricos

---

## [1.1.0] — 2026-04-13

### Añadido
- **Mapas geopolíticos** por región — galería de infografías en colaboración con FairPolitik, accesible desde el bottom sheet de cada región
- **Sección de libros** — listado de portadas en cuadrícula, detalle con ficha técnica (autores, editorial, fecha), descripción y botones de compra en Amazon y Kindle
- **Enlace a Seminarios** en la pantalla de perfil, visible tanto para usuarios logueados como no logueados
- **Botones Libros y Seminarios** visibles en la pantalla de login (sin necesidad de iniciar sesión)
- Los mapas se cargan dinámicamente desde la web — se actualizan automáticamente cuando se añaden nuevos sin necesidad de actualizar la app

### Mejorado
- **Contraste general** — mejorado en títulos de secciones, descripciones, autores, fechas, botones y textos secundarios en todas las pantallas
- **Barra de navegación inferior** — mayor contraste en iconos y etiquetas no seleccionados
- **Pantalla de ajustes** — títulos de sección en rojo y negrita (`w800`)
- **Cabecera de regiones** — eliminado el gradiente oscuro sobre la imagen del mapa SVG
- **Tarjetas de artículos** — título en `w800`, mayor diferenciación visual con la descripción
- **Noticia destacada** — autor y fecha con mayor contraste
- **OfflineBanner** — ya no ocupa espacio cuando está invisible (usando `SizedBox.shrink`)
- **Perfil sin sesión** — eliminado el botón "Continuar sin iniciar sesión"
- **Icono de ajustes** en perfil con mayor contraste

### Corregido
- Mapas de Europa no aparecían por título mezclado con cabecera de página en el HTML de Elementor — resuelto con búsqueda parcial de clave

---

## [1.0.0] — 2026-01-10

### Lanzamiento inicial
- Listado de noticias y análisis con paginación infinita
- Detalle de artículos con contenido HTML renderizado
- Visor de imágenes con zoom (doble tap y pinch)
- Secciones por región geográfica con imagen SVG
- Artículos por región con paginación infinita
- Buscador de artículos con sugerencias en tiempo real (debounce 400ms) y búsqueda por título
- Autenticación segura via WebView — las credenciales nunca pasan por la app
- Detección automática de membresía y contenido exclusivo
- Paywall inline para contenido premium
- Caché local con TTL de 30 minutos
- Tema claro (crema) y oscuro
- 5 fuentes tipográficas seleccionables
- Ajuste de tamaño de texto en 5 niveles
- Compartir artículos
- Indicador de conectividad con animación
- Splash screen nativa
