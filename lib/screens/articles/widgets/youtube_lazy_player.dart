import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../theme/app_colors.dart';

/// Reproductor de YouTube de carga perezosa.
///
/// Muestra la miniatura del vídeo (sin crear ningún WebView) hasta que el
/// usuario pulsa play; solo entonces se instancia el reproductor inline.
/// El botón de la esquina abre el vídeo directamente en YouTube.
///
/// Solo un vídeo puede sonar a la vez: al reproducirse uno se pausa el
/// reproductor activo anterior, y al salir del detalle se libera el
/// controller para que no quede audio ni WebView colgado.
class YoutubeLazyPlayer extends StatefulWidget {
  final String videoId;

  const YoutubeLazyPlayer({super.key, required this.videoId});

  /// Referencia al reproductor que se está reproduciendo actualmente,
  /// para poder pausarlo cuando otro vídeo empiece.
  static YoutubePlayerController? _activeController;

  @override
  State<YoutubeLazyPlayer> createState() => _YoutubeLazyPlayerState();
}

class _YoutubeLazyPlayerState extends State<YoutubeLazyPlayer> {
  YoutubePlayerController? _controller;

  Future<void> _openInYoutube() async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _play() {
    // Pausar el vídeo que estuviera sonando, si es otro distinto.
    final active = YoutubeLazyPlayer._activeController;
    if (active != null && !identical(active, _controller)) {
      active.pause();
    }

    final controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(autoPlay: true),
    );
    YoutubeLazyPlayer._activeController = controller;
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    // Liberar el WebView y desregistrar el controller para que no quede
    // audio sonando ni memoria retenida al salir del detalle.
    if (identical(YoutubeLazyPlayer._activeController, _controller)) {
      YoutubeLazyPlayer._activeController = null;
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _controller == null
          ? _buildThumbnail(isDark, screenWidth)
          : _buildPlayer(),
    );
  }

  Widget _buildThumbnail(bool isDark, double screenWidth) {
    final thumbUrl =
        'https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg';
    return GestureDetector(
      onTap: _play,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: thumbUrl,
              width: screenWidth - 40,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 200,
                color: AppColors.surf(isDark),
              ),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _openInYoutube,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.open_in_new,
                      color: AppColors.accent, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.accent,
          progressColors: const ProgressBarColors(
            playedColor: AppColors.accent,
            handleColor: AppColors.accent,
            bufferedColor: Colors.white24,
            backgroundColor: Colors.grey,
          ),
          topActions: [
            const Spacer(),
            GestureDetector(
              onTap: _openInYoutube,
              child: const Icon(Icons.open_in_new,
                  color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 8),
          ],
          bottomActions: [
            const SizedBox(width: 14.0),
            const CurrentPosition(),
            const SizedBox(width: 8.0),
            ProgressBar(
              isExpanded: true,
              colors: const ProgressBarColors(
                  playedColor: AppColors.accent,
                  handleColor: AppColors.accent,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.grey),
            ),
            const RemainingDuration(),
            const PlaybackSpeedButton(),
          ],
        ),
      ),
    );
  }
}
