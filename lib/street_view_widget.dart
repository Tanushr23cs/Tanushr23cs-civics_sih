import 'dart:ui_web' as ui;
import 'dart:html';
import 'package:flutter/material.dart';

class StreetViewWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String apiKey;

  const StreetViewWidget({
    required this.latitude,
    required this.longitude,
    required this.apiKey,
    Key? key,
  }) : super(key: key);

  @override
  State<StreetViewWidget> createState() => _StreetViewWidgetState();
}

class _StreetViewWidgetState extends State<StreetViewWidget> {
  final String viewType = 'google-street-view-iframe';

  @override
  void initState() {
    super.initState();
    // Register the view factory for the web
    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      // Construct the URL for the Street View iframe
      final streetViewUrl =
          'https://www.google.com/maps/embed/v1/streetview'
          '?key=${widget.apiKey}'
          '&location=${widget.latitude},${widget.longitude}';

      // Create an iframe element with the URL
      IFrameElement iframe = IFrameElement()
        ..width = '100%'
        ..height = '100%'
        ..src = streetViewUrl
        ..style.border = 'none';

      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Return the HtmlElementView, which renders the iframe
    return HtmlElementView(viewType: viewType);
  }
}
