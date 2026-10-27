#ifndef RUNNER_WINDOWS_INSTALLER_H_
#define RUNNER_WINDOWS_INSTALLER_H_

#include <optional>

// Handles native installer commands before Flutter, the installation guard,
// or the app mutex. nullopt means an ordinary application launch.
std::optional<int> RunWindowsInstallerCommand();

#endif
