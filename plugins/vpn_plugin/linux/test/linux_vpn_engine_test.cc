#include "linux_vpn_engine.h"
#include "trusttunnel_transport.h"

#include <gtest/gtest.h>

#include <algorithm>
#include <deque>
#include <functional>
#include <string>
#include <vector>

using namespace vpn_plugin;

namespace {

struct StateRecorder {
  // The engine always starts disconnected.
  std::vector<int> states = {static_cast<int>(kEngineStateDisconnected)};

  static void OnState(void* user_data, int state) {
    static_cast<StateRecorder*>(user_data)->states.push_back(state);
  }

  bool Has(int state) const {
    return std::find(states.begin(), states.end(), state) != states.end();
  }
};

// Deterministic mock of the TrustTunnel daemon connection. Test code drives
// the daemon-side state transitions through `EmulateDaemonState` and scripts
// request results through the result queues (a queue entry is consumed first;
// the default field is used once the queue is empty).
class MockTransport : public TrustTunnelTransport {
 public:
  bool Init() override {
    ++init_calls;
    return init_result;
  }

  TransportCallResult Start(const std::string& config) override {
    last_config = config;
    ++start_calls;
    if (on_start != nullptr) {
      on_start();
    }
    if (!start_results.empty()) {
      const TransportCallResult result = start_results.front();
      start_results.pop_front();
      if (result == TransportCallResult::kSuccess) {
        // An accepted start request moves the daemon into the connecting state.
        get_state_result = static_cast<int>(kEngineStateConnecting);
      }
      return result;
    }
    const TransportCallResult result = start_result;
    if (result == TransportCallResult::kSuccess) {
      // An accepted start request moves the daemon into the connecting state.
      get_state_result = static_cast<int>(kEngineStateConnecting);
    }
    return result;
  }

  TransportCallResult Stop() override {
    ++stop_calls;
    if (!stop_results.empty()) {
      const TransportCallResult result = stop_results.front();
      stop_results.pop_front();
      if (result == TransportCallResult::kSuccess) {
        // The daemon reports the disconnected state after a stop request.
        get_state_result = static_cast<int>(kEngineStateDisconnected);
      }
      return result;
    }
    const TransportCallResult result = stop_result;
    if (result == TransportCallResult::kSuccess) {
      // The daemon reports the disconnected state after a stop request.
      get_state_result = static_cast<int>(kEngineStateDisconnected);
    }
    return result;
  }

  int GetState() override {
    ++get_state_calls;
    if (!get_state_results.empty()) {
      const int state = get_state_results.front();
      get_state_results.pop_front();
      return state;
    }
    return get_state_result;
  }

  void ClearLogs() override { ++clear_logs_calls; }

  void SetHandlers(TransportHandlers handlers) override {
    on_state_handler = std::move(handlers.on_state);
    on_connection_info_handler = std::move(handlers.on_connection_info);
  }

  // Emulates a daemon-side state transition: subsequent GetState() calls
  // report the new state and the registered on-state handler fires, exactly
  // like the real transport.
  void EmulateDaemonState(int state) {
    get_state_result = state;
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
  // Default results used once the scripted queues are empty.
  TransportCallResult start_result = TransportCallResult::kSuccess;
  TransportCallResult stop_result = TransportCallResult::kSuccess;
  int get_state_result = static_cast<int>(kEngineStateDisconnected);

  std::deque<TransportCallResult> start_results;
  std::deque<TransportCallResult> stop_results;
  std::deque<int> get_state_results;

  // Invoked from Start() before the result is produced; lets a test emulate a
  // daemon signal delivered while the synchronous call is in flight.
  std::function<void()> on_start;

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

// Bounded ALREADY_RUNNING wait override so tests do not sleep for seconds.
constexpr int kTestWaitTimeoutMs = 200;

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

  EXPECT_TRUE(engine.Stop(&unused_error));
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

TEST(LinuxVpnEngineTest, AlreadyRunningAdoptsExistingSession) {
  MockTransport transport;
  transport.start_result = TransportCallResult::kAlreadyRunning;
  // The daemon was already connected when the session was adopted.
  transport.get_state_result = static_cast<int>(kEngineStateConnected);
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec, kTestWaitTimeoutMs);

  std::string unused_error;
  EXPECT_TRUE(engine.Start("config", &unused_error));
  // One GetState to classify the ALREADY_RUNNING reply, one to sync the state.
  EXPECT_EQ(transport.get_state_calls, 2);
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateConnected);

