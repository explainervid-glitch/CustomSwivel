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

## 3. AIR SDK from HARMAN

<https://airsdk.harman.com/download>

Requires a free account. The free tier covers revenue under $50k/year. Take the
**SDK**, not the end-user runtime. This fork is built against **33.1.1**. Unzip it,
then point `AIR_SDK` at the folder that directly contains `bin/`:

```
setx AIR_SDK "C:\path\to\AIRSDK_33.1.1"
```

Open a new terminal afterwards.

Using a different SDK version means updating the namespace in
[application.xml](application.xml) to match `<descriptorNamespace>` in that SDK's
`airsdk.xml`.

## 4. Clone with submodules

```
git clone --recursive <repo url>
```

Or, if already cloned:

```
git submodule update --init --recursive
```

`lib/format` is a submodule holding the SWF reader and writer. Without it, nothing
compiles.

### Apply the gradient patch

The submodule needs one fix that is **not** committed upstream. Without it, any SWF
containing a gradient with more than 8 control points is rejected outright with
`Gradient supports at most 8 control points`.

```
cd lib/format
git apply ../../format-gradient-fix.patch
cd ../..
```

Confirm it applied:

```
git -C lib/format diff --stat
```

Git submodules record only a commit pointer, so this patch does not travel with a
clone. Re-apply it whenever the submodule is reset.

---

# Building and running

## Build

```
haxe Swivel.hxml
```

Produces `bin/Swivel.swf`.

## Run

```
& "$env:AIR_SDK\bin\adl64.exe" application.xml .
```

Use `adl64`, not `adl` — the 32-bit launcher is capped near 2 GB, which matters
when capturing large frames.

Build and run together:

```
haxe Swivel.hxml; if ($?) { & "$env:AIR_SDK\bin\adl64.exe" application.xml . }
```

PowerShell has no `&&`, hence `; if ($?) { }`.

## Package

```
PackageApp.bat
```

Produces a self-contained bundle in `bin/Swivel/` with a captive AIR runtime and
ffmpeg, so end users install nothing.

It also writes an empty `META-INF/AIR/debug` marker. **This is required.** Frame
throttling uses `System.pause()`, which only works in a debug build; package by hand
without that marker and conversions drop frames.

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

**Toolchain** — builds on Haxe 4 and HARMAN AIR, plus the `externs/` patch above and
a gradient-validation fix in the SWF writer.

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

Swivel runs using the [Harman AIR](https://airsdk.harman.com/) runtime. AIR is
owned by Adobe Systems, Inc.

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
