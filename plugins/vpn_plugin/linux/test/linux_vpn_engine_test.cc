#include "linux_vpn_engine.h"

#include <gtest/gtest.h>

#include <algorithm>
#include <chrono>
#include <string>
#include <thread>
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

}  // namespace

TEST(LinuxVpnEngineTest, FullLifecycleTransitions) {
  StateRecorder rec;
  LinuxVpnEngine engine(20, StateRecorder::OnState, &rec);

  engine.Start("config");
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateConnecting);

  std::this_thread::sleep_for(std::chrono::milliseconds(50));
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateConnected);

  engine.Stop();
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateDisconnected);
  EXPECT_EQ(rec.states.back(), kEngineStateDisconnected);
}

TEST(LinuxVpnEngineTest, StopCancelsPendingConnection) {
  StateRecorder rec;
  LinuxVpnEngine engine(5000, StateRecorder::OnState, &rec);

  engine.Start("config");
  engine.Stop();
  EXPECT_EQ(engine.GetCurrentState(), kEngineStateDisconnected);
  EXPECT_FALSE(rec.Has(kEngineStateConnected));
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
