import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// データ暗号化を管理するサービス
/// Hiveの暗号化と暗号鍵の安全な保管を提供
class EncryptionService {
  static const String _encryptionKeyName = 'hive_encryption_key';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Hive用の暗号化キーを取得または生成
  /// キーはデバイスのセキュアストレージに保存される
  Future<List<int>> getOrCreateEncryptionKey() async {
    try {
      // 既存のキーを取得
      final existingKey = await _secureStorage.read(key: _encryptionKeyName);

      if (existingKey != null) {
        return base64Decode(existingKey);
      }

      // 新しいキーを生成
      final key = _generateEncryptionKey();
      final encodedKey = base64Encode(key);

      // セキュアストレージに保存
      await _secureStorage.write(key: _encryptionKeyName, value: encodedKey);

      return key;
    } catch (e) {
      throw EncryptionException('暗号化キーの取得/生成に失敗しました: $e');
    }
  }

  /// 暗号化キーが存在するか確認
  Future<bool> hasEncryptionKey() async {
    try {
      final key = await _secureStorage.read(key: _encryptionKeyName);
      return key != null;
    } catch (e) {
      return false;
    }
  }

  /// 暗号化キーを削除（アプリのリセット時などに使用）
  Future<void> deleteEncryptionKey() async {
    try {
      await _secureStorage.delete(key: _encryptionKeyName);
    } catch (e) {
      throw EncryptionException('暗号化キーの削除に失敗しました: $e');
    }
  }

  /// 暗号化されたBoxを開く
  Future<Box<T>> openEncryptedBox<T>(
    String name, {
    required List<int> encryptionKey,
  }) async {
    try {
      final encryptionCipher = HiveAesCipher(encryptionKey);

      return await Hive.openBox<T>(
        name,
        encryptionCipher: encryptionCipher,
      );
    } catch (e) {
      throw EncryptionException('暗号化Boxの開封に失敗しました: $e');
    }
  }

  /// 256ビット暗号化キーを生成
  List<int> _generateEncryptionKey() {
    final random = Random.secure();
    final key = List<int>.generate(32, (i) => random.nextInt(256));
    return key;
  }

  /// 暗号化が推奨されるデータか判定
  bool isEncryptionRecommended() {
    // 現在のアプリではタスク名などの個人情報を含むため、暗号化を推奨
    // ただし、パフォーマンスと使いやすさを考慮してオプションとする
    return true;
  }

  /// セキュアストレージの健全性チェック
  Future<bool> checkSecureStorageHealth() async {
    try {
      const testKey = 'health_check_test_key';
      const testValue = 'test_value';

      // 書き込みテスト
      await _secureStorage.write(key: testKey, value: testValue);

      // 読み取りテスト
      final readValue = await _secureStorage.read(key: testKey);

      // クリーンアップ
      await _secureStorage.delete(key: testKey);

      return readValue == testValue;
    } catch (e) {
      return false;
    }
  }

  /// 暗号化の統計情報を取得
  Future<EncryptionStats> getEncryptionStats() async {
    final hasKey = await hasEncryptionKey();
    final isHealthy = await checkSecureStorageHealth();

    return EncryptionStats(
      isEncryptionEnabled: hasKey,
      isSecureStorageHealthy: isHealthy,
      encryptionAlgorithm: 'AES-256',
      keyStorageMethod: 'Platform Secure Storage',
    );
  }
}

/// 暗号化の統計情報
class EncryptionStats {
  final bool isEncryptionEnabled;
  final bool isSecureStorageHealthy;
  final String encryptionAlgorithm;
  final String keyStorageMethod;

  EncryptionStats({
    required this.isEncryptionEnabled,
    required this.isSecureStorageHealthy,
    required this.encryptionAlgorithm,
    required this.keyStorageMethod,
  });

  @override
  String toString() {
    return 'EncryptionStats(\n'
        '  暗号化: ${isEncryptionEnabled ? "有効" : "無効"}\n'
        '  セキュアストレージ: ${isSecureStorageHealthy ? "正常" : "異常"}\n'
        '  暗号化方式: $encryptionAlgorithm\n'
        '  鍵保管方法: $keyStorageMethod\n'
        ')';
  }
}

/// 暗号化関連の例外
class EncryptionException implements Exception {
  final String message;

  EncryptionException(this.message);

  @override
  String toString() => message;
}
