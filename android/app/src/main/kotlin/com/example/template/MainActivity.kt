package com.example.template

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — WebView file-upload bridge
// ============================================================
// Dependency-free WebView file upload: the site's <input type="file">
// triggers the WebView's file selector, which hops here over a
// MethodChannel and returns the picked content:// URIs back to the
// WebView. No file_picker dependency (see gray_part_pitfalls.md §1).
//
// [FINGERPRINT] Per-project mandatory changes:
//   1. Move this file: rename `com/example/template/` (both the folder
//      path AND the `package` declaration above) to your project id.
//      Must match `applicationId` / `namespace` in
//      android/app/build.gradle.kts.
//   2. Rename `channelName` to a project-unique string (e.g.
//      "riverstone/upload", "cloudpickers/fs"). The literal appears
//      in the compiled Dart binary too — WebStage._uploadChannel must
//      be updated to the SAME string.
//   3. Vary `pickRequest` request code across projects (any unused
//      short-int is fine).
// ============================================================
class MainActivity : FlutterActivity() {
    // [FINGERPRINT] Rename per project. Keep in sync with
    // lib/veil/web_stage.dart → `MethodChannel('...upload...')`.
    private val channelName = "tower/upload"
    private val pickRequest = 0x7A11
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") {
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    openChooser(multiple, mimes, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // Resolve any abandoned request before starting a new one.
        pendingResult?.success(emptyList<String>())
        pendingResult = result

        val valid = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                valid.isEmpty() -> type = "*/*"
                valid.size == 1 -> type = valid[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, valid.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(intent, null), pickRequest)
        } catch (e: Exception) {
            pendingResult = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return

        val result = pendingResult
        pendingResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        result.success(uris)
    }
}
