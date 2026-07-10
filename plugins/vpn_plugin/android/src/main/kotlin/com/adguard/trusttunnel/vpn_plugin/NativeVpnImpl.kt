// plugins/vpn_plugin/android/src/main/kotlin/com/adguard/trusttunnel/vpn_plugin/NativeVpnImpl.kt
package com.adguard.trusttunnel.vpn_plugin

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.util.ArrayDeque
import java.util.Queue
import com.adguard.trusttunnel.AppNotifier
import com.adguard.trusttunnel.Logger
import com.adguard.trusttunnel.VpnService
import io.flutter.plugin.common.EventChannel
import java.io.File

class NativeVpnImpl(
    private val appContext: Context
) : EventChannel.StreamHandler, AppNotifier {

    private var events: EventChannel.EventSink? = null
    private var currentState = VpnManagerState.DISCONNECTED
    private val main = Handler(Looper.getMainLooper())
    private val log = Logger("VPN_PLUGIN")

    val queryLogHandler: QueryLogStreamHandler = QueryLogStreamHandler()

    init {
        VpnService.initialize(appContext)
        val queryLogFile = File(appContext.filesDir, "query_log.dat")
        VpnService.setAppNotifier(queryLogFile, this)
    }

    fun startPrepared(ctx: Context, config: String) {
        log.info("startPrepared()")
        VpnService.start(ctx, config)
    }

    fun stop() {
        log.info("stop()")
        VpnService.stop(appContext)
    }

    fun exportLogs(): List<String> {
        log.info("exportLogs()")
        return VpnService.exportLogs(appContext)
    }

    fun clearLogs() {
        log.info("clearLogs()")
        VpnService.clearLogs()
    }

    fun getCurrentState(): VpnManagerState = currentState

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        log.info("onListen() -> subscribe state notifier")
        this.events = events
        postEvent(currentState.ordinal)
    }

    override fun onCancel(arguments: Any?) {
        log.info("onCancel() -> unsubscribe")
        try {
            events = null
        } catch (t: Throwable) {
            log.warn("clearStateNotifier failed", t)
        }
    }

    override fun onStateChanged(state: Int) {
        log.info("onStateChanged($state)")
        currentState = VpnManagerState.entries[state]
        postEvent(state)
    }

    override fun onConnectionInfo(info: String) {
        log.debug("onConnectionInfo")
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
    private val log = Logger("VPN_PLUGIN")

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        log.info("QueryLog#onListen() -> subscribe state notifier")
        this.events = events
        for (log in queue) {
            postEvent(log)
        }
        queue.clear()
    }

    override fun onCancel(arguments: Any?) {
        log.info("QueryLog#onCancel() -> unsubscribe")
        try {
            events = null
        } catch (t: Throwable) {
            log.warn("clearNotifier failed for QueryLog", t)
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
