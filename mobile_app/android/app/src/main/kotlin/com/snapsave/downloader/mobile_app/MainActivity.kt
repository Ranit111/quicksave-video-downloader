package com.snapsave.downloader.mobile_app

import android.media.MediaScannerConnection
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.snapsave.downloader/media_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "scanFile") {
                val path = call.argument<String>("path")
                if (path != null) {
                    val mimeType = if (path.endsWith(".mp3", ignoreCase = true) || path.endsWith(".m4a", ignoreCase = true)) {
                        "audio/*"
                    } else {
                        "video/*"
                    }
                    MediaScannerConnection.scanFile(
                        applicationContext,
                        arrayOf(path),
                        arrayOf(mimeType)
                    ) { scannedPath: String, uri: Uri? ->
                        // File indexed into Android MediaStore successfully
                    }
                    result.success(true)
                } else {
                    result.error("INVALID_PATH", "Path cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

