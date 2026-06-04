#pragma once

/**
 * Stub state for the vpn_easy C functions.
 *
 * Defined in test/mocks/vpn_easy_stubs.cpp. Tests include this header to
 * inspect and control the stub behaviour (e.g. set return values, check
 * call counts).
 */

#include <cstdint>
#include <string>

struct VpnEasyStubState {
    // vpn_easy_service_attach
    int32_t attach_return_value = 0;
    int attach_call_count = 0;
    std::wstring last_attach_service_name;
    std::wstring last_attach_pipe_name;
    void* last_attach_state_cb = nullptr;
    void* last_attach_state_cb_arg = nullptr;
    void* last_attach_info_cb = nullptr;
    void* last_attach_info_cb_arg = nullptr;

    // vpn_easy_service_start
    int32_t start_return_value = 0;
    int start_call_count = 0;
    std::wstring last_start_service_name;
    std::wstring last_start_pipe_name;
    std::string last_start_config;
    void* last_start_state_cb = nullptr;
    void* last_start_state_cb_arg = nullptr;
    void* last_start_info_cb = nullptr;
    void* last_start_info_cb_arg = nullptr;

    // vpn_easy_service_stop
    int32_t stop_return_value = 0;
    int stop_call_count = 0;
    std::wstring last_stop_service_name;
    std::wstring last_stop_pipe_name;

    // vpn_easy_service_detach
    int detach_call_count = 0;

    // vpn_easy_service_read_all_connection_info
    int read_all_info_call_count = 0;
    std::wstring last_read_all_info_path;

    // Reset all state to defaults.
    void Reset();

    // Global singleton that tests can inspect.
    static VpnEasyStubState& Instance();
};
