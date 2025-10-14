# セキュリティベストプラクティスガイド

## 目的

このドキュメントは、Habit Penguinの開発・保守において従うべきセキュリティベストプラクティスをまとめたものです。

## 1. コーディング規約

### 1.1 機密情報の取り扱い

**❌ やってはいけないこと:**
```dart
// ハードコードされたシークレット（絶対にやらない）
const apiKey = 'sk-1234567890abcdef';
const password = 'mypassword123';
```

**✅ 正しい方法:**
```dart
// 環境変数から読み込む
final apiKey = Platform.environment['API_KEY'];

// セキュアストレージから読み込む
final encryptionService = EncryptionService();
final key = await encryptionService.getOrCreateEncryptionKey();
```

### 1.2 ログ出力

**❌ やってはいけないこと:**
```dart
// センシティブデータのログ出力
print('User email: ${user.email}');
print('Task name: ${task.name}');
print('Encryption key: $encryptionKey');
```

**✅ 正しい方法:**
```dart
// デバッグモードでのみ、センシティブでない情報を出力
if (kDebugMode) {
  print('Task count: ${tasks.length}');
  print('Operation completed successfully');
}

// センシティブデータはマスキング
if (kDebugMode) {
  print('Task: ${task.name.substring(0, min(3, task.name.length))}***');
}
```

### 1.3 エラーハンドリング

**❌ やってはいけないこと:**
```dart
try {
  await sensitiveOperation();
} catch (e) {
  // スタックトレースをそのまま表示
  showDialog(content: Text('Error: $e\n${e.stackTrace}'));
}
```

**✅ 正しい方法:**
```dart
try {
  await sensitiveOperation();
} catch (e) {
  // ユーザーフレンドリーなメッセージ
  showDialog(content: Text('操作に失敗しました'));

  // 詳細はデバッグログのみ
  if (kDebugMode) {
    print('Error in sensitiveOperation: $e');
  }
}
```

## 2. データ保護

### 2.1 暗号化の使用

**タスクデータの暗号化:**
```dart
// 暗号化サービスの初期化
final encryptionService = EncryptionService();
final encryptionKey = await encryptionService.getOrCreateEncryptionKey();

// 暗号化されたBoxを開く
final box = await encryptionService.openEncryptedBox<HabitTask>(
  'tasks',
  encryptionKey: encryptionKey,
);
```

**暗号化の推奨箇所:**
- ✅ タスク名（個人情報）
- ✅ 完了履歴のメモ
- ⚠️ XPデータ（必要に応じて）
- ❌ アイコンコード（機密性なし）

### 2.2 データ削除

**完全削除の実装:**
```dart
// 単純なclear()だけでは不十分な場合がある
await box.clear();

// Hiveファイル自体を削除
await Hive.deleteFromDisk();

// 暗号化キーも削除
await encryptionService.deleteEncryptionKey();
```

### 2.3 バックアップ制御

**Android:**
```xml
<!-- AndroidManifest.xml -->
<application
    android:allowBackup="false"
    android:fullBackupContent="false">
    <!-- または選択的バックアップ -->
    <!-- android:fullBackupContent="@xml/backup_rules" -->
</application>
```

**iOS:**
```dart
// ファイル属性でバックアップ除外
// （必要に応じて実装）
```

## 3. 依存関係管理

### 3.1 定期的な更新

**月次チェックリスト:**
```bash
# 1. 古いパッケージをチェック
flutter pub outdated

# 2. セキュリティアドバイザリを確認
flutter pub outdated --json | jq '.packages[] | select(.isCurrentAffectedByAdvisory == true)'

# 3. 更新可能なパッケージを更新
flutter pub upgrade --major-versions

# 4. テストを実行
flutter test

# 5. 動作確認
flutter run
```

### 3.2 信頼できるパッケージの選択

**チェック項目:**
- ✅ pub.dev の Verified Publisher バッジ
- ✅ GitHub スター数（目安: 100+）
- ✅ 最終更新日（目安: 6ヶ月以内）
- ✅ issueの対応状況
- ✅ ライセンスの確認

**例:**
```yaml
dependencies:
  # ✅ Verified Publisher
  flutter_riverpod: ^2.6.1

  # ✅ 公式パッケージ
  path_provider: ^2.1.5

  # ⚠️ 個人開発、要確認
  # some_package: ^1.0.0
```

### 3.3 脆弱性への対応

**Critical/High の場合:**
1. 即座にパッチを適用
2. 緊急アップデートをリリース
3. ユーザーに通知

**Medium/Low の場合:**
1. 次回更新時にパッチを適用
2. 通常のアップデートサイクルで対応

## 4. 入力検証

### 4.1 フォーム入力

**必須項目:**
```dart
TextFormField(
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'タスク名を入力してください';
    }
    if (value.length > 100) {
      return 'タスク名は100文字以内にしてください';
    }
    return null;
  },
);
```

