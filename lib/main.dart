import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:screen_state/screen_state.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AG Tax Schedule',
      home: const WebViewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  // Stream subscriptions
  StreamSubscription<FGBGType>? _fgbgSubscription;
  StreamSubscription<ScreenStateEvent>? _screenSubscription;

  // Timers và flags
  Timer? _periodicRefreshTimer;
  bool _hasBeenBackground = false;
  bool _wasScreenOff = false;
  DateTime _lastRefreshTime = DateTime.now();

  // Cấu hình
  static const int periodicRefreshMinutes = 15; // Refresh mỗi 15 phút
  static const int minRefreshInterval = 1; // Tối thiểu 30 giây giữa các lần refresh

  @override
  void initState() {
    super.initState();

    _initializeWebView();
    _setupAppLifecycleListener();
    _setupScreenStateListener();
    _startPeriodicRefresh();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('Loading: $url');
          },
          onPageFinished: (String url) {
            print('Loaded: $url');
          },
          onWebResourceError: (WebResourceError error) {
            print('Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('https://lichlv.vn'));
  }

  void _setupAppLifecycleListener() {
    _fgbgSubscription = FGBGEvents.stream.listen((event) {
      if (event == FGBGType.background) {
        print('App moved to background');
        _hasBeenBackground = true;
        _pausePeriodicRefresh();
      } else if (event == FGBGType.foreground) {
        print('App moved to foreground');

        if (_hasBeenBackground) {
          print('Refreshing: App returned from background');
          _performRefresh('background return');
          _hasBeenBackground = false;
        }
        _resumePeriodicRefresh();
      }
    });
  }

  void _setupScreenStateListener() {
    try {
      Screen screen = Screen();
      _screenSubscription = screen.screenStateStream?.listen((event) {
        print('Screen event: $event');

        if (event == ScreenStateEvent.SCREEN_OFF) {
          print('Screen turned OFF');
          _wasScreenOff = true;
          _pausePeriodicRefresh();
        } else if (event == ScreenStateEvent.SCREEN_ON) {
          print('Screen turned ON');

          if (_wasScreenOff) {
            print('Refreshing: Screen turned back on');
            _performRefresh('screen on');
            _wasScreenOff = false;
          }
          _resumePeriodicRefresh();
        }
      });
    } catch (e) {
      print('Screen state detection not available: $e');
    }
  }

  void _startPeriodicRefresh() {
    _periodicRefreshTimer = Timer.periodic(
      Duration(minutes: periodicRefreshMinutes),
          (timer) {
        print('Periodic refresh triggered (every $periodicRefreshMinutes minutes)');
        _performRefresh('periodic');
      },
    );
  }

  void _pausePeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    print('Periodic refresh paused');
  }

  void _resumePeriodicRefresh() {
    if (_periodicRefreshTimer?.isActive != true) {
      _startPeriodicRefresh();
      print('Periodic refresh resumed');
    }
  }

  void _performRefresh(String trigger) {
    final now = DateTime.now();
    final timeSinceLastRefresh = now.difference(_lastRefreshTime).inSeconds;

    if (timeSinceLastRefresh < minRefreshInterval) {
      print('Refresh throttled (only ${timeSinceLastRefresh}s since last refresh)');
      return;
    }

    print('Refreshing WebView (trigger: $trigger)');
    _controller.reload();
    _lastRefreshTime = now;
  }

  @override
  void dispose() {
    _fgbgSubscription?.cancel();
    _screenSubscription?.cancel();
    _periodicRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // XÓA AppBar hoàn toàn
      body: SafeArea(
        child: FGBGNotifier(
          onEvent: (event) {
            // Additional logging if needed
          },
          // Chỉ giữ WebView, bỏ RefreshIndicator để tránh pull-to-refresh
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}
