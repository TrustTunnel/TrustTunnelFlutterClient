#include "linux_vpn_engine.h"

#include <chrono>
#include <thread>
#include <utility>

namespace vpn_plugin {

namespace {

// Poll step while waiting out a daemon-side stop.
constexpr int kDisconnectPollStepMs = 100;

}  // namespace

LinuxVpnEngine::LinuxVpnEngine(TrustTunnelTransport* transport,
                               VpnEngineStateCallback callback,
                               void* user_data,
                               int already_running_wait_timeout_ms)
    : transport_(transport),
      callback_(callback),
      user_data_(user_data),
      state_(kEngineStateDisconnected),
      already_running_wait_timeout_ms_(already_running_wait_timeout_ms) {
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
  // Unknown values must not reach Dart: the Pigeon enum only defines 0..5.
  // Silently ignored: the transport already logs D-Bus problems.
  if (state < kEngineStateDisconnected || state > kEngineStateWaitingForNetwork) {
    return;
  }
  ++state_generation_;
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

bool LinuxVpnEngine::WaitForDaemonDisconnected(int timeout_ms) {
  const auto step = std::chrono::milliseconds(kDisconnectPollStepMs);
  for (int waited = 0; waited < timeout_ms; waited += kDisconnectPollStepMs) {
    if (transport_->GetState() == kEngineStateDisconnected) {
      return true;
    }
    std::this_thread::sleep_for(step);
  }
  return transport_->GetState() == kEngineStateDisconnected;
}

void LinuxVpnEngine::ApplyDaemonStateIfUnchanged(uint64_t generation) {
  if (state_generation_ != generation) {
    // A newer daemon event (e.g. the CONNECTING/CONNECTED signal delivered
    // while the synchronous call was in flight) has already been applied.
    return;
  }
  const int daemon_state = transport_->GetState();
  if (daemon_state >= 0) {
    OnDaemonState(daemon_state);
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

  const uint64_t generation = state_generation_;
  TransportCallResult result = transport_->Start(config);
  if (result == TransportCallResult::kAlreadyRunning) {
    const int daemon_state = transport_->GetState();
    if (daemon_state == kEngineStateDisconnected) {
      // The daemon has just finished a stop: the reply raced with the teardown
      // of the previous session. Wait for it to complete and retry once.
      if (WaitForDaemonDisconnected(already_running_wait_timeout_ms_)) {
        result = transport_->Start(config);
      } else {
        if (error_message != nullptr) {
          *error_message = "a previous VPN session is still stopping; try again shortly";
        }
        RollBackToDisconnected();
        return false;
      }
    } else if (daemon_state < 0) {
      result = TransportCallResult::kUnavailable;
    }
    // daemon_state > 0: a live session is running (e.g. started by a previous
    // app run); adopt it in the success path below.
  }

  switch (result) {
    case TransportCallResult::kSuccess:
    case TransportCallResult::kAlreadyRunning: {
      // A session started (or an existing one was adopted): synchronize with
      // the daemon-reported state, since a transition may have happened while
      // this request was in flight.
      ApplyDaemonStateIfUnchanged(generation);
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

  RollBackToDisconnected();
  return false;
}

void LinuxVpnEngine::RollBackToDisconnected() {
  const int restored = state_.exchange(kEngineStateDisconnected);
  if (restored != kEngineStateDisconnected && callback_ != nullptr) {
    callback_(user_data_, kEngineStateDisconnected);
  }
}

bool LinuxVpnEngine::Stop(std::string* error_message) {
  if (transport_ == nullptr) {
    if (error_message != nullptr) {
      *error_message = "transport is not available";
    }
    return false;
  }
  if (transport_->Stop() != TransportCallResult::kSuccess) {
    // The stop request did not reach the daemon: the final DISCONNECTED state
    // would never arrive, so the cached state must not change.
    if (error_message != nullptr) {
      *error_message = "trusttunneld is not available on the system bus";
    }
    return false;
  }
  const int prev = state_.exchange(kEngineStateDisconnected);
  if (prev != kEngineStateDisconnected && callback_ != nullptr) {
    callback_(user_data_, kEngineStateDisconnected);
  }
  return true;
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
