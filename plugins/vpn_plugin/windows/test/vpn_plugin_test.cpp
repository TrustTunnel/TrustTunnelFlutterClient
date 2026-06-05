#include <gtest/gtest.h>
#include <gmock/gmock.h>

#include <atomic>
#include <chrono>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "background_worker.h"
#include "vpn_plugin.h"
#include "mocks/vpn_easy_stub_state.h"

namespace vpn_plugin {
namespace test {

// ---------------------------------------------------------------------------
// BackgroundWorker tests
// ---------------------------------------------------------------------------

TEST(BackgroundWorkerTest, PostExecutesTask) {
    BackgroundWorker worker;
    std::atomic<bool> executed{false};
    worker.Post([&]() { executed = true; });
    for (int i = 0; i < 100 && !executed; ++i) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    EXPECT_TRUE(executed);
}

TEST(BackgroundWorkerTest, SyncBlocksUntilTaskCompletes) {
    BackgroundWorker worker;
    std::atomic<int> counter{0};
    worker.Sync([&]() { counter++; });
    EXPECT_EQ(counter, 1);
}

TEST(BackgroundWorkerTest, MultiplePostsAreAllExecuted) {
    BackgroundWorker worker;
    std::atomic<int> counter{0};
    constexpr int kCount = 10;
    for (int i = 0; i < kCount; ++i) {
        worker.Post([&]() { counter++; });
    }
    worker.Sync([&]() {});
    EXPECT_EQ(counter, kCount);
}

TEST(BackgroundWorkerTest, DestructorDoesNotHang) {
    auto worker = std::make_unique<BackgroundWorker>();
    std::atomic<int> counter{0};
    worker->Sync([&]() { counter++; });
    EXPECT_EQ(counter, 1);
    worker.reset();  // Should not hang.
}

TEST(BackgroundWorkerTest, TasksExecuteInOrder) {
    BackgroundWorker worker;
    std::vector<int> order;
    std::mutex m;
    for (int i = 0; i < 5; ++i) {
        worker.Post([&m, &order, i]() {
            std::lock_guard<std::mutex> lock(m);
            order.push_back(i);
        });
    }
    worker.Sync([&m, &order]() {
        std::lock_guard<std::mutex> lock(m);
        order.push_back(99);
    });
    std::lock_guard<std::mutex> lock(m);
    ASSERT_EQ(order.size(), 6u);
    for (int i = 0; i < 5; ++i) {
        EXPECT_EQ(order[i], i);
    }
    EXPECT_EQ(order[5], 99);
}

TEST(BackgroundWorkerTest, SyncAfterMultiplePosts) {
    BackgroundWorker worker;
    std::atomic<int> counter{0};
    worker.Post([&]() { counter++; });
    worker.Post([&]() { counter++; });
    worker.Sync([&]() { counter++; });
    EXPECT_EQ(counter, 3);
}

// ---------------------------------------------------------------------------
// VpnEventStreamHandler tests — event queuing is the plugin's own logic
// ---------------------------------------------------------------------------

class MockEventSink : public flutter::EventSink<flutter::EncodableValue> {
public:
    MOCK_METHOD(void, SuccessInternal,
                (const flutter::EncodableValue* event), (override));
    MOCK_METHOD(void, ErrorInternal,
                (const std::string& error_code,
                 const std::string& error_message,
                 const flutter::EncodableValue* error_details), (override));
    MOCK_METHOD(void, EndOfStreamInternal, (), (override));
};

TEST(VpnEventStreamHandlerTest, SendEventQueuesWhenNoSink) {
    VpnEventStreamHandler handler;
    handler.SendEvent(flutter::EncodableValue("hello"));
    handler.SendEvent(flutter::EncodableValue("world"));

    auto sink = std::make_unique<MockEventSink>();
    EXPECT_CALL(*sink, SuccessInternal(testing::NotNull())).Times(2);
    handler.OnListen(nullptr, std::move(sink));
}

TEST(VpnEventStreamHandlerTest, ReListenDeliversQueuedEvents) {
    VpnEventStreamHandler handler;

    auto sink1 = std::make_unique<MockEventSink>();
    EXPECT_CALL(*sink1, SuccessInternal(testing::_)).Times(0);
    handler.OnListen(nullptr, std::move(sink1));
    handler.OnCancel(nullptr);

    handler.SendEvent(flutter::EncodableValue(100));

    auto sink2 = std::make_unique<MockEventSink>();
    EXPECT_CALL(*sink2, SuccessInternal(testing::NotNull())).Times(1);
    handler.OnListen(nullptr, std::move(sink2));
}

}  // namespace test
}  // namespace vpn_plugin
