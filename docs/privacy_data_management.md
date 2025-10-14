# プライバシーとデータ管理機能

## 概要

Habit Penguinは、ユーザーのプライバシーを最優先し、GDPR/CCPAに準拠したデータ管理機能を提供しています。すべてのデータはローカルに保存され、ユーザーは自分のデータを完全にコントロールできます。

## 実装した機能

### 1. データエクスポート機能

#### DataExportService (`lib/services/data_export_service.dart`)

**機能:**
- JSON形式でのエクスポート
- CSV形式でのエクスポート（タスクと履歴を別ファイルで）
- ファイル共有機能（share_plusを使用）
- エクスポート前のデータサマリー表示

**エクスポートされるデータ:**
```json
{
  "exportedAt": "2025-01-15T10:30:00.000Z",
  "version": "1.0",
  "appState": {
    "currentXp": 250,
    "schemaVersion": 2
  },
  "tasks": [
    {
      "id": 0,
      "name": "Morning Exercise",
      "iconCodePoint": 58826,
      "difficulty": "normal",
      "reminderEnabled": true,
      "reminderTime": {"hour": 9, "minute": 0},
      "isRepeating": true,
      "repeatStart": "2025-01-01T00:00:00.000Z",
      "repeatEnd": "2025-12-31T00:00:00.000Z"
    }
  ],
  "completionHistory": [
    {
      "taskId": 0,
      "completedAt": "2025-01-15T09:15:00.000Z",
      "earnedXp": 30,
      "notes": null
    }
  ]
}
```

**CSV形式:**
- `habit_penguin_tasks_[timestamp].csv` - タスク情報
- `habit_penguin_history_[timestamp].csv` - 完了履歴

**使用例:**
```dart
final exportService = DataExportService();

// JSONエクスポート
await exportService.exportAndShare(format: ExportFormat.json);

// CSVエクスポート
await exportService.exportAndShare(format: ExportFormat.csv);

// サマリー取得
final summary = await exportService.getExportSummary();
print('タスク数: ${summary.taskCount}');
print('完了履歴数: ${summary.completionHistoryCount}');
```

### 2. データ削除機能

#### DataDeletionService (`lib/services/data_deletion_service.dart`)

**機能:**
- すべてのユーザーデータの完全削除
- 完了履歴のみの削除
- XPのみのリセット
- 古い履歴の削除（期間指定）
- 削除前の確認情報表示
- 削除後の検証

**GDPR/CCPA準拠:**
- 「忘れられる権利」のサポート
- 完全なデータ削除
- 削除の検証機能

**使用例:**
```dart
final deletionService = DataDeletionService();

// 削除前のサマリー取得
final summary = await deletionService.getDeletionSummary();
print(summary.summary);

// すべてのデータを削除
await deletionService.deleteAllUserData();

// 完了履歴のみ削除
await deletionService.deleteCompletionHistoryOnly();

// XPのみリセット
await deletionService.deleteXpDataOnly();

// 90日より古い履歴を削除
final deletedCount = await deletionService.deleteOldCompletionHistory(
  Duration(days: 90),
);

// 削除の検証
final verified = await deletionService.verifyDataDeletion();
```

### 3. プライバシー設定画面

#### PrivacySettingsScreen (`lib/screens/privacy_settings_screen.dart`)

**機能:**
- データエクスポート（JSON/CSV）
- データ削除（全体/部分）
- プライバシーポリシーの表示
- 利用規約の表示
- データの権利に関する説明

**UI構成:**
```
プライバシーとデータ管理
├── データのエクスポート
│   ├── JSON形式でエクスポート
│   └── CSV形式でエクスポート
├── データの削除
│   ├── すべてのデータを削除
│   ├── 完了履歴のみを削除
│   └── XPをリセット
├── 規約とポリシー
│   ├── プライバシーポリシー
│   └── 利用規約
└── データの権利について（説明文）
```

**ユーザーフロー:**
1. エクスポート選択 → サマリー確認 → エクスポート実行 → 共有
2. 削除選択 → 確認ダイアログ → 削除実行 → 完了通知

## 法的コンプライアンス

### GDPR（EU一般データ保護規則）準拠

✅ **実装済みの要件:**
1. **データアクセス権**: ユーザーはいつでもデータをエクスポート可能
2. **データポータビリティ**: JSON/CSV形式でデータを移行可能
3. **忘れられる権利**: 完全なデータ削除機能
4. **透明性**: プライバシーポリシーで明確に説明
5. **データ最小化**: 必要最小限のデータのみ収集
6. **ローカル保存**: 個人データは外部に送信されない

### CCPA（カリフォルニア州消費者プライバシー法）準拠

✅ **実装済みの要件:**
1. **情報へのアクセス権**: データエクスポート機能
2. **削除権**: 全データ削除機能
3. **オプトアウト権**: データは第三者に共有されない
4. **通知**: プライバシーポリシーで収集データを明記

## プライバシーポリシーの内容

### 主要セクション:
1. **収集する情報** - タスク、履歴、XP、リマインダー設定
2. **情報の使用目的** - アプリ機能提供、進捗管理
3. **情報の共有** - 第三者との共有なし
4. **データの保存場所** - デバイス内ローカル保存
5. **ユーザーの権利** - エクスポート、削除の権利
6. **GDPR/CCPA準拠** - 準拠の明記
7. **第三者サービス** - 使用するライブラリの説明
8. **子供のプライバシー** - 13歳未満の保護
9. **ポリシーの変更** - 更新時の通知
10. **お問い合わせ** - サポート窓口

