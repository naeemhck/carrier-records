# T01 verification evidence

Date: 2026-10-11. Environment: this Windows 10 Pro N 22H2 workstation, local repository on `main`, existing VS Code Flutter SDK. No hosted backend is linked. This record is committed with the T01 scaffold; obtain the exact revision with `git log --oneline -- docs/tooling-evidence.md`.

| Check/action | Actual result |
|---|---|
| Read project instructions/specification | AGENTS.md, memory.md, PRD.md, rules.md, architecture.md, design.md and tasks.md read before implementation |
| SDK version | Flutter 3.47.4 stable, revision 9584c6713b; Dart 3.13.3 |
| Initial `flutter doctor -v` | SDK works; Flutter/Dart absent from PATH, no Android SDK, no Visual Studio C++ tooling |
| `flutter create --platforms=windows,android --org com.carrierrecords --project-name carrier_records app` | Exit 0; both native runners generated |
| Add core packages | Resolution/download succeeded; command initially exited 1 on Windows plugin symlink setup |
| Final `flutter pub get` after explicit version pins | Exit 0; `app/pubspec.lock` retained |
| Dart formatting | Four files checked, two formatted |
| Flutter analysis | Exit 0, no issues |
| Flutter test harness | Exit 0, one setup-route widget test passed |
| Windows debug build attempt | Exit 1; Flutter requires plugin symlink support / Developer Mode |
| Android debug build attempt | Exit 1; no Android SDK found |
| Enable Developer Mode via registry | Denied by Windows registry permissions; not enabled by this session |
| Install missing C++ tooling | `winget` started Visual Studio Build Tools 2022 17.14.41 with VCTools workload and recommended components; download/install still running at this checkpoint. Doctor sees an incomplete installation; success not claimed |
| Install Android prerequisites | `winget` started Android Studio 2026.2.1.8; installer download hash verified, installation still pending at this checkpoint. SDK/JDK/licence verification not yet completed |
| Docker | Desktop started; `docker version` confirms Desktop 4.90.0 and Linux engine 29.7.2 |
| Supabase CLI | Official v2.120.0 Windows AMD64 zip checksum matches `0db5224fc5d92ae5f15e675ed65dad376967326921122ab8d9a78e790874c92e`; version and init exit 0 |
| Local backend startup | First wrapper attempt stopped on redirected stderr progress. Wrapper fixed to preserve native exit codes. Retry is downloading container images; healthy stack not yet confirmed |
| Repository ignores | `git check-ignore` confirms local CLI, Android SDK path file and private local config are ignored |

Pending: finish installers, enable Developer Mode through administrator-controlled Settings, configure Android SDK/command-line tools/JDK and verify licences, rerun doctor and native debug builds, confirm local Supabase startup. Startup logs remain ignored at `tools/.local/supabase/start.log`. Visual Studio installer logs are under the current user's temporary directory. Do not restart duplicate installers without checking the running processes.

No business acceptance scenario AT-01–AT-35, clean database migration, production deployment, installer/APK release, backup or restore has been completed. T02 schema/domain work has not begun. Local configuration examples contain no key, and application code performs no backend writes.

## Continuation checks (2026-10-11)

- Inspected the existing installer processes, WinGet/Visual Studio logs and active Supabase startup. No duplicate installer or container startup was launched.
- Visual Studio Build Tools 2022 17.14.41 completed with installer exit 0. `flutter doctor -v` reports the Windows C++ toolchain as passing and Windows SDK 10.0.26100.0.
- User enabled Developer Mode. Registry verification shows `AllowDevelopmentWithoutDevLicense = 1`; `flutter pub get` passed afterward.
- The existing Android Studio 2026.2.1.8 installer completed successfully. Its bundled OpenJDK 25.0.3 runs. Flutter's local SDK/JDK settings now point to the user's Android SDK directory and Studio JBR.
- No command-line tools were already installed. Downloaded Google's `commandlinetools-win-15859902_latest.zip`, verified SHA-256 `90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a`, and installed it under the user's Android SDK directory. `sdkmanager --licenses` reports all SDK package licences accepted. Installation of the required SDK/NDK packages is still running at this checkpoint.
- Initial Supabase startup completed with exit 0. Optional Vector logging restarted because it could not connect to Docker's TCP logging endpoint. Disabled optional local analytics instead of enabling an unauthenticated Docker TCP listener. After the completed startup, stopped the stack and restarted once (exit 0); no simultaneous startup was used.
- Verified Auth `/auth/v1/health`, REST `/rest/v1/` and Storage `/storage/v1/status`: each HTTP 200. `pg_isready` reports PostgreSQL accepting connections. All health-checked containers pass; REST and Edge Runtime are running without container health probes. Local public keys were used only in memory for health checks and were not printed or committed.
- Windows debug build is running. Android debug build awaits required SDK packages. T01 remains IN PROGRESS and T02 remains TODO until the remaining checks pass.

