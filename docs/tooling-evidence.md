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
