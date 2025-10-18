# オンボーディング機能実装ドキュメント

## 概要
このドキュメントでは、Habit Penguinアプリに実装されたオンボーディング機能について説明します。

## 実装内容

### 1. オンボーディング画面（OnboardingScreen）

初回起動時に表示される、アプリの使い方を説明する4画面構成のフロー。

#### 画面構成

1. **ウェルカム画面**
   - アプリの紹介と歓迎メッセージ
   - ペンギンアイコンを表示

2. **機能紹介1：XPとレベルシステム**
   - タスク完了でXPを獲得できることを説明
   - 難易度別のXP獲得量を表示
     - Easy: 10 XP
     - Normal: 20 XP
     - Hard: 30 XP

3. **機能紹介2：習慣トラッキング**
   - ストリーク機能の説明
   - リマインダーと完了履歴の紹介

4. **サンプルタスク選択画面**
   - サンプルタスクの自動作成オプション
   - ゼロから始めるオプション

#### 実装ファイル
- `lib/screens/onboarding_screen.dart`

### 2. オンボーディング状態管理（OnboardingService）

初回起動フラグを管理するサービス。

#### 主要メソッド

```dart
class OnboardingService {
  // オンボーディングが完了しているかどうかを取得
  bool get hasCompletedOnboarding;

  // オンボーディングを完了としてマーク
  Future<void> completeOnboarding();

  // オンボーディング状態をリセット（開発・テスト用）
  Future<void> resetOnboarding();
}
```

#### データ保存
- Hiveの`appState`ボックスに`hasCompletedOnboarding`キーで保存
- デフォルト値: `false`

#### 実装ファイル
- `lib/services/onboarding_service.dart`

### 3. サンプルタスク作成機能（SampleTasksService）

新規ユーザー向けにサンプルタスクを自動作成する機能。

#### サンプルタスク（日本語）

1. **朝の散歩** - Easy - 7:00リマインダー
2. **読書 30分** - Normal - 20:00リマインダー
3. **水を8杯飲む** - Easy - リマインダーなし
4. **筋トレ** - Hard - 18:00リマインダー

#### サンプルタスク（英語）

1. **Morning Walk** - Easy - 7:00リマインダー
2. **Read for 30min** - Normal - 20:00リマインダー
3. **Drink 8 glasses of water** - Easy - リマインダーなし
4. **Workout** - Hard - 18:00リマインダー

#### 実装ファイル
- `lib/services/sample_tasks_service.dart`

### 4. 空状態の改善（EmptyStateWidget）

タスクがない場合に表示される、ユーザーフレンドリーな空状態画面。

#### 表示内容
- タスク追加アイコン（大）
- タイトル：「タスクを追加して始めましょう」
- 説明：「右下の＋ボタンをタップして、最初の習慣タスクを作成しましょう。」
- アクションボタン：「最初のタスクを作成」

#### 実装場所
- `lib/main.dart` 内の `_EmptyStateWidget` クラス

### 5. ヘルプとFAQ

#### FAQ画面（FaqScreen）

よくある質問とその回答を表示する画面。

**質問項目（10項目）:**
1. タスクを完了するとどうなりますか？
2. ストリーク（連続記録）とは何ですか？
3. タスクの難易度はどのように選べばいいですか？
4. リマインダー通知が届きません
5. タスクを削除してしまいました。復元できますか？
6. タスクの順番を変更できますか？
7. 複数のタスクを一度に削除できますか？
8. データはどこに保存されますか？
9. データをバックアップできますか？
10. オンボーディングをもう一度見たい

**実装ファイル:**
- `lib/screens/faq_screen.dart`

#### 使い方ガイド画面（HowToUseScreen）

アプリの主要機能の使い方を説明する画面。

**ガイドセクション（8セクション）:**
1. タスクの作成
2. タスクの完了
3. タスクの編集
4. タスクの並び替え
5. タスクの削除
6. 取り消し機能
7. リマインダーの設定
8. データ管理

