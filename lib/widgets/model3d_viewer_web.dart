// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

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

  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'model3d-${DateTime.now().millisecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      return html.IFrameElement()
        ..srcdoc = widget.htmlContent
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return HtmlElementView(viewType: _viewId);
  }
}
