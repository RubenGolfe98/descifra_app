import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/coverage.dart';
import '../repositories/coverage_repository.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import 'coverage_detail_screen.dart';

class CoveragesScreen extends StatefulWidget {
  const CoveragesScreen({super.key});

  @override
  State<CoveragesScreen> createState() => _CoveragesScreenState();
}

class _CoveragesScreenState extends State<CoveragesScreen> {
  final _repository = CoverageRepository();
  final _scrollController = ScrollController();
  final _coverages = <Coverage>[];

  late Future<List<Coverage>> _firstPageFuture;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _firstPageFuture = _repository.fetchCoverages(perPage: 5);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final more = await _repository.fetchCoverages(page: _currentPage + 1, perPage: 5);
    if (mounted) {
      setState(() {
        if (more.length < 5) _hasMore = false;
        if (more.isNotEmpty) {
          _coverages.addAll(more);
          _currentPage++;
        }
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _coverages.clear();
      _initialized = false;
      _firstPageFuture = _repository.fetchCoverages(perPage: 5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final bg  = AppColors.bg(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: AppColors.surf(isDark),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Coberturas',
            style: TextStyle(color: pri, fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppColors.bord(isDark)),
        ),
      ),
      body: FutureBuilder<List<Coverage>>(
        future: _firstPageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _coverages.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
            );
          }

          if (snapshot.hasError && _coverages.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error al cargar las coberturas', style: TextStyle(color: sec)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Reintentar',
                        style: TextStyle(color: AppColors.accent)),
                  ),
                ],
              ),
            );
          }

          if (!_initialized && snapshot.data != null && _coverages.isEmpty) {
            _initialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _coverages.isEmpty) {
                setState(() => _coverages.addAll(snapshot.data!));
              }
            });
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.accent,
            backgroundColor: AppColors.surf(isDark),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _coverages.length + 1,
              itemBuilder: (context, index) {
                if (index == _coverages.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: _isLoadingMore
                        ? const Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: AppColors.accent, strokeWidth: 2),
                            ),
                          )
                        : _hasMore
                            ? const SizedBox.shrink()
                            : Center(
                                child: Text('No hay más coberturas',
                                    style: TextStyle(
                                        color: AppColors.textMut(isDark),
                                        fontSize: 12)),
                              ),
                  );
                }
                return _CoverageCard(coverage: _coverages[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  final Coverage coverage;
  const _CoverageCard({required this.coverage});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CoverageDetailScreen(coverage: coverage)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 200,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: const Color(0xFF1A1A1A)),
            ),
            if (coverage.imageUrl.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: coverage.imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  memCacheWidth: 800,
                  fadeInDuration: const Duration(milliseconds: 300),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1.0],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Text(
                coverage.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}