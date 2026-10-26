{{flutter_js}}
{{flutter_build_config}}

// Serve Flutter's executable renderer assets from this app, not a public CDN.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href
  }
});
