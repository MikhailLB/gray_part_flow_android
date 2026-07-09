/// Parsed response from the gate (config) endpoint.
///
/// Wire format from the backend is `{ ok, url, expires, message }`; the
/// fields are renamed here but the JSON keys are mapped verbatim so the
/// backend contract is preserved.
class GateReply {
  const GateReply({
    required this.allowed,
    this.link,
    this.note,
    this.ttl,
  });

  /// Backend `ok` — true means show the WebView with [link].
  final bool allowed;

  /// Backend `url` — the content URL to display.
  final String? link;

  /// Backend `message` — diagnostic note (e.g. "organic").
  final String? note;

  /// Backend `expires` — unix seconds after which [link] should be refreshed.
  final int? ttl;

  factory GateReply.fromMap(Map<String, dynamic> map) {
    return GateReply(
      allowed: map['ok'] as bool? ?? false,
      link: map['url'] as String?,
      note: map['message'] as String?,
      ttl: map['expires'] as int?,
    );
  }

  factory GateReply.failure(String note) => GateReply(allowed: false, note: note);

  bool get hasLink => link != null && link!.isNotEmpty;
}
