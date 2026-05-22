#pragma once

#include <functional>
#include <memory>

class UIThreadDispatcher {
 public:
  UIThreadDispatcher();
  ~UIThreadDispatcher();

  UIThreadDispatcher(const UIThreadDispatcher&) = delete;
  UIThreadDispatcher& operator=(const UIThreadDispatcher&) = delete;

  void RunOnUIThread(std::function<void()> task);

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
