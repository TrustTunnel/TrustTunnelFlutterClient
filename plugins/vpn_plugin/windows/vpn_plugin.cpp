// Copyright 2024 TrustTunnel contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license.

#include "vpn_plugin.h"

#include <appmodel.h>
#include <shellapi.h>
#include <ShlObj.h>

#include <cstdarg>
#include <cstdio>
#include <filesystem>

#include "vpn/trusttunnel.h"
#include "vpn/trusttunnel_service.h"

namespace vpn_plugin {

/**
 * Minimal Windows-native logging (replaces common/logger.h dependency).
 * OutputDebugStringA sends to the debugger; for production MSIX builds
 * these messages appear in tools like DebugView or ETW traces.
 * @param fmt Printf-style format string.
 */
static void LogError(const char* fmt, ...) {
    char buf[512];
    va_list args;
    va_start(args, fmt);
    int n = vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    if (n > 0) {
        OutputDebugStringA(buf);
        OutputDebugStringA("\n");
    }
}

// ---------------------------------------------------------------------------
// MSIX helpers
// ---------------------------------------------------------------------------

/**
 * Check whether the process is running inside an MSIX/AppX container.
 * @return True when running in a packaged context.
 */
static bool IsRunningInMsixPackage() {
    UINT32 len = 0;
    // Call with null buffer to probe: ERROR_INSUFFICIENT_BUFFER (122) means
    // the process HAS package identity; APPMODEL_ERROR_NO_PACKAGE (15700)
    // means it's an unpackaged Win32 process.
    LONG result = GetCurrentPackageFullName(&len, nullptr);
    return (result == ERROR_INSUFFICIENT_BUFFER);
}

/**
 * Return the directory containing the running executable.
 * Uses dynamic allocation to avoid MAX_PATH truncation.
 * @return Parent directory of the executable, or empty path on failure.
 */
static std::filesystem::path GetExeDir() {
    std::wstring exe_path;
    DWORD buf_size = MAX_PATH;
    do {
        exe_path.resize(buf_size);
        DWORD len = GetModuleFileNameW(nullptr, exe_path.data(), buf_size);
        if (len == 0) {
            LogError("GetModuleFileNameW failed (error: %lu)", GetLastError());
            return {};
        }
        if (len < buf_size) {
            exe_path.resize(len);
            break;
        }
        buf_size *= 2;
    } while (true);
    return std::filesystem::path(exe_path).parent_path();
}

/**
 * Return a writable directory for runtime data (logs, ring buffers).
 *
 * MSIX: %ProgramData%\TrustTunnel\ (shared between app and SYSTEM service).
 * Otherwise: same directory as the executable.
 * @return Writable path; guaranteed to exist on return.
 */
static std::filesystem::path GetWritableAppDataPath() {
    if (IsRunningInMsixPackage()) {
        PWSTR program_data = nullptr;
        if (SUCCEEDED(SHGetKnownFolderPath(
                FOLDERID_ProgramData, 0, nullptr, &program_data))) {
            std::filesystem::path p =
                    std::filesystem::path(program_data) / L"TrustTunnel";
            CoTaskMemFree(program_data);
            std::error_code ec;
            std::filesystem::create_directories(p, ec);
            return p;
        }
    }
    return GetExeDir();
}

// ---------------------------------------------------------------------------
// trusttunnel C Callbacks
// ---------------------------------------------------------------------------

static void s_notify_state_changed(void* arg, int state) {
    auto* plugin = static_cast<VpnPlugin*>(arg);
    plugin->NotifyStateChanged(state);
}

static void s_notify_connection_info(void* arg, const char* json) {
    auto* plugin = static_cast<VpnPlugin*>(arg);
    if (json != nullptr) {
        plugin->NotifyConnectionInfo(std::string(json));
    }
}

// ---------------------------------------------------------------------------
// VpnEventStreamHandler
// ---------------------------------------------------------------------------

void VpnEventStreamHandler::SendEvent(
        const flutter::EncodableValue& event) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_sink) {
        m_sink->Success(event);
    } else {
        m_event_queue.push(event);
    }
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
VpnEventStreamHandler::OnListenInternal(
        const flutter::EncodableValue* /*arguments*/,
        std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_sink = std::move(events);
    while (!m_event_queue.empty()) {
        m_sink->Success(m_event_queue.front());
        m_event_queue.pop();
    }
    return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
VpnEventStreamHandler::OnCancelInternal(
        const flutter::EncodableValue* /*arguments*/) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_sink.reset();
    return nullptr;
}

