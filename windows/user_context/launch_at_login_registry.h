#ifndef TRUSTTUNNEL_LAUNCH_AT_LOGIN_REGISTRY_H_
#define TRUSTTUNNEL_LAUNCH_AT_LOGIN_REGISTRY_H_

#include <string>

#include "user_context.h"

namespace windows_launch_at_login {
// App settings pass HKCU. Installer operations pass the resolved user's hive.
LSTATUS ReadEnabled(HKEY root, bool& enabled);
LSTATUS ReadWindowPreference(HKEY root, bool& enabled);
LSTATUS SetEnabled(HKEY root, bool enabled,
                   windows_user_context::RegistryHiveType hive_type =
                       windows_user_context::RegistryHiveType::kUser);
LSTATUS SetWindowPreference(HKEY root, bool enabled);
// Leaves another installation's command and the window preference intact.
LSTATUS RemoveForExecutable(HKEY root, const std::wstring& executable,
                            windows_user_context::RegistryHiveType hive_type =
                                windows_user_context::RegistryHiveType::kUser);
}  // namespace windows_launch_at_login

#endif
