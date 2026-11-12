// plugins/vpn_plugin/android/src/main/kotlin/com/adguard/trusttunnel/vpn_plugin/TunVpnService.kt
//
// A local replacement for the prebuilt `com.adguard.trusttunnel.VpnService`
// that additionally supports per-app tunneling exclusions via
// `VpnService.Builder.addDisallowedApplications`.
//
// The service replicates the upstream logic (TrustTunnelClient, Apache-2.0)
// but keeps full control over the TUN builder setup. The heavy lifting
// (protocol, routing, DNS) stays in the prebuilt native core (`VpnClient`).
package com.adguard.trusttunnel.vpn_plugin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import com.adguard.trusttunnel.AppNotifier
import com.adguard.trusttunnel.CertificateVerificator
import com.adguard.trusttunnel.Logger
import com.adguard.trusttunnel.PersistentRingBuffer
import com.adguard.trusttunnel.VpnClient
import com.adguard.trusttunnel.VpnClientListener
import com.adguard.trusttunnel.VpnConfigStorage
import com.adguard.trusttunnel.VpnServiceConfig
import com.adguard.trusttunnel.VpnState
import com.adguard.trusttunnel.log.FileLogger
import com.adguard.trusttunnel.utils.NetworkUtils
import com.adguard.trusttunnel.utils.concurrent.thread.ThreadManager
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class TunVpnService : android.net.VpnService(), VpnClientListener {

    companion object {
        private val LOG = Logger("TunVpnService")
        private val NETWORK_MANAGER_SYNC = Any()

        // Network monitoring
        private lateinit var connectivityManager: ConnectivityManager
        private lateinit var networkRequest: NetworkRequest
        private lateinit var networkCallback: NetworkUtils.Companion.NetworkCollector
        private var connectionInfoFile: PersistentRingBuffer? = null
        private var currentStartId: Int = -1

        private var fileLogger: FileLogger? = null
        private var initialized = false

        private var vpnClient: VpnClient? = null
        @Volatile
        private var configStorage: VpnConfigStorage? = null
        // The last VpnState observed by `onStateChanged`
        private var lastState: Int = 0
        private const val ACTION_START = "Start"
        private const val ACTION_STOP = "Stop"
        private const val PARAM_CONFIG = "Config Extra"
        private const val PARAM_FALL_INTO_RECOVERY = "Fall Into Recovery Extra"
        private const val PARAM_DISALLOWED_APPS = "Disallowed Apps Extra"
        private const val NOTIFICATION_ID = 1
        private val IPV4_NON_ROUTABLE = listOf("0.0.0.0/8", "224.0.0.0/3")
        private val ADGUARD_DNS_SERVERS = listOf("46.243.231.30", "46.243.231.31", "2a10:50c0::2:ff", "2a10:50c0::1:ff")
        private val FAKE_DNS_SERVER = listOf("198.18.53.53")

        private const val DISALLOWED_APPS_PREFS = "trusttunnel_vpn_plugin"
        private const val KEY_DISALLOWED_APPS = "disallowed_apps"

        private fun getConfigStorage(context: Context): VpnConfigStorage {
            return configStorage ?: VpnConfigStorage(context).also { configStorage = it }
        }

        private fun saveDisallowedApps(context: Context, apps: List<String>?) {
            val prefs = context.getSharedPreferences(DISALLOWED_APPS_PREFS, Context.MODE_PRIVATE)
            if (apps == null) {
                prefs.edit().remove(KEY_DISALLOWED_APPS).apply()
            } else {
                prefs.edit().putStringSet(KEY_DISALLOWED_APPS, apps.toSet()).apply()
            }
        }

        private fun loadDisallowedApps(context: Context): Set<String> {
            val prefs = context.getSharedPreferences(DISALLOWED_APPS_PREFS, Context.MODE_PRIVATE)
            return prefs.getStringSet(KEY_DISALLOWED_APPS, emptySet()) ?: emptySet()
        }

        private fun start(context: Context, intent: Intent, config: String?, fallIntoRecovery: Boolean, disallowedApps: List<String>?) {
            try {
                if (!isPrepared(context)) {
                    LOG.warn("VPN is not prepared, can't manipulate the service")
                    return
                }
                config?.apply {
                    getConfigStorage(context).save(config)
                    intent.putExtra(PARAM_CONFIG, config)
                }
                disallowedApps?.apply { saveDisallowedApps(context, disallowedApps) }
                intent.putStringArrayListExtra(PARAM_DISALLOWED_APPS, disallowedApps?.let { ArrayList(it) })
                intent.putExtra(PARAM_FALL_INTO_RECOVERY, fallIntoRecovery)
                context.startForegroundService(intent)
            } catch (e: Exception) {
                LOG.error("Error occurred while service starting", e)
            }
        }

        fun stop(context: Context) {
            getConfigStorage(context).clear()
            start(context, ACTION_STOP, null, false, null)
        }

        fun start(context: Context, config: String?, fallIntoRecovery: Boolean, disallowedApps: List<String>? = null) =
            start(context, getIntent(context, ACTION_START), config, fallIntoRecovery, disallowedApps)

        private fun start(context: Context, action: String, config: String?, fallIntoRecovery: Boolean, disallowedApps: List<String>?) =
            start(context, getIntent(context, action), config, fallIntoRecovery, disallowedApps)

        fun startNetworkManager(context: Context) = synchronized(NETWORK_MANAGER_SYNC) {
            if (::networkCallback.isInitialized) {
                // Avoid double initialization
                return
            }

            connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            networkRequest = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                .addTransportType(NetworkCapabilities.TRANSPORT_ETHERNET)
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
                .addTransportType(NetworkCapabilities.TRANSPORT_BLUETOOTH)
                .build()

            networkCallback = NetworkUtils.Companion.NetworkCollector()
            connectivityManager.registerNetworkCallback(networkRequest, networkCallback)
        }

        private fun startNetworkNotifications(vpnClient: VpnClient?) = synchronized(NETWORK_MANAGER_SYNC) {
            networkCallback.startNotifying(vpnClient)
        }

        private fun stopNetworkNotifications() = synchronized(NETWORK_MANAGER_SYNC) {
            networkCallback.stopNotifying()
        }

        fun isPrepared(context: Context): Boolean {
            return try {
                prepare(context) == null
            } catch (e: Exception) {
                LOG.error("Error while checking VPN service is prepared", e)
                false
            }
        }

        /** Gets an intent instance with [action] */
        private fun getIntent(context: Context, action: String): Intent = Intent(context, TunVpnService::class.java).setAction(action)

        private val eventsSync = ThreadManager.create("events-sync", 1)
        private var appNotifier: AppNotifier? = null
        fun setAppNotifier(file: File, notifier: AppNotifier) = eventsSync.execute {
            connectionInfoFile = PersistentRingBuffer(file)
            appNotifier = notifier
            // Notify current state
            appNotifier?.onStateChanged(lastState)
            // Notify all query logs
            connectionInfoFile?.apply {
                val records = readAll()
                if (records == null) {
                    clear()
                    return@execute
                }
                for (record in records) {
                    appNotifier?.onConnectionInfo(record)
                }
            }
        }

        /**
         * Initialize the adapter. Call once at plugin startup to set up
         * network monitoring and file logging.
         *
         * Idempotent — safe to call multiple times.
         */
        fun initialize(context: Context) {
            if (initialized) return
            initialized = true

            // FileLogger — captures all logs from this point forward
            val logsDir = File(context.filesDir, "logs")
            val logger = FileLogger(logsDir, FileLogger.VPN_BASE_NAME)
            logger.install()
            fileLogger = logger

            // Network monitoring — detect network changes for VPN recovery
            startNetworkManager(context)
        }

        /**
         * Export log files to a timestamped temp directory.
         *
         * Returns absolute paths to snapshot copies. Caller (Flutter) owns cleanup.
         * Safe to call while VPN is active.
         */
        fun exportLogs(context: Context): List<String> {
            if (!initialized) return emptyList()

            val dateStr = SimpleDateFormat("yyyyMMdd'T'HHmmss", Locale.US).apply {
                timeZone = TimeZone.getDefault()
            }.format(Date())

            val exportDirName = "trusttunnel_android_logs_$dateStr"
            val exportDir = File(context.cacheDir, exportDirName)

            return fileLogger?.snapshotTo(exportDir) ?: emptyList()
        }

        /**
         * Delete all log files produced by the VPN service.
         *
         * Safe to call while the VPN is active.
         */
        fun clearLogs() {
            if (!initialized) return
            fileLogger?.clearLogs()
        }
    }

    private var state = State.Stopped
    private val singleThread = ThreadManager.create("vpn-service", 1)
    @Volatile
    private var certificateVerificator: CertificateVerificator? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            LOG.info("Received a null intent, doing nothing")
            stopSelf()
            return START_NOT_STICKY
        }

        // Foreground service must spawn its notification in the first 5 seconds of the service lifetime
        val notification = createNotification(this.applicationContext)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // We run all payload in another thread (not main) to minimize UI lags
        singleThread.execute {
            try {
                currentStartId = startId
                val action = intent.action
                val config = intent.getStringExtra(PARAM_CONFIG)
                LOG.info("Start executing action=$action flags=$flags startId=$startId configChars=${config?.length ?: -1}")
                when (action) {
                    ACTION_START -> {
                        val disallowedApps = intent.getStringArrayListExtra(PARAM_DISALLOWED_APPS)
                        processStarting(config, intent.getBooleanExtra(PARAM_FALL_INTO_RECOVERY, false), startId, disallowedApps ?: emptyList())
                    }
                    ACTION_STOP -> close(startId)
                    else -> {
                        startNetworkManager(applicationContext)
                        LOG.info("System-triggered start (Always-On VPN), loading persisted config")
                        val persistedConfig = getConfigStorage(applicationContext).load()
                        val persistedApps = loadDisallowedApps(applicationContext)
                        // Always-On VPN should keep recovering instead of giving up after several attempts.
                        processStarting(persistedConfig, true, startId, persistedApps.toList())
                    }
                }

                LOG.info("Command $action for the VPN has been executed")
            } catch (e: Exception) {
                LOG.error("Error while executing command", e)
            }
        }

        return START_NOT_STICKY
    }

    private fun processStarting(configStr: String?, fallIntoRecovery: Boolean, startId: Int, disallowedApps: List<String>) {
        if (state == State.Started) {
            LOG.info("VPN service has already been started, do nothing")
            return
        }
        if (configStr == null) {
            LOG.error("Failed to get the Vpn Interface config settings")
            return
        }
        // ktoml only needs the listener/endpoint sections; the exclusions array can hold
        // tens of thousands of entries and dominates parse time on devices, so drop it
        // here (the native client still receives the full string below).
        val configWithoutExclusions = configStr.lineSequence()
            .filterNot { it.trimStart().startsWith("exclusions") }
            .joinToString("\n")
        val parseStartMs = android.os.SystemClock.elapsedRealtime()
        val config = VpnServiceConfig.parseToml(configWithoutExclusions)
        LOG.info("Service config parsed in ${android.os.SystemClock.elapsedRealtime() - parseStartMs} ms")
        if (config == null) {
            LOG.error("Failed to parse Vpn Interface config")
            return
        }

        try {
            certificateVerificator = CertificateVerificator()
        } catch (e: Exception) {
            LOG.error("Failed to create certificate verifier: $e")
            return run {
                close()
            }
        }

        LOG.info("VPN is starting...")
        val vpnTunInterface = createTunInterface(config, disallowedApps) ?: return run {
            close()
        }
        // This is required to save startId and pass it to `closeIfLast` in case of DISCONNECTED state event
        val service = this
        val proxyClientListener = object : VpnClientListener by service {
            override fun onStateChanged(state: Int) {
                try {
                    val vpnState = VpnState.getByCode(state)
                    LOG.info("TunVpnService onStateChanged: ${vpnState.name}")
                    if (vpnState == VpnState.DISCONNECTED) {
                        singleThread.execute {
                            service.closeIfLast(startId)
                        }
                    }
                } catch (e: Exception) {
                    LOG.warn("Failed to process unknown VPN state $state: $e")
                }
                service.onStateChanged(state)
            }
        }
        vpnClient = VpnClient(configStr, proxyClientListener)

        startNetworkNotifications(vpnClient)
        if (vpnClient?.start(vpnTunInterface, fallIntoRecovery) != true) {
            LOG.error("Failed to start Vpn client");
            close();
        }

        state = State.Started
    }

    override fun onRevoke() = singleThread.execute {
        LOG.info("Revoking the VPN service")
        close()
    }

    private fun createTunInterface(config: VpnServiceConfig, disallowedApps: List<String>): ParcelFileDescriptor? {
        LOG.info("Request 'create tun interface' received (disallowedApps=${disallowedApps.size})")
        val tunConfig = config.listener.tun
        try {
            val builder = Builder().setSession("Trust Tunnel")
                .setMtu(tunConfig.mtuSize.toInt())
                .addAddress("172.20.2.13", 32)
                .addAddress("fdfd:29::2", 64)
                .addDisallowedApplication(applicationContext.packageName)
            applyDisallowedApplications(builder, disallowedApps)
            val dnsServers = if (config.endpoint.dnsUpstreams.isEmpty()) {
                ADGUARD_DNS_SERVERS
            } else {
                FAKE_DNS_SERVER
            }
            dnsServers.forEach { server ->
                builder.addDnsServer(server)
            }

            val routes = VpnClient.excludeCidr(tunConfig.includedRoutes, tunConfig.excludedRoutes + IPV4_NON_ROUTABLE)
                ?: throw Exception("Failed to process routes")
            routes.forEach { route ->
                val r = NetworkUtils.convertCidrToAddressPrefixPair(route)
                if (r != null) {
                    builder.addRoute(r.first, r.second)
                } else {
                    throw Exception("Wrong syntax for included_routes")
                }
            }

            return builder.establish()

        } catch (e: Exception) {
            LOG.error("Error while building the TUN interface", e)
            return null
        }
    }

    /**
     * Excludes the given packages from the VPN: their traffic bypasses the
     * tunnel completely and uses the underlying network.
     *
     * Packages that are not installed are skipped silently —
     * `addDisallowedApplication` throws `NameNotFoundException` for them.
     */
    private fun applyDisallowedApplications(builder: Builder, disallowedApps: List<String>) {
        if (disallowedApps.isEmpty()) return

        val pm = packageManager
        var applied = 0
        for (pkg in disallowedApps.distinct()) {
            try {
                pm.getPackageInfo(pkg, 0)
                builder.addDisallowedApplication(pkg)
                applied++
            } catch (e: Exception) {
                LOG.warn("Skip disallowed application (not installed): $pkg")
            }
        }
        LOG.info("Excluded $applied application(s) from the VPN")
    }

    /**
     * Closes the VPN TUN interface and stops itself only if the called is the only one who
     * tries to stop the service.
     * @param startId start id known to the caller
     * @return true if the service has been closed successfully
     *         false if the service hasn't been stopped because startId is too old
     */
    private fun closeIfLast(startId: Int): Boolean {
        if (startId < currentStartId) {
            return false
        }

        return close(startId)
    }

    /**
     * Closes the VPN TUN interface and stops itself
     * @param startId current start id of the service to forward to `stopSelf`
     * @return true if the service has been closed successfully
     *         false if something is wrong with closing or the service has already been closed
     */
    private fun close(startId: Int? = null): Boolean {
        if (state != State.Started) return false.also { LOG.info("VPN service is not running, do nothing") }

        LOG.info("Closing VPN service")

        stopNetworkNotifications()
        vpnClient?.stop()
        vpnClient?.close()
        vpnClient = null
        if (startId != null) {
            stopSelf(startId)
        } else {
            stopSelf()
        }
        state = State.Stopped

        LOG.info("VPN service closed!")
        return true
    }

    /** An enum to represent the VPN service states */
    enum class State {
        Started, Stopped
    }

    /**
     * Protects passed socket by the [TunVpnService].
     * @param socket socket to protect
     * @return true if socket was protected or false if an error occurred
     */
    override fun protectSocket(socket: Int): Boolean {
        if (protect(socket)) {
            LOG.info("The socket $socket has been protected successfully")
            return true
        }
        LOG.info("Failed to protect socket $socket")
        return false
    }

    override fun verifyCertificate(certificate: ByteArray?, rawChain: List<ByteArray?>?): Boolean {
        val verificator = certificateVerificator ?: return false
        return verificator.verifyCertificate(certificate, rawChain)
    }

    override fun onStateChanged(state: Int) = eventsSync.execute {
        lastState = state
        appNotifier?.onStateChanged(state)
    }

    override fun onConnectionInfo(info: String) = eventsSync.execute {
        LOG.debug("TunVpnService onConnectionInfo event")
        connectionInfoFile?.apply {
            if (!append(info)) {
                clear()
            }
        }
        appNotifier?.onConnectionInfo(info)
    }

    private fun createNotification(context: Context): Notification {
        val name = "ConnectionStatus"
        val descriptionText = "VPN connection status"
        val channel = NotificationChannel(
            name,
            descriptionText,
            NotificationManager.IMPORTANCE_LOW // Set importance to LOW to be less intrusive, but still visible.
        ).apply {
            description = "TrustTunnel status" // User-visible description of the channel
        }
        val notificationManager: NotificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
        return NotificationCompat.Builder(context, name)
            .setContentTitle("TrustTunnel") // Main title of the notification
            .setContentText("VPN is running in foreground") // Content text of the notification
            // Use a small icon that represents your VPN service.
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Placeholder icon (replace with your app's icon)
            .setPriority(NotificationCompat.PRIORITY_LOW) // Set priority for older Android versions
            .setOngoing(true) // Makes the notification non-dismissible by the user.
            // This is a key characteristic of foreground service notifications.
            .build()
    }
}
