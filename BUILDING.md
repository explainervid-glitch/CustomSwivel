# Building Swivel (Windows)

Swivel is a **Haxe 3** application targeting the **Adobe AIR** desktop runtime.
It shells out to a bundled `ffmpeg.exe` to do the actual encoding.

This working copy tracks the **[SwivelRevival](https://github.com/SwivelRevival/Swivel-Source)**
fork (remote `revival`), which is the original `Herschel/Swivel` tree ported to
Haxe 4 and Harman AIR. It is a strict linear descendant of upstream — same
features, modernized toolchain.

The CI config ([.appveyor.yml](.appveyor.yml)) is stale and still describes the
old Haxe 3 / Adobe AIR 27 setup: it downloads the AIR SDK from
`airdownload.adobe.com`, which no longer serves it. AIR is now maintained by
HARMAN, not Adobe. Ignore that file; the steps below are the working path.

---

## 1. Haxe 4

This tree has been ported to **Haxe 4** syntax (via the SwivelRevival fork), so
install a current Haxe 4.x release — *not* the Haxe 3.4.7 the original upstream
README implies.

<https://haxe.org/download/>

Verify:

```bash
haxe --version
```

The port replaced `haxe.xml.Fast` with `haxe.xml.Access`, converted every
`(get_foo, set_foo)` property accessor to `(get, set)`, and fixed the huey macro
code for the Haxe 4 compiler AST (`EDisplayNew` and `EIn` were removed).

## 2. The `air` haxelib

Provides the Flash/AIR API externs the code compiles against. Note this is
**`air`**, not the `air3` the old upstream `Swivel.hxml` referenced:

```bash
haxelib install air
```

Confirm it registered:

```bash
haxelib list
```

## 3. AIR SDK

Get the **AIR SDK from HARMAN**: <https://airsdk.harman.com/download>

Notes before you download:

- It requires a free account. The **free tier covers revenue under $50k/year**,
  which covers personal/hobby use — but it is a license you are agreeing to, so
  read it rather than taking my word for it.
- Current releases are version **51.x**. The repo was written against AIR **27**.
- Take the **SDK** (the compiler/packager bundle), not the end-user *runtime*.

Unzip it, then set the environment variable the build scripts read
([bat/SetupSDK.bat](bat/SetupSDK.bat) looks for `AIR_SDK`, and validates that
`%AIR_SDK%\bin` exists). Point it at the folder that directly contains `bin/` —
the AIRSDK Manager nests the SDK one level deep:

```bash
setx AIR_SDK "C:\01 Development\AIRSDK\AIRSDK_51.3.3"
```

Open a **new** terminal afterwards for it to take effect.

### Namespace

[application.xml](application.xml) originally declared the AIR 27 namespace,
which a 51.x SDK rejects. It is now:

```xml
<application xmlns="http://ns.adobe.com/air/application/51.3">
```

The correct value for your SDK is in `<AIR_SDK>/airsdk.xml`, under
`<descriptorNamespace>`. If you upgrade the SDK, update this to match.

`-swf-version 27` in [Swivel.hxml](Swivel.hxml) is left alone — it controls
bytecode features, not the runtime, and 27 still compiles fine.

## 4. Submodule

`lib/format` is a git submodule (a Swivel-specific fork of the Haxe `format`
library) and is **not** included in a plain `git clone`. Without it, nothing
compiles. It is pinned to the **`swf-button`** branch — see
[.gitmodules](.gitmodules).

```bash
git submodule update --init --recursive
```

*(Already done in this working copy, at `2dfcd74` on `swf-button`.)*

---

## Building

Compile to `bin/Swivel.swf`:

```bash
haxe Swivel.hxml
```

Run it under the AIR Debug Launcher, without packaging:

```bash
Run.bat
```

Package a distributable app bundle into `bin/Swivel`:

```bash
PackageApp.bat
```

For day-to-day work you only need `haxe Swivel.hxml` followed by `Run.bat`.

### Debug builds

`SwivelController` relies on `flash.system.System.pause()` / `.resume()` to
throttle frame delivery into ffmpeg. **These only work in a debug AIR build.**
That is why both [PackageApp.bat](PackageApp.bat) and the [Makefile](Makefile)
create an empty `META-INF/AIR/debug` marker file after packaging. If you package
by hand and skip that step, conversion will run away and drop frames.

---

## The `externs/` folder

`externs/` is **not** upstream — it was added here to make the build work on
Haxe 4, and [Swivel.hxml](Swivel.hxml) has a matching `-cp externs`.

The `air` haxelib is from 2015 and written for Haxe 3. Two problems:

1. **It is incomplete.** `NativeProcess`, `NativeProcessStartupInfo` and
   `NativeProcessExitEvent` are missing entirely — and Swivel drives ffmpeg
   through `NativeProcess`, so nothing compiles without them.
2. **It shadows 17 of Haxe 4's own std externs with older, weaker versions.**
   Haxe 4 already ships `LoaderContext.allowCodeImport`, `LoaderContext.parameters`
   and `CompressionAlgorithm.LZMA`; the haxelib was hiding them behind Haxe 3-era
   copies that lack those fields.

`externs/` sits *after* `-lib air` on the classpath (later entries win in Haxe),
so it re-shadows the shadower. Contents:

| File | Why |
|---|---|
| `desktop/NativeProcess.hx`, `NativeProcessStartupInfo.hx`, `events/NativeProcessExitEvent.hx` | Missing from `air`; taken from `air3` |
| `desktop/SystemIdleMode.hx` | `air`'s uses `@:fakeEnum`, removed in Haxe 4 |
| `system/LoaderContext.hx`, `utils/CompressionAlgorithm.hx` | Verbatim Haxe 4 std, to undo the haxelib's shadowing |
| `events/Event.hx` | Haxe 4 std + the 11 AIR-only constants (`EXITING`, `USER_IDLE`, …) |
| `events/ProgressEvent.hx`, `events/IOErrorEvent.hx` | Haxe 4 std + the `STANDARD_*` NativeProcess stdio constants |
| `filesystem/FileStream.hx` | `air`'s, with `endian` retyped from `String` to `flash.utils.Endian` |
| `filesystem/File.hx` | `air`'s + `openWithDefaultApplication()` |

If a future `air` haxelib release fixes these, `externs/` and the `-cp externs`
line can be deleted.

## Known rough edges

- **Code signing** — [bat/Swivel.p12](bat/Swivel.p12) is Newgrounds' self-signed
  certificate, and its password sits in plaintext in
  [bat/SetupApplication.bat](bat/SetupApplication.bat) and the
  [Makefile](Makefile). For your own builds, generate your own with
  [bat/CreateCertificate.bat](bat/CreateCertificate.bat).
- **32-bit ffmpeg** — [ffmpeg/win32/ffmpeg.exe](ffmpeg/win32) is an old Zeranoe
  build. It still works, but is missing roughly a decade of encoders (no
  reasonable HEVC, no AV1, no modern ProRes). Swapping in a current
  [gyan.dev](https://www.gyan.dev/ffmpeg/builds/) build is a drop-in replacement
  and a prerequisite for adding modern presets.
- **`redirecter.exe`** — a small C++ shim ([redirecter/](redirecter/)) that sits
  between AIR and ffmpeg on Windows to work around a stdin-flushing bug in
  `NativeProcess`. You do not normally need to rebuild it; the prebuilt binary is
  committed.
- The README's warning still applies: the open-source tree has regressions
  relative to the binary release Newgrounds ships.
