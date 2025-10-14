import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/data_deletion_service.dart';
import '../services/data_export_service.dart';

/// プライバシーとデータ管理の設定画面
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プライバシーとデータ管理'),
      ),
      body: ListView(
        children: [
          // データエクスポートセクション
          _SectionHeader(title: 'データのエクスポート'),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('JSON形式でエクスポート'),
            subtitle: const Text('すべてのデータを構造化されたJSON形式で保存'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportData(context, ExportFormat.json),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('CSV形式でエクスポート'),
            subtitle: const Text('タスクと履歴をCSVファイルとして保存'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportData(context, ExportFormat.csv),
          ),
          const Divider(),

          // データ削除セクション
          _SectionHeader(title: 'データの削除'),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              'すべてのデータを削除',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('タスク、履歴、XPをすべて削除します'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDeleteAllDataDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.clear_all),
            title: const Text('完了履歴のみを削除'),
            subtitle: const Text('タスクとXPは保持されます'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDeleteHistoryDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('XPをリセット'),
            subtitle: const Text('タスクと履歴は保持されます'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showResetXpDialog(context),
          ),
          const Divider(),

          // ポリシーセクション
          _SectionHeader(title: '規約とポリシー'),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPrivacyPolicy(context),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showTermsOfService(context),
          ),
          const Divider(),

          // 情報セクション
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'データの権利について',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Habit Penguinはあなたのデータを尊重します。すべてのデータはデバイス内にローカルで保存され、'
                  '外部サーバーには送信されません。GDPR/CCPAに準拠し、いつでもデータをエクスポートまたは削除できます。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, ExportFormat format) async {
    final exportService = DataExportService();

    // エクスポート前の確認
    final summary = await exportService.getExportSummary();

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データをエクスポート'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('以下のデータをエクスポートします:'),
            const SizedBox(height: 8),
            Text('• タスク: ${summary.taskCount}件'),
            Text('• 完了履歴: ${summary.completionHistoryCount}件'),
            Text('• 現在のXP: ${summary.currentXp}'),
            const SizedBox(height: 16),
            Text(
              format == ExportFormat.json
                  ? 'JSON形式でエクスポートします'
                  : 'CSV形式（2ファイル）でエクスポートします',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('エクスポート'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // エクスポート実行
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('エクスポート中...'),
                ],
              ),
            ),
          ),
        ),
      );

      await exportService.exportAndShare(format: format);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // ローディングダイアログを閉じる

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データをエクスポートしました')),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // ローディングダイアログを閉じる

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エクスポートに失敗しました: $e')),
      );
    }
  }

  Future<void> _showDeleteAllDataDialog(BuildContext context) async {
    final deletionService = DataDeletionService();
    final summary = await deletionService.getDeletionSummary();

    if (!summary.hasData) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除するデータがありません')),
      );
      return;
    }

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ すべてのデータを削除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('この操作は取り消せません。'),
            const SizedBox(height: 16),
            Text(summary.summary),
            const SizedBox(height: 16),
            const Text(
              '本当にすべてのデータを削除しますか？',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await deletionService.deleteAllUserData();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべてのデータを削除しました')),
      );

      // 設定画面を閉じる
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }

  Future<void> _showDeleteHistoryDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('完了履歴を削除'),
        content: const Text(
          'すべての完了履歴を削除します。タスクとXPは保持されます。\n\n'
          'この操作は取り消せません。続けますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final deletionService = DataDeletionService();
      await deletionService.deleteCompletionHistoryOnly();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('完了履歴を削除しました')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }

  Future<void> _showResetXpDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('XPをリセット'),
        content: const Text(
          'XPを0にリセットします。タスクと完了履歴は保持されます。\n\n'
          'この操作は取り消せません。続けますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('リセット'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final deletionService = DataDeletionService();
      await deletionService.deleteXpDataOnly();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('XPをリセットしました')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('リセットに失敗しました: $e')),
      );
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const _PolicyScreen(
          title: 'プライバシーポリシー',
          policyType: _PolicyType.privacy,
        ),
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const _PolicyScreen(
          title: '利用規約',
          policyType: _PolicyType.terms,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

enum _PolicyType { privacy, terms }

class _PolicyScreen extends StatelessWidget {
  final String title;
  final _PolicyType policyType;

  const _PolicyScreen({
    required this.title,
    required this.policyType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          policyType == _PolicyType.privacy
              ? _getPrivacyPolicyText()
              : _getTermsOfServiceText(),
          style: const TextStyle(height: 1.5),
        ),
      ),
    );
  }

  String _getPrivacyPolicyText() {
    return '''プライバシーポリシー

最終更新日: ${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日

Habit Penguin（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めます。

1. 収集する情報

本アプリは以下の情報をローカルに保存します：
• タスク情報（名前、アイコン、難易度、スケジュール）
• タスク完了履歴
• 獲得経験値（XP）
• リマインダー設定

2. 情報の使用目的

収集した情報は以下の目的でのみ使用されます：
• アプリの機能提供
• ユーザーの進捗管理
• 統計情報の表示

3. 情報の共有

本アプリは、ユーザーの個人情報を第三者と共有することはありません。すべてのデータはユーザーのデバイス内にローカルで保存され、外部サーバーに送信されることはありません。

4. データの保存場所

すべてのデータは、ユーザーのデバイス内にローカルで保存されます。データは暗号化されず、デバイスの他のアプリからはアクセスできません。

5. ユーザーの権利

ユーザーは以下の権利を有します：
• データのエクスポート（JSON/CSV形式）
• データの削除（部分的または全体）
• アプリのアンインストールによる完全なデータ削除

6. GDPR/CCPA準拠

本アプリは、GDPR（EU一般データ保護規則）およびCCPA（カリフォルニア州消費者プライバシー法）に準拠しています。ユーザーは「忘れられる権利」を有し、いつでもすべてのデータを削除できます。

7. 第三者サービス

本アプリは、以下の第三者サービスを使用する場合があります：
• ローカル通知（flutter_local_notifications）
• ファイル共有（share_plus）

これらのサービスは、個人情報を収集しません。

8. 子供のプライバシー

本アプリは、13歳未満の子供から意図的に個人情報を収集しません。

9. ポリシーの変更

本プライバシーポリシーは、必要に応じて更新される場合があります。重要な変更がある場合は、アプリ内で通知します。

10. お問い合わせ

プライバシーに関するご質問は、以下までお問い合わせください：
[メールアドレスを追加]

本ポリシーに同意することで、上記の条件を承認したものとみなされます。''';
  }

  String _getTermsOfServiceText() {
    return '''利用規約

最終更新日: ${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日

Habit Penguin（以下「本アプリ」）の利用規約をお読みください。

1. 規約の適用

本規約は、ユーザーと本アプリの開発者との間で適用されます。本アプリを使用することで、これらの規約に同意したものとみなされます。

2. サービスの説明

本アプリは、習慣トラッキングおよびタスク管理のためのツールです。ユーザーは、タスクの作成、完了、進捗の追跡ができます。

3. ユーザーの責任

ユーザーは以下に同意します：
• 本アプリを合法的な目的でのみ使用すること
• 他者の権利を侵害しないこと
• 不適切または違法なコンテンツを作成しないこと

4. 知的財産権

本アプリおよびそのコンテンツ（テキスト、グラフィック、ロゴ、アイコンなど）は、開発者の知的財産であり、著作権法により保護されています。

5. 免責事項

本アプリは「現状のまま」提供されます。開発者は、以下について一切の責任を負いません：
• アプリの中断または遅延
• データの損失または破損
• アプリの使用によるいかなる損害

6. サービスの変更と終了

開発者は、予告なく本アプリの機能を変更、一時停止、または終了する権利を有します。

7. データのバックアップ

ユーザーは、重要なデータを定期的にエクスポートしてバックアップすることを推奨します。開発者は、データの損失について責任を負いません。

8. 規約の変更

本規約は、必要に応じて更新される場合があります。重要な変更がある場合は、アプリ内で通知します。

9. 準拠法

本規約は、[管轄地域]の法律に準拠します。

10. お問い合わせ

利用規約に関するご質問は、以下までお問い合わせください：
[メールアドレスを追加]

本規約に同意することで、上記の条件を承認したものとみなされます。''';
  }
}
