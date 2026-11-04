#include "linux_vpn_engine.h"

#include <chrono>
#include <cstdint>
#include <cstring>

namespace vpn_plugin {

static const int kPollIntervalMs = 10;

static bool IsBase64Char(char c) {
  return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
         (c >= '0' && c <= '9') || c == '+' || c == '/';
}

static int Base64Value(char c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return c - 'a' + 26;
  if (c >= '0' && c <= '9') return c - '0' + 52;
  if (c == '+') return 62;
  if (c == '/') return 63;
  return -1;
}

LinuxVpnEngine::LinuxVpnEngine(int connect_delay_ms,
                               VpnEngineStateCallback callback,
                               void* user_data)
    : connect_delay_ms_(connect_delay_ms),
      callback_(callback),
      user_data_(user_data),
      state_(kEngineStateDisconnected),
      cancel_(false) {}

LinuxVpnEngine::~LinuxVpnEngine() {
  cancel_ = true;
  if (worker_.joinable()) {
    worker_.join();
  }
}

void LinuxVpnEngine::Start(const char* /*config*/) {
  // TODO: Parse the backend configuration and set up the tun interface and routes.
  cancel_ = true;
  if (worker_.joinable()) {
    worker_.join();
  }
  cancel_ = false;
  state_ = kEngineStateConnecting;
  if (callback_ != nullptr) {
    callback_(user_data_, state_);
  }
  worker_ = std::thread(&LinuxVpnEngine::WorkerMain, this);
}

void LinuxVpnEngine::Stop() {
  cancel_ = true;
  if (worker_.joinable()) {
    worker_.join();
  }
  int prev = state_.exchange(kEngineStateDisconnected);
  if (prev != kEngineStateDisconnected && callback_ != nullptr) {
    callback_(user_data_, kEngineStateDisconnected);
  }
}

void LinuxVpnEngine::WorkerMain() {
  const std::chrono::steady_clock::time_point deadline =
      std::chrono::steady_clock::now() +
      std::chrono::milliseconds(connect_delay_ms_);
  while (!cancel_) {
    if (std::chrono::steady_clock::now() >= deadline) {
      state_ = kEngineStateConnected;
      if (callback_ != nullptr) {
        callback_(user_data_, state_);
      }
      break;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(kPollIntervalMs));
  }
}

bool LinuxVpnEngine::DecodeDeepLink(const char* uri, std::string* payload) {
  if (uri == nullptr || payload == nullptr) {
    return false;
  }

  std::string cleaned;
  const size_t uri_len = strlen(uri);
  cleaned.reserve(uri_len);
  for (size_t i = 0; i < uri_len; i++) {
    char c = uri[i];
    if (c == '-') c = '+';
    else if (c == '_') c = '/';
    if (IsBase64Char(c) || c == '=') {
      cleaned += c;
    }
  }
  while (cleaned.size() % 4 != 0) {
    cleaned += '=';
  }
  if (cleaned.empty()) {
    return false;
  }

  std::string decoded;
  decoded.reserve(cleaned.size() / 4 * 3);
  for (size_t i = 0; i < cleaned.size(); i += 4) {
    int values[4] = {0, 0, 0, 0};
    int data_count = 0;
    for (int j = 0; j < 4; j++) {
      char c = cleaned[i + j];
      if (c == '=') {
        continue;
      }
      int value = Base64Value(c);
      if (value < 0 || j != data_count) {
        return false;
      }
      values[j] = value;
      data_count = j + 1;
    }
    if (data_count < 2) {
      return false;
    }
    const uint32_t group = static_cast<uint32_t>(
        (values[0] << 18) | (values[1] << 12) | (values[2] << 6) | values[3]);
    decoded += static_cast<char>((group >> 16) & 0xFF);
    if (data_count >= 3) {
      decoded += static_cast<char>((group >> 8) & 0xFF);
    }
    if (data_count >= 4) {
      decoded += static_cast<char>(group & 0xFF);
    }
  }

  *payload = decoded;
  return true;
}

}  // namespace vpn_plugin
