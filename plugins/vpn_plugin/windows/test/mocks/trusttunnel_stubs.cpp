/**
 * Stub implementations for the trusttunnel C functions.
 *
 * These stubs replace the real TrustTunnelClientWindows library so
 * that unit tests can link and exercise the plugin code without
 * actually starting/stopping a VPN service.
 *
 * The stubs record call arguments in global state so tests can
 * verify behaviour (e.g. "Start was called with the right config").
 *
 * Headers come from the real TrustTunnelClientWindows package (added
 * to the include path via CMake). Only the IMPLEMENTATIONS are stubbed.
 */

#include "trusttunnel_stub_state.h"
#include "vpn/trusttunnel.h"
#include "vpn/trusttunnel_service.h"

#include <cstring>
#include <string>

// ---------------------------------------------------------------------------
// TrusttunnelStubState implementation
// ---------------------------------------------------------------------------

void TrusttunnelStubState::Reset() {
    attach_return_value = 0;
    attach_call_count = 0;
    last_attach_service_name.clear();
    last_attach_pipe_name.clear();
    last_attach_state_cb = nullptr;
    last_attach_state_cb_arg = nullptr;
    last_attach_info_cb = nullptr;
    last_attach_info_cb_arg = nullptr;

    start_return_value = 0;
    start_call_count = 0;
    last_start_config.clear();

    stop_return_value = 0;
    stop_call_count = 0;

    detach_call_count = 0;

    read_all_info_call_count = 0;
    last_read_all_info_path.clear();

    log_init_call_count = 0;
    last_log_init_dir.clear();

    log_export_call_count = 0;
    last_log_export_dir.clear();

    log_clear_call_count = 0;
}

TrusttunnelStubState& TrusttunnelStubState::Instance() {
    static TrusttunnelStubState instance;
    return instance;
}

// Global accessor for tests — delegates to the singleton.
static TrusttunnelStubState& g_stub = TrusttunnelStubState::Instance();

// ---------------------------------------------------------------------------
// Stub implementations
// ---------------------------------------------------------------------------

extern "C" {

int32_t trusttunnel_service_attach(
        const wchar_t* service_name,
        const wchar_t* pipe_name,
        on_state_changed_t state_cb,
        void* state_cb_arg,
        on_connection_info_json_t info_cb,
        void* info_cb_arg) {
    auto& s = g_stub;
    s.attach_call_count++;
    s.last_attach_service_name = service_name ? service_name : L"";
    s.last_attach_pipe_name = pipe_name ? pipe_name : L"";
    s.last_attach_state_cb = reinterpret_cast<void*>(state_cb);
    s.last_attach_state_cb_arg = state_cb_arg;
    s.last_attach_info_cb = reinterpret_cast<void*>(info_cb);
    s.last_attach_info_cb_arg = info_cb_arg;
    return s.attach_return_value;
}

int32_t trusttunnel_service_start(
        const char* toml_config) {
    auto& s = g_stub;
    s.start_call_count++;
    s.last_start_config = toml_config ? toml_config : "";
    return s.start_return_value;
}

int32_t trusttunnel_service_stop(void) {
    auto& s = g_stub;
    s.stop_call_count++;
    return s.stop_return_value;
}

void trusttunnel_service_detach(void) {
    g_stub.detach_call_count++;
}

void trusttunnel_service_read_all_connection_info(
        const wchar_t* ring_buffer_path,
        on_connection_info_json_t info_cb,
        void* info_cb_arg) {
    auto& s = g_stub;
    s.read_all_info_call_count++;
    s.last_read_all_info_path = ring_buffer_path ? ring_buffer_path : L"";
    // Stub does not invoke the callback by default.
}

void trusttunnel_log_init(const wchar_t* logs_dir) {
    auto& s = g_stub;
    s.log_init_call_count++;
    s.last_log_init_dir = logs_dir ? logs_dir : L"";
}

void trusttunnel_log_export(const wchar_t* dest_dir, on_log_path_t path_cb,
        void* path_cb_arg) {
    auto& s = g_stub;
    s.log_export_call_count++;
    s.last_log_export_dir = dest_dir ? dest_dir : L"";
    // Report a single sample exported file so tests can assert the
    // resulting path list without touching the real filesystem.
    if (path_cb != nullptr && dest_dir != nullptr) {
        std::wstring sample = std::wstring(dest_dir) + L"\\service.log";
        path_cb(path_cb_arg, sample.c_str());
    }
}

void trusttunnel_log_clear(void) {
    g_stub.log_clear_call_count++;
}

// Stubs for the non-service trusttunnel API (not used by VpnPlugin but
// required to resolve all symbols from the header).
void trusttunnel_start(const char*, on_state_changed_t, void*) {}
void trusttunnel_stop() {}
trusttunnel_t* trusttunnel_start_ex(const char*, on_state_changed_t, void*,
        on_connection_info_t, void*) { return nullptr; }
void trusttunnel_stop_ex(trusttunnel_t*) {}
int32_t trusttunnel_service_install(const wchar_t*, const wchar_t*,
        const wchar_t*, const wchar_t*, const wchar_t*, const wchar_t*,
        const wchar_t*) { return 0; }
int32_t trusttunnel_service_uninstall(const wchar_t*) { return 0; }

} // extern "C"
