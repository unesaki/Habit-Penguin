import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通知タップ時のナビゲーション用のStreamController
final notificationTapStreamProvider =
    StreamProvider<String>((ref) {
  final controller = StreamController<String>.broadcast();

  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
});

/// StreamControllerにアクセスするためのプロバイダー
final notificationTapControllerProvider =
    Provider<StreamController<String>>((ref) {
  return StreamController<String>.broadcast();
});

/// 現在のタブインデックスを管理するプロバイダー
final currentTabIndexProvider = StateProvider<int>((ref) => 1); // デフォルトはHomeタブ
