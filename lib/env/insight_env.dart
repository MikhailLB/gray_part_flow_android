// ============================================================
// insight_env.dart — Microsoft Clarity project id (per-project).
// ============================================================
// [FINGERPRINT] The Clarity `projectId` is unique per project. Never
// reuse another project's id here — it would merge session replays and
// tags from two different apps into one dashboard and poison the funnel.
// See .cursor/rules/clarity_analytics.mdc §1.
// ============================================================

// [TODO] Paste this project's OWN Clarity project id — do NOT reuse
// the id from another gray-flow build. Create a fresh Clarity project
// at https://clarity.microsoft.com and copy the id from the setup step.
const String kClarityProjectId = 'xmjuqx4kx9';