Official Android tools/checksum reference: https://developer.android.com/studio. Downloads and package/licence logs remain ignored under `tools/.local/`.

Native follow-up: Windows build exited 1 after 336.2 seconds because the secure-storage plugin could not find `atlstr.h` (C1083). The C++ workload alone was insufficient. An ATL modification attempt exited with installer code 5007: quiet/passive modification must start elevated. No modification process remains from that attempt. User was given exact Visual Studio Installer steps to add the latest v143 x86/x64 ATL component; completion remains pending. This is an actual build failure, not a passing Windows check.

Android package download initially stalled in Java's TLS read and was stopped after verifying its process identity; the old command exited 1. A single retry with TLS 1.2, certificate verification intact, explicit connection/read timeouts and verbose output installed CMake 3.22.1 and downloaded the 748,118,221-byte NDK archive; extraction is ongoing. No simultaneous SDK download was started. Remaining API/build-tools installation and Android build are pending.

Latest checkpoint (2026-10-11): SDK installation finished. `sdkmanager --list_installed` recognizes API 36 revision 2, build-tools 36.0.0, platform-tools 37.0.1, NDK 28.2.13676358 and CMake 3.22.1. Remaining Google archives were downloaded using verified HTTPS range requests after stalled processes ended; size and SHA-1 matched Google's repository XML: build-tools `f16ccffd34de8790dede813a6c7d8e2c11a27b50`, platform `2c1a80dd4d9f7d0e6dd336ec603d9b5c55a6f576`, platform-tools `e03e78b1d80b396f1c3358e31251cb31740e1110`. `flutter doctor -v` exits 0 with no issues found. User PATH now includes the verified Flutter bin; existing application sessions need restarting.

Windows retry exits 1 after 30.0 seconds with LNK1104: cannot open `atls.lib`. Inspected installation: ATL header `atlstr.h` and `atlmfc/lib/spectre/x64/atls.lib` exist, but `atlmfc/lib/x64/atls.lib` is absent. User guidance now explicitly selects standard latest v143 x86/x64 ATL without Spectre Mitigations. No library copying or build configuration workaround was used.

Android `flutter build apk --debug --no-pub` exits 1 after 141.9 seconds: Gradle wrapper distribution download times out in TLS read. No Java download process remains. A single HTTPS range download of the official Gradle 9.3.1 all distribution is running; its official SHA-256 was fetched for verification before cache use. Native builds remain failed, T01 remains IN PROGRESS and T02 remains TODO.

Subsequent verification: standard MSVC 14.44 x64 `atls.lib` appeared after the user's installer modification. Windows debug retry exits 0 after 126.2 seconds and produces `app/build/windows/x64/runner/Debug/carrier_records.exe`. This is a debug build, not a packaged installer or a launch test. Official Gradle archive download completed (234,893,460 bytes); SHA-256 matches `17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43`. Copied the verified archive to the wrapper cache only after confirming no wrapper process remained. Android retry successfully extracted Gradle and started its build daemon; final result pending.

Android retry then exited 1 after 339.6 seconds: requested AGP 9.1.0 plugin could not resolve. An HTTPS GET confirmed Google's official POM is available. A sequential Gradle diagnostic using IPv4 preference resolved AGP 9.1.0 and Kotlin 2.4.0, compiled Flutter's Gradle tooling and configured app plugins. The diagnostic itself exited 1 after 16m35s because PowerShell split an unquoted `-D` timeout argument into a task name; this was a command error, not a passing test. Moved timeout flags into `JAVA_TOOL_OPTIONS` and started one APK retry after the diagnostic ended. Gradle automatically installed plugin-required API 35 revision 2 with the accepted licence; download/extraction/install completed. APK result remains pending.

That APK retry exited 1 after 538.1 seconds (8m57s): `shared_preferences_android` and `url_launcher_android` Kotlin incremental caches could not close; stack traces identify different roots between Pub sources on C: and project on D:. Set documented `kotlin.incremental=false` in Android Gradle properties and started one subsequent debug retry after the previous command ended. No dependency version changes, duplicate builds or SDK/cache moves were used. Final retry result pending.

Final T01 result: APK retry exits 0 after 345.3 seconds and produces `app/build/app/outputs/flutter-apk/app-debug.apk`. Both native debug builds now pass. Debug executable SHA-256: `7040a70dfc5fb01749ca31af9fe25585a3d1a3db83bf858a39f2e3104b18bec2`; debug APK SHA-256: `b103c9d6d98ebcc683418587f112fd45ae038a680e940f6cfd62514ea1753963`. These artifacts remain ignored, with no signing keys or credentials committed. Doctor, analyzer, widget harness and local backend health pass. T01 marked DONE; T02 begins. No native launch/device test, packaged installer, signed release, business acceptance, hosted deployment or restore is claimed.
