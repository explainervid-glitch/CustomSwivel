# Reskinning Swivel

The look is artwork, not styling. To change it you replace image files in
`assets/` and, if sizes change, adjust coordinates in
[SwivelHuey.xml](SwivelHuey.xml).

After replacing artwork, rebuild:

```
haxe Swivel.hxml
```

---

## How assets are wired

Every image is declared once at the top of [SwivelHuey.xml](SwivelHuey.xml):

```xml
<asset name="bg01" source="assets/BG-01.png"/>
```

and referenced by `name` in the layout below:

```xml
<image source="bg01" x="0" y="0"/>
```

**Filenames are free** -- point `source` at any path you like. Keep `name` the
same, since the layout refers to it.

**Use PNG.** The loader accepts JPEG too, but JPEG has no alpha channel. The
original uses `.jpg` only for opaque rectangles that sit flat on the background.
Anything with rounded corners, soft edges or shadows needs PNG.

**Match the dimensions**, or reposition the element. Every `x`/`y` in the
layout is absolute -- there is no automatic layout.

---

## The trap: buttons with no resting artwork

Several buttons have **no `<upState>`** in the markup. Their normal appearance
is painted directly into `BG-01.png`; only the hover and pressed states are
separate files.

If your new background does not paint these at exactly these coordinates, the
buttons will be **invisible until hovered**.

| Button | Position | Size |
|---|---|---|
| SOURCE tab | 363, 54 | 114x37 |
| VIDEO tab | 483, 54 | 114x37 |
| AUDIO tab | 603, 54 | 114x37 |
| OVERLAY tab | 723, 54 | 114x37 |
| Info (`i`) | 96, 488 | 34x39 |
| Help (`?`) | 136, 488 | 34x39 |
| CONVERT | 690, 488 | 144x39 |
| Minimise | 854, 1 | 25x17 |
| Close | 884, 1 | 25x17 |

**There is a better way.** Ask for `<upState>` entries to be added to these
buttons, and each one becomes self-contained -- then the background is only a
background, and you can move buttons freely without repainting it.

---

## Main screen assets

Window canvas is **930x590**, non-resizable
([application.xml](application.xml), and `-D swf-header=930:590:30` in
[Swivel.hxml](Swivel.hxml)).

| Asset name | File | Size | Notes |
|---|---|---|---|
| `shadow` | SHADOW.png | 930x590 | Drop shadow / window silhouette, drawn under everything |
| `bg01` | BG-01.png | 930x590 | **The whole window**: frame, logo, content area, and the resting state of the buttons listed above |
| `bgConverting` | BG-02.png | 930x590 | Background for the converting/complete screens |
| `tabSource` | barTOGGLE-01.png | 820x92 | Panel header strip, drawn at 55,96 |
| `tabVideo` | barTOGGLE-02.png | 820x92 | |
| `tabAudio` | barTOGGLE-03.png | 820x92 | |
| `tabOverlay` | barTOGGLE-04.png | 820x92 | |
| `btnSourceOver` / `btnSourceOn` | SOURCE-OVER.jpg / SOURCE-ON.jpg | 114x37 | Hover / selected |
| `btnVideoOver` / `btnVideoOn` | VIDEO-*.jpg | 114x37 | |
| `btnAudioOver` / `btnAudioOn` | AUDIO-*.jpg | 114x37 | |
| `btnOverlayOver` / `btnOverlayOn` | OVERLAY-*.jpg | 114x37 | |
| `btnConvertOver` / `btnConvertOn` | CONVERT-*.jpg | 144x39 | |
| `btnInfoOver` / `btnInfoOn` | INFO-*.jpg | 34x39 | |
| `btnHelpOver` / `btnHelpOn` | HELP-*.jpg | 34x39 | |
| `btnAddUp` / `btnAddOver` / `btnAddDown` | ADD*.png | 70x25 | Full 3-state set |
| `btnRemoveUp` / `btnRemoveOver` / `btnRemoveDown` | REMOVE*.png | 70x25 | Full 3-state set |
| `btnCloseOver` / `btnCloseDown` | CLOSE-*.png | 25x17 | |
| `btnMinOver` / `btnMinDown` | MIN-*.png | 25x17 | |
| `listBoxBigBG` | FIELD-BIG.png | 312x75 | Input SWF list background |
| `ngUpsell` | NEWGROUNDS.png | 502x55 | Newgrounds promo strip |

