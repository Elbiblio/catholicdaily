package com.elbiblio.catholicdaily.occurrencebridge

import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FeastReminderOccurrenceStorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        channel = MethodChannel(
            binding.binaryMessenger,
            "com.elbiblio.catholicdaily/feast_reminder_occurrence_store",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "claimedKeys") {
            callStore("claimedKeys", null, null, result)
            return
        }
        if (call.method != "claim") {
            result.notImplemented()
            return
        }
        val occurrenceKey = call.argument<String>("occurrenceKey")
        val celebrationDate = call.argument<String>("celebrationDate")
        if (occurrenceKey.isNullOrBlank() || celebrationDate.isNullOrBlank()) {
            result.error("invalid-claim", "Occurrence identity is required", null)
            return
        }
        callStore(
            "claim",
            occurrenceKey,
            Bundle().apply { putString("celebrationDate", celebrationDate) },
            result,
        )
    }

    private fun callStore(
        method: String,
        argument: String?,
        extras: Bundle?,
        result: MethodChannel.Result,
    ) {
        try {
            val authority = "${binding.applicationContext.packageName}.feast-reminder-occurrences"
            val response = binding.applicationContext.contentResolver.call(
                Uri.parse("content://$authority"),
                method,
                argument,
                extras,
            )
            result.success(
                if (method == "claim") {
                    response?.getBoolean("claimed") == true
                } else {
                    response?.getStringArrayList("occurrenceKeys") ?: emptyList<String>()
                },
            )
        } catch (error: Exception) {
            result.error("store-failed", error.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
