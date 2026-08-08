# ![Swivel](https://3.ntv.ru/public/files/82266708/swivel_logo.png)

Converts Adobe Flash SWF files to video.

A fork of [Herschel/Swivel](https://github.com/Herschel/Swivel), by way of
[SwivelRevival](https://github.com/SwivelRevival/Swivel-Source), updated to build on a
current toolchain and extended for an Adobe Animate workflow.
See [What this fork changes](#what-this-fork-changes).

## Binaries

The original stable release can be found here:
[Legacy Edition](https://www.newgrounds.com/wiki/creator-resources/flash-resources/swivel?path=/wiki/creator-resources/flash-resources/swivel).

---

# Setting up on another PC

Four things to install. None are optional.

## 1. Haxe 4

<https://haxe.org/download/>

**Not Haxe 3.** This tree uses Haxe 4 syntax throughout. Verify:

```
haxe --version
```

## 2. The `air` haxelib

```
haxelib install air
```

Then pin the library folder so every shell agrees where it lives:

```
haxelib setup
```

Without a config file, different shells guess different repository locations, and
you get `Library air is not installed` in one terminal while another builds fine.

## 3. AIR SDK 32.0

This fork targets **Adobe AIR 32.0**, the final release before HARMAN took over at
AIR 33. That is a deliberate choice for one reason: **AIR 32 displays no HARMAN
splash screen**. Every later runtime shows one unless you hold a paid HARMAN
licence.

Adobe no longer distributes it, so the 32.0 SDK takes some hunting to find.

Unzip it, then point `AIR_SDK` at the folder that directly contains `bin/`:

```
setx AIR_SDK "C:\path\to\AIRSDK_32.0"
```

Open a new terminal afterwards.

**Newer SDKs also work.** This tree is verified on HARMAN
[51.3.3](https://airsdk.harman.com/download) (free account, free under $50k/year
revenue — take the **SDK**, not the end-user runtime). You trade the splash screen
for a supported, 64-bit runtime. Switching versions means two changes: update the
namespace in [application.xml](application.xml) to match `<descriptorNamespace>` in
that SDK's `airsdk.xml`, and use `adl64.exe` in place of `adl.exe` below.

## 4. Clone

```
git clone <repo url>
```

That is all — no `--recursive`, no submodule step.

`lib/format` holds the SWF reader and writer. Upstream it is a git submodule, which
means a clone gets only a commit pointer and local fixes do not travel with it. Here
it is vendored: the files are committed directly, so a plain clone builds.

That matters because the copy here carries fixes the upstream library does not. All
of them are in [Reader.hx](lib/format/format/swf/Reader.hx) and
[Writer.hx](lib/format/format/swf/Writer.hx):

- **Morph gradient count byte.** The reader consumed a count byte before the gradient
  records; the writer never wrote it back. Every `DefineMorphShape` carrying a
  gradient fill came out exactly one byte short, so all following edge records were
  read misaligned. AIR did not error on the corrupt geometry — it stalled silently,
  forever, on the frame where such a shape was placed. In practice that meant **any
  shape tween animating a gradient hung the conversion**.
- **Radial morph gradients** were written with a `LinearGradient` fill style type.
- **Control point limits** ignored the shape version. `DefineShape4` and
  `DefineMorphShape2` permit 15 control points, not 8; without this, affected files
  are rejected with `Gradient supports at most 8 control points`.

[format-gradient-fix.patch](format-gradient-fix.patch) holds the original
control-point diff for reference only. Everything is already applied.

Still unfixed: focal radial gradients. The reader accepts the fill style then throws,
and never reads the focal point field. Supporting them needs a new variant in
`Data.hx`.

---

# Building and running

## Build

```
haxe Swivel.hxml
```

Produces `bin/Swivel.swf`.

## Run

```
& "$env:AIR_SDK\bin\adl.exe" application.xml .
```

AIR 32 is 32-bit only and ships `adl.exe` alone. That caps the process near 2 GB —
ample at 1080p, but a real ceiling if you push to 4K. On a HARMAN SDK use
`adl64.exe`, which has no such limit.

Build and run together:

```
haxe Swivel.hxml; if ($?) { & "$env:AIR_SDK\bin\adl.exe" application.xml . }
```

PowerShell has no `&&`, hence `; if ($?) { }`.

## Package

```
PackageApp.bat
```

Produces a self-contained bundle in `bin/Swivel/` with a captive AIR runtime and
ffmpeg, so end users install nothing.

**The bundled runtime comes from whichever SDK `AIR_SDK` points at, not from the
namespace in `application.xml`.** `-target bundle` copies a captive runtime out of
the packaging SDK, so packaging with a HARMAN SDK puts the splash screen back even
though `adl` from AIR 32 showed none during development. Verify what actually
shipped:

```
(Get-Item "bin\Swivel\Adobe AIR\Versions\1.0\Adobe AIR.dll").VersionInfo.ProductVersion
```

Since `AIR_SDK` is an ambient environment variable, this drifts silently between
terminals. If packaging matters, pin it.

`Packager.bat` passes `-tsa none`. The timestamp authority AIR 32 defaults to is
long dead and signing otherwise fails with `Could not generate timestamp: Connection
reset`. Timestamping only preserves a signature past certificate expiry, which is
meaningless for the self-signed certificate from `CreateCertificate.bat`.

`PackageApp.bat` also writes an empty `META-INF/AIR/debug` marker. This is no longer
load-bearing — throttling used to rely on `System.pause()`, which needs a debug
build, but that was replaced with a frame-rate throttle. The marker is harmless and
still written.

## Install

```
bin\install.bat
```

Copies the bundle to `C:\Program Files (x86)\Swivel2` and adds a Start Menu entry.
It lives in `bin\` rather than `bin\Swivel\` because `PackageApp.bat` deletes and
recreates that folder on every run.

---

# Why `externs/` exists

`externs/` is not upstream. The `air` haxelib is from 2015 and written for Haxe 3:

- It lacks `NativeProcess` and `ServerSocket` entirely. Swivel drives ffmpeg through
  `NativeProcess`, so nothing compiles without them.
- It shadows 17 of Haxe 4's own standard Flash externs with older, weaker copies,
  hiding fields such as `LoaderContext.allowCodeImport` and
  `CompressionAlgorithm.LZMA`.

`externs/` re-shadows the shadower. In [Swivel.hxml](Swivel.hxml) it must stay
**after** `-lib air`, because later classpath entries win in Haxe.

---

# What this fork changes

**Toolchain** — builds on Haxe 4 and AIR 32 (or any HARMAN SDK), plus the `externs/`
patch above and the SWF reader/writer fixes described earlier — the morph gradient
one is what stopped conversions hanging on shape tweens.

**Reliability** — orphaned `ffmpeg`/`redirecter` processes are killed on shutdown
instead of accumulating at roughly 900 MB each, and backpressure is applied by
throttling the capture window's frame rate rather than suspending the whole runtime
with `System.pause()`.

**Workflow** — multi-file import, drag and drop, visible errors instead of silent
failure, remembered folders, a queue mode that converts each SWF to its own video
rather than chaining them into one, and an optional skip of the first captured frame
for projects using a VCAM rig.

**Adobe Animate bridge** — a CEP panel that hands the SWF you just published straight
to a running Swivel, starts the conversion, and reports progress. Swivel listens on
`127.0.0.1:47800`, loopback only. See
[animate-extension/README.md](animate-extension/README.md).

**Swappable assets** — the completion sound plays `assets/audio/complete.mp3` if
present, and the intro plays `assets/intro.swf` if present, so both can be replaced
without recompiling.

---

# Notes

- [BUILDING.md](BUILDING.md) — toolchain detail and known rough edges
- [THEMING.md](THEMING.md) — reskinning, asset dimensions, fonts
- [tools/check-fonts.py](tools/check-fonts.py) — verifies every font named in
  `SwivelHuey.xml` is actually embedded in `SwivelFonts.swf`

That last one matters more than it sounds. A font name that does not match the
embedded name silently falls back to a system font: it looks perfect on a machine
that has the font installed, and renders **blank** everywhere else. Run it after any
change to `SwivelFonts.fla`:

```
python tools/check-fonts.py
```

---

# License

Swivel is licensed under the GNU GPLv3.
See [LICENSE.md](LICENSE.md) for the full license.

Swivel bundles a captive Adobe AIR runtime — 32.0 by default, or a
[HARMAN](https://airsdk.harman.com/) build if you package with one of their SDKs.
AIR is owned by Adobe Systems, Inc.; releases from 33 onward are distributed by
HARMAN.

Swivel uses software from the [FFmpeg](https://ffmpeg.org/) project along
with supporting libraries, licensed under their corresponding licenses. These
libraries include:

bzip2, fontconfig, FreeType, frei0r, gnutls, LAME, libass, libbluray, libcaca,
libgsm, libtheora, libvorbis, libvpx, opencore-amr, openjpeg, opus, rtmpdump,
schroedinger, speez, twolame, vo-aacenc, vo-amrwbenc, libx264, xavs, xvid, zlib

The full licenses for FFmpeg and each library can be found in the
[FFmpeg/licenses](https://github.com/FFmpeg/FFmpeg/blob/master/LICENSE.md)
folder. These licenses are compatible with the GPLv3.

FFmpeg and these libraries are property of their respective owners.
The FFmpeg build bundled in this software was compiled by Kyle Schwarz and
downloaded from <http://ffmpeg.zeranoe.com/builds/>.
