// ============================================================
// LEGAL LINKS — public, non-sensitive URLs
// ============================================================
// These strings ship as plaintext in the APK because they appear
// inside the native game menu (Privacy Policy / Support buttons)
// and would look suspicious to a reviewer if they were encoded.
//
// [TODO] Replace all three URLs before shipping. Requirements:
//   • privacyPolicyLink — public, permanent, matches the URL you
//     supplied to the App Store / Play Console during listing.
//     Store review will reject the app if this is missing or 404s.
//   • supportLink — any public support / contact page. Required
//     by Google Play policies as of 2024+.
//   • siteHome — landing page URL (optional; falls back to the
//     privacy page if left empty).
//
// ⚠️ Do NOT reuse the same three URLs across multiple projects.
// Store scanners cross-reference privacy URLs between listings to
// detect templated submissions. Each project should own its own
// domain (or at minimum, its own /project-slug/ path).
// ============================================================

const String siteHome = 'https://example.com'; // [TODO]
const String privacyPolicyLink = 'https://example.com/privacy-policy.html'; // [TODO]
const String supportLink = 'https://example.com/support.html'; // [TODO]