// ---------------------------------------------------------------------------
// VpnPlugin
// ---------------------------------------------------------------------------

void VpnPlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarWindows* registrar) {
    auto plugin = std::make_unique<VpnPlugin>(registrar);

    // Register IVpnManager with Pigeon generated handler
    IVpnManager::SetUp(registrar->messenger(), plugin.get());

    registrar->AddPlugin(std::move(plugin));
}

VpnPlugin::VpnPlugin(flutter::PluginRegistrarWindows* registrar)
    : m_registrar(registrar),
      m_service_name(L"TrustTunnelVPN"),
      m_pipe_name(L"\\\\.\\pipe\\trusttunnel_vpn") {
    // Use writable path (MSIX-safe) for runtime data.
    std::filesystem::path app_data = GetWritableAppDataPath();
    m_ring_buffer_path = app_data / L"vpn_query_log.ring";
    m_logs_dir = app_data / L"logs";

    // Install the client-process file log sink before anything logs.
    // Remembered by trusttunnel so export/clear can also reach the service
    // log family, which the service process writes into the same directory.
    trusttunnel_log_init(m_logs_dir.wstring().c_str());

    // Setup Event Channel for State
    auto state_handler = std::make_unique<VpnEventStreamHandler>();
    m_state_handler = state_handler.get();
    m_state_channel =
            std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                    registrar->messenger(), "vpn_plugin_event_channel",
                    &flutter::StandardMethodCodec::GetInstance());
    m_state_channel->SetStreamHandler(std::move(state_handler));

    // Setup Event Channel for Query Log
    auto query_log_handler = std::make_unique<VpnEventStreamHandler>();
    m_query_log_handler = query_log_handler.get();
    m_query_log_channel =
            std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
                    registrar->messenger(),
                    "vpn_plugin_event_channel_query_log",
                    &flutter::StandardMethodCodec::GetInstance());
    m_query_log_channel->SetStreamHandler(std::move(query_log_handler));

    // Attach to the background service and replay persisted connection info.
    m_worker.Post([this]() {
        AttachService();
        std::wstring ring_buffer_path = m_ring_buffer_path.wstring();
        trusttunnel_service_read_all_connection_info(
                ring_buffer_path.c_str(), s_notify_connection_info, this);
    });
}

VpnPlugin::~VpnPlugin() {
    // Tear down the pipe IO synchronously before the worker stops.
    m_worker.Sync([]() {
        trusttunnel_service_detach();
    });
}

int32_t VpnPlugin::RunElevatedHelper(const std::wstring& params) {
    std::filesystem::path exe_dir = GetExeDir();
    std::wstring helper_exe = (exe_dir / L"trusttunnel_service_installer.exe").wstring();

    SHELLEXECUTEINFOW sei = {};
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_NOCLOSEPROCESS;
    sei.lpVerb = L"runas";
    sei.lpFile = helper_exe.c_str();
    sei.lpParameters = params.c_str();
    sei.nShow = SW_HIDE;

    if (!ShellExecuteExW(&sei)) {
        DWORD err = GetLastError();
        if (err == ERROR_CANCELLED) {
            return TRUSTTUNNEL_SVC_ERR_ACCESS;
        }
        return TRUSTTUNNEL_SVC_ERR_OTHER;
    }

    DWORD wait_result =
            WaitForSingleObject(sei.hProcess, SERVICE_INSTALL_TIMEOUT_MS);
    if (wait_result == WAIT_TIMEOUT) {
        CloseHandle(sei.hProcess);
        return TRUSTTUNNEL_SVC_ERR_TIMED_OUT;
    }
    DWORD exit_code = 0;
    GetExitCodeProcess(sei.hProcess, &exit_code);
    CloseHandle(sei.hProcess);

    return static_cast<int32_t>(exit_code);
}