## 利用規約の内容

### 主要セクション:
1. **規約の適用** - 同意の確認
2. **サービスの説明** - アプリの目的
3. **ユーザーの責任** - 適切な使用
4. **知的財産権** - 著作権の保護
5. **免責事項** - 責任の制限
6. **サービスの変更と終了** - 開発者の権利
7. **データのバックアップ** - ユーザーの推奨事項
8. **規約の変更** - 更新時の通知
9. **準拠法** - 管轄法域
10. **お問い合わせ** - サポート窓口

## 技術的な詳細

### 依存パッケージ

```yaml
dependencies:
  path_provider: ^2.1.5  # 一時ファイル保存
  share_plus: ^10.1.3    # ファイル共有
```

### データフロー

#### エクスポート:
```
User Request
    ↓
Get Summary → Show Confirmation Dialog
    ↓
Collect Data from Hive Boxes
    ↓
Format Data (JSON/CSV)
    ↓
Write to Temporary File
    ↓
Share via Platform Share Sheet
```

#### 削除:
```
User Request
    ↓
Get Deletion Summary → Show Warning Dialog
    ↓
Confirm Deletion
    ↓
Clear Hive Boxes
    ↓
Verify Deletion
    ↓
Show Success Message
```

### セキュリティ考慮事項

1. **ローカル保存**: データは外部サーバーに送信されない
2. **暗号化なし**: Hiveは暗号化なしでデータを保存（将来的に改善可能）
3. **アクセス制御**: OSレベルのサンドボックスで保護
4. **削除の完全性**: Hive.deleteFromDisk()で完全削除

## 使用方法

### プライバシー設定画面へのナビゲーション

```dart
// メイン画面から設定を開く
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const PrivacySettingsScreen(),
  ),
);
```

### データエクスポートの実装例

```dart
Future<void> exportUserData() async {
  final exportService = DataExportService();

  try {
    // エクスポート実行
    await exportService.exportAndShare(format: ExportFormat.json);

    // 成功
    print('エクスポート完了');
  } on DataExportException catch (e) {
    // エラーハンドリング
    print('エクスポート失敗: $e');
  }
}
```

### データ削除の実装例

```dart
Future<void> deleteUserData() async {
  final deletionService = DataDeletionService();

  // サマリー取得
  final summary = await deletionService.getDeletionSummary();

  if (!summary.hasData) {
    print('削除するデータがありません');
    return;
  }

  // 確認ダイアログを表示してから削除
  final confirmed = await showConfirmDialog();

  if (confirmed) {
    try {
      await deletionService.deleteAllUserData();

      // 検証
      final verified = await deletionService.verifyDataDeletion();
      print('削除完了: $verified');
    } on DataDeletionException catch (e) {
      print('削除失敗: $e');
    }
  }
}
```

## テスト

### ユニットテスト

```dart
test('exports data to JSON', () async {
  final exportService = DataExportService();
  final json = await exportService.exportToJson();

  expect(json, isNotEmpty);
  final data = jsonDecode(json);
  expect(data['version'], '1.0');
  expect(data['tasks'], isA<List>());
});

test('deletes all user data', () async {
  final deletionService = DataDeletionService();

  // データ追加
  await addTestData();

  // 削除実行
  await deletionService.deleteAllUserData();

  // 検証
  final verified = await deletionService.verifyDataDeletion();
  expect(verified, true);
});
```

## 今後の改善

### 短期的な改善
1. データエクスポートの自動スケジュール機能
2. エクスポートデータの暗号化オプション
3. インポート機能（JSON/CSVから復元）
4. データのバージョン管理

### 長期的な改善
1. クラウド同期（オプトイン）
2. データの差分エクスポート
3. 複数デバイス間の同期
4. データアクセスログの記録

## トラブルシューティング

### エクスポートが失敗する

**原因:** ストレージ権限がない、または一時ディレクトリにアクセスできない

**解決策:**
```dart
try {
  await exportService.exportAndShare(format: ExportFormat.json);
} on DataExportException catch (e) {
  print('エラー: $e');
  // ユーザーに適切なメッセージを表示
}
```

### 削除が完了しない

**原因:** Hive Boxが開いていない、または書き込み権限がない

**解決策:**
```dart
// Boxが開いているか確認
if (!Hive.isBoxOpen('tasks')) {
  await Hive.openBox('tasks');
}
```

## まとめ

Habit Penguinは、ユーザーのプライバシーとデータ管理を最優先に設計されています。GDPR/CCPAに完全準拠し、以下の機能を提供します：

✅ **透明性**: 収集データと使用目的を明確に説明
✅ **コントロール**: いつでもデータをエクスポート・削除可能
✅ **ローカル保存**: 外部サーバーへのデータ送信なし
✅ **準拠性**: GDPR/CCPAの要件を満たす
✅ **ユーザーフレンドリー**: 直感的なUI/UX

この実装により、ユーザーは安心してHabit Penguinを使用でき、自分のデータを完全にコントロールできます。
