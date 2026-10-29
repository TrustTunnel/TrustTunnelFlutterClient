#ifndef TRUSTTUNNEL_EXECUTABLE_PATH_H_
#define TRUSTTUNNEL_EXECUTABLE_PATH_H_

#include <windows.h>

#include <string>

namespace windows_user_context {
// Resolves an absolute executable path to its full and, when available, long
// form. Relative paths are rejected with ERROR_BAD_PATHNAME because a
// registration without an absolute path cannot be attributed to a specific
// executable. When GetLongPathNameW fails, the full path is returned as is.
LSTATUS NormalizeExecutablePath(const std::wstring& input,
                                std::wstring& path);
}  // namespace windows_user_context

#endif
