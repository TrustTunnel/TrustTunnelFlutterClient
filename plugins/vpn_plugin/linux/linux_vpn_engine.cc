#include "linux_vpn_engine.h"

#include <cstdint>
#include <cstring>
#include <utility>

namespace vpn_plugin {

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

LinuxVpnEngine::LinuxVpnEngine(TrustTunnelTransport* transport,
                               VpnEngineStateCallback callback,
                               void* user_data)
    : transport_(transport),
      callback_(callback),
      user_data_(user_data),
      state_(kEngineStateDisconnected) {
  if (transport_ != nullptr) {
    TransportHandlers handlers;
    handlers.on_state = [this](int state) { OnDaemonState(state); };
    handlers.on_connection_info = [this](const std::string& json) {
      OnDaemonConnectionInfo(json);
    };
    transport_->SetHandlers(std::move(handlers));
    // Idempotent: transport stays uninitialized if the daemon is absent yet;
    // Start() retries the attachment.
    transport_->Init();
  }
}

LinuxVpnEngine::~LinuxVpnEngine() = default;

void LinuxVpnEngine::SetConnectionInfoSink(ConnectionInfoSink sink) {
  connection_info_sink_ = std::move(sink);
}

void LinuxVpnEngine::OnDaemonState(int state) {
  const int prev = state_.exchange(state);
  if (prev != state && callback_ != nullptr) {
    callback_(user_data_, state);
  }
}

void LinuxVpnEngine::OnDaemonConnectionInfo(const std::string& json) {
  if (connection_info_sink_ != nullptr) {
    connection_info_sink_(json);
  }
}

bool LinuxVpnEngine::Start(const std::string& config, std::string* error_message) {
  if (transport_ == nullptr) {
    if (error_message != nullptr) {
      *error_message = "transport is not available";
    }
    return false;
  }
  // Retry attaching in case the daemon was not present during construction.
  if (!transport_->Init()) {
    if (error_message != nullptr) {
      *error_message = "trusttunneld is not available on the system bus";
    }
    return false;
  }

  // Report a consistent in-flight state while the request is being processed.
  const int prev = state_.exchange(kEngineStateConnecting);
  if (prev != kEngineStateConnecting && callback_ != nullptr) {
    callback_(user_data_, kEngineStateConnecting);
  }

  const TransportCallResult result = transport_->Start(config);
  switch (result) {
    case TransportCallResult::kSuccess:
    case TransportCallResult::kAlreadyRunning: {
      // A session started (or one was already running, e.g. adopted from
      // another client): synchronize with the daemon-reported state, since
      // a transition happened while this request was in flight.
      const int daemon_state = transport_->GetState();
      if (daemon_state >= 0) {
        OnDaemonState(daemon_state);
      }
      return true;
    }
    case TransportCallResult::kInvalidConfig:
      if (error_message != nullptr) {
        *error_message = "daemon rejected the configuration (invalid config)";
      }
      break;
    case TransportCallResult::kUnavailable:
      if (error_message != nullptr) {
        *error_message = "trusttunneld is not available on the system bus";
      }
      break;
  }

  // Roll the optimistic state back.
  const int restored = state_.exchange(kEngineStateDisconnected);
  if (restored != kEngineStateDisconnected && callback_ != nullptr) {
    callback_(user_data_, kEngineStateDisconnected);
  }
  return false;
}

void LinuxVpnEngine::Stop() {
  if (transport_ == nullptr) {
    return;
  }
  transport_->Stop();
  const int prev = state_.exchange(kEngineStateDisconnected);
  if (prev != kEngineStateDisconnected && callback_ != nullptr) {
    callback_(user_data_, kEngineStateDisconnected);
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
