#ifndef WINDOW_MANAGER_WINDOWS_TITLE_BAR_H_
#define WINDOW_MANAGER_WINDOWS_TITLE_BAR_H_

#include <flutter/encodable_value.h>
#include <windows.h>

#include <functional>
#include <optional>
#include <string>
#include <vector>

// Owns custom non-client geometry/input. The runner only sizes the child HWND.
class WindowsTitleBar {
 public:
  using StateCallback = std::function<void(const flutter::EncodableMap&)>;
  WindowsTitleBar(HWND window, HWND view, StateCallback callback);
  ~WindowsTitleBar();

  static bool IsWindows11OrGreater();

  void Configure();
  void Center();
  bool SetRegions(const flutter::EncodableMap& arguments);
  flutter::EncodableMap State() const;
  void InvokeButton(const std::string& button);
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam,
                                       LPARAM lparam, bool resizable);

 private:
  struct LogicalRect {
    double left = 0;
    double top = 0;
    double right = 0;
    double bottom = 0;
  };
  static bool ReadRect(const flutter::EncodableValue& value, LogicalRect* rect);
  static LRESULT CALLBACK ChildProc(HWND window, UINT message, WPARAM wparam,
                                    LPARAM lparam, UINT_PTR id,
                                    DWORD_PTR reference);
  LRESULT HitTest(POINT screen_point, bool resizable) const;
  RECT PhysicalRect(const LogicalRect& rect, bool caption_button = false) const;
  RECT WorkArea() const;
  int FrameMetric(int metric) const;
  void UpdateAppearance();
  void EmitState();
  void ResetInput();
  void SetHover(int hit);
  static std::string ButtonName(int hit);

  HWND window_;
  HWND view_;
  StateCallback callback_;
  bool enabled_ = false;
  bool regions_ready_ = false;
  double view_width_ = 0;
  bool resizable_ = true;
  bool windows_11_ = false;
  bool maximized_ = false;
  int hovered_ = HTCLIENT;
  int pressed_ = HTCLIENT;
  LogicalRect drag_;
  LogicalRect minimize_;
  LogicalRect maximize_;
  LogicalRect close_;
  std::vector<LogicalRect> exclusions_;
  std::string font_family_ = "Segoe UI";
};

#endif
