import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Caché local de artículos en disco.
/// - El listado se guarda con clave 'articles_list'
/// - Cada detalle se guarda con clave 'article_detail_{id}'
/// - TTL de 30 minutos — si han pasado más se refresca en background
class ArticleCache {
  static const _ttlMinutes = 30;
  static const _keyList = 'articles_list';
  static const _keyListTs = 'articles_list_ts';
  static const _keyDetailPrefix = 'article_detail_';
  static const _keyDetailTsPrefix = 'article_detail_ts_';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ─── Listado ───────────────────────────────────────────────────────────────

  Future<String?> getList({String? key}) async {
    try {
      return await _storage.read(key: key ?? _keyList);
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Cache] Error leyendo listado: $e');
      return null;
    }
  }

  Future<void> saveList(String json, {String? key}) async {
    try {
      final k = key ?? _keyList;
      await _storage.write(key: k, value: json);
      await _storage.write(
          key: '${k}_ts',
          value: DateTime.now().millisecondsSinceEpoch.toString());
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Cache] Error guardando listado: $e');
    }
  }

  Future<bool> isListStale({String? key}) async {
    try {
      final k = key ?? _keyList;
      final ts = await _storage.read(key: '${k}_ts');
      if (ts == null) return true;
      final saved = DateTime.fromMillisecondsSinceEpoch(int.parse(ts));
      return DateTime.now().difference(saved).inMinutes > _ttlMinutes;
    } catch (_) {
      return true;
    }
  }

  // ─── Detalle ───────────────────────────────────────────────────────────────

  Future<String?> getDetail(int id) async {
    try {
      return await _storage.read(key: '$_keyDetailPrefix$id');
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Cache] Error leyendo detalle $id: $e');
      return null;
    }
  }

  Future<void> saveDetail(int id, String json) async {
    try {
      await _storage.write(key: '$_keyDetailPrefix$id', value: json);
      await _storage.write(
          key: '$_keyDetailTsPrefix$id',
          value: DateTime.now().millisecondsSinceEpoch.toString());
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Cache] Error guardando detalle $id: $e');
    }
  }

  Future<bool> isDetailStale(int id) async {
    try {
      final ts = await _storage.read(key: '$_keyDetailTsPrefix$id');
      if (ts == null) return true;
      final saved = DateTime.fromMillisecondsSinceEpoch(int.parse(ts));
      return DateTime.now().difference(saved).inMinutes > _ttlMinutes;
    } catch (_) {
      return true;
    }
  }

  /// Elimina de la caché los detalles de artículos exclusivos (content vacío
  /// o con rcp-is-restricted) para que se vuelvan a pedir al servidor.
  /// Llamar cuando la suscripción expira.
  Future<void> clearExclusiveContent() async {
    try {
      final all = await _storage.readAll();
      int cleared = 0;
      for (final entry in all.entries) {
        if (!entry.key.startsWith(_keyDetailPrefix)) continue;
        if (entry.key.contains('_ts')) continue;
        try {
          final json = entry.value;
          if (json.contains('rcp-is-restricted') ||
              json.contains('"rendered":""') ||
              json.contains('"rendered": ""')) {
            final id = entry.key.replaceFirst(_keyDetailPrefix, '');
            await _storage.delete(key: entry.key);
            await _storage.delete(key: '$_keyDetailTsPrefix$id');
            cleared++;
          }
        } catch (_) {}
      }
      if (kDebugMode) debugPrint('📦 [Cache] Limpiados $cleared artículos exclusivos');
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Cache] Error limpiando exclusivos: $e');
    }
  }
}