#include "linux_vpn_engine.h"
#include "trusttunnel_transport.h"

#include <gtest/gtest.h>

#include <algorithm>
#include <string>
#include <vector>

using namespace vpn_plugin;

namespace {

struct StateRecorder {
  std::vector<int> states;

  static void OnState(void* user_data, int state) {
    static_cast<StateRecorder*>(user_data)->states.push_back(state);
  }

  bool Has(int state) const {
    return std::find(states.begin(), states.end(), state) != states.end();
  }
};

// Deterministic mock of the TrustTunnel daemon connection. Test code drives
// the daemon-side state transitions through `EmulateDaemonState`.
class MockTransport : public TrustTunnelTransport {
 public:
  bool Init() override {
    ++init_calls;
    return init_result;
  }

  TransportCallResult Start(const std::string& config) override {
    last_config = config;
    ++start_calls;
    return start_result;
  }

  TransportCallResult Stop() override {
    ++stop_calls;
    return TransportCallResult::kSuccess;
  }

  int GetState() override { ++get_state_calls; return get_state_result; }
  void ClearLogs() override { ++clear_logs_calls; }

  void SetHandlers(TransportHandlers handlers) override {
    on_state_handler = std::move(handlers.on_state);
    on_connection_info_handler = std::move(handlers.on_connection_info);
  }

  void EmulateDaemonState(int state) {
    if (on_state_handler != nullptr) {
      on_state_handler(state);
    }
  }

  void EmulateDaemonConnectionInfo(const std::string& json) {
    if (on_connection_info_handler != nullptr) {
      on_connection_info_handler(json);
    }
  }

  bool init_result = true;
  TransportCallResult start_result = TransportCallResult::kSuccess;
  // Daemon-reported state for GetState(); after a successful Start request the
  // daemon normally reports Connecting (2 for an adopted live session).
  int get_state_result = static_cast<int>(kEngineStateConnecting);

  int init_calls = 0;
  int start_calls = 0;
  int stop_calls = 0;
  int clear_logs_calls = 0;
  int get_state_calls = 0;
  std::vector<int> states = {static_cast<int>(kEngineStateDisconnected)};
  std::string last_config;

  std::function<void(int)> on_state_handler;
  std::function<void(const std::string&)> on_connection_info_handler;
};

}  // namespace

TEST(LinuxVpnEngineTest, FullLifecycleFollowsDaemonSignals) {
  MockTransport transport;
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec);

  std::string unused_error;
  EXPECT_TRUE(engine.Start("config", &unused_error));
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateConnecting);
  EXPECT_EQ(transport.last_config, "config");

  transport.EmulateDaemonState(kEngineStateConnected);
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateConnected);

  engine.Stop();
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateDisconnected);
  EXPECT_EQ(rec.states.back(), kEngineStateDisconnected);
}

TEST(LinuxVpnEngineTest, StartInvalidConfigFailsAndRollsBack) {
  MockTransport transport;
  transport.start_result = TransportCallResult::kInvalidConfig;
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec);

  std::string error;
  EXPECT_FALSE(engine.Start("bad", &error));
  EXPECT_FALSE(error.empty());
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateDisconnected);
  EXPECT_TRUE(rec.Has(kEngineStateConnecting));
  EXPECT_TRUE(rec.Has(kEngineStateDisconnected));
}

TEST(LinuxVpnEngineTest, StartUnavailableDaemonFails) {
  MockTransport transport;
  transport.start_result = TransportCallResult::kUnavailable;
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec);

  std::string error;
  EXPECT_FALSE(engine.Start("config", &error));
  EXPECT_FALSE(error.empty());
  EXPECT_NE(error.find("not available"), std::string::npos);
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateDisconnected);
}

TEST(LinuxVpnEngineTest, AlreadyRunningAdoptsExistingSession) {
  MockTransport transport;
  transport.start_result = TransportCallResult::kAlreadyRunning;
  // The daemon was already connected when the session was adopted.
  transport.get_state_result = static_cast<int>(kEngineStateConnected);
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec);

  std::string unused_error;
  EXPECT_TRUE(engine.Start("config", &unused_error));
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateConnected);
  EXPECT_EQ(transport.get_state_calls, 1);

  // A subsequent daemon signal keeps the engine in sync.
  transport.EmulateDaemonState(kEngineStateDisconnected);
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateDisconnected);
}

TEST(LinuxVpnEngineTest, StateIsUpdatedOnlyOnTransitions) {
  MockTransport transport;
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec);

  transport.EmulateDaemonState(kEngineStateConnecting);
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateConnecting);
  transport.EmulateDaemonState(kEngineStateConnecting);
  EXPECT_EQ(rec.states.back(), kEngineStateConnecting);
}

TEST(LinuxVpnEngineTest, StopDuringConnectingReportsDisconnected) {
  MockTransport transport;
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec);

  std::string unused_error;
  EXPECT_TRUE(engine.Start("config", &unused_error));
  engine.Stop();
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateDisconnected);
  EXPECT_EQ(transport.stop_calls, 1);
}

TEST(LinuxVpnEngineTest, ConnectionInfoForwardedToSink) {
  MockTransport transport;
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec);

  std::vector<std::string> received;
  engine.SetConnectionInfoSink([&received](const std::string& json) {
    received.push_back(json);
  });

  transport.EmulateDaemonConnectionInfo(R"({"proto":"TCP"})");
  ASSERT_EQ(received.size(), 1u);
  EXPECT_EQ(received[0], R"({"proto":"TCP"})");
}

TEST(LinuxVpnEngineTest, DecodeValidPayloads) {
  std::string out;
  EXPECT_TRUE(LinuxVpnEngine::DecodeDeepLink("SGVsbG8=", &out) && out == "Hello");
  EXPECT_TRUE(LinuxVpnEngine::DecodeDeepLink("SGVsbG8", &out) && out == "Hello");
  EXPECT_TRUE(LinuxVpnEngine::DecodeDeepLink("S GV\nsb\rG8=", &out) && out == "Hello");
  EXPECT_TRUE(LinuxVpnEngine::DecodeDeepLink("-_A=", &out) && out.size() == 2);
}

TEST(LinuxVpnEngineTest, DecodeRejectsMalformedInput) {
  std::string out;
  EXPECT_FALSE(LinuxVpnEngine::DecodeDeepLink("", &out));
  EXPECT_FALSE(LinuxVpnEngine::DecodeDeepLink(nullptr, &out));
  EXPECT_FALSE(LinuxVpnEngine::DecodeDeepLink("====", &out));
  EXPECT_FALSE(LinuxVpnEngine::DecodeDeepLink("AB=C", &out));
}
