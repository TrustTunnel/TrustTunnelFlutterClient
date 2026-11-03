#ifndef RUNNER_WINDOWS_UPDATE_LAUNCHER_H_
#define RUNNER_WINDOWS_UPDATE_LAUNCHER_H_

#include <flutter/encodable_value.h>
#include <windows.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <string>

struct WindowsUpdateLaunch {
  std::atomic<bool> cancelled{false};
  std::mutex mutex;
  bool completed = false;
  bool finished = false;
  std::string error;
  std::string message;
};

std::string CreateUpdateOperation();
std::shared_ptr<WindowsUpdateLaunch>
LaunchWindowsUpdate(const flutter::EncodableMap &arguments,
                    const std::string &operation);
flutter::EncodableValue ReadWindowsUpdateResult();

#endif
