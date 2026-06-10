package com.adguard.adg_share

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException

class AdgSharePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "adg_share")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
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
            result.success(mapOf("status" to "unavailable"))
            return
        }

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

            val chooserIntent = Intent.createChooser(
                shareIntent,
                (arguments["chooserTitle"] as? String)?.takeIf { !it.isNullOrBlank() },
            )

            grantUriPermissions(appContext, chooserIntent, uris)
            currentActivity.startActivity(chooserIntent)
            result.success(mapOf("status" to "success"))
        } catch (exception: SharePluginException) {
            result.error(exception.code, exception.message, null)
        } catch (exception: ActivityNotFoundException) {
            result.success(mapOf("status" to "unavailable"))
        } catch (exception: FileNotFoundException) {
            result.error("file_not_found", exception.message, null)
        } catch (exception: SecurityException) {
            result.error("permission_denied", exception.localizedMessage, null)
        } catch (exception: Exception) {
            result.error("share_failed", exception.localizedMessage, null)
        }
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
