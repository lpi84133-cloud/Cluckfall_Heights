import 'dart:async';

import 'package:cluckfall_heights/loft/infra/span_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuietDeck extends StatefulWidget {
  const QuietDeck({
    super.key,
    required this.probe,
    required this.retryBuilder,
  });

  /// Preserved as an empty list so existing callers that pre-cache assets
  /// stay valid without touching the routing code.
  static const List<String> artAssets = <String>[];

  final SpanProbe probe;
  final WidgetBuilder retryBuilder;

  @override
  State<QuietDeck> createState() => _QuietDeckState();
}

class _QuietDeckState extends State<QuietDeck> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _retry() async {
    if (_checking) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _checking = true);
    bool online = false;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: widget.retryBuilder),
        ),
      );
      return;
    }
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final raw = MediaQuery.of(context);
    final landscapeHint = raw.size.width > raw.size.height;
    final media = landscapeHint
        ? raw.copyWith(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          )
        : raw;

    return MediaQuery(
      data: media,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F1A),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final landscape = width > height;
            final shortest = width < height ? width : height;

            final headlineSize = (shortest * 0.085).clamp(22.0, 40.0);
            final subSize = (shortest * 0.040).clamp(13.0, 19.0);
            final chipWidth = landscape
                ? (width * 0.44).clamp(280.0, 520.0)
                : (width * 0.72).clamp(240.0, 420.0);
            final chipHeight = landscape
                ? (height * 0.14).clamp(52.0, 70.0)
                : (height * 0.085).clamp(56.0, 78.0);
            final horizontalPad = width * 0.06;

            return Container(
              width: width,
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF1F2A44),
                    Color(0xFF0B0F1A),
                    Color(0xFF241A0F),
                  ],
                  stops: <double>[0.0, 0.55, 1.0],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Spacer(flex: landscape ? 2 : 3),
                    Text(
                      'NO INTERNET CONNECTION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: headlineSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        height: 1.15,
                        shadows: const <Shadow>[
                          Shadow(color: Colors.black54, blurRadius: 10),
                        ],
                      ),
                    ),
                    SizedBox(height: shortest * 0.025),
                    Text(
                      'Check your connection and try again',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: subSize,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                        height: 1.35,
                      ),
                    ),
                    Spacer(flex: landscape ? 8 : 4),
                    _RetryChip(
                      width: chipWidth,
                      height: chipHeight,
                      busy: _checking,
                      onTap: _retry,
                    ),
                    SizedBox(height: height * (landscape ? 0.035 : 0.05)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RetryChip extends StatelessWidget {
  const _RetryChip({
    required this.width,
    required this.height,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFF2B824), Color(0xFFC07830)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF34373C), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(34),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Color(0xFF34373C),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF34373C),
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Retry',
                          style: TextStyle(
                            color: Color(0xFF34373C),
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
