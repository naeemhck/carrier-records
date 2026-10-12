# Private GitHub backup — 2026-10-12

User explicitly authorizes backing up the updated app, code and documents. This supersedes the earlier no-automatic-push instruction for this backup only; future pushes still require user authorization. T19 remains IN PROGRESS; T20 TODO; Windows restart remains deferred. No production scheduling or rollout approval is inferred.

## Actual audit and destination

- Starting working tree clean; HEAD `4b51041b15abf259aa29e2524a1fb7e6624efd56`. Origin fetch/push exactly `https://github.com/naeemhck/carrier-records.git`; only local branch main and no existing local tags.
- `gh` is absent from PATH and checked standard locations; reused the existing Git Credential Manager authentication in memory. Account/destination API verifies `naeemhck`, intended repository, PRIVATE/private visibility and main default branch. No token printed or saved.
- First audit fails before scanning because managed sandbox cannot access local CLI/Docker status. Approved read-only rerun exits 0: **255 tracked files, zero untracked intended files, 454 reachable historical blobs, 15,836 ignored files, no findings**. Existing source/history credential patterns and actual local-key checks remain intact.
- Installer stage/installed credential/hash audit exits 0: **60 inspections**, no privileged/signing material. No new build or field acceptance is claimed.

## Actual backup

`git -C D:/portfolio/transport_project push -u origin main` exits 0, without force, preserving history. Remote advances from `6c8e435` to **`4b51041b15abf259aa29e2524a1fb7e6624efd56`**, independently matched by `git ls-remote origin refs/heads/main`. This evidence follow-up is committed/pushed separately for the same authorized backup; its final SHA/remote match is reported to the user and retained in ignored verification metadata.

Updated app is backed up as a **draft prerelease**, not as build folders in Git:

- [Private installer backup](https://github.com/naeemhck/carrier-records/releases/tag/untagged-e48702ad26d38eefaab7), proposed tag `v0.1.0-pilot.4`, draft=true/prerelease=true; source target is the above initial backed-up commit.
- `CarrierRecords-0.1.0+4-windows-x64-setup.exe`: **14,123,997 bytes**, SHA-256 **c77439b6d4e6ac8e5f0ea781ad8b6229ced242609a47d16c503d217454d3dfc8**.
- `CarrierRecords-0.1.0+4-SHA256.txt` also uploaded. GitHub asset state/size/digest checked, then authenticated installer download streamed and independently hashed; actual size/hash matches local artifact. Redirect handling removes Authorization before a signed asset-host redirect; no credentials or signed URLs recorded.
- Private visibility rechecked after upload. Existing release/assets are never overwritten; unrelated repositories untouched. No installer configuration, protected sessions, privileged key, operational database export, receipt or recovery material uploaded.

Credentials, `.env`, signing keys, backend local settings, receipt/export/backup/recovery data, caches, downloaded tools and other build outputs remain ignored and local, without deletion. This GitHub backup is not a database/receipt disaster-recovery backup.

## Screen-control investigation

Computer-use skill/module is present and `@oai/sky` imports, but fresh `sky.list_apps()` still returns native-pipe-unavailable/system-cannot-find-file/os error 2, before window discovery or any permission prompt. Prior two-second retry and session reset/reinitialize also failed. Carrier Records and ChatGPT process inventory show the same Windows session; process presence is not visible-window or UI acceptance evidence. Narrow read-only inspection finds no explicit computer_use=false in the inspected user configuration/requirements files. No app policy, security setting or host configuration was changed.

The failure is the native computer-use connection being unavailable. Whether its lifecycle failed or the current session did not attach it is **not established**; do not call the helper binary missing or blame Flutter, Windows permissions or the sandbox without evidence. Plugin discovery returned no relevant actionable dependency diagnosis. Did not search/spawn the native helper or substitute shell UI automation.

Official [Computer Use setup](https://learn.chatgpt.com/docs/computer-use) says to use the ChatGPT desktop app, open Plugins → Computer Use/install if prompted, keep Windows target visible in the active desktop, and review access prompts. User can check this setup, keep Carrier Records visible/unlocked, and invoke `@Computer` explicitly. If already installed, closing/reopening ChatGPT (not rebooting Windows) is a troubleshooting suggestion to reestablish its connection, **not a verified fix**. Agent does not control authentication or restart the host/app hosting this conversation. Native screen tests remain blocked until a successful window inventory.
