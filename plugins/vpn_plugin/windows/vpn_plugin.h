#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <mutex>
#include <optional>
#include <queue>
#include <string>
#include <thread>
#include <filesystem>

#include "background_worker.h"
#include "runner/platform_api.g.h"
#include "ui_thread_dispatcher.h"

namespace vpn_plugin {

class VpnEventStreamHandler
    : public flutter::StreamHandler<flutter::EncodableValue> {
public:
    VpnEventStreamHandler() = default;
    virtual ~VpnEventStreamHandler() = default;

    /**
     * Send an event to the Flutter side via the event channel.
     * If no listener is active, the event is queued and delivered on the next listen.
     * @param event The event value to send.
     */
    void SendEvent(const flutter::EncodableValue& event);

protected:
    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnListenInternal(
            const flutter::EncodableValue* arguments,
            std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
            override;

    std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
    OnCancelInternal(const flutter::EncodableValue* arguments) override;

private:
    std::mutex m_mutex;
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> m_sink;
    std::queue<flutter::EncodableValue> m_event_queue;
};

class VpnPlugin : public flutter::Plugin, public IVpnManager {
public:
    /**
     * Register this plugin with the Flutter engine.
     * @param registrar The plugin registrar provided by Flutter.
     */
    static void RegisterWithRegistrar(
            flutter::PluginRegistrarWindows* registrar);

    VpnPlugin(flutter::PluginRegistrarWindows* registrar);
    ~VpnPlugin() override;

    VpnPlugin(const VpnPlugin&) = delete;
    VpnPlugin& operator=(const VpnPlugin&) = delete;

    // IVpnManager implementation
    /**
     * Start the VPN service with the given configuration.
     * If the service is not installed, it will be installed first (non-MSIX only).
     * @param config The VPN configuration string.
     * @return Error if the operation cannot be initiated, nullopt otherwise.
     */
    std::optional<FlutterError> Start(const std::string& config) override;

    /**
     * Stop the VPN service.
     * @return Error if the operation cannot be initiated, nullopt otherwise.
     */
    std::optional<FlutterError> Stop() override;

    /**
     * Update the VPN configuration.
     * No-op on Windows: configuration is passed via Start().
     * @param config The new configuration (unused).
     * @return Always nullopt.
     */
    std::optional<FlutterError> UpdateConfiguration(
            const std::string* config) override;

    /**
     * Get the current VPN manager state.
     * @return The current state.
     */
    ErrorOr<VpnManagerState> GetCurrentState() override;

    /**
     * Handle state change notification from vpn_easy.
     * @param state The new state value (cast to VpnManagerState).
     */
    void NotifyStateChanged(int state);

    /**
     * Handle connection info notification from vpn_easy.
     * @param json The connection info as a JSON string.
     */
    void NotifyConnectionInfo(const std::string& json);

private:
    static constexpr DWORD SERVICE_INSTALL_TIMEOUT_MS = 30000;

    /**
     * Launch the service installer helper elevated and wait for it.
     * @param params Command-line arguments for service_installer.exe.
     * @return The helper's exit code, or a negative VpnEasyServiceError on failure.
     */
    int32_t RunElevatedHelper(const std::wstring& params);

    /**
     * Install the VPN service via the elevated helper (non-MSIX only).
     * @return 0 on success, error code otherwise.
     */
    int32_t InstallService();

    /**
     * Uninstall the VPN service via the elevated helper (non-MSIX only).
     * @return 0 on success, error code otherwise.
     */
    int32_t UninstallService();

    /**
     * Attach to the running VPN background service.
     * @return 0 on success, error code otherwise.
     */
    int32_t AttachService();

    /**
     * Start the VPN background service with the given configuration.
     * @param config The VPN configuration string.
     * @return 0 on success, error code otherwise.
     */
    int32_t StartService(const std::string& config);

    flutter::PluginRegistrarWindows* m_registrar;
    UIThreadDispatcher m_dispatcher;
    BackgroundWorker m_worker;

    std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
            m_state_channel;
    std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
            m_query_log_channel;

    VpnEventStreamHandler* m_state_handler = nullptr;
    VpnEventStreamHandler* m_query_log_handler = nullptr;

    std::wstring m_service_name;
    std::wstring m_pipe_name;
    std::filesystem::path m_ring_buffer_path;

    VpnManagerState m_current_state = VpnManagerState::kDisconnected;
};

} // namespace vpn_plugin