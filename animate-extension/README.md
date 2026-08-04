# Send to Swivel — Adobe Animate extension

Pushes the SWF you just published straight into a running copy of Swivel.

```
Animate (CEP panel)  ──HTTP 127.0.0.1:47800──>  Swivel (AnimateBridge)
```

## Why HTTP and not a socket

Animate's CEP host provides `fetch()` but **no Node.js**, so a panel cannot
open a TCP socket. Swivel therefore runs a tiny HTTP server on the loopback
interface. Nothing is reachable from the network.

| Request | Response |
|---|---|
| `GET /ping` | `{"ok":true,"app":"Swivel","version":"1.11"}` |
| `POST /add` — body = absolute path, `Content-Type: text/plain` | `{"ok":true,"message":"Added scene.swf"}` or `{"ok":false,"message":"…"}` |

`text/plain` keeps the POST a CORS-simple request, so no preflight is sent.
Every response carries `Access-Control-Allow-Origin: *`, required because a CEP
panel's origin is not `127.0.0.1`.

Server: [../src/com/newgrounds/swivel/AnimateBridge.hx](../src/com/newgrounds/swivel/AnimateBridge.hx)

---

## Installing

**One file is missing:** `swivel_bridge/js/CSInterface.js` is Adobe's library
and is not redistributed here. Get it from
[Adobe-CEP/CEP-Resources](https://github.com/Adobe-CEP/CEP-Resources), or copy
it from any other CEP 9+ panel you already have.

Then:

```
install.bat
```

It elevates, copies `swivel_bridge\` into the CEP extensions folder as
`swivel_animate_bridge`, and sets `PlayerDebugMode=1` for CSXS 9–13 so the
unsigned panel loads. It refuses to run if `CSInterface.js` is absent, and
tells you whether Swivel is currently listening.

Restart Animate afterwards.

---

## Using it

1. Open **Swivel**.
2. In Animate, open **Window → Extensions → Send to Swivel**. The dot turns
   green when Swivel is reachable.
3. Press **Ctrl+Enter** — Animate writes a `.swf` beside your `.fla`.
4. Click **Send to Swivel**.

The SWF appears in Swivel's Input SWFs list and Swivel comes to the front.

**Publish & Send** saves and publishes first, then sends — for when you have
not pressed Ctrl+Enter, or the SWF is stale.

---

## Layout

```
install.bat          launcher
operator.ps1         installer
swivel_bridge\
  CSXS\manifest.xml  panel definition (FLPR, CSXS 9+)
  .debug             debug port, unsigned development
  index.html
  css\style.css
  js\panel.js        fetch() client
  js\CSInterface.js  ** you supply this **
  jsx\host.jsx       JSFL: resolves the published SWF path
```

---

## Troubleshooting

**Dot stays red.** Swivel is not running, or its listener failed to start —
usually a second Swivel instance already holds port 47800. Check
`%AppData%\Roaming\com.newgrounds.swivel.Swivel\Local Store\SwivelLog.txt`
for a line beginning `AnimateBridge:`.

**Panel missing from the Extensions menu.** `PlayerDebugMode` not set,
`CSInterface.js` missing, or the folder nested one level too deep — the
installed folder must contain `CSXS\manifest.xml` at its top level.

**"Animate could not run host.jsx."** `ScriptPath` in the manifest does not
match the actual file location.

**"No SWF beside the .fla yet."** Ctrl+Enter has not been pressed, or your
publish profile writes the SWF elsewhere. Use **Publish & Send**, or point
Animate's publish target back beside the `.fla`.

Test the server without Animate:

```powershell
Invoke-WebRequest -Uri "http://127.0.0.1:47800/ping" -UseBasicParsing | Select -Expand Content
Invoke-WebRequest -Uri "http://127.0.0.1:47800/add" -Method POST `
  -ContentType "text/plain" -Body "C:\path\to\movie.swf" -UseBasicParsing | Select -Expand Content
```

To change the port, edit `BASE` in `js/panel.js`, `$SwivelPort` in
`operator.ps1`, and `DEFAULT_PORT` in `AnimateBridge.hx`, then rebuild Swivel.
