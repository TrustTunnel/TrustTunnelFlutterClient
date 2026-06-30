package com.adguard.adg_share

import android.app.Activity
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileNotFoundException

class AdgSharePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    companion object {
        private const val TAG = "AdgSharePlugin"
        private const val SHARE_REQUEST_CODE = 4321
        private const val ACTION_SHARE_RESULT = "com.adguard.adg_share.SHARE_RESULT"
    }

    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var pendingShareResult: MethodChannel.Result? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var shareTargetSelected: Boolean = false

    private val shareResultReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d(TAG, "Broadcast received: share target selected")
            shareTargetSelected = true
            resolvePendingResultWithSuccess()
        }
    }

    private val activityResultListener = PluginRegistry.ActivityResultListener { requestCode, _, _ ->
        Log.d(TAG, "onActivityResult: requestCode=$requestCode, shareTargetSelected=$shareTargetSelected")
        if (requestCode == SHARE_REQUEST_CODE) {
            if (!shareTargetSelected) {
                // Chooser was dismissed without selecting a target.
                Log.d(TAG, "Share dismissed by user")
                resolvePendingResult(mapOf("status" to "dismissed"))
            }
            true
        } else {
            false
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "adg_share")
        channel?.setMethodCallHandler(this)

        val filter = IntentFilter(ACTION_SHARE_RESULT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context?.registerReceiver(
                shareResultReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            context?.registerReceiver(shareResultReceiver, filter)
        }
        Log.d(TAG, "Plugin attached to engine, receiver registered")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            context?.unregisterReceiver(shareResultReceiver)
        } catch (_: IllegalArgumentException) {
            // Receiver was already unregistered.
        }
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
        Log.d(TAG, "Activity attached: ${binding.activity.javaClass.simpleName}")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "Activity detached for config changes")
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
        Log.d(TAG, "Activity reattached for config changes")
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "Activity detached")
        dismissPendingResult()
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "share" -> handleShare(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleShare(call: MethodCall, result: MethodChannel.Result) {
        val currentActivity = activity
        val appContext = context
        if (currentActivity == null || appContext == null) {
            Log.w(TAG, "handleShare: activity=$currentActivity, context=$appContext — returning unavailable")
            result.success(mapOf("status" to "unavailable"))
            return
        }

        Log.d(TAG, "handleShare: building share intent")
        val arguments = call.arguments as? Map<*, *>
        val serializedContent = arguments?.get("content") as? List<*>
        if (serializedContent.isNullOrEmpty()) {
            result.error("validation_error", "Share request content must not be empty.", null)
            return
        }

        try {
            val textParts = mutableListOf<String>()
            val uris = arrayListOf<Uri>()
            val mimeTypes = mutableListOf<String>()

            serializedContent.forEach { rawItem ->
                val item = rawItem as? Map<*, *> ?: return@forEach
                when (item["type"] as? String) {
                    "text" -> {
                        val text = (item["text"] as? String)?.trim()
                        if (text.isNullOrEmpty()) {
                            throw SharePluginException("validation_error", "Share text must not be empty.")
                        }
                        textParts.add(text)
                    }
                    "uri" -> {
                        val uriString = (item["uri"] as? String)?.trim()
                        if (uriString.isNullOrEmpty()) {
                            throw SharePluginException("validation_error", "Share URI must not be empty.")
                        }
                        textParts.add(uriString)
                    }
                    "file" -> {
                        val filePath = (item["path"] as? String)?.trim()
                        if (filePath.isNullOrEmpty()) {
                            throw SharePluginException("validation_error", "Share file path must not be empty.")
                        }
                        uris.add(createContentUri(appContext, filePath))
                        mimeTypes.add(((item["mimeType"] as? String)?.trim()).orEmpty().ifEmpty { "application/octet-stream" })
                    }
                }
            }

            if (textParts.isEmpty() && uris.isEmpty()) {
                throw SharePluginException("validation_error", "Share request content must not be empty.")
            }

            val shareIntent = Intent(if (uris.size > 1) Intent.ACTION_SEND_MULTIPLE else Intent.ACTION_SEND).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                if (uris.isNotEmpty()) {
                    if (uris.size > 1) {
                        putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                    } else {
                        putExtra(Intent.EXTRA_STREAM, uris.first())
                    }
                    clipData = buildClipData(appContext, uris)
                }
                if (textParts.isNotEmpty()) {
                    putExtra(Intent.EXTRA_TEXT, textParts.joinToString(separator = "\n"))
                }

                val subject = (arguments["subject"] as? String)?.trim()
                if (!subject.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }

                type = resolveMimeType(hasText = textParts.isNotEmpty(), mimeTypes = mimeTypes)
            }

            // Build a PendingIntent that fires when the user selects a share target.
            // This is the officially documented way to detect share completion:
            // https://developer.android.com/training/sharing/send#get-info-about-sharing
            val resultIntent = Intent(ACTION_SHARE_RESULT).apply {
                setPackage(appContext.packageName)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(
                appContext,
                SHARE_REQUEST_CODE,
                resultIntent,
                flags,
            )

            val chooserIntent = Intent.createChooser(
                shareIntent,
                (arguments["chooserTitle"] as? String)?.takeIf { !it.isNullOrBlank() },
                pendingIntent.intentSender,
            )

            grantUriPermissions(appContext, chooserIntent, uris)

            // Guard against concurrent share requests.
            dismissPendingResult()
            shareTargetSelected = false
            pendingShareResult = result
            currentActivity.startActivityForResult(chooserIntent, SHARE_REQUEST_CODE)
            Log.d(TAG, "Chooser launched, waiting for result")
        } catch (exception: SharePluginException) {
            Log.e(TAG, "Share validation error", exception)
            result.error(exception.code, exception.message, null)
        } catch (exception: ActivityNotFoundException) {
            Log.e(TAG, "No activity found to handle share intent", exception)
            result.success(mapOf("status" to "unavailable"))
        } catch (exception: FileNotFoundException) {
            Log.e(TAG, "Share file not found", exception)
            result.error("file_not_found", exception.message, null)
        } catch (exception: SecurityException) {
            Log.e(TAG, "Share security exception", exception)
            result.error("permission_denied", exception.localizedMessage, null)
        } catch (exception: Exception) {
            Log.e(TAG, "Share failed", exception)
            result.error("share_failed", exception.localizedMessage, null)
        }
    }

    private fun resolvePendingResultWithSuccess() {
        Log.d(TAG, "Resolving pending result: success")
        pendingShareResult?.let { result ->
            result.success(mapOf("status" to "success"))
        }
        pendingShareResult = null
    }

    private fun resolvePendingResult(response: Map<String, String>) {
        Log.d(TAG, "Resolving pending result: ${response["status"]}")
        pendingShareResult?.let { result ->
            result.success(response)
        }
        pendingShareResult = null
    }

    private fun dismissPendingResult() {
        pendingShareResult?.let { result ->
            Log.d(TAG, "Dismissing stale pending result")
            result.success(mapOf("status" to "unavailable"))
        }
        pendingShareResult = null
    }

    private fun resolveMimeType(hasText: Boolean, mimeTypes: List<String>): String {
        if (mimeTypes.isEmpty()) {
            return if (hasText) "text/plain" else "application/octet-stream"
        }

        return mimeTypes.distinct().singleOrNull() ?: "*/*"
    }

    private fun buildClipData(context: Context, uris: List<Uri>): ClipData? {
        if (uris.isEmpty()) {
            return null
        }

        val clipData = ClipData.newUri(context.contentResolver, "shared_content", uris.first())
        uris.drop(1).forEach { uri ->
            clipData.addItem(ClipData.Item(uri))
        }
        return clipData
    }

    private fun grantUriPermissions(context: Context, chooserIntent: Intent, uris: List<Uri>) {
        if (uris.isEmpty()) {
            return
        }

        val resolveInfos = context.packageManager.queryIntentActivities(
            chooserIntent,
            PackageManager.MATCH_DEFAULT_ONLY,
        )

        resolveInfos.forEach { resolveInfo ->
            val packageName = resolveInfo.activityInfo.packageName
            uris.forEach { uri ->
                context.grantUriPermission(
                    packageName,
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            }
        }
    }

    private fun createContentUri(context: Context, filePath: String): Uri {
        val file = File(filePath)
        if (!file.exists()) {
            throw FileNotFoundException(filePath)
        }

        return FileProvider.getUriForFile(
            context,
            "${context.packageName}.adg_share.fileprovider",
            file,
        )
    }
}

private class SharePluginException(
    val code: String,
    override val message: String,
) : RuntimeException(message)
