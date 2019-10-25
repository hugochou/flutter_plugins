import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_siri_shortcuts/flutter_siri_shortcuts.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription _shotcutSubscription;
  String _content = '';
  List<SiriShotcut> shotcuts = [
    SiriShotcut(
      type: 'siri.shotcut.bike_location',
      title: '查看爱车位置',
      subTitle: '将会显示您的爱车位置',
      suggestion: '爱车位置',
    ),
    SiriShotcut(
      type: 'siri.shotcut.bike_soc',
      title: '查看爱车电量',
      subTitle: '将会显示您的爱车电量',
      suggestion: '爱车电量',
    ),
  ];

  /// 是否进入前台
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shotcutSubscription = FlutterSiriShortcuts.listenShotcut().listen((value) {
      _changeContent(value);
    });

    FlutterSiriShortcuts.getLaunchShotcut().then((value) {
      if (_isForeground) {
        _changeContent(value);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
    }
    if (state == AppLifecycleState.paused) {
      _isForeground = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shotcutSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Siri Shotcut'),
        ),
        body: FutureBuilder<Object>(
            future: FlutterSiriShortcuts.getAllVoiceShortcuts,
            initialData: <String>[],
            builder: (context, snapshot) {
              final data = snapshot.hasData ? snapshot.data as List<String> : [];
              return Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: ListView.builder(
                  itemCount: shotcuts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == shotcuts.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 25),
                        child: Text(_content, style: TextStyle(color: Colors.blue)),
                      );
                    } else {
                      return Column(
                        children: <Widget>[
                          _buildItems(shotcuts[index], data.contains(shotcuts[index].type)),
                          Divider(height: 0.5, indent: 25.0, endIndent: 25.0),
                        ],
                      );
                    }
                  },
                ),
              );
            }),
      ),
    );
  }

  Widget _buildItems(SiriShotcut shotcut, bool added) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Row(
        children: <Widget>[
          Text(shotcut.title),
          Spacer(),
          RaisedButton(
            color: Colors.blue,
            textColor: Colors.white,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
            child: Text(added ? '编辑捷径' : '添加到Siri'),
            onPressed: () async {
              final result = await FlutterSiriShortcuts.setShotcut(
                type: shotcut.type,
                title: shotcut.title,
                subTitle: shotcut.subTitle,
                suggestion: shotcut.suggestion,
              );
              if (result != 0) {
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  void _changeContent(String data) {
    if (data == 'siri.shotcut.bike_location') {
      _content = '您的爱车在深圳市';
    }

    if (data == 'siri.shotcut.bike_soc') {
      _content = '您的爱车电量还是80%';
    }

    setState(() {});
  }
}

class SiriShotcut {
  final String type;
  final String title;
  final String subTitle;
  final String suggestion;

  SiriShotcut({@required this.type, this.title, this.subTitle, this.suggestion});
}
