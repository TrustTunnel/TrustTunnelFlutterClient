#ifndef TRUSTTUNNEL_USER_CONTEXT_H_
#define TRUSTTUNNEL_USER_CONTEXT_H_

#include <windows.h>

#include <string>

namespace windows_user_context {
enum class RegistryHiveType { kUser, kApplication };

DWORD CanonicalizeSid(const std::wstring& input, std::wstring& sid);
// Resolves this process's session, never an arbitrary active console session.
// Session 0 has no interactive target and must supply an explicit SID instead.
DWORD GetSessionUserSid(std::wstring& sid);
DWORD ReadProfilePath(const std::wstring& sid, std::wstring& profile);
// The caller owns the returned key. Offline hives are unloaded when it closes.
LSTATUS OpenUserRegistry(const std::wstring& sid, const std::wstring& profile,
                         REGSAM access, HKEY* key, RegistryHiveType& hive_type);
DWORD GetTokenUserSid(HANDLE token, std::wstring& sid);
// Requires the session user's token; elevation is allowed only with UAC off.
DWORD IsSessionUserToken(HANDLE token, const std::wstring& sid,
                         DWORD session_id, bool& matches);
// Starts the GUI using the shell token of the current Windows session.
// Refuses session 0 and tokens that do not satisfy IsSessionUserToken.
DWORD LaunchAsSessionUser(const std::wstring& executable);
}  // namespace windows_user_context

#endif
