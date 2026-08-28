import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/infra/beam_hub.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PermitDeck extends StatefulWidget {
  const PermitDeck({
    super.key,
    required this.vault,
    required this.notifications,
    required this.nextBuilder,
  });

  static const String portraitArt =
      'assets/Cluckfall_Heights_APPLICATION_additional_assets/'
      'Vertical_Notifications_Screen.webp';
  static const String landscapeArt =
      'assets/Cluckfall_Heights_APPLICATION_additional_assets/'
      'Horizontal_Notifications_Screen.webp';
  static const List<String> artAssets = <String>[portraitArt, landscapeArt];

  final LoftVault vault;
  final BeamHub notifications;
  final WidgetBuilder nextBuilder;

  @override
  State<PermitDeck> createState() => _PermitDeckState();
}

class _PermitDeckState extends State<PermitDeck> {
  bool _working = false;

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

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.notifications.askPermission();
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        LoftConfig.pushSnoozeSeconds;
    return widget.vault.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final raw = MediaQuery.of(context);
    final landscape = raw.size.width > raw.size.height;
    final media = landscape
        ? raw.copyWith(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          )
        : raw;

    return MediaQuery(
      data: media,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isLandscape = width > constraints.maxHeight;
            final background = isLandscape
                ? PermitDeck.landscapeArt
                : PermitDeck.portraitArt;

            final Widget actions;
            if (isLandscape) {
              final btnW = (width * 0.28).clamp(180.0, 280.0);
              const btnH = 62.0;
              actions = Row(
                key: const Key('permit-actions'),
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _DeckButton(
                    width: btnW,
                    height: btnH,
                    fontSize: 21,
                    label: 'Accept',
                    emphasized: true,
                    busy: _working,
                    onTap: _accept,
                  ),
                  const SizedBox(width: 16),
                  _DeckButton(
                    width: btnW,
                    height: btnH,
                    fontSize: 21,
                    label: 'Skip',
                    emphasized: false,
                    busy: false,
                    onTap: _skip,
                  ),
                ],
              );
            } else {
              final btnW = (width * 0.80).clamp(280.0, 440.0);
              actions = Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _DeckButton(
                    width: btnW,
                    height: 74,
                    fontSize: 25,
                    label: 'Accept',
                    emphasized: true,
                    busy: _working,
                    onTap: _accept,
                  ),
                  const SizedBox(height: 16),
                  _DeckButton(
                    width: btnW,
                    height: 74,
                    fontSize: 25,
                    label: 'Skip',
                    emphasized: false,
                    busy: false,
                    onTap: _skip,
                  ),
                ],
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fill(
                  child: Image.asset(
                    background,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Align(
                  alignment: Alignment(0, isLandscape ? 0.88 : 0.90),
                  child: actions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeckButton extends StatelessWidget {
  const _DeckButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.emphasized,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final String label;
  final bool emphasized;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: emphasized
                ? const <Color>[Color(0xFFF2B824), Color(0xFFC07830)]
                : const <Color>[Color(0xFFE0D0B2), Color(0xFFCDBB9B)],
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
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Color(0xFF34373C),
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF34373C),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
