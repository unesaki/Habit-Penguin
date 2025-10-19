# アプリアイコンとスプラッシュスクリーン実装ドキュメント

## 概要
このドキュメントでは、Habit Penguinアプリに実装されたアプリアイコンとスプラッシュスクリーンについて説明します。

## 実装日
2025年10月19日

## 使用アセット

### 1. アプリアイコン
- **ファイル名**: `icon_check.png`
- **サイズ**: 160x160 pixels
- **フォーマット**: PNG (8-bit RGB)
- **説明**: チェックマークのデザインのアプリアイコン

### 2. スプラッシュスクリーン
- **ファイル名**: `splash_heart.png`
- **サイズ**: 1024x1536 pixels
- **フォーマット**: PNG (8-bit RGB)
- **説明**: ハート型のデザインのスプラッシュ画像

## 使用パッケージ

### flutter_launcher_icons (v0.14.4)
アプリアイコンを自動生成するパッケージ。

**機能:**
- Android用アイコンを複数解像度で自動生成
- iOS用アイコンを複数解像度で自動生成
- アルファチャンネルの自動削除（iOS）

### flutter_native_splash (v2.4.7)
ネイティブスプラッシュスクリーンを自動生成するパッケージ。

**機能:**
- Android用スプラッシュスクリーン（通常版・ダークモード版）
- Android 12以降用スプラッシュスクリーン
- iOS用スプラッシュスクリーン（通常版・ダークモード版）
- 背景色のカスタマイズ

## pubspec.yaml設定

### アセットの登録
```yaml
assets:
  - assets/icon_check.png
  - assets/splash_heart.png
```

### アイコン設定
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon_check.png"
  min_sdk_android: 21
  remove_alpha_ios: true
```

### スプラッシュスクリーン設定
```yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: assets/splash_heart.png
  color_dark: "#1E1E1E"
  image_dark: assets/splash_heart.png
  android_12:
    image: assets/splash_heart.png
    color: "#FFFFFF"
    image_dark: assets/splash_heart.png
    color_dark: "#1E1E1E"
  android: true
  ios: true
  web: false
```

## 生成コマンド

### アイコンの生成
```bash
dart run flutter_launcher_icons
```

**生成されるファイル:**
- Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
  - mdpi (48x48)
  - hdpi (72x72)
  - xhdpi (96x96)
  - xxhdpi (144x144)
  - xxxhdpi (192x192)

- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
  - 複数サイズのアイコン（20pt - 1024pt）

### スプラッシュスクリーンの生成
```bash
dart run flutter_native_splash:create
```

**生成されるファイル:**
- Android:
  - `android/app/src/main/res/drawable-*/splash.png`
  - `android/app/src/main/res/drawable-*/android12splash.png`
  - `android/app/src/main/res/drawable*/launch_background.xml`
  - `android/app/src/main/res/values*/styles.xml`

- iOS:
  - `ios/Runner/Assets.xcassets/LaunchImage.imageset/`
  - `ios/Runner/Info.plist`（更新）

## カラースキーム

### ライトモード
- 背景色: `#FFFFFF` (白)
- スプラッシュ画像: `splash_heart.png`

### ダークモード
- 背景色: `#1E1E1E` (ダークグレー)
- スプラッシュ画像: `splash_heart.png`（同じ画像）

## 対応プラットフォーム

### Android
- ✅ 通常のアプリアイコン
- ✅ スプラッシュスクリーン（Android 12未満）
- ✅ スプラッシュスクリーン（Android 12以降）
- ✅ ダークモード対応
- 最小SDK: API 21 (Android 5.0 Lollipop)

### iOS
- ✅ アプリアイコン
- ✅ スプラッシュスクリーン
- ✅ ダークモード対応
- アルファチャンネル: 自動削除

### Web
- ❌ 未対応（現時点では不要）

## 実装の詳細

### Android 12以降の対応

Android 12からスプラッシュスクリーンAPIが変更されたため、専用の設定が追加されています。

**特徴:**
- システム標準のスプラッシュスクリーン体験
- アイコンとブランドイメージを表示
- アニメーション効果（システム提供）

**設定ファイル:**
- `android/app/src/main/res/values-v31/styles.xml`
- `android/app/src/main/res/values-night-v31/styles.xml`

### iOSのステータスバー

スプラッシュスクリーン表示中、ステータスバーは自動的に管理されます。

