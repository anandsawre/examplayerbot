import 'dart:js_interop';
import 'package:web/web.dart' as web;

class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  bool get isTelegramWebApp {
    try {
      final tg = (web.window as dynamic).Telegram?.WebApp;
      return tg != null && tg.initData != null && (tg.initData as String).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String? get initData {
    try {
      final tg = (web.window as dynamic).Telegram?.WebApp;
      return tg?.initData as String?;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get user {
    try {
      final tg = (web.window as dynamic).Telegram?.WebApp;
      final userObj = tg?.initDataUnsafe?.user;
      if (userObj == null) return null;
      return {
        'id': userObj.id,
        'first_name': userObj.first_name,
        'last_name': userObj.last_name,
        'username': userObj.username,
        'photo_url': userObj.photo_url,
      };
    } catch (_) {
      return null;
    }
  }

  void ready() {
    try {
      (web.window as dynamic).Telegram?.WebApp?.ready?.call();
    } catch (_) {}
  }

  void expand() {
    try {
      (web.window as dynamic).Telegram?.WebApp?.expand?.call();
    } catch (_) {}
  }

  void hapticImpact([String style = 'medium']) {
    try {
      (web.window as dynamic).Telegram?.WebApp?.HapticFeedback?.impactOccurred?.call(style.toJS);
    } catch (_) {}
  }

  void hapticNotification([String type = 'success']) {
    try {
      (web.window as dynamic).Telegram?.WebApp?.HapticFeedback?.notificationOccurred?.call(type.toJS);
    } catch (_) {}
  }
}
