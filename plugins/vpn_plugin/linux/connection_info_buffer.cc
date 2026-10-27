#include "connection_info_buffer.h"

namespace vpn_plugin {

ConnectionInfoBuffer::ConnectionInfoBuffer(size_t capacity) : capacity_(capacity) {}

void ConnectionInfoBuffer::Add(std::string json) {
  if (capacity_ == 0) {
    return;
  }
  if (records_.size() >= capacity_) {
    records_.pop_front();
  }
  records_.push_back(std::move(json));
}

std::vector<std::string> ConnectionInfoBuffer::Drain() {
  std::vector<std::string> drained(records_.begin(), records_.end());
  records_.clear();
  return drained;
}

bool ConnectionInfoBuffer::IsEmpty() const {
  return records_.empty();
}

size_t ConnectionInfoBuffer::Size() const {
  return records_.size();
}

}  // namespace vpn_plugin
