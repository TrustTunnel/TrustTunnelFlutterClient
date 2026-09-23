#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cwchar>
#include <iterator>
#include <regex>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kAppMutexName[] = L"TrustTunnelFlutterClient";
constexpr wchar_t kFlutterWindowClassName[] =
    L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kWindowTitle[] = L"TrustTunnel";
// Allow the first process time to create its window during startup.
constexpr DWORD kExistingWindowWaitMilliseconds = 5000;
// Avoid busy-waiting while checking for the window or mutex ownership.
constexpr DWORD kWindowPollIntervalMilliseconds = 50;
// Bound the responsiveness check if the existing window is hung.
constexpr UINT kWindowResponseTimeoutMilliseconds = 100;
// Fit Windows extended-length executable paths without truncation.
constexpr DWORD kExecutablePathCapacity = 32768;
// app_links identifies link payloads by this WM_COPYDATA value.
constexpr ULONG_PTR kAppLinkMessageId = WM_USER + 2;

std::wstring GetCurrentExecutablePath() {
  std::wstring path(kExecutablePathCapacity, L'\0');
  const DWORD length =
      ::GetModuleFileNameW(nullptr, path.data(), kExecutablePathCapacity);
  if (length == 0 || length == kExecutablePathCapacity) {
    return {};
  }

  path.resize(length);
  return path;
}

bool WindowBelongsToExecutable(HWND window,
                               const std::wstring& executable_path) {
  DWORD process_id = 0;
  ::GetWindowThreadProcessId(window, &process_id);
  if (process_id == 0) {
    return false;
  }

  HANDLE process =
      ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (process == nullptr) {
    return false;
  }

  std::wstring window_executable_path(kExecutablePathCapacity, L'\0');
  DWORD path_length = kExecutablePathCapacity;
  const BOOL query_succeeded = ::QueryFullProcessImageNameW(
      process, 0, window_executable_path.data(), &path_length);
  ::CloseHandle(process);

  if (!query_succeeded) {
    return false;
  }

  window_executable_path.resize(path_length);
  return ::CompareStringOrdinal(
             executable_path.c_str(), -1, window_executable_path.c_str(), -1,
             TRUE) == CSTR_EQUAL;
}

struct FindWindowContext {
  const std::wstring& executable_path;
  HWND window = nullptr;
};

BOOL CALLBACK FindExistingAppWindowCallback(HWND window, LPARAM parameter) {
  auto* context = reinterpret_cast<FindWindowContext*>(parameter);

  wchar_t class_name[64] = {};
  if (::GetClassNameW(window, class_name,
                      static_cast<int>(std::size(class_name))) == 0 ||
      std::wcscmp(class_name, kFlutterWindowClassName) != 0) {
    return TRUE;
  }

  if (::GetWindowTextLengthW(window) !=
      static_cast<int>(std::size(kWindowTitle) - 1)) {
    return TRUE;
  }

  wchar_t title[std::size(kWindowTitle)] = {};
  if (::GetWindowTextW(window, title, static_cast<int>(std::size(title))) == 0 ||
      std::wcscmp(title, kWindowTitle) != 0) {
    return TRUE;
  }

  if (!WindowBelongsToExecutable(window, context->executable_path)) {
    return TRUE;
  }

  context->window = window;
  return FALSE;
}

HWND FindExistingAppWindow() {
  const std::wstring executable_path = GetCurrentExecutablePath();
  if (executable_path.empty()) {
    return nullptr;
  }

  FindWindowContext context{executable_path};
  ::EnumWindows(FindExistingAppWindowCallback,
                reinterpret_cast<LPARAM>(&context));
  return context.window;
}

bool IsWindowReady(HWND window) {
  if (::IsHungAppWindow(window)) {
    return false;
  }

  DWORD_PTR message_result = 0;
  return ::SendMessageTimeoutW(
             window, WM_NULL, 0, 0, SMTO_ABORTIFHUNG | SMTO_BLOCK,
             kWindowResponseTimeoutMilliseconds, &message_result) != 0;
}

HWND WaitForExistingAppWindowOrMutex(HANDLE app_mutex, bool& owns_mutex) {
  const ULONGLONG started_at = ::GetTickCount64();
  do {
    HWND window = FindExistingAppWindow();
    if (window != nullptr && IsWindowReady(window)) {
      return window;
    }

    // Keep this handle and take ownership if the first process exits.
    const DWORD wait_result =
        ::WaitForSingleObject(app_mutex, kWindowPollIntervalMilliseconds);
    if (wait_result == WAIT_OBJECT_0 || wait_result == WAIT_ABANDONED) {
      owns_mutex = true;
      return nullptr;
    }
    if (wait_result != WAIT_TIMEOUT) {
      return nullptr;
    }
  } while (::GetTickCount64() - started_at <
           kExistingWindowWaitMilliseconds);

  return nullptr;
}

void ForwardAppLink(HWND window) {
  const std::vector<std::string> arguments = GetCommandLineArguments();
  if (arguments.size() != 1 ||
      !std::regex_search(arguments.front(),
                         std::regex(R"(^([a-z][a-z0-9+.-]+):)",
                                    std::regex_constants::icase))) {
    return;
  }

  const std::string& link = arguments.front();
  COPYDATASTRUCT data{};
  data.dwData = kAppLinkMessageId;
  // Send the UTF-8 byte count, including '\0', expected by app_links package.
  data.cbData = static_cast<DWORD>(link.size() + 1);
  data.lpData = const_cast<char*>(link.c_str());
  ::SendMessageW(window, WM_COPYDATA, reinterpret_cast<WPARAM>(window),
                 reinterpret_cast<LPARAM>(&data));
}

void ActivateWindow(HWND window) {
  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  } else {
    ::ShowWindow(window, SW_SHOW);
  }

  ::SetWindowPos(window, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  ::SetForegroundWindow(window);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE app_mutex = ::CreateMutexW(nullptr, TRUE, kAppMutexName);
  const DWORD mutex_error = ::GetLastError();
  if (app_mutex == nullptr) {
    return EXIT_FAILURE;
  }

  bool owns_mutex = mutex_error != ERROR_ALREADY_EXISTS;
  if (!owns_mutex) {
    HWND existing_window = WaitForExistingAppWindowOrMutex(app_mutex, owns_mutex);
    if (existing_window != nullptr) {
      ForwardAppLink(existing_window);
      ActivateWindow(existing_window);
      ::CloseHandle(app_mutex);
      return EXIT_SUCCESS;
    }

    if (!owns_mutex) {
      ::CloseHandle(app_mutex);
      return EXIT_FAILURE;
    }
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  int exit_code = EXIT_SUCCESS;
  {
    FlutterWindow window(project);
    Win32Window::Point origin(10, 10);
    Win32Window::Size size(1280, 720);
    if (!window.Create(kWindowTitle, origin, size)) {
      exit_code = EXIT_FAILURE;
    } else {
      window.SetQuitOnClose(true);

      ::MSG msg;
      while (::GetMessage(&msg, nullptr, 0, 0)) {
        ::TranslateMessage(&msg);
        ::DispatchMessage(&msg);
      }
    }
  }

  ::CoUninitialize();
  ::ReleaseMutex(app_mutex);
  ::CloseHandle(app_mutex);
  return exit_code;
}
