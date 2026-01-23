// plugins/vpn_plugin/android/src/main/kotlin/com/adguard/trusttunnel/vpn_plugin/NativeVpnImpl.kt
package com.adguard.trusttunnel.vpn_plugin

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.ArrayDeque
import java.util.Queue
import com.adguard.trusttunnel.AppNotifier
import com.adguard.trusttunnel.VpnService
import io.flutter.plugin.common.EventChannel
import java.io.File

class NativeVpnImpl(
    private val appContext: Context
) : EventChannel.StreamHandler, AppNotifier {

    private var events: EventChannel.EventSink? = null
    private var currentState = VpnManagerState.DISCONNECTED
    private val main = Handler(Looper.getMainLooper())

    val queryLogHandler: QueryLogStreamHandler = QueryLogStreamHandler()

    init {
        VpnService.startNetworkManager(appContext)
        val queryLogFile = File(appContext.filesDir, "query_log.dat")
        VpnService.setAppNotifier(queryLogFile, this)
    }

    fun startPrepared(ctx: Context, config: String) {
        Log.i("VPN_PLUGIN", "startPrepared() config=$config")
        VpnService.start(ctx, config)
    }

    fun stop() {
        Log.i("VPN_PLUGIN", "stop()")
        VpnService.stop(appContext)
    }

    fun getCurrentState(): VpnManagerState = currentState

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.i("VPN_PLUGIN", "onListen() -> subscribe state notifier")
        this.events = events
        postEvent(currentState.ordinal)
    }

    override fun onCancel(arguments: Any?) {
        Log.i("VPN_PLUGIN", "onCancel() -> unsubscribe")
        try {
            events = null
        } catch (t: Throwable) {
            Log.w("VPN_PLUGIN", "clearStateNotifier failed", t)
        }
    }

    override fun onStateChanged(state: Int) {
        Log.i("VPN_PLUGIN", "onStateChanged($state)")
        currentState = VpnManagerState.entries[state]
        postEvent(state)
    }

    override fun onConnectionInfo(info: String) {
        Log.i("VPN_PLUGIN", "onConnectionInfo")
        queryLogHandler.onQueryLog(info)
    }

    private fun postEvent(value: Any) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            events?.success(value)
        } else {
            main.post { events?.success(value) }
        }
    }
}

class QueryLogStreamHandler : EventChannel.StreamHandler {

    private var events: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private val queue: Queue<String> = ArrayDeque()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.i("VPN_PLUGIN", "QueryLog#onListen() -> subscribe state notifier")
        this.events = events
        for (log in queue) {
            postEvent(log)
        }
        queue.clear()
    }

    override fun onCancel(arguments: Any?) {
        Log.i("VPN_PLUGIN", "QueryLog#onCancel() -> unsubscribe")
        try {
            events = null
        } catch (t: Throwable) {
            Log.w("VPN_PLUGIN", "clearNotifier failed for QueryLog", t)
        }
    }

    private fun postEvent(value: Any) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            events?.success(value)
        } else {
            main.post { events?.success(value) }
        }
    }

    fun onQueryLog(log: String) {
        main.post {
            if (events == null) {
                queue.offer(log)
            } else {
                postEvent(log)
            }
        }
    }
}