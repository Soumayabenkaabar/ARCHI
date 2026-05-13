import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Model3DViewerWidget extends StatefulWidget {
  final String htmlContent;
  const Model3DViewerWidget({required this.htmlContent, super.key});

  @override
  State<Model3DViewerWidget> createState() => _Model3DViewerWidgetState();
}

class _Model3DViewerWidgetState extends State<Model3DViewerWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late WebViewController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()..loadHtmlString(widget.htmlContent);
  }

  @override
  void didUpdateWidget(Model3DViewerWidget old) {
    super.didUpdateWidget(old);
    if (old.htmlContent != widget.htmlContent) {
      _ctrl.loadHtmlString(widget.htmlContent);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WebViewWidget(controller: _ctrl);
  }
}
