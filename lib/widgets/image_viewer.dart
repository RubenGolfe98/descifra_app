import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// Elemento de una galería de imágenes: URL, título opcional y grupo
/// (p. ej. la región a la que pertenece el mapa).
typedef GalleryItem = ({String url, String? caption, String? group});

/// Abre el visor de imagen a pantalla completa con zoom y arrastre.
void showImageViewer(BuildContext context, String imageUrl) {
  _showViewer(context, [(url: imageUrl, caption: null, group: null)], 0);
}

/// Abre el visor en modo galería: permite desplazarse lateralmente entre
/// las imágenes de [items], empezando por [initialIndex].
void showImageGalleryViewer(
  BuildContext context, {
  required List<GalleryItem> items,
  int initialIndex = 0,
}) {
  if (items.isEmpty) return;
  _showViewer(context, items, initialIndex.clamp(0, items.length - 1));
}

/// Abre el visor en modo galería agrupada: igual que [showImageGalleryViewer]
/// pero el contador muestra el grupo del elemento actual y su posición
/// dentro del grupo ('Europa 3/11'). Los items deben venir ordenados por
/// grupo, con los elementos de cada grupo contiguos.
void showImageGroupedGalleryViewer(
  BuildContext context, {
  required List<GalleryItem> items,
  int initialIndex = 0,
}) {
  if (items.isEmpty) return;
  _showViewer(context, items, initialIndex.clamp(0, items.length - 1));
}

void _showViewer(BuildContext context, List<GalleryItem> items, int index) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) =>
          _ImageViewerScreen(items: items, initialIndex: index),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _ImageViewerScreen extends StatefulWidget {
  final List<GalleryItem> items;
  final int initialIndex;

  const _ImageViewerScreen({required this.items, required this.initialIndex});

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _pageScrollEnabled = true;

  /// Para cada posición, su índice relativo dentro de su grupo (1-based).
  late final List<int> _groupRelativeIndex;

  /// Para cada posición, el tamaño total de su grupo.
  late final List<int> _groupSize;

  bool get _isGallery => widget.items.length > 1;

  bool get _isGrouped => widget.items.any((item) => item.group != null);

  /// Texto del contador: con grupos, 'Europa 3/11'; sin ellos, '3 / 12'.
  String get _counterText {
    if (_isGrouped) {
      final item = widget.items[_currentIndex];
      final group = item.group ?? '';
      return '$group ${_groupRelativeIndex[_currentIndex]}/${_groupSize[_currentIndex]}';
    }
    return '${_currentIndex + 1} / ${widget.items.length}';
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _computeGroupInfo();
  }

  /// Calcula, asumiendo grupos contiguos, la posición relativa y el tamaño
  /// de grupo de cada elemento.
  void _computeGroupInfo() {
    final items = widget.items;
    _groupRelativeIndex = List.filled(items.length, 1);
    _groupSize = List.filled(items.length, 1);

    var start = 0;
    while (start < items.length) {
      var end = start + 1;
      while (end < items.length && items[end].group == items[start].group) {
        end++;
      }
      final size = end - start;
      for (var i = start; i < end; i++) {
        _groupRelativeIndex[i] = i - start + 1;
        _groupSize[i] = size;
      }
      start = end;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Bloquea el cambio de página mientras la imagen visible está ampliada.
  void _onZoomChanged(bool zoomed) {
    if (zoomed == _pageScrollEnabled) {
      setState(() => _pageScrollEnabled = !zoomed);
    }
  }

  void _precacheAdjacent(int index) {
    for (final i in [index - 1, index + 1]) {
      if (i >= 0 && i < widget.items.length) {
        precacheImage(
          CachedNetworkImageProvider(widget.items[i].url),
          context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.items[_currentIndex].caption;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fondo negro al tocar para cerrar
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black87),
          ),

          // Imagen(es) con zoom y swipe lateral
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            // Con zoom activo se congela el PageView: el arrastre mueve la
            // imagen y nunca salta de mapa hasta volver a escala 1.0.
            physics: _pageScrollEnabled
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _precacheAdjacent(index);
            },
            itemBuilder: (context, index) => _ZoomableImage(
              imageUrl: widget.items[index].url,
              onZoomChanged: _onZoomChanged,
            ),
          ),

          // Contador "3 / 12" o "Europa 3/11" (solo en modo galería)
          if (_isGallery)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _counterText,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),

          // Título del mapa
          if (caption != null && caption.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),

          // Botón cerrar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Imagen individual con zoom (pinch + doble tap) y arrastre.
///
/// Cuando la imagen no está ampliada, el arrastre horizontal se desactiva
/// para que el [PageView] padre capture el swipe entre imágenes. Además,
/// notifica a [onZoomChanged] si la imagen está ampliada para que el padre
/// pueda bloquear el cambio de página.
class _ZoomableImage extends StatefulWidget {
  final String imageUrl;
  final ValueChanged<bool>? onZoomChanged;

  const _ZoomableImage({required this.imageUrl, this.onZoomChanged});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;
  bool _panEnabled = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
    _transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    // Si la página se destruye estando ampliada, libera el bloqueo del
    // PageView para que no quede congelado.
    widget.onZoomChanged?.call(false);
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final zoomed =
        _transformationController.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _panEnabled) {
      setState(() => _panEnabled = zoomed);
      widget.onZoomChanged?.call(zoomed);
    }
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _onDoubleTap() {
    final isZoomedIn =
        _transformationController.value.getMaxScaleOnAxis() > 1.5;

    if (isZoomedIn) {
      // Volver a zoom original
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ));
    } else {
      // Hacer zoom x3 centrado en el punto donde pulsó
      final pos = _doubleTapDetails!.localPosition;
      final x = -pos.dx * 2;
      final y = -pos.dy * 2;
      final zoom = Matrix4.identity()
        ..translateByVector3(Vector3(x, y, 0))
        ..scaleByVector3(Vector3(3.0, 3.0, 1.0));
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: zoom,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ));
    }

    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onDoubleTapDown: _onDoubleTapDown,
        onDoubleTap: _onDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 5.0,
          panEnabled: _panEnabled,
          clipBehavior: Clip.none,
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