Run this to list every asset with its current dimensions:

```powershell
Add-Type -AssemblyName System.Drawing
$xml = [xml](Get-Content SwivelHuey.xml)
foreach ($a in $xml.application.assets.asset) {
  $p = Join-Path (Get-Location) $a.source
  if (Test-Path $p) {
    $i = [System.Drawing.Image]::FromFile($p)
    "{0,-22} {1,-26} {2}x{3}" -f $a.name, (Split-Path $a.source -Leaf), $i.Width, $i.Height
    $i.Dispose()
  }
}
```

---

## Text, colours and shapes

Not everything is a bitmap. These are editable directly in the markup:

```xml
<label text="Input SWFs" x="115" y="226" font="Swis721 Cn BT" size="14"
       bold="true" color="0x425137"/>
<rectangle x="98" y="194" width="734" height="95" color="0xa6ffffff" radius="4"/>
```

Colours are **ARGB**: `0xa6ffffff` is white at `a6` alpha; `0xff425137` is
opaque dark green. `radius` rounds rectangle corners (0 or omitted = square).

Button states accept drawn shapes as well as images -- wrap several elements in
a `<container>`:

```xml
<upState><container>
  <rectangle x="0" y="0" width="114" height="37" color="0xff20242a" radius="5"/>
  <label text="SOURCE" x="30" y="11" font="Swis721 Cn BT" size="13" color="0xff9aa0a6"/>
</container></upState>
```

State names: `upState`, `overState`, `downState`, and for checkboxes and radio
buttons also `selectedUpState`, `selectedOverState`, `selectedDownState`.

---

## Fonts

Only two fonts are available, because they are **embedded** in
`assets/SwivelFonts.swf`:

- `Swis721 Cn BT` -- headings
- `AdvoCut` -- body text

Naming any other font renders nothing. To add fonts you must rebuild
`SwivelFonts.swf` in Adobe Animate (see below).

---

## Sound effects

The app plays **one** sound: a chime when a conversion completes.

To change it, drop an MP3 at:

```
assets/audio/complete.mp3
```

That is all -- it is read at runtime, so no rebuild is needed. If the file is
absent, the original sound compiled into `assets/SwivelFonts.swf` is used
instead.

**MP3 only.** The Flash runtime cannot decode WAV. The `.wav` files in
`assets/audio/` are dead leftovers, referenced by nothing.

More sounds can be added the same way -- `Sfx.play("name")` looks for
`assets/audio/name.mp3`. See [Sfx.hx](src/com/newgrounds/swivel/Sfx.hx).

---

## Rebuilding SwivelFonts.swf (Adobe Animate)

Only needed for **new fonts**. Not needed for sound.

`assets/SwivelFonts.swf` is a compiled Flash library containing:

- the two embedded fonts
- `CompleteSound` -- the completion chime
- `SplashAnim` -- the intro animation (no longer used)

There is no `.fla` in this repo, so rebuilding means recreating it:

1. New ActionScript 3.0 document in Animate.
2. Import each font into the Library, and in its properties enable **Export for
   ActionScript**, matching the font name used in the markup.
3. Import the sound, set its linkage class to `CompleteSound`.
4. Publish as SWF and replace `assets/SwivelFonts.swf`.

If `CompleteSound` is missing from the rebuilt SWF the build will fail, since
[Swivel.hx](src/com/newgrounds/swivel/Swivel.hx) still references it as the
fallback.
