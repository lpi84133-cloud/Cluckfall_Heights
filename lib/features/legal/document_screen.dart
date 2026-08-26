import 'package:cluckfall_heights/core/assets/app_assets.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/progress_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum LegalDocument {
  privacy(
    title: 'Privacy policy',
    asset: LegalAsset.privacy,
    web: LegalAsset.privacyUrl,
  ),
  support(
    title: 'Support and FAQ',
    asset: LegalAsset.support,
    web: LegalAsset.supportUrl,
  );

  const LegalDocument({required this.title, required this.asset, required this.web});

  final String title;
  final String asset;
  final String web;
}

/// Shows the bundled copy of a legal or help page.
///
/// The HTML ships inside the app, so this works on a plane with no signal, and it
/// is the same document either way. Text is dark on white regardless of the app
/// theme so it stays legible, and the web version is offered as a link rather than
/// loaded, because a page that needs a connection to appear is not something to
/// hide a policy behind.
class DocumentScreen extends StatefulWidget {
  const DocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value / 100);
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _progress = 1;
                _ready = true;
              });
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _error = error.description);
            }
          },
          // Links inside the document open in the browser rather than replacing
          // the page, so the user can never end up stranded in a web session
          // with no way back.
          onNavigationRequest: (request) {
            if (request.url.startsWith('file://') || request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      );
    _load();
  }

  Future<void> _load() async {
    try {
      final String html = await rootBundle.loadString(widget.document.asset);
      await _controller.loadHtmlString(html, baseUrl: 'about:blank');
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return AppPage(
      title: widget.document.title,
      subtitle: 'Included in the app, so it opens without a connection.',
      showBack: true,
      scrollable: false,
      actions: [
        CircleAction(
          icon: LucideIcons.externalLink,
          tooltip: 'Open on the web',
          onTap: () => launchUrl(
            Uri.parse(widget.document.web),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.page, 0, Insets.page, Insets.page),
        child: ClipRRect(
          borderRadius: Corners.card,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: Corners.card,
              border: Border.all(color: palette.hairline),
            ),
            child: _error != null
                ? _Failure(message: _error!, onRetry: _load)
                : Stack(
                    children: [
                      WebViewWidget(controller: _controller),
                      if (!_ready)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: ProgressTrack(value: _progress, thickness: 3),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.fileWarning, size: 34, color: Color(0xFF6B6257)),
          const SizedBox(height: Insets.lg),
          Text(
            'This page could not be displayed',
            style: AppTypography.title.copyWith(color: Colors.black),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: const Color(0xFF6B6257)),
          ),
          const SizedBox(height: Insets.xl),
          AppButton(label: 'Try again', kind: AppButtonKind.quiet, onPressed: onRetry),
        ],
      ),
    );
  }
}
