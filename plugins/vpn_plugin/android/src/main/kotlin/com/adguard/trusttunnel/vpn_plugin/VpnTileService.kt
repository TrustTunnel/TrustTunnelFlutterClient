package com.adguard.trusttunnel.vpn_plugin

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.drawable.Icon
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import com.adguard.trusttunnel.AppNotifier
import com.adguard.trusttunnel.VpnService
import java.io.File

class VpnTileService : TileService(), AppNotifier, SharedPreferences.OnSharedPreferenceChangeListener {

    companion object {
        private const val TAG = "VpnTileService"
    }

    override fun onStartListening() {
        super.onStartListening()
        try {
            val prefs = getSharedPreferences(NativeVpnImpl.PREFS_NAME, Context.MODE_PRIVATE)
            prefs.registerOnSharedPreferenceChangeListener(this)
            updateTile(prefs.getInt(NativeVpnImpl.KEY_STATE, 0))
        } catch (e: Exception) {
            Log.e(TAG, "Error in onStartListening", e)
        }
    }

    override fun onStopListening() {
        super.onStopListening()
        try {
            val prefs = getSharedPreferences(NativeVpnImpl.PREFS_NAME, Context.MODE_PRIVATE)
            prefs.unregisterOnSharedPreferenceChangeListener(this)
        } catch (e: Exception) {
            Log.e(TAG, "Error in onStopListening", e)
        }
    }

    override fun onClick() {
        try {
            val prefs = getSharedPreferences(NativeVpnImpl.PREFS_NAME, Context.MODE_PRIVATE)
            val stateRaw = prefs.getInt(NativeVpnImpl.KEY_STATE, 0)
            val state = VpnManagerState.entries.getOrElse(stateRaw) { VpnManagerState.DISCONNECTED }

            Log.d(TAG, "onClick: current state=$state")

            if (state == VpnManagerState.CONNECTED || state == VpnManagerState.CONNECTING) {
                VpnService.stop(applicationContext)
            } else {
                val config = prefs.getString(NativeVpnImpl.KEY_CONFIG, null)
                if (config != null) {
                    VpnService.startNetworkManager(applicationContext)
                    if (!NativeVpnImpl.isRunning) {
                        val queryLogFile = File(filesDir, "query_log.dat")
                        VpnService.setAppNotifier(queryLogFile, this)
                    }
                    VpnService.start(applicationContext, config)
                } else {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    if (intent != null) {
                        startActivityAndCollapse(intent)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onClick", e)
        }
    }

    override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences?, key: String?) {
        try {
            if (key == NativeVpnImpl.KEY_STATE) {
                val state = sharedPreferences?.getInt(key, 0) ?: 0
                Log.d(TAG, "onSharedPreferenceChanged: new state=$state")
                updateTile(state)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onSharedPreferenceChanged", e)
        }
    }

    private fun updateTile(stateRaw: Int) {
        try {
            val state = VpnManagerState.entries.getOrElse(stateRaw) { VpnManagerState.DISCONNECTED }
            val tile = qsTile ?: return

            val iconId = resources.getIdentifier("ic_vpn_tile", "drawable", packageName)
            if (iconId != 0) {
                tile.icon = Icon.createWithResource(this, iconId)
            }

            when (state) {
                VpnManagerState.CONNECTED -> {
                    tile.state = Tile.STATE_ACTIVE
                    tile.label = "VPN Connected"
                }
                VpnManagerState.CONNECTING, VpnManagerState.RECOVERING -> {
                    tile.state = Tile.STATE_INACTIVE
                    tile.label = "Connecting..."
                }
                else -> {
                    tile.state = Tile.STATE_INACTIVE
                    tile.label = "VPN"
                }
            }
            tile.updateTile()
        } catch (e: Exception) {
            Log.e(TAG, "Error updating tile", e)
        }
    }

    override fun onStateChanged(state: Int) {
        try {
            Log.d(TAG, "onStateChanged: $state")
            val prefs = getSharedPreferences(NativeVpnImpl.PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putInt(NativeVpnImpl.KEY_STATE, state).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error in onStateChanged", e)
        }
    }

    override fun onConnectionInfo(info: String) {
    }
}