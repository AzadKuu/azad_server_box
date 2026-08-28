import 'dart:async';

import 'package:flutter/services.dart';

/// 鸿蒙软键盘退格键处理。
///
/// 鸿蒙的 `TextInputPlugin.handleDeleteEvent` 在选区为 (0,0) 时直接返回不通知
/// Flutter，导致终端退格键无响应。`EntryAbility.ets` 在 ArkTS 层面监听
/// `deleteLeft` 事件并通过 MethodChannel `azad/ime` 通知 Flutter。
///
/// 终端页面在获得焦点时调用 [setBackspaceHandler]，失去焦点时清除。
typedef OhosBackspaceHandler = void Function();

class OhosIme {
  static const _channel = MethodChannel('azad/ime');

  static OhosIme? _instance;
  static OhosIme get _inst => _instance ??= OhosIme._();

  OhosIme._() {
    _channel.setMethodCallHandler((call) async {
      print('OHOS_BS ohos_ime channel: ${call.method} args=${call.arguments}');
      if (call.method == 'deleteLeft') {
        _handler?.call();
      }
    });
  }

  OhosBackspaceHandler? _handler;

  /// 设置全局退格键回调。终端获得焦点时调用。
  static void setBackspaceHandler(OhosBackspaceHandler? handler) {
    _inst._handler = handler;
  }

  /// 查询当前设备是否是手机/平板（通过 ArkTS 判断）。
  ///
  /// 注意：2in1（鸿蒙 PC）也返回 true——它在触屏/平板模式下同样依赖软键盘
  /// 退格兜底。如果只想区分设备形态做 UI 决策，请用 [deviceType]。
  static Future<bool> isMobile() async {
    const channel = MethodChannel('azad/device_info');
    try {
      return await channel.invokeMethod<bool>('isMobile') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 获取鸿蒙设备类型原始字符串（如 "phone"、"tablet"、"2in1"、"pc"、"tv"）。
  ///
  /// 这是纯查询，不影响退格 handler 的注册逻辑。
  static Future<String> deviceType() async {
    const channel = MethodChannel('azad/device_info');
    try {
      return await channel.invokeMethod<String>('deviceType') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 是否是带物理键盘的桌面形态设备（2in1 / PC）。
  static Future<bool> isDesktop() async {
    final dt = await deviceType();
    return dt == '2in1' || dt == 'pc';
  }

  /// 获取鸿蒙系统偏好语言（如 "zh-Hans-CN"、"en-US"）。
  ///
  /// 由 EntryAbility.ets 通过 i18n.getAppPreferredLanguage() 提供。
  /// 首次启动时用于设置 Flutter locale，使首启语言与系统一致。
  static Future<String?> getPreferredLanguage() async {
    const channel = MethodChannel('azad/locale');
    try {
      return await channel.invokeMethod<String>('getPreferredLanguage');
    } catch (_) {
      return null;
    }
  }

  /// 把鸿蒙语言标签（如 "zh-Hans-CN"）转为 Flutter locale code（如 "zh"、"zh_TW"）。
  ///
  /// supportedLocales: de, en, es, fr, id, it, ja, ko, nl, pt, ru, tr, uk, zh, zh_TW
  static String? ohosLangToLocaleCode(String ohosLang) {
    if (ohosLang.isEmpty) return null;
    final parts = ohosLang.split('-');
    final lang = parts[0].toLowerCase();
    // 繁体中文 → zh_TW（最接近的 supportedLocale）
    if (lang == 'zh' && (ohosLang.contains('Hant') || ohosLang.contains('TW') || ohosLang.contains('HK'))) {
      return 'zh_TW';
    }
    return lang;
  }
}
