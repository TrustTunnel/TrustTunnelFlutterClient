#ifndef VPN_PLUGIN_LINUX_CONNECTION_INFO_BUFFER_H_
#define VPN_PLUGIN_LINUX_CONNECTION_INFO_BUFFER_H_

#include <cstddef>
#include <deque>
#include <string>
#include <vector>

namespace vpn_plugin {

// Bounded FIFO for connection telemetry records received while no query-log
// listener is attached. Draining empties the buffer, so every record is
// delivered exactly once and in arrival order.
//
// Not thread-safe: the producer (GDBus signal callbacks) and the consumer
// (EventChannel listen handler) both run on the main GLib context.
class ConnectionInfoBuffer {
 public:
  explicit ConnectionInfoBuffer(size_t capacity);

  // Adds a record; the oldest one is dropped once the capacity is reached.
  void Add(std::string json);

  // Removes and returns all buffered records in arrival order.
  std::vector<std::string> Drain();

  bool IsEmpty() const;
  size_t Size() const;

 private:
  size_t capacity_;
  std::deque<std::string> records_;
};

}  // namespace vpn_plugin

#endif  // VPN_PLUGIN_LINUX_CONNECTION_INFO_BUFFER_H_
