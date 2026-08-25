/**
 * Stub implementations for the vpn_easy C functions.
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

#include "vpn_easy_stub_state.h"
#include "vpn/vpn_easy.h"
#include "vpn/vpn_easy_service.h"

#include <cstring>
#include <string>

// ---------------------------------------------------------------------------
// VpnEasyStubState implementation
// ---------------------------------------------------------------------------

void VpnEasyStubState::Reset() {
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
    last_start_service_name.clear();
    last_start_pipe_name.clear();
    last_start_config.clear();
    last_start_state_cb = nullptr;
    last_start_state_cb_arg = nullptr;
    last_start_info_cb = nullptr;
    last_start_info_cb_arg = nullptr;

    stop_return_value = 0;
    stop_call_count = 0;
    last_stop_service_name.clear();
    last_stop_pipe_name.clear();

    detach_call_count = 0;

    read_all_info_call_count = 0;
    last_read_all_info_path.clear();
}

VpnEasyStubState& VpnEasyStubState::Instance() {
    static VpnEasyStubState instance;
    return instance;
}

// Global accessor for tests — delegates to the singleton.
static VpnEasyStubState& g_stub = VpnEasyStubState::Instance();

// ---------------------------------------------------------------------------
// Stub implementations
// ---------------------------------------------------------------------------

extern "C" {

int32_t vpn_easy_service_attach(
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

int32_t vpn_easy_service_start(
        const wchar_t* service_name,
        const wchar_t* pipe_name,
        const char* toml_config,
        on_state_changed_t state_cb,
        void* state_cb_arg,
        on_connection_info_json_t info_cb,
        void* info_cb_arg) {
    auto& s = g_stub;
    s.start_call_count++;
    s.last_start_service_name = service_name ? service_name : L"";
    s.last_start_pipe_name = pipe_name ? pipe_name : L"";
    s.last_start_config = toml_config ? toml_config : "";
    s.last_start_state_cb = reinterpret_cast<void*>(state_cb);
    s.last_start_state_cb_arg = state_cb_arg;
    s.last_start_info_cb = reinterpret_cast<void*>(info_cb);
    s.last_start_info_cb_arg = info_cb_arg;
    return s.start_return_value;
}

int32_t vpn_easy_service_stop(
        const wchar_t* service_name,
        const wchar_t* pipe_name) {
    auto& s = g_stub;
    s.stop_call_count++;
    s.last_stop_service_name = service_name ? service_name : L"";
    s.last_stop_pipe_name = pipe_name ? pipe_name : L"";
    return s.stop_return_value;
}

void vpn_easy_service_detach(void) {
    g_stub.detach_call_count++;
}

void vpn_easy_service_read_all_connection_info(
        const wchar_t* ring_buffer_path,
        on_connection_info_json_t info_cb,
        void* info_cb_arg) {
    auto& s = g_stub;
    s.read_all_info_call_count++;
    s.last_read_all_info_path = ring_buffer_path ? ring_buffer_path : L"";
    // Stub does not invoke the callback by default.
}

// Stubs for the non-service vpn_easy API (not used by VpnPlugin but
// required to resolve all symbols from the header).
void vpn_easy_start(const char*, on_state_changed_t, void*) {}
void vpn_easy_stop() {}
vpn_easy_t* vpn_easy_start_ex(const char*, on_state_changed_t, void*,
        on_connection_info_t, void*) { return nullptr; }
void vpn_easy_stop_ex(vpn_easy_t*) {}
int32_t vpn_easy_service_install(const wchar_t*, const wchar_t*,
        const wchar_t*, const wchar_t*, const wchar_t*, const wchar_t*,
        const wchar_t*) { return 0; }
int32_t vpn_easy_service_uninstall(const wchar_t*) { return 0; }

} // extern "C"
