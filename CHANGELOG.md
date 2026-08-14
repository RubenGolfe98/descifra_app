# Changelog

## [1.5.2] — 2026-08-14

### Añadido
- Mapas interactivos en las coberturas

### Corregido
- Al caducar la sesión ya no se pierden las preferencias de tema, tipografía y tamaño de letra
- La pantalla de bienvenida deja de reaparecer tras cerrar sesión
- Corregido un aviso interno al cambiar de tema en Ajustes

## [1.5.1] — 2026-07-31

### Añadido
- Nueva pantalla de bienvenida y configuración al abrir la app después de instalar (el texto de bienvenida se puede cambiar)
- Soporte para vídeos de YouTube y podcasts de Spotify incrustados
- Acceso a todos los mapas desde la sección de ‘Explorar’
- Nuevo ajuste para justificar texto (activado por defecto)
- Doble tap en tab en el menú Inicio → scroll-to-top
- Barra de progreso de lectura

### Mejorado 
- Migrar SVGs de regiones a assets locales y mejorar contraste de los mismos
- Limpieza de la barra de navegación
- Agrupar badges de países
- UI en modo horizontal

## [1.5.0] — 2026-07-24

### Añadido
- Badges (etiquetas) de países
- En seminarios se ha añadido la introducción de los mismos debajo de las sesiones
- Autor clickable, al pulsar sobre un autor te lleva a un listado de todos sus textos (análisis, entrevistas y noticias) ordenados por fecha
- Badges clickables

### Mejorado 
- Títulos de los seminarios ampliados para que destaquen más
- En los listados se amplia la resolución de las imágenes sin afectar demasiado al rendimiento, en función del dispositivo donde se está ejecutando la app para que se vean mejor.
- Badges (etiquetas) en negrita y mejorar contraste para que se vean mejor
- Subtítulos en negrita
- Quitar imagen duplicada en detalles de análisis y noticias
- En entrevistas mejorar el contraste de las preguntas y respuestas

### Corregido
- En Análisis y Entrevistas ahora aparece la flecha para volver atrás
- En los libros ahora los títulos entran enteros
- La letra del título de ‘DESCIFRANDO LA GUERRA’ en la pantalla principal ya no cambia de tamaño

## [1.4.1] — 2026-06-20

### Mejorado (rendimiento)
- **Caché reescrita**: `FlutterSecureStorage` reemplazado por caché en disco (`path_provider`) + memoria caliente (hot cache). Las lecturas de caché pasan de operaciones de Keychain (~50-200ms cada una) a accesos a memoria RAM o lecturas de archivos planos, eliminando el cuello de botella principal al abrir artículos
- **Carga diferida de artículos premium**: se espera al nonce REST antes de hacer la primera petición, eliminando la carga duplicada que antes disparaba 2-3 requests por cada artículo restringido
- **HTTP Client directo**: se usa `http.Client()` en lugar de `LoggingHttpClient` por defecto, eliminando la sobrecarga de bufferización de respuestas en modo debug
- **Timeouts reducidos**: de 35s a 15s (listas) y 20s (detalles); los reintentos por 503 bajan de 3 a 2 intentos con menor espaciado
- **TTLs ampliados**: listas 2h (antes 30min), detalles 24h (antes 30min), menos refrescos en background innecesarios
- **Caché de búsqueda**: resultados de búsqueda se cachean 15 minutos
- **Splash mínimo**: eliminado el delay fijo de 1.5s — la splash solo se muestra mientras auth inicializa (~100-200ms)
- **Flash eliminado en feeds**: las pantallas de inicio, análisis, entrevistas y regiones ya no muestran un frame extra de spinner antes de renderizar los artículos

### Corregido
- Race condition que causaba cargas duplicadas (2-3 requests) al abrir artículos premium con sesión activa
- `saveDetail` ahora guarda también el flag `isPremium` para permitir limpieza eficiente de caché exclusiva sin escanear contenidos

### Dependencias
- Añadido `path_provider` para caché en disco
- Eliminada dependencia interna de `flutter_secure_storage` para el sistema de caché (sigue usándose exclusivamente para auth)

---

## [1.4.0] — 2026-04-22

### Añadido
- **Validación de membresía al arrancar** — si la suscripción no está activa, la fecha de expiración es anterior a hoy, o hay inconsistencia entre el estado de membresía e `isSubscriber`, la app valida contra el servidor antes de mostrar la pantalla principal
- **Limpieza automática de caché exclusiva** — al detectar que la suscripción ha expirado, se eliminan de la caché los artículos con `rcp-is-restricted` o `content` vacío
- **Refresco forzado al renovar suscripción** — si el usuario es suscriptor pero el artículo tiene content vacío en caché, se fuerza una nueva petición al servidor en lugar de mostrar el paywall

### Mejorado
- **Todos los timeouts de `auth_service`** subidos a 35s — la verificación de suscripción (`rcp_is_restricted`) tardaba hasta 17s y fallaba con el timeout anterior de 15s
- **`isMembershipStale`** — lógica inteligente: valida si la suscripción no está activa, si la fecha de expiración es anterior a hoy, o si hay inconsistencia entre `membershipStatus` e `isSubscriber`

### Corregido
- `isSubscriber` quedaba en `false` tras renovar la suscripción porque la petición de verificación superaba el timeout de 15s
- El `access_dialog` aparecía en artículos exclusivos tras renovar la suscripción aunque la membresía estuviera activa
- El perfil mostraba el estado de membresía desactualizado entre arranques

---

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