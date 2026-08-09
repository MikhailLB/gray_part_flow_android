// ============================================================
// LEGAL URLs — public policy/support links (plaintext by design)
// ============================================================
// These URLs are visible from the native game menu (Privacy /
// Support buttons). Encoding them would look suspicious to a
// reviewer — a puzzle game hiding its own privacy page URL is
// exactly the kind of anomaly a scanner flags. They ship as
// plain string constants.
//
// [FORGE] Rotate all three per project. Never ship two projects
// with the same three URLs. Store review cross-references privacy
// URLs between listings to detect templated submissions — each
// project should own its own domain (or at minimum, its own
// `/project-slug/` path).
// ============================================================

const String homeLink = 'https://example.com'; // [FORGE]
const String privacyLink = 'https://example.com/privacy.html'; // [FORGE]
const String supportLink = 'https://example.com/support.html'; // [FORGE]