### 4.2 ファイル入出力

**安全なパス処理:**
```dart
// ❌ 危険: ユーザー入力をそのまま使用
final file = File(userInputPath);

// ✅ 安全: アプリディレクトリ内に制限
final directory = await getApplicationDocumentsDirectory();
final sanitizedFilename = basename(userInputPath)
    .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
final file = File('${directory.path}/$sanitizedFilename');
```

## 5. プラットフォーム固有のセキュリティ

### 5.1 Android

**ProGuard設定 (android/app/build.gradle):**
```gradle
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

**proguard-rules.pro:**
```
# Hive
-keep class hive.** { *; }
-keep class * extends hive.HiveObject { *; }

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
```

**権限の最小化 (AndroidManifest.xml):**
```xml
<!-- 必要な権限のみ -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- 不要な権限は削除 -->
<!-- <uses-permission android:name="android.permission.INTERNET" /> -->
```

### 5.2 iOS

**Entitlements設定:**
```xml
<!-- ios/Runner/Runner.entitlements -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.example.habitpenguin</string>
</array>

<!-- App Sandbox有効化 -->
<key>com.apple.security.app-sandbox</key>
<true/>
```

**Info.plist:**
```xml
<!-- プライバシー説明 -->
<key>NSUserNotificationsUsageDescription</key>
<string>タスクのリマインダー通知を送信します</string>
```

## 6. テストとCI/CD

### 6.1 セキュリティテスト

**ユニットテスト例:**
```dart
test('encryption service generates secure keys', () async {
  final encryptionService = EncryptionService();
  final key = await encryptionService.getOrCreateEncryptionKey();

  // キー長の検証
  expect(key.length, 32); // 256 bits

  // ランダム性の検証（簡易）
  final key2 = encryptionService._generateEncryptionKey();
  expect(key, isNot(equals(key2)));
});

test('sensitive data is not logged', () {
  // ログキャプチャの実装
  final logs = <String>[];

  // 操作実行
  final task = HabitTask(name: 'Secret Task', ...);

  // センシティブデータがログに含まれないことを確認
  expect(logs.any((log) => log.contains('Secret')), false);
});
```

### 6.2 CI/CDパイプライン

**GitHub Actions例:**
```yaml
name: Security Checks

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - uses: subosito/flutter-action@v2

      # 依存関係チェック
      - name: Check dependencies
        run: flutter pub outdated --json > outdated.json

      # 静的解析
      - name: Analyze
        run: flutter analyze

      # テスト
      - name: Run tests
        run: flutter test

      # セキュリティスキャン（例）
      - name: Security scan
        run: |
          # カスタムスクリプトまたはツール
          ./scripts/security_check.sh
```

## 7. インシデント対応

### 7.1 脆弱性報告の受付

**報告フォーマット:**
```markdown
## 脆弱性の詳細
- 種類: [XSS / SQLi / etc.]
- 影響範囲: [Critical / High / Medium / Low]
- 再現手順: ...
- 影響: ...

## 環境
- アプリバージョン: ...
- OS: ...
- デバイス: ...
```

### 7.2 対応フロー

1. **受付**: 24時間以内に返信
2. **評価**: 72時間以内に重大度を判定
3. **修正**: 重大度に応じて対応
   - Critical: 24時間以内
   - High: 1週間以内
   - Medium: 1ヶ月以内
   - Low: 次回リリース時
4. **リリース**: 修正版の配布
5. **公開**: 必要に応じて開示

## 8. チェックリスト

### コミット前
- [ ] ハードコードされたシークレットがない
- [ ] センシティブデータのログ出力がない
- [ ] 適切なエラーハンドリングがある
- [ ] 入力検証が実装されている

### プルリクエスト前
- [ ] すべてのテストが通過
- [ ] flutter analyze でエラーなし
- [ ] セキュリティレビューが完了

### リリース前
- [ ] リリースビルドでテスト
- [ ] 難読化が有効
- [ ] 依存関係が最新
- [ ] セキュリティ監査が完了

## 9. 教育とトレーニング

### 9.1 推奨リソース

**学習資料:**
- OWASP Mobile Top 10
- Flutter Security Best Practices
- Dart Security Guidelines

**ツール:**
- flutter analyze
- dart analyze
- MobSF (Mobile Security Framework)

### 9.2 定期レビュー

- 四半期ごとのセキュリティレビュー
- 半年ごとの監査
- 年次のペネトレーションテスト（必要に応じて）

## 10. 連絡先

**セキュリティ問題の報告:**
- Email: [security@example.com]
- GitHub: Private security advisory

**緊急連絡先:**
- [担当者名・連絡先]

---

**最終更新**: 2025年1月
**次回レビュー**: 2025年7月
