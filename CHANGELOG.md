# Changelog

## [1.3.0] — 2026-04-20

### Añadido
- **Firebase Analytics** integrado de forma opcional — si no hay `firebase_options.dart` la app compila y funciona sin Analytics; `firebase_options.dart.example` incluido como plantilla
- **Eventos de Analytics**: `article_view`, `coverage_view`, `seminar_view`, `seminar_session_view`, `newsletter_view`, `section_view`, `region_articles_view`, `region_maps_view`, `book_view`, `search`, `article_saved/unsaved`, `login_success`, `logout`, `access_dialog_shown`
- **Precarga al arrancar** — coberturas y seminarios se precargan en background al iniciar la app; caché con TTL de 6h y 12h respectivamente
- **Reintento automático** en detalle de artículo: hasta 3 intentos en timeout (2s, 4s entre intentos) y hasta 4 en error 503 (5s, 10s, 15s)
- **Botón Reintentar** con icono en seminar_detail y seminar_session

### Mejorado
- **Artículos exclusivos** — skeleton visible mientras se espera el nonce REST; `forceRefresh` al llegar el nonce evita leer caché con content vacío; `_loadVersion` evita race condition entre peticiones
- **Paginación robusta** — `fetchMore*` devuelve `null` en error de red y `[]` solo en fin real (400); "No hay más artículos" ya no aparece por error de red
- **LoggingHttpClient** — log movido a `microtask` para no bloquear el hilo principal; body truncado a 300 chars
- **Timeouts HTTP** subidos a 35s en todas las peticiones (servidor tarda 15-30s en custom post types)
- **Badge "Exclusivo"** añadido al artículo destacado en portada
- **Seminarios** — reintento automático cuando las sesiones vienen vacías

### Corregido
- Race condition entre petición sin nonce y con nonce en detalle de artículo
- Skeleton no aparecía en artículos de pago mientras se esperaba el nonce
- Paginación marcaba fin de lista en errores de red (timeout, 503)
- Favoritos: `type 'List<dynamic>' is not a subtype of 'Map<String, dynamic>'` — el servidor devuelve `posts` como `List`, no como `Map`

### Eliminado
- Artículos relacionados en coberturas (la taxonomía `cobertura` no está expuesta en la API REST)
- Botones de suscripción en todos los paywalls (cumplimiento App Store y Google Play)
- Botón "¿No tienes cuenta? ¡Suscríbete!" del perfil sin sesión
- `paywall_dialog.dart` renombrado a `access_dialog.dart`

### Seguridad
- `.gitignore` actualizado: `google-services.json`, `GoogleService-Info.plist`, `lib/firebase_options.dart`, keystores Android, certificados iOS

### Tests
- Nuevos: `coverage_test`, `seminar_test`, `article_detail_test`, `auth_exception_test`
- Nuevos: `coverage_repository_test`, `seminar_repository_test`
- Nuevos: `favorites_service_test`, `analytics_service_test`, `logging_http_client_test`
- Actualizados: `article_test` (ArticleCategory incluye `entrevista`), `article_repository_test` (fetchMore* devuelve `List?`)

---

## [1.2.0] — 2026-04-17

### Añadido
- **Pantalla de Coberturas** — listado paginado (5 en 5) con imagen de portada, descripción y badge "Cobertura"; detalle con SliverAppBar y contenido HTML renderizado
- **Pantalla de Entrevistas** — sección independiente accesible desde Explorar con paginación infinita
- **Pantalla de Newsletter** — accesible desde Perfil cuando el usuario está autenticado; muestra el último boletín enviado renderizado con `flutter_html`
- **Artículos Guardados** — pantalla de favoritos con pull-to-refresh; sincronización con el plugin Simple Favorites de WordPress vía `admin-ajax.php`; botón de bookmark en el detalle; actualización optimista del estado
- **Redes sociales en Perfil** — sección "Síguenos" con logos SVG oficiales (Instagram, Twitter/X, Telegram, TikTok, Twitch, YouTube) en color acento
- **Reestructuración de Explorar** — nueva cuadrícula con acceso directo a Análisis, Coberturas, Entrevistas, Seminarios, Libros y Mapas

### Mejorado
- **Rendimiento del login** — reducido de ~22s a ~11s mediante paralelización de peticiones
- **Newsletter extraída sin coste extra** — HTML del boletín extraído del mismo `/mi-cuenta/` del login
- **Logs de red más limpios** — body HTML omitido en consola

### Corregido
- Comillas simples en raw strings de Dart en `auth_service.dart`
- `notifyListeners()` durante el ciclo de build en `FavoritesService`

### Seguridad
- `.gitignore` completo con Firebase, keystores y certificados

---

## [1.1.0] — 2026-04-13

### Añadido
- **Mapas geopolíticos** por región en colaboración con FairPolitik
- **Sección de libros** con ficha técnica y botones de compra en Amazon y Kindle
- **Enlace a Seminarios** en la pantalla de perfil

### Mejorado
- **Contraste general** en títulos, descripciones, autores, fechas y botones
- **Barra de navegación inferior** con mayor contraste

### Corregido
- Mapas de Europa no aparecían por título mezclado con cabecera de Elementor

---

## [1.0.0] — 2026-01-10

### Lanzamiento inicial
- Listado de noticias y análisis con paginación infinita
- Detalle de artículos con contenido HTML renderizado
- Visor de imágenes con zoom (doble tap y pinch)
- Secciones por región geográfica con imagen SVG
- Artículos por región con paginación infinita
- Buscador con sugerencias en tiempo real (debounce 400ms)
- Autenticación segura via WebView
- Detección automática de membresía y contenido exclusivo
- Caché local con TTL de 30 minutos
- Tema claro (crema) y oscuro
- 5 fuentes tipográficas seleccionables
- Ajuste de tamaño de texto en 5 niveles
- Compartir artículos
- Indicador de conectividad con animación
- Splash screen nativa