  // A subsequent daemon signal keeps the engine in sync.
  transport.EmulateDaemonState(kEngineStateDisconnected);
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateDisconnected);
}

TEST(LinuxVpnEngineTest, AlreadyRunningAfterStopWaitsAndRetries) {
  MockTransport transport;
  // The first Start races with the teardown of the previous session...
  transport.start_results = {TransportCallResult::kAlreadyRunning, TransportCallResult::kSuccess};
  // ...which the daemon reports as disconnected on the first state probe.
  transport.get_state_results = {static_cast<int>(kEngineStateDisconnected),
                                 static_cast<int>(kEngineStateDisconnected)};
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec, kTestWaitTimeoutMs);

  std::string unused_error;
  EXPECT_TRUE(engine.Start("config", &unused_error));
  EXPECT_EQ(transport.start_calls, 2);
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateConnecting);
}

TEST(LinuxVpnEngineTest, AlreadyRunningStillStoppingTimesOut) {
  MockTransport transport;
  transport.start_results = {TransportCallResult::kAlreadyRunning};
  // Classified as disconnected, but the teardown never finishes in time.
  transport.get_state_results = {static_cast<int>(kEngineStateDisconnected)};
  transport.get_state_result = static_cast<int>(kEngineStateConnecting);
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec, kTestWaitTimeoutMs);

  std::string error;
  EXPECT_FALSE(engine.Start("config", &error));
  EXPECT_NE(error.find("still stopping"), std::string::npos);
  // The timed-out start must not be retried unboundedly.
  EXPECT_EQ(transport.start_calls, 1);
  // The rollback published the disconnected state before the engine fell back.
  EXPECT_TRUE(rec.Has(kEngineStateConnecting));
  EXPECT_EQ(rec.states.back(), kEngineStateDisconnected);
}

TEST(LinuxVpnEngineTest, StartDoesNotOverwriteNewerSignalState) {
  MockTransport transport;
  // A daemon signal arrives while the Start request is in flight; the stale
  // GetState reply (connecting) must not regress the applied CONNECTED state.
  transport.on_start = [&transport]() {
    transport.EmulateDaemonState(kEngineStateConnected);
    transport.get_state_result = static_cast<int>(kEngineStateConnecting);
  };
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec, kTestWaitTimeoutMs);

  std::string unused_error;
  EXPECT_TRUE(engine.Start("config", &unused_error));
  // The stale GetState reply was skipped entirely.
  EXPECT_EQ(transport.get_state_calls, 0);
  EXPECT_EQ(rec.states.back(), kEngineStateConnected);
}

TEST(LinuxVpnEngineTest, UnknownDaemonStateIsIgnored) {
  MockTransport transport;
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec, kTestWaitTimeoutMs);

  transport.EmulateDaemonState(42);
  EXPECT_EQ(rec.states.size(), 1u);
  EXPECT_EQ(rec.states.back(), kEngineStateDisconnected);
}

TEST(LinuxVpnEngineTest, StopUnavailableKeepsStateAndReportsError) {
  MockTransport transport;
  transport.stop_result = TransportCallResult::kUnavailable;
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec, kTestWaitTimeoutMs);

  std::string unused_error;
  EXPECT_TRUE(engine.Start("config", &unused_error));
  transport.EmulateDaemonState(kEngineStateConnected);

  std::string error;
  EXPECT_FALSE(engine.Stop(&error));
  EXPECT_FALSE(error.empty());
  EXPECT_NE(error.find("not available"), std::string::npos);
  // A failed stop must not report a disconnection the daemon never confirmed.
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateConnected);
  EXPECT_EQ(rec.states.back(), kEngineStateConnected);
}

TEST(LinuxVpnEngineTest, ConnectionInfoForwardedToSink) {
  MockTransport transport;
  StateRecorder rec;
  LinuxVpnEngine engine(&transport, StateRecorder::OnState, &rec, kTestWaitTimeoutMs);

  std::vector<std::string> received;
  engine.SetConnectionInfoSink([&received](const std::string& json) {
    received.push_back(json);
  });

  transport.EmulateDaemonConnectionInfo(R"({"proto":"TCP"})");
  ASSERT_EQ(received.size(), 1u);
  EXPECT_EQ(received[0], R"({"proto":"TCP"})");
}
