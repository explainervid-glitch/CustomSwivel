/*
 * Send to Swivel — panel logic.
 *
 * The Animate CEP host provides fetch() but no Node.js, so this panel talks to
 * Swivel over HTTP on the loopback interface rather than a TCP socket.
 * Swivel's server lives in src/com/newgrounds/swivel/AnimateBridge.hx:
 *
 *     GET  /ping   ->  {"ok":true,"app":"Swivel","version":"..."}
 *     POST /add    ->  {"ok":true,"message":"Added scene.swf"}
 *                      body = absolute path, Content-Type: text/plain
 *
 * text/plain keeps the POST a CORS-"simple" request, so no preflight is sent.
 */

/* global CSInterface */
(function () {
    "use strict";

    var BASE = "http://127.0.0.1:47800";
    var TIMEOUT_MS = 5000;
    /* Swivel answers its port before the UI is usable -- the intro splash
       covers the window for a few seconds after launch. */
    var LAUNCH_SETTLE_MS = 6000;
    var POLL_MS = 3000;

    var cs = new CSInterface();

    var dotEl = document.getElementById("dot");
    var stateEl = document.getElementById("state");
    var docEl = document.getElementById("doc");
    var sendBtn = document.getElementById("send");
    var grabBtn = document.getElementById("grab");
    var launchBtn = document.getElementById("launch");
    var convertBtn = document.getElementById("convert");
    var progressWrap = document.getElementById("progressWrap");
    var progressFill = document.getElementById("progressFill");
    var progressLabel = document.getElementById("progressLabel");

    var connected = false;
    var launching = false;
    var progressTimer = null;

    /* Where Swivel might live. First hit wins; a browsed path is remembered. */
    var SWIVEL_CANDIDATES = [
        "C:\\Program Files (x86)\\Swivel2\\Swivel2.exe",
        "C:\\01 Development\\theNewSwivel\\Swivel\\bin\\Swivel\\Swivel2.exe"
    ];

    /* Shrinks or grows the panel to match its content. Anything that changes
       the layout -- status text wrapping, the launch button appearing, the
       progress bar showing -- should call this afterwards. */
    var lastHeight = 0;

    function fitPanelHeight() {
        try {
            var panel = document.getElementById("panel");
            if (!panel) return;

            var height = Math.ceil(panel.getBoundingClientRect().height);
            if (!height || height === lastHeight) return;

            lastHeight = height;
            cs.resizeContent(window.innerWidth, height);
        } catch (e) {}
    }

    function setState(text, kind) {
        stateEl.textContent = text;
        stateEl.className = kind === "ok" || kind === "err" ? kind : "";
        dotEl.className = "dot " + (kind === "ok" ? "on" : kind === "busy" ? "busy" : "off");
    }

    /* Buttons stay enabled while disconnected on purpose -- clicking then
       reports why Swivel could not be reached, which is more useful than a
       dead control that explains nothing. */
    var busy = false;

    function setBusy(value) {
        busy = value;
        refreshButtons();
    }

    /* Sending needs Swivel already running; Render opens it itself, so it
       stays enabled either way. */
    function refreshButtons() {
        sendBtn.disabled = busy || !connected;
        grabBtn.disabled = busy;
        convertBtn.disabled = busy;
        launchBtn.disabled = busy || launching;
    }

    function fileExists(path) {
        try {
            var r = window.cep.fs.stat(path);
            return r && r.err === 0;
        } catch (e) {
            return false;
        }
    }

    function swivelPath() {
        var saved = null;
        try { saved = window.localStorage.getItem("swivelPath"); } catch (e) {}
        if (saved && fileExists(saved)) return saved;

        for (var i = 0; i < SWIVEL_CANDIDATES.length; i++) {
            if (fileExists(SWIVEL_CANDIDATES[i])) return SWIVEL_CANDIDATES[i];
        }
        return null;
    }

    function askForSwivelPath() {
        try {
            var r = window.cep.fs.showOpenDialog(false, false, "Where is Swivel2.exe?", "", ["exe"]);
            if (r && r.data && r.data.length) {
                window.localStorage.setItem("swivelPath", r.data[0]);
                return r.data[0];
            }
        } catch (e) {}
        return null;
    }

    /* CEP's own process API -- works without Node, which this host lacks.
       Returns a Promise that resolves once Swivel answers /ping, so callers
       like sendUsing can chain a send after launch. */
    function launchSwivel() {
        return new Promise(function (resolve, reject) {
            var path = swivelPath() || askForSwivelPath();
            if (!path) {
                setState("Could not find Swivel2.exe.", "err");
                reject(new Error("Could not find Swivel2.exe."));
                return;
            }

            try {
                var r = window.cep.process.createProcess(path);
                if (r && r.err !== 0) {
                    setState("Windows refused to start Swivel.", "err");
                    reject(new Error("Windows refused to start Swivel."));
                    return;
                }
            } catch (e) {
                setState("Could not start Swivel: " + e, "err");
                reject(new Error("Could not start Swivel: " + e));
                return;
            }

            launching = true;
            setBusy(false);
            setState("Starting Swivel…", "busy");

            /* Swivel takes a few seconds to open its port. */
            var tries = 0;
            var timer = setInterval(function () {
                tries++;
                request("/ping")
                    .then(function () {
                        clearInterval(timer);
                        launching = false;
                        checkSwivel();
                        resolve();
                    })
                    .catch(function () {
                        if (tries >= 15) {
                            clearInterval(timer);
                            launching = false;
                            setState("Swivel started but never answered.", "err");
                            reject(new Error("Swivel started but never answered."));
                        }
                    });
            }, 1000);
        });
    }

    /* fetch() with a timeout, since a dead port can otherwise hang. */
    function request(path, options) {
        options = options || {};

        return new Promise(function (resolve, reject) {
            var done = false;

            var timer = setTimeout(function () {
                if (done) return;
                done = true;
                reject(new Error("Swivel did not respond."));
            }, TIMEOUT_MS);

            fetch(BASE + path, options)
                .then(function (response) { return response.json(); })
                .then(function (json) {
                    if (done) return;
                    done = true;
                    clearTimeout(timer);
                    resolve(json);
                })
                .catch(function () {
                    if (done) return;
                    done = true;
                    clearTimeout(timer);
                    reject(new Error("Could not reach Swivel. Is it running?"));
                });
        });
    }

    /* Runs a JSFL function returning "OK|payload" or "ERR|message". */
    function runHost(call) {
        return new Promise(function (resolve, reject) {
            cs.evalScript(call, function (raw) {
                var result = String(raw === null || raw === undefined ? "" : raw);

                if (result === "" || result === "undefined" || result === "EvalScript error.") {
                    reject(new Error("Animate could not run host.jsx."));
                    return;
                }

                var bar = result.indexOf("|");
                var tag = bar < 0 ? result : result.substring(0, bar);
                var body = bar < 0 ? "" : result.substring(bar + 1);

                if (tag === "OK") resolve(body);
                else reject(new Error(body || "Unknown error from Animate."));
            });
        });
    }

    function setProgress(visible, percent, label) {
        progressWrap.style.display = visible ? "block" : "none";
        progressFill.style.width = Math.max(0, Math.min(100, percent)) + "%";
        progressLabel.textContent = label || "";
        fitPanelHeight();
    }

    function pollProgress() {
        if (progressTimer) clearInterval(progressTimer);

        progressTimer = setInterval(function () {
            request("/progress")
                .then(function (json) {
                    if (!json.ok) return;

                    var pct = Math.round((json.progress || 0) * 100);
                    setProgress(true, pct, json.message || "");

                    if (json.complete) {
                        clearInterval(progressTimer);
                        progressTimer = null;
                        setBusy(false);
                        setState("Conversion complete!", "ok");
                    }
                })
                .catch(function () {
                    /* Swivel might have closed; stop polling. */
                    clearInterval(progressTimer);
                    progressTimer = null;
                });
        }, 1000);
    }

    function sendUsing(hostCall, workingMessage) {
        setBusy(true);
        setState(workingMessage, "busy");

        /* Sending requires Swivel already running -- these buttons are
           disabled otherwise. Only Render in Swivel opens it. */
        runHost(hostCall)
            .then(function (swfPath) {
                return request("/add", {
                    method: "POST",
                    headers: { "Content-Type": "text/plain" },
                    body: swfPath
                });
            })
            .then(function (json) {
                setBusy(false);
                setState(json.message || "Sent.", json.ok ? "ok" : "err");
                /* Still poll progress so the bar tracks conversion when the
                   user clicks Convert in Swivel manually. */
                if (json.ok) {
                    setProgress(true, 0, "Ready to convert in Swivel.");
                    pollProgress();
                }
            })
            .catch(function (err) {
                setBusy(false);
                setState(err.message, "err");
            });
    }

    sendBtn.addEventListener("click", function () {
        sendUsing("sw_getSwfPath()", "Locating published SWF…");
    });

    /* Purely an Animate operation -- no Swivel involved. */
    grabBtn.addEventListener("click", function () {
        setBusy(true);
        setState("Exporting frame…", "busy");

        runHost("sw_grabStill()")
            .then(function (path) {
                setBusy(false);
                var name = path.split("\\").pop().split("/").pop();
                setState("Saved " + name, "ok");
            })
            .catch(function (err) {
                setBusy(false);
                setState(err.message, "err");
            });
    });

    /* Starts the conversion Swivel already has queued, using its current
       settings -- the same thing as pressing CONVERT in Swivel itself. */
    /* One shot: open Swivel if needed, hand it the published SWF, then start
       the conversion -- rather than making the user do all three. */
    convertBtn.addEventListener("click", function () {
        setBusy(true);
        setState(connected ? "Locating published SWF…" : "Opening Swivel…", "busy");

        var hadToLaunch = !connected;
        var prep = connected ? Promise.resolve() : launchSwivel();

        prep
            .then(function () {
                if (!hadToLaunch) return null;

                /* Let the intro splash finish before driving the UI. */
                setState("Waiting for Swivel…", "busy");
                return new Promise(function (resolve) {
                    setTimeout(resolve, LAUNCH_SETTLE_MS);
                });
            })
            .then(function () {
                setState("Locating published SWF…", "busy");
                return runHost("sw_getSwfPath()");
            })
            .then(function (swfPath) {
                setState("Sending to Swivel…", "busy");
                return request("/add", {
                    method: "POST",
                    headers: { "Content-Type": "text/plain" },
                    body: swfPath
                });
            })
            .then(function (json) {
                if (!json.ok) throw new Error(json.message || "Swivel refused the file.");
                setState("Starting conversion…", "busy");
                return request("/convert", { method: "POST" });
            })
            .then(function (json) {
                setBusy(false);

                if (!json.ok) {
                    setState(json.message || "Swivel refused to convert.", "err");
                    return;
                }

                setState(json.message || "Converting…", "busy");
                setProgress(true, 0, "Starting…");
                pollProgress();
            })
            .catch(function (err) {
                setBusy(false);
                setState(err.message, "err");
            });
    });

    function refreshDocumentName() {
        cs.evalScript("sw_getDocumentName()", function (raw) {
            var result = String(raw || "");
            docEl.textContent = result.indexOf("OK|") === 0
                ? result.substring(3)
                : "No document open";
        });
    }

    function checkSwivel() {
        if (launching) return;

        request("/ping")
            .then(function (json) {
                connected = true;
                var version = json.version ? " v" + json.version : "";
                setState("Connected to Swivel" + version, "ok");
                /* flex, not block -- the button centres its icon with flexbox. */
                launchBtn.style.display = "none";
                refreshButtons();
                fitPanelHeight();
            })
            .catch(function () {
                connected = false;
                setState("Swivel not running.", "err");
                launchBtn.style.display = "flex";
                refreshButtons();
                fitPanelHeight();
            });
    }

    launchBtn.addEventListener("click", function () {
        launchSwivel().catch(function () {});
    });

    if (typeof fetch !== "function") {
        setState("No fetch() in this CEP host.", "err");
        sendBtn.disabled = grabBtn.disabled = true;
        return;
    }

    refreshDocumentName();
    checkSwivel();
    fitPanelHeight();

    setInterval(function () {
        refreshDocumentName();
        checkSwivel();
    }, POLL_MS);
})();
