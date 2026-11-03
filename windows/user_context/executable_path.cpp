#include "executable_path.h"

#include <windows.h>

#include <string>

namespace windows_user_context {
namespace {

constexpr DWORD kExecutablePathCapacity = 32768;

}  // namespace

LSTATUS NormalizeExecutablePath(const std::wstring& input,
                                std::wstring& path) {
  // A registration without an absolute path cannot be attributed to a specific
  // executable.
  if (input.size() < 3 ||
      !((input[1] == L':' && (input[2] == L'\\' || input[2] == L'/')) ||
        (input[0] == L'\\' && input[1] == L'\\'))) {
    return ERROR_BAD_PATHNAME;
  }

  std::wstring buffer(kExecutablePathCapacity, L'\0');
  DWORD size = ::GetFullPathNameW(input.c_str(), kExecutablePathCapacity,
                                  buffer.data(), nullptr);
  if (size == 0) {
    return static_cast<LSTATUS>(::GetLastError());
  }
  if (size >= kExecutablePathCapacity) {
    return ERROR_FILENAME_EXCED_RANGE;
  }
  buffer.resize(size);
  path = buffer;

  buffer.resize(kExecutablePathCapacity);
  size = ::GetLongPathNameW(path.c_str(), buffer.data(),
                            kExecutablePathCapacity);
  if (size > 0 && size < kExecutablePathCapacity) {
    buffer.resize(size);
    path = buffer;
  }
  return ERROR_SUCCESS;
}

}  // namespace windows_user_context