**実装ファイル:**
- `lib/screens/how_to_use_screen.dart`

### 6. 多言語対応

オンボーディング、FAQ、使い方ガイドのすべてのテキストを日本語と英語で提供。

#### 追加された翻訳キー

**オンボーディング関連:**
- `onboardingWelcomeTitle`
- `onboardingWelcomeDescription`
- `onboardingFeature1Title` / `Description` / `Point1-3`
- `onboardingFeature2Title` / `Description` / `Point1-3`
- `onboardingSampleTitle` / `Description`
- `onboardingCreateSampleTasks`
- `onboardingStartFromScratch`
- `onboardingNext` / `Back`

**空状態関連:**
- `emptyStateTitle`
- `emptyStateDescription`
- `emptyStateCreateTask`

#### 実装ファイル
- `lib/l10n/app_ja.arb`
- `lib/l10n/app_en.arb`

### 7. Riverpodプロバイダー

```dart
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  final box = Hive.box('appState');
  return OnboardingService(box);
});
```

#### 実装ファイル
- `lib/providers/providers.dart`

### 8. アプリ起動時の統合

`main.dart`の`_HabitHomeShellState.initState()`で、初回起動時にオンボーディング画面を自動表示。

```dart
// 初回起動時にオンボーディング画面を表示
final onboardingService = ref.read(onboardingServiceProvider);
if (!onboardingService.hasCompletedOnboarding) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const OnboardingScreen(),
      fullscreenDialog: true,
    ),
  );
}
```

## ユーザーフロー

### 初回起動時
1. アプリ起動
2. `OnboardingService`が`hasCompletedOnboarding`をチェック（false）
3. オンボーディング画面を全画面ダイアログとして表示
4. ユーザーが4つの画面をナビゲート
5. 最後の画面で「サンプルタスクを作成」または「ゼロから始める」を選択
6. オンボーディング完了フラグを保存
7. メイン画面に戻る

### 2回目以降の起動
1. アプリ起動
2. `OnboardingService`が`hasCompletedOnboarding`をチェック（true）
3. オンボーディングをスキップし、直接メイン画面を表示

## テスト

### 開発時のリセット方法

オンボーディングを再度テストする場合：

```dart
// 開発中のみ使用
final onboardingService = ref.read(onboardingServiceProvider);
await onboardingService.resetOnboarding();
```

または、アプリデータを完全に削除：
```bash
flutter clean
# アプリを再インストール
```

## UX設計の考慮事項

1. **スキップできない設計**
   - 初回起動時は必ずオンボーディングを完了する必要がある
   - アプリの基本機能を理解してもらうため

2. **サンプルタスクの提供**
   - すぐに機能を試せるようにサンプルタスクを提供
   - ゼロから始めるオプションも提供し、選択の自由を確保

3. **視覚的なフィードバック**
   - ページインジケーター（ドット）で進捗を表示
   - アイコンと色を使って視認性を向上

4. **多言語対応**
   - デバイスの言語設定に基づいて自動的に日本語/英語を切り替え

5. **ヘルプへのアクセス**
   - 設定画面から「FAQ」と「使い方ガイド」にいつでもアクセス可能
   - オンボーディングを見逃しても、後から確認できる

## 今後の拡張予定

1. **オンボーディングの再表示機能**
   - 設定画面から再度オンボーディングを表示できる機能

2. **コンテキストヘルプ**
   - 主要な機能の初回使用時にツールチップを表示

3. **アプリ内ガイドツアー**
   - 実際の画面を使った対話的なチュートリアル

## まとめ

この実装により、Phase 1の最後の必須タスク「オンボーディングと空状態」が完了しました。
新規ユーザーは、アプリの使い方を理解しやすくなり、より良い初期体験を得られるようになりました。

**Phase 1（MVPリリース準備）: 100%完了** ✅
