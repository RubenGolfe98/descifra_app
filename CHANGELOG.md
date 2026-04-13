# Changelog

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
- Buscador con sugerencias en tiempo real (debounce 400ms)
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
