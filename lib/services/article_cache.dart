import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ArticleCache {
  // TTL ampliados: listas 2h, detalles 24h, búsqueda 15min
  static const _listTtlMinutes   = 120;
  static const _detailTtlMinutes = 1440;
  static const _searchTtlMinutes = 15;

  // ─── Caché en memoria (hot) ─────────────────────────────────────────────────
  static final _mem = <String, _Entry>{};
  static const _memMax = 100;

  // ─── Caché en disco ─────────────────────────────────────────────────────────
  static Directory? _diskDir;

  Future<Directory> _dir() async {
    _diskDir ??= await getApplicationCacheDirectory();
    return _diskDir!;
  }

  String _fileKey(String k) {
    // Sanitizar para nombre de archivo seguro
    final safe = k.replaceAll(RegExp(r'[^\w-]'), '_');
    return 'dlg_$safe.json';
  }

  // ─── Lectura: mem → disco ──────────────────────────────────────────────────
  Future<_Entry?> _read(String key) async {
    final mem = _mem[key];
    if (mem != null) return mem;

    try {
      final dir = await _dir();
      final file = File('${dir.path}/${_fileKey(key)}');
      if (!file.existsSync()) return null;
      final raw = await file.readAsString();
      final entry = _Entry.fromJson(raw);
      _mem[key] = entry;
      _trimMem();
      return entry;
    } catch (_) {
      return null;
    }
  }

  // ─── Escritura: mem + disco ────────────────────────────────────────────────
  Future<void> _write(String key, String data, {bool restricted = false}) async {
    final entry = _Entry(data, restricted: restricted);
    _mem[key] = entry;
    _trimMem();

    try {
      final dir = await _dir();
      await File('${dir.path}/${_fileKey(key)}').writeAsString(entry.toJson());
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Cache] write error $key: $e');
    }
  }

  void _trimMem() {
    if (_mem.length <= _memMax) return;
    final sorted = _mem.entries.toList()
      ..sort((a, b) => a.value.ts.compareTo(b.value.ts));
    for (var i = 0; i < _mem.length - _memMax; i++) {
      _mem.remove(sorted[i].key);
    }
  }

  // ─── API pública ────────────────────────────────────────────────────────────

  Future<String?> getList({String? key}) async {
    final e = await _read(key ?? 'articles_list');
    return e?.data;
  }

  Future<void> saveList(String json, {String? key}) async {
    await _write(key ?? 'articles_list', json);
  }

  Future<bool> isListStale({String? key}) async {
    final e = await _read(key ?? 'articles_list');
    return e == null || e.isExpired(_listTtlMinutes);
  }

  Future<String?> getDetail(int id) async {
    final e = await _read('detail_$id');
    return e?.data;
  }

  Future<void> saveDetail(int id, String json, {bool isPremium = false}) async {
    await _write('detail_$id', json, restricted: isPremium);
  }

  Future<bool> isDetailStale(int id) async {
    final e = await _read('detail_$id');
    return e == null || e.isExpired(_detailTtlMinutes);
  }

  Future<String?> getSearch(String query) async {
    final e = await _read('search_${query.hashCode}');
    if (e == null) return null;
    return e.isExpired(_searchTtlMinutes) ? null : e.data;
  }

  Future<void> saveSearch(String query, String json) async {
    await _write('search_${query.hashCode}', json);
  }

  /// Elimina de la caché los detalles de artículos exclusivos
  /// para que se vuelvan a pedir al servidor tras expirar la suscripción.
  Future<void> clearExclusiveContent() async {
    try {
      final dir = await _dir();
      final files = dir.listSync().whereType<File>()
          .where((f) => f.path.contains('dlg_detail_'));
      int cleared = 0;
      for (final f in files) {
        try {
          final raw = await f.readAsString();
          final e = _Entry.fromJson(raw);
          if (e.restricted) {
            await f.delete();
            _mem.remove(f.uri.pathSegments.last.replaceAll('.json', ''));
            cleared++;
          }
        } catch (_) {}
      }
      if (kDebugMode) {
        debugPrint('📦 [Cache] cleared $cleared restricted details');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Cache] clearExclusive error: $e');
    }
  }
}

// ─── Entrada de caché: datos + timestamp + metadatos ──────────────────────────
class _Entry {
  final String data;
  final int ts;
  final bool restricted;

  _Entry(this.data, {this.restricted = false})
      : ts = DateTime.now().millisecondsSinceEpoch;

  _Entry._(this.data, this.ts, this.restricted);

  bool isExpired(int ttlMinutes) =>
      DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts))
          .inMinutes > ttlMinutes;

  String toJson() => jsonEncode({'d': data, 't': ts, 'r': restricted});

  factory _Entry.fromJson(String raw) {
    final m = jsonDecode(raw);
    return _Entry._(m['d'], m['t'], m['r'] ?? false);
  }
}
