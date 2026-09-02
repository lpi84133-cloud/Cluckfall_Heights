import 'dart:async';
import 'dart:io';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/infra/beam_hub.dart';
import 'package:cluckfall_heights/loft/infra/link_gate.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:cluckfall_heights/loft/infra/span_agent.dart';
import 'package:cluckfall_heights/loft/infra/span_probe.dart';
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
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;
  Object? _destinationToken;
  bool _firstMainLoadStarted = false;
  bool _firstMainLoadRetried = false;
  bool _emptyDocReloadIssued = false;

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

    // Owner-scoped callback: BeamHub only releases it if we are still the
    // registered listener at dispose time. Prevents a newer SpanPane from
    // having its callback wiped by a stale one that is unmounting.
    _destinationToken = widget.notifications.registerOnDestination(
      _onWarmDestination,
    );
    _networkSubscription = widget.probe.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        unawaited(_goOffline());
      }
    });

    final initialUri = LinkGate.admit(widget.url);
    if (initialUri == null) {
      // Constructor URL didn't pass the gate — nothing safe to load. The
      // returning-portal fallback will hit no-net rather than open blank.
      unawaited(_goOffline());
      return;
    }

    if (widget.coldLaunch) {
      _settleColdViewport(initialUri);
    } else {
      _viewportReady = true;
      _controller.loadRequest(initialUri);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _onWarmDestination(String url) {
    if (!mounted) return;
    final uri = LinkGate.admit(url);
    if (uri == null) return;
    _controller.loadRequest(uri);
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport(Uri initial) async {
    _enterImmersive();
    await Future<void>.delayed(LoftConfig.coldViewportSettle);
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(initial);
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
    // Warm queue (BeamHub.onMessageOpenedApp stashes here whenever no live
    // callback is registered). Read on appear AND on foreground resume so a
    // tap that arrived while we were mounting is still honoured.
    final value = await widget.vault.consumePushUrl();
    if (value == null) return;
    final uri = LinkGate.admit(value);
    if (!mounted || uri == null) return;
    await _controller.loadRequest(uri);
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
        _firstMainLoadStarted = true;
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
          // Push URLs are often one-shot (session token consumed on first
          // GET). An unconditional reload sends the WebView to the partner's
          // start page. Reload only when the document is literally empty.
          if (widget.coldLaunch && !_emptyDocReloadIssued) {
            await _reloadIfDocumentEmpty();
          }
        });
      },
      onWebResourceError: (error) {
        // -999 = cancelled. If it is the FIRST main-frame navigation being
        // cancelled and nothing has been rendered yet, retry once — that
        // covers the WKWebView cold-start hiccup where the first request is
        // dropped before the process is fully ready. Any subsequent -999 is
        // a legitimate supersede (a new navigation replaced this one) and
        // must NOT be retried, otherwise back/forward and inline navigation
        // start bouncing.
        if (error.errorCode == -999) {
          final mainFrame = error.isForMainFrame ?? true;
          if (mainFrame &&
              _firstMainLoadStarted &&
              !_firstMainLoadRetried &&
              _lastMainUrl != null) {
            _firstMainLoadRetried = true;
            _controller.loadRequest(Uri.parse(_lastMainUrl!));
          }
          return;
        }
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
        // Decide by the scheme extracted from the raw string, NOT from
        // `Uri.parse()`. Dart's URI parser is stricter than WKWebView and
        // rejects perfectly loadable redirects with unusual characters —
        // returning `prevent` on those blanks the screen.
        final scheme = LinkGate.schemeOf(request.url);
        // Relative addresses, http, https, and the special in-shell schemes
        // stay inside the WebView. `about:blank` in particular must stay:
        // partner landings often hop through it before committing.
        if (scheme.isEmpty ||
            scheme == 'http' ||
            scheme == 'https' ||
            scheme == 'about' ||
            scheme == 'data' ||
            scheme == 'blob') {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        if (scheme == 'javascript') return NavigationDecision.prevent;
        // Everything else — tel:, mailto:, sms:, whatsapp://, tg://,
        // viber://, fb-messenger://, weixin://, line://, snssdk://,
        // itms-apps://, plus one-off partner schemes — is handed off to
        // whichever app owns it. url_launcher takes a full Uri, so parse
        // here (after the scheme decision, so a parse failure can no
        // longer blank the screen).
        final uri = Uri.tryParse(request.url);
        if (uri != null) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        }
        return NavigationDecision.prevent;
      },
    );
  }

  Future<void> _reloadIfDocumentEmpty() async {
    _emptyDocReloadIssued = true;
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'document.body ? document.body.innerHTML.trim().length : 0',
      );
      final asString = result.toString().replaceAll('"', '');
      final length = int.tryParse(asString) ?? 0;
      if (length == 0 && mounted) {
        await _controller.reload();
      }
    } catch (_) {}
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
    final token = _destinationToken;
    if (token != null) widget.notifications.releaseOnDestination(token);
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