int32_t VpnPlugin::InstallService() {
    if (IsRunningInMsixPackage()) {
        // When running in MSIX, the service is managed by the platform
        // (packaged service). Installing isn't supported; the service is
        // installed along with the package.
        return TRUSTTUNNEL_SVC_ERR_OTHER;
    }
    std::filesystem::path exe_dir = GetExeDir();
    std::wstring service_exe = (exe_dir / L"trusttunnel_service.exe").wstring();
    // The directory where both the client and the service write their
    // rotating log families ("client" and "service" respectively).
    std::wstring logs_dir = m_logs_dir.wstring();
    std::wstring ring_buffer_path_w =
            std::filesystem::path(m_ring_buffer_path).wstring();

    // Build the command-line arguments for trusttunnel_service_installer.exe:
    //   install <image_path> <logs_dir> <pipe_name> <name>
    //           <display_name> <description> <ring_buffer_path>
    std::wstring params = L"install";
    params += L" \"" + service_exe + L"\"";
    params += L" \"" + logs_dir + L"\"";
    params += L" \"" + m_pipe_name + L"\"";
    params += L" \"" + m_service_name + L"\"";
    params += L" \"TrustTunnel VPN Service\"";
    params += L" \"Provides VPN connectivity for the TrustTunnel client.\"";
    params += L" \"" + ring_buffer_path_w + L"\"";

    return RunElevatedHelper(params);
}

int32_t VpnPlugin::UninstallService() {
    if (IsRunningInMsixPackage()) {
        // When running in MSIX, the service is managed by the platform
        // (packaged service). Uninstalling isn't supported; the service is
        // removed when the package is uninstalled.
        return TRUSTTUNNEL_SVC_ERR_OTHER;
    }
    std::wstring params = L"uninstall \"" + m_service_name + L"\"";
    return RunElevatedHelper(params);
}

int32_t VpnPlugin::AttachService() {
    return trusttunnel_service_attach(
            m_service_name.c_str(), m_pipe_name.c_str(),
            s_notify_state_changed, this, s_notify_connection_info, this);
}

int32_t VpnPlugin::StartService(const std::string& config) {
    return trusttunnel_service_start(config.c_str());
}

std::optional<FlutterError> VpnPlugin::Start(const std::string& config) {
    m_worker.Post([this, config = config]() {
        int32_t start_result = StartService(config);

        if (start_result == TRUSTTUNNEL_SVC_ERR_NO_SUCH_SERVICE) {
            int32_t install_result = InstallService();
            if (install_result != 0) {
                LogError("Failed to install VPN service (error code: %d)",
                         install_result);
                return;
            }

            start_result = StartService(config);
        }

        if (start_result != 0) {
            LogError("Failed to start VPN service (error code: %d)",
                     start_result);
            return;
        }
    });

    return std::nullopt;
}

std::optional<FlutterError> VpnPlugin::Stop() {
    m_worker.Post([this]() {
        trusttunnel_service_stop();
    });

    return std::nullopt;
}

std::optional<FlutterError> VpnPlugin::UpdateConfiguration(
        const std::string* /*config*/) {
    // No-op on Windows
    return std::nullopt;
}

ErrorOr<VpnManagerState> VpnPlugin::GetCurrentState() {
    return ErrorOr<VpnManagerState>(m_current_state);
}

void VpnPlugin::NotifyStateChanged(int state) {
    m_dispatcher.RunOnUIThread([this, state]() {
        VpnManagerState converted_state =
                static_cast<VpnManagerState>(state);
        m_current_state = converted_state;
        if (m_state_handler) {
            m_state_handler->SendEvent(
                    flutter::EncodableValue(
                            static_cast<int64_t>(converted_state)));
        }
    });
}

void VpnPlugin::NotifyConnectionInfo(const std::string& json) {
    m_dispatcher.RunOnUIThread([this, json]() {
        if (m_query_log_handler) {
            m_query_log_handler->SendEvent(
                    flutter::EncodableValue(json));
        }
    });
}

ErrorOr<flutter::EncodableList> VpnPlugin::ExportLogs() {
    // Unique temp export dir per call; the caller owns cleanup.
    std::filesystem::path export_dir =
            std::filesystem::temp_directory_path() /
            (L"trusttunnel_windows_logs_" +
             std::to_wstring(GetTickCount64()));

    flutter::EncodableList result;
    trusttunnel_log_export(
            export_dir.wstring().c_str(),
            [](void* arg, const wchar_t* path) {
                // Dart strings are marshaled as UTF-8; transcode the
                // native wide path.
                std::u8string u8 = std::filesystem::path(path).u8string();
                static_cast<flutter::EncodableList*>(arg)->push_back(
                        flutter::EncodableValue(
                                std::string(u8.begin(), u8.end())));
            },
            &result);
    return ErrorOr<flutter::EncodableList>(result);
}

std::optional<FlutterError> VpnPlugin::ClearLogs() {
    trusttunnel_log_clear();
    return std::nullopt;
}

} // namespace vpn_plugin
