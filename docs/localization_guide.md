# 多言語化（i18n）実装ガイド

このドキュメントでは、Habit Penguinアプリの多言語化（国際化 - Internationalization）の実装について説明します。

## 目次

1. [概要](#概要)
2. [セットアップ](#セットアップ)
3. [使用方法](#使用方法)
4. [新しい文字列の追加](#新しい文字列の追加)
5. [日付・時刻のローカライゼーション](#日付時刻のローカライゼーション)
6. [ベストプラクティス](#ベストプラクティス)
7. [トラブルシューティング](#トラブルシューティング)

---

## 概要

Habit Penguinは以下の言語をサポートしています：

- **日本語（ja）** - デフォルト言語
- **英語（en）** - 第二言語

### 技術スタック

- **Flutter Intl**: Flutter公式の国際化パッケージ
- **ARBファイル**: Application Resource Bundle形式で文字列を管理
- **自動生成**: `flutter gen-l10n`コマンドで型安全なローカライゼーションクラスを生成

---

## セットアップ

### 1. 依存関係

`pubspec.yaml`に以下が追加されています：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

### 2. 設定ファイル

`l10n.yaml`でローカライゼーション設定を管理：

```yaml
arb-dir: lib/l10n
template-arb-file: app_ja.arb
output-localization-file: app_localizations.dart
```

### 3. アプリケーション設定

`lib/main.dart`でローカライゼーションを有効化：

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HabitPenguinApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''), // 日本語
        Locale('en', ''), // 英語
      ],
      // ...
    );
  }
}
```

---

## 使用方法

### 基本的な使い方

Widgetのbuild メソッド内で`AppLocalizations.of(context)`を使用します：

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  return Text(l10n.appTitle); // "Habit Penguin"
}
```

### パラメータ付き文字列

ARBファイルでプレースホルダーを定義：

```json
{
  "currentXp": "経験値: {xp} XP",
  "@currentXp": {
    "description": "現在のXP表示",
    "placeholders": {
      "xp": {
        "type": "int",
        "example": "150"
      }
    }
  }
}
```

Dartコードで使用：

```dart
Text(l10n.currentXp(150)); // "経験値: 150 XP" (日本語)
                           // "XP: 150 XP" (英語)
```

### ヘルパークラスの使用

`L10nHelper`クラスを使用すると、より簡潔に記述できます：

```dart
import 'package:habit_penguin/l10n/l10n_helper.dart';

// AppLocalizationsの取得
final l10n = L10nHelper.of(context);

// 日付のフォーマット
final formattedDate = L10nHelper.formatDate(context, DateTime.now());
// 日本語: "2025/01/15"
// 英語: "Jan 15, 2025"

// 時刻のフォーマット
final formattedTime = L10nHelper.formatTimeOfDay(context, TimeOfDay(hour: 9, minute: 30));
// 日本語: "09:30"
// 英語: "9:30 AM"
```

---

## 新しい文字列の追加

### 手順

1. **日本語ARBファイルに追加** (`lib/l10n/app_ja.arb`)

```json
{
  "newFeature": "新機能",
  "@newFeature": {
    "description": "新機能のタイトル"
  }
}
```

2. **英語ARBファイルに追加** (`lib/l10n/app_en.arb`)

```json
{
  "newFeature": "New Feature"
}
```

3. **自動生成を実行**

```bash
flutter gen-l10n
```

または、ビルド時に自動生成されます：

```bash
flutter pub get
```

4. **コードで使用**

```dart
Text(l10n.newFeature)
```

### 複数のパラメータを持つ文字列

```json
{
  "taskInfo": "{taskName}は{difficulty}で、{xp} XPを獲得できます。",
  "@taskInfo": {
    "description": "タスク情報の表示",
    "placeholders": {
      "taskName": {
        "type": "String",
        "example": "朝の運動"
      },
      "difficulty": {
        "type": "String",
        "example": "Normal"
      },
      "xp": {
        "type": "int",
        "example": "30"
      }
    }
  }
}
```

使用例：

```dart
l10n.taskInfo('朝の運動', 'Normal', 30)
// "朝の運動はNormalで、30 XPを獲得できます。"
```

---

## 日付・時刻のローカライゼーション

### DateFormatterクラス

`lib/utils/date_formatter.dart`を使用：

```dart
import 'package:habit_penguin/utils/date_formatter.dart';

// 日付フォーマット
final date = DateTime(2025, 1, 15);
DateFormatter.formatDate(date, 'ja'); // "2025/01/15"
DateFormatter.formatDate(date, 'en'); // "Jan 15, 2025"

// 時刻フォーマット
final time = DateTime(2025, 1, 15, 9, 30);
DateFormatter.formatTime(time, 'ja'); // "09:30"
DateFormatter.formatTime(time, 'en'); // "9:30 AM"

// 日付範囲フォーマット
final start = DateTime(2025, 1, 1);
final end = DateTime(2025, 12, 31);
DateFormatter.formatDateRange(start, end, 'ja'); // "2025/01/01 〜 2025/12/31"
DateFormatter.formatDateRange(start, end, 'en'); // "Jan 1, 2025 - Dec 31, 2025"

// 相対日付
DateFormatter.formatRelativeDate(DateTime.now(), 'ja'); // "今日"
DateFormatter.formatRelativeDate(DateTime.now(), 'en'); // "Today"
```

### L10nHelperを使用した簡潔な記述

```dart
// BuildContextから自動的にロケールを取得
final formattedDate = L10nHelper.formatDate(context, DateTime.now());
final formattedTime = L10nHelper.formatTimeOfDay(context, TimeOfDay.now());
```

---

## ベストプラクティス

### 1. 文字列の命名規則

- **キャメルケース**を使用: `createTask`, `completedTasks`
- **動詞を先頭に**: `saveChanges`, `deleteTask`
- **明確で説明的**: `noActiveTasks` > `empty`

### 2. 説明（@description）を必ず追加

```json
{
  "saveButton": "保存",
  "@saveButton": {
    "description": "保存ボタンのラベル" // ← 必須
  }
}
```

### 3. プレースホルダーの型を明示

```json
{
  "xpGained": "{xp} XPを獲得しました！",
  "@xpGained": {
    "placeholders": {
      "xp": {
        "type": "int",  // ← 型を明示
        "example": "30" // ← 例を提供
      }
    }
  }
}
```

### 4. 文脈に応じた文字列の分割

同じ意味でも文脈が異なる場合は別の文字列を定義：

```json
{
  "deleteTaskButton": "削除",      // ボタンラベル
  "deleteTaskTitle": "タスクを削除", // ダイアログタイトル
  "deleteTaskConfirm": "本当に削除しますか？" // 確認メッセージ
}
```

### 5. 複数形の対応

```json
{
  "taskCount": "{count, plural, =0{タスクなし} =1{1個のタスク} other{{count}個のタスク}}",
  "@taskCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

### 6. 日付・時刻は常にフォーマッタを使用

```dart
// ❌ 悪い例
Text('${DateTime.now()}'); // "2025-01-15 14:30:00.000"

// ✅ 良い例
Text(L10nHelper.formatDate(context, DateTime.now())); // "2025/01/15" (ja)
```

---

## 主要な文字列リスト

### 画面タイトル

| キー | 日本語 | 英語 |
|------|--------|------|
| `appTitle` | Habit Penguin | Habit Penguin |
| `tabTasks` | Tasks | Tasks |
| `tabHome` | Home | Home |
| `tabPenguin` | Penguin | Penguin |
| `completedTasks` | 完了済みタスク | Completed Tasks |
| `editTask` | タスクを編集 | Edit Task |
| `addTask` | タスクを追加 | Add Task |

### メッセージ

| キー | 日本語 | 英語 |
|------|--------|------|
| `welcomeBack` | おかえり！ | Welcome back! |
| `questAchieved` | クエスト達成！ | Quest Achieved! |
| `taskDeleted` | タスクを削除しました。 | Task deleted. |
| `alreadyCompletedToday` | 本日は既に完了しています | Already completed today |

### ボタンラベル

| キー | 日本語 | 英語 |
|------|--------|------|
| `ok` | OK | OK |
| `cancel` | キャンセル | Cancel |
| `delete` | 削除 | Delete |
| `saveChanges` | 変更を保存 | Save Changes |
| `createTask` | タスクを作成 | Create Task |

---

## トラブルシューティング

### 1. 生成されたファイルが見つからない

**問題**: `AppLocalizations`が見つからない

**解決策**:

```bash
flutter clean
flutter pub get
flutter gen-l10n
```

### 2. ARBファイルの構文エラー

**問題**: JSONパースエラー

**解決策**: ARBファイルの構文を確認
- カンマの位置
- 引用符の対応
- ブラケットの対応

オンラインJSONバリデーターを使用: https://jsonlint.com/

### 3. プレースホルダーが機能しない

**問題**: `{xp}`が文字列として表示される

**解決策**: ARBファイルでプレースホルダーを定義：

```json
{
  "message": "XP: {xp}",
  "@message": {
    "placeholders": {
      "xp": {
        "type": "int"
      }
    }
  }
}
```

### 4. ロケールが切り替わらない

**問題**: 言語が変わらない

**解決策**:
- デバイスの言語設定を変更
- または、`MaterialApp`の`locale`プロパティを明示的に設定：

```dart
MaterialApp(
  locale: const Locale('en', ''), // 強制的に英語
  // ...
)
```

### 5. ホットリロードで反映されない

**問題**: ARBファイルの変更が反映されない

**解決策**: フルリスタートが必要

```bash
# ホットリロード（R）ではなく、ホットリスタート（Shift+R）
# またはアプリを停止して再起動
```

---

## 拡張方法

### 新しい言語の追加

1. **新しいARBファイルを作成**

```bash
touch lib/l10n/app_fr.arb  # フランス語の例
```

2. **翻訳を追加**

`app_fr.arb`:
```json
{
  "@@locale": "fr",
  "appTitle": "Habit Penguin",
  "welcomeBack": "Bon retour !",
  // ...
}
```

3. **サポートロケールに追加**

`lib/main.dart`:
```dart
supportedLocales: const [
  Locale('ja', ''),
  Locale('en', ''),
  Locale('fr', ''), // フランス語を追加
],
```

4. **DateFormatterを拡張**

`lib/utils/date_formatter.dart`:
```dart
static String formatDate(DateTime date, String locale) {
  if (locale.startsWith('ja')) {
    return DateFormat('yyyy/MM/dd').format(date);
  } else if (locale.startsWith('fr')) {
    return DateFormat('dd/MM/yyyy').format(date);
  } else {
    return DateFormat('MMM d, y').format(date);
  }
}
```

---

## まとめ

### 実装済み機能

- ✅ 日本語・英語の2言語対応
- ✅ ARBファイルによる文字列管理
- ✅ 型安全なローカライゼーション
- ✅ 日付・時刻のロケール対応
- ✅ パラメータ付き文字列のサポート
- ✅ ヘルパークラス（L10nHelper）
- ✅ 主要画面の多言語化（サンプル実装）

### 今後の拡張

1. **全画面の多言語化**
   - すべてのハードコードされた文字列をARBファイルに移行
   - 各画面でl10nを使用するようにリファクタリング

2. **追加言語のサポート**
   - 中国語（簡体字・繁体字）
   - スペイン語
   - ドイツ語
   など

3. **動的な言語切り替え**
   - アプリ内設定で言語を選択
   - デバイス設定に依存しない独立した言語設定

4. **RTL（右から左）レイアウトのサポート**
   - アラビア語、ヘブライ語などへの対応

---

## 参考リンク

- [Flutter Internationalization](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization)
- [ARB File Format](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- [Flutter Intl Package](https://pub.dev/packages/intl)
- [DateFormat Class](https://pub.dev/documentation/intl/latest/intl/DateFormat-class.html)
