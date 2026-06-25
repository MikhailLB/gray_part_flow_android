/// Which experience the shell locked onto for this install.
///
/// - [web]    → returning user previously routed to the WebView.
/// - [native] → returning user previously routed to the game.
/// - [unset]  → first launch, not yet decided.
enum ShellMode {
  web,
  native,
  unset;

  static ShellMode decode(String? raw) {
    switch (raw) {
      case 'web':
        return ShellMode.web;
      case 'native':
        return ShellMode.native;
      default:
        return ShellMode.unset;
    }
  }

  String encode() => name;
}
