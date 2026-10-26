#include "linux_vpn_engine.h"

#include <utility>

namespace vpn_plugin {

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

int LinuxVpnEngine::GetCurrentState() {
  if (transport_ != nullptr) {
    // Initial sync / refresh: adopt the daemon-reported state (e.g. a session
    // started by another client or a previous app run). OnDaemonState
    // deduplicates and notifies the listener only on real transitions.
    const int daemon_state = transport_->GetState();
    if (daemon_state >= 0) {
      OnDaemonState(daemon_state);
    }
    // daemon_state < 0 means the daemon is unreachable: keep the cached value.
  }
  return state_.load();
}

}  // namespace vpn_plugin
