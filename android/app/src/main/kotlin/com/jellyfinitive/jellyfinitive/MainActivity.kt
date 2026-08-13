package com.jellyfinitive.jellyfinitive

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jellyfinitive/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTv" -> {
                        val uiMode = resources.configuration.uiMode
                        result.success(
                            (uiMode and Configuration.UI_MODE_TYPE_MASK) ==
                                Configuration.UI_MODE_TYPE_TELEVISION
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