**設定:**
`ios/Runner/Info.plist`に以下が追加されます：
```xml
<key>UIStatusBarHidden</key>
<false/>
<key>UIViewControllerBasedStatusBarAppearance</key>
<false/>
```

## テストとデバッグ

### アイコンの確認方法

**Android:**
1. エミュレータまたは実機でアプリをインストール
2. ホーム画面でアイコンを確認
3. アプリドロワーでアイコンを確認

**iOS:**
1. シミュレータまたは実機でアプリをインストール
2. ホーム画面でアイコンを確認

### スプラッシュスクリーンの確認方法

**Android:**
```bash
flutter run
```
アプリ起動時にスプラッシュスクリーンが表示されます。

**ダークモードの確認:**
1. デバイスの設定でダークモードを有効化
2. アプリを起動
3. ダークモード用の背景色とスプラッシュが表示されることを確認

**iOS:**
```bash
flutter run
```
アプリ起動時にスプラッシュスクリーンが表示されます。

## 更新方法

### アイコンを変更する場合

1. 新しいアイコン画像を`assets/`に配置
2. `pubspec.yaml`の`image_path`を更新
3. アイコンを再生成：
   ```bash
   dart run flutter_launcher_icons
   ```

### スプラッシュスクリーンを変更する場合

1. 新しいスプラッシュ画像を`assets/`に配置
2. `pubspec.yaml`の`image`を更新
3. 背景色を変更する場合は`color`と`color_dark`を更新
4. スプラッシュスクリーンを再生成：
   ```bash
   dart run flutter_native_splash:create
   ```

## トラブルシューティング

### アイコンが更新されない

**Android:**
```bash
flutter clean
flutter pub get
dart run flutter_launcher_icons
flutter run
```

**iOS:**
```bash
flutter clean
cd ios
pod install
cd ..
dart run flutter_launcher_icons
flutter run
```

### スプラッシュスクリーンが表示されない

1. 生成コマンドを再実行：
   ```bash
   dart run flutter_native_splash:create
   ```

2. クリーンビルド：
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. AndroidManifest.xmlとInfo.plistが正しく更新されているか確認

### ダークモードが機能しない

1. `pubspec.yaml`に`color_dark`と`image_dark`が設定されているか確認
2. スプラッシュスクリーンを再生成
3. デバイスのダークモード設定を確認

## ベストプラクティス

### アイコンのデザイン

1. **サイズ**: 最低512x512ピクセル以上を推奨
2. **フォーマット**: PNG（透過背景可）
3. **デザイン**: シンプルで認識しやすいデザイン
4. **マージン**: 端から少し余白を持たせる

### スプラッシュスクリーンのデザイン

1. **サイズ**: 高解像度（1024x1536以上）を推奨
2. **アスペクト比**: 複数のデバイスサイズを考慮
3. **コンテンツ**: 中央に主要な要素を配置
4. **ファイルサイズ**: 500KB以下を推奨（読み込み速度のため）

## セキュリティとプライバシー

- アイコンとスプラッシュスクリーンにはユーザーの個人情報を含めない
- ブランドガイドラインに従う
- 著作権に注意（すべての画像は適切にライセンスされていること）

## パフォーマンス

### スプラッシュスクリーン表示時間

- Android: システムが自動的に管理（通常1-2秒）
- iOS: アプリの初期化が完了するまで表示

### 最適化

- スプラッシュ画像のファイルサイズを最適化
- 不要な解像度の画像を削除しない（各デバイスに最適化されている）

## 今後の拡張予定

1. **アニメーション付きスプラッシュスクリーン**
   - Lottieアニメーションの追加
   - カスタムアニメーション効果

2. **アダプティブアイコン（Android）**
   - フォアグラウンドとバックグラウンドの分離
   - 動的な形状対応

3. **複数のアイコンバリアント**
   - 季節ごとのアイコン
   - イベント限定アイコン

## まとめ

アプリアイコンとスプラッシュスクリーンの実装により、Habit Penguinアプリのブランディングが強化されました。

**実装完了:**
- ✅ Android/iOS用アプリアイコン（複数解像度）
- ✅ Android/iOS用スプラッシュスクリーン
- ✅ ダークモード対応
- ✅ Android 12以降の新APIに対応

**次のステップ:**
- ストア申請用のスクリーンショット作成
- プロモーション画像の作成
- ブランドガイドラインの策定
