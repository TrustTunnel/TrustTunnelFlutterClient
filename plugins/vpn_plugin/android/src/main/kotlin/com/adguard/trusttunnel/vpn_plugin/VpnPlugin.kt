// plugins/vpn_plugin/android/src/main/kotlin/com/adguard/trusttunnel/vpn_plugin/VpnPlugin.kt
package com.adguard.trusttunnel.vpn_plugin

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService as AndroidVpnService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.PluginRegistry

class VpnPlugin :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    IVpnManager {

    companion object {
        private const val REQ_VPN_PREPARE = 1001
        private const val STATE_CHANNEL_NAME = "vpn_plugin_event_channel"
        private const val QUERY_LOG_CHANNEL_NAME = "vpn_plugin_event_channel_query_log"
    }

    private lateinit var appContext: Context
    private var activity: Activity? = null

    private var stateChannel: EventChannel? = null
    private var queryLogChannel: EventChannel? = null
    
    private lateinit var vpnImpl: NativeVpnImpl

    private var pendingConfig: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        val messenger: BinaryMessenger = binding.binaryMessenger

        vpnImpl = NativeVpnImpl(appContext)

        IVpnManager.setUp(messenger, this)

        stateChannel = EventChannel(messenger, STATE_CHANNEL_NAME).apply {
            setStreamHandler(vpnImpl)
        }

        queryLogChannel = EventChannel(messenger, QUERY_LOG_CHANNEL_NAME).apply {
            setStreamHandler(vpnImpl.queryLogHandler)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stateChannel?.setStreamHandler(null)
        queryLogChannel?.setStreamHandler(null)
        stateChannel = null
        queryLogChannel = null
        if (::vpnImpl.isInitialized) {
            vpnImpl.dispose()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQ_VPN_PREPARE) {
            val cfg = pendingConfig
            pendingConfig = null
            if (cfg != null && resultCode == Activity.RESULT_OK) {
                val ctx = activity ?: appContext
                vpnImpl.startPrepared(ctx, cfg)
            }
            return true
        }
        return false
    }

    override fun start(serverName: String, config: String) {
        val act = activity
        if (act != null) {
            val prepare = AndroidVpnService.prepare(act)
            if (prepare == null) {
                vpnImpl.startPrepared(act, config)
            } else {
                pendingConfig = config
                act.startActivityForResult(prepare, REQ_VPN_PREPARE)
            }
        } else {
            val prepare = AndroidVpnService.prepare(appContext)
            if (prepare == null) {
                vpnImpl.startPrepared(appContext, config)
            }
        }
    }

    override fun stop() {
        vpnImpl.stop()
    }

    override fun updateConfiguration(serverName: String?, config: String?) {
        // Do nothing, this is iOS specific
    }

    override fun getCurrentState(): VpnManagerState {
        return vpnImpl.getCurrentState()
    }
}