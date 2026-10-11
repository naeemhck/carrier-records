# Development tooling

T01 uses the existing VS Code SDK. From the repository root, `tools/flutter.ps1` reads `FLUTTER_SDK` or VS Code's `dart.flutterSdkPath`; no machine-specific SDK path is committed. Run Flutter commands from `app/`:

```powershell
cd app
../tools/flutter.ps1 pub get
../tools/flutter.ps1 analyze --no-pub
../tools/flutter.ps1 test --no-pub
../tools/flutter.ps1 run -d windows
```

Verified SDK: Flutter 3.47.4 stable, framework 9584c6713b, Dart 3.13.3. Direct application dependencies are pinned: flutter_riverpod 3.4.3, go_router 18.0.2, supabase_flutter 2.18.2, flutter_secure_storage 11.2.0. Transitive versions are in `app/pubspec.lock`. Do not upgrade them without rerunning the relevant checks.

Windows requires Developer Mode for plugin symlinks, Visual Studio's C++ workload, and **C++ ATL for latest v143 build tools (x86 & x64)** for the pinned secure-storage plugin. Doctor does not detect every plugin-specific header/library requirement; the native build must pass too. Add ATL using Visual Studio Installer → Build Tools 2022 → Modify → Individual components → search `ATL for latest` → select the x86/x64 latest v143 component without Spectre Mitigations → Modify. If needed, search `14.44` and select its standard x86/x64 ATL entry to match the installed MSVC toolset. The installer needs administrator approval. The standard x64 `atls.lib` must exist under that toolset's `atlmfc/lib/x64/`; installing only Spectre libraries does not satisfy this build.

Android requires an Android SDK, command-line tools, accepted SDK licences, and a compatible JDK (Android Studio provides one). This Flutter SDK requests Android API 36 and NDK 28.2.13676358. `flutter doctor -v` reports readiness. See [Flutter Windows setup](https://docs.flutter.dev/platform-integration/windows/setup), [Android setup](https://docs.flutter.dev/platform-integration/android/setup), and [Microsoft ATL component IDs](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022).

Android plugins also requested API 35, which Gradle installed with its accepted licence. Kotlin incremental compilation is disabled in `app/android/gradle.properties`: plugin sources in the user Pub cache on C: and this project on D: caused relative-path cache failures. This permits full compilation without moving the user's SDK/cache. See [Kotlin compilation and caches](https://kotlinlang.org/docs/gradle-compilation-and-caches.html). For this workstation's transient download failures, build retries used `JAVA_TOOL_OPTIONS` with TLS 1.2, IPv4 preference and bounded HTTP timeouts; certificate verification remained enabled and dependency versions were retained.

## Local backend

`tools/install-supabase.ps1` downloads CLI 2.120.0 from the official release and checks its SHA-256 against the release checksums. Downloaded binaries are ignored under `tools/.local/`. Docker Desktop must be running in Linux-container mode. See [Supabase local development](https://supabase.com/docs/guides/local-development).

```powershell
./tools/install-supabase.ps1
./tools/supabase.ps1 --version
./tools/supabase.ps1 start
# After T02 migrations exist, reset only this disposable local database:
./tools/supabase.ps1 db reset
./tools/supabase.ps1 stop
```

Never use local reset against a hosted project. No hosted project is linked or deployed by T01. The local backend and its test records are disposable, separate from future production setup. Public signup must be disabled even locally; accounts will be provisioned through T03.

Optional local analytics is disabled because Vector could not reach Docker's logging endpoint on this workstation. Auth, database, REST, Storage and Edge Runtime remain enabled. Do not enable an unauthenticated Docker TCP listener to make optional logs work.

## Client configuration

Copy `config/local.example.json` to ignored `config/local.json`, or `config/test.example.json` to ignored `config/test.json`. Fill only the local/test public client key from the local backend. Tests requiring a database must use isolated disposable fixtures, never production records. The examples are configuration contracts; backend initialization and secure session persistence are implemented in T03. The T01 scaffold performs no authentication or financial writes.

Future configured runs use `--dart-define-from-file=../config/local.json`. Only public client configuration may enter builds. Service-role keys, secret API keys, database passwords, signing material and backup keys stay outside client configuration. Production setup is a separate release step, not a fallback for missing development configuration.

Local Git is the versioning authority for this session. Do not publish, push or create a GitHub repository.
