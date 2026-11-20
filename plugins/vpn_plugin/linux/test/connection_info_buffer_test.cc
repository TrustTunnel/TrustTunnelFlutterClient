#include "connection_info_buffer.h"

#include <gtest/gtest.h>

#include <string>

using vpn_plugin::ConnectionInfoBuffer;

TEST(ConnectionInfoBufferTest, PreservesOrderAndDrainsExactlyOnce) {
  ConnectionInfoBuffer buffer(8);
  buffer.Add("first");
  buffer.Add("second");

  const auto drained = buffer.Drain();
  ASSERT_EQ(drained.size(), 2u);
  EXPECT_EQ(drained[0], "first");
  EXPECT_EQ(drained[1], "second");
  // Draining empties the buffer: records are never delivered twice.
  EXPECT_TRUE(buffer.IsEmpty());
  EXPECT_TRUE(buffer.Drain().empty());
}

TEST(ConnectionInfoBufferTest, EvictsOldestBeyondCapacity) {
  ConnectionInfoBuffer buffer(2);
  buffer.Add("old");
  buffer.Add("mid");
  buffer.Add("new");

  EXPECT_EQ(buffer.Size(), 2u);
  const auto drained = buffer.Drain();
  ASSERT_EQ(drained.size(), 2u);
  EXPECT_EQ(drained[0], "mid");
  EXPECT_EQ(drained[1], "new");
}
