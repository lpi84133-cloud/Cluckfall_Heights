import 'dart:async';
import 'dart:io';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/infra/beam_hub.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:cluckfall_heights/loft/infra/span_agent.dart';
import 'package:cluckfall_heights/loft/infra/span_probe.dart';
import 'package:cluckfall_heights/loft/infra/tap_path_reader.dart';
import 'package:cluckfall_heights/loft/pages/quiet_deck.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class SpanPane extends StatefulWidget {
  const SpanPane({
    super.key,
    required this.url,
    required this.vault,
    required this.probe,
    required this.notifications,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final LoftVault vault;
  final SpanProbe probe;
  final BeamHub notifications;
  final SpanAgent agent;
  final bool coldLaunch;

  @override
  State<SpanPane> createState() => _SpanPaneState();
}

class _SpanPaneState extends State<SpanPane> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.agent.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    widget.notifications.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (mounted && uri != null && uri.hasScheme) {
        _controller.loadRequest(uri);
      }
    };
    _networkSubscription = widget.probe.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        unawaited(_goOffline());
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    await Future<void>.delayed(LoftConfig.coldViewportSettle);
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated =
        _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    _metricsDebounce?.cancel();
    _pokeReflow(LoftConfig.reflowDelaysMs);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller
            .runJavaScript(
              'window.dispatchEvent(new Event("orientationchange"));'
              'window.dispatchEvent(new Event("resize"));'
              'if(window.visualViewport)'
              '  window.visualViewport.dispatchEvent(new Event("resize"));',
            )
            .catchError((_) {});
      });
    }
    _metricsDebounce = Timer(const Duration(milliseconds: 410), () {
      if (!mounted) return;
      _installShellBundle();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
    }
  }

  Future<void> _consumePending() async {
    // Warm push stash (BeamHub.onMessageOpenedApp) wins; cold-tap stash from
    // SceneDelegate is the fallback. Both are trusted, no host filter.
    final value =
        await widget.vault.consumePushUrl() ?? await TapPathReader.consume();
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (!mounted || uri == null || !uri.hasScheme) return;
    await _controller.loadRequest(uri);
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _installShellBundle();
        Future<void>.delayed(LoftConfig.pageFinishedResize, () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _installShellBundle();
          if (widget.coldLaunch && !_coldReloadIssued) {
            _coldReloadIssued = true;
            await _controller.reload();
          }
        });
      },
      onWebResourceError: (error) {
        if (error.errorCode == -999) return;
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop =
            error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        if (redirectLoop &&
            _lastMainUrl != null &&
            _redirectAttempts < LoftConfig.redirectLoopRetries) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        unawaited(_showOfflineAfterProbe());
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        // Anything WKWebView can render in place stays inside the shell.
        // `about:blank` in particular must stay: partner landings often
        // hop through it in an iframe before committing to the real URL.
        if (const <String>{
          'http',
          'https',
          'about',
          'data',
          'blob',
        }.contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        // Everything else — tel:, mailto:, sms:, whatsapp://, tg://,
        // viber://, fb-messenger://, weixin://, line://, snssdk://,
        // itms-apps://, plus one-off partner schemes — is handed off
        // to whichever app owns it. Scheme-gate, no host allowlist.
        unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        return NavigationDecision.prevent;
      },
    );
  }

  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    bool online = true;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    unawaited(_goOffline());
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    await Future.wait<void>(
      QuietDeck.artAssets.map(
        (asset) => precacheImage(AssetImage(asset), context),
      ),
    );
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => QuietDeck(
            probe: widget.probe,
            retryBuilder: (_) => SpanPane(
              url: current,
              vault: widget.vault,
              probe: widget.probe,
              notifications: widget.notifications,
              agent: widget.agent,
            ),
          ),
        ),
      ),
    );
  }

  /// Single injection bundle (inset + zoom + tap + keyboard + focus scale +
  /// a project-specific scrollbar tint). Inline media is native-only.
  void _installShellBundle() {
    _controller.runJavaScript(r'''
(function(){
  var w = window;
  if (w.__cfhBoot) { w.__cfhBoot(); return; }
  w.__cfhBoot = function(){
    var kbOpen = function(){
      var vis = w.visualViewport;
      return !!vis && vis.height < w.innerHeight * 0.75;
    };
    var css =
      ':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;' +
      '--safe-top:0px!important;--safe-right:0px!important;' +
      '--safe-bottom:0px!important;--safe-left:0px!important;}' +
      'html,body{overscroll-behavior:none!important;overscroll-behavior-y:none!important;}' +
      '*{-webkit-tap-highlight-color:transparent!important;}' +
      '*:not(input):not(textarea):not([contenteditable="true"]){-webkit-touch-callout:none!important;}' +
      'input,textarea,select,[contenteditable="true"]{font-size:max(16px,1em)!important;}' +
      '::-webkit-scrollbar{width:5px;height:5px;}' +
      '::-webkit-scrollbar-thumb{background:#c07830;border-radius:4px;}';
    var paint = function(){
      if (kbOpen()) return;
      var host = document.head || document.documentElement;
      if (!host) return;
      var vp = document.querySelector('meta[name="viewport"]');
      if (!vp) {
        vp = document.createElement('meta');
        vp.setAttribute('name','viewport');
        host.appendChild(vp);
      }
      vp.setAttribute('content',
        'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
        'minimum-scale=1.0, user-scalable=no, viewport-fit=contain');
      var sheet = document.getElementById('cfh-shell-sheet');
      if (!sheet) {
        sheet = document.createElement('style');
        sheet.id = 'cfh-shell-sheet';
        host.appendChild(sheet);
      }
      sheet.textContent = css;
    };
    paint();
    var halt = function(e){ e.preventDefault(); };
    ['gesturestart','gesturechange','gestureend'].forEach(function(t){
      document.addEventListener(t, halt, {passive:false});
    });
    document.addEventListener('touchmove', function(e){
      if (e.scale !== undefined && e.scale !== 1) e.preventDefault();
    }, {passive:false});
    var lastTap = 0;
    document.addEventListener('touchend', function(e){
      var now = Date.now();
      if (now - lastTap <= 300) e.preventDefault();
      lastTap = now;
    }, {passive:false});
    var editable = function(node){
      return !!node && node.matches && node.matches('input, textarea, select, [contenteditable="true"]');
    };
    document.addEventListener('focusin', function(ev){
      if (!editable(ev.target)) return;
      w.setTimeout(function(){
        var active = document.activeElement;
        if (editable(active)) active.scrollIntoView({behavior:'auto', block:'nearest'});
      }, 350);
    }, true);
    var later = function(){ w.setTimeout(paint, 160); w.setTimeout(paint, 620); };
    ['pushState','replaceState'].forEach(function(name){
      var orig = history[name];
      history[name] = function(){
        var result = orig.apply(this, arguments);
        later();
        return result;
      };
    });
    w.addEventListener('popstate', later);
    w.setInterval(paint, 3100);
  };
  w.__cfhBoot();
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.notifications.onDestination = null;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
