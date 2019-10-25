import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FlutterSiriShortcuts {
  static const EventChannel _setShotcutChannel = const EventChannel('github.com/hugochou/setShotcut');
  static const EventChannel _getShotcutsChannel = const EventChannel('github.com/hugochou/getAllVoiceShortcuts');
  static const EventChannel _listenShotcutChannel = const EventChannel('github.com/hugochou/listenShotcut');
  static const MethodChannel _methodChannel = const MethodChannel('github.com/hugochou/methodChannel');

  /// 设置 Siri 捷径
  /// [type] 区分不同捷径的标识
  /// [title] Siri语音设置界面显示的标题
  /// [subTitle] Siri语音设置界面显示的子标题
  /// [suggestion] 建议唤起 Siri 的短语，实际按用户录音时的短语作为唤起短语
  /// 返回结果：0 失败/取消，1 新增， 2 编辑，3 删除
  static Future<int> setShotcut({@required String type, String title, String subTitle, String suggestion}) {
    if (Platform.isIOS) {
      Completer<int> completer = Completer<int>();
      final params = {
        'channelName': 'setShotcut',
        'type': type,
        'title': title,
        'subTitle': subTitle,
        'suggestion': suggestion,
      };
      _setShotcutChannel.receiveBroadcastStream(params).listen(
        (event) {
          if (event is num) {
            completer.complete(event.toInt());
          } else {
            completer.complete(0);
          }
        },
        cancelOnError: true,
        onError: (_) => completer.complete(0),
      );
      return completer.future;
    } else {
      return Future.value(0);
    }
  }

  /// 获取所有 Siri 捷径标识
  static Future<List<String>> get getAllVoiceShortcuts {
    List<String> result = [];
    if (Platform.isIOS) {
      Completer<List<String>> completer = Completer<List<String>>();
      _getShotcutsChannel.receiveBroadcastStream({'channelName': 'getAllVoiceShortcuts'}).listen(
        (event) {
          if (event is List) {
            result = event.map((e) => e.toString()).toList();
            completer.complete(result);
          } else {
            completer.complete(result);
          }
        },
        cancelOnError: true,
        onError: (_) => completer.complete(result),
      );
      return completer.future;
    }
    return Future.value(result);
  }

  /// 监听 Siri 捷径命令，返回捷径标识
  static Stream<String> listenShotcut() {
    if (Platform.isIOS) {
      return _listenShotcutChannel.receiveBroadcastStream({'channelName': 'listenShotcut'}).map((event) {
        if (event is String) {
          return event;
        }
        return '';
      });
    }
    return null;
  }

  /// 获取当前siri捷径命令
  /// 当通过siri启动时，listenShotcut 在启动后才调用， 所以监听不到相关的siri捷径命令，此时就需要用此方法
  static Future<String> getLaunchShotcut() {
    if (Platform.isIOS) {
      return _methodChannel.invokeMethod('getLaunchShotcut');
    } else {
      return null;
    }
  }
}
