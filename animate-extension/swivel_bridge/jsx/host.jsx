/*
 * JSFL host for the "Send to Swivel" panel.
 *
 * Animate runs these via CSInterface.evalScript. Every function returns a
 * string starting with "OK|" or "ERR|" so the panel never has to guess.
 */

function _ok(payload)   { return "OK|" + payload; }
function _err(message)  { return "ERR|" + message; }

/**
 * Resolves the SWF that Ctrl+Enter (Test Movie) writes: same name and folder
 * as the .fla.
 */
function sw_getSwfPath() {
    var doc = fl.getDocumentDOM();
    if (!doc) return _err("No document is open in Animate.");
    if (!doc.pathURI) return _err("Save the .fla first — an unsaved document has no folder to publish into.");

    var swfURI = doc.pathURI.replace(/\.fla$/i, ".swf");
    if (swfURI === doc.pathURI) swfURI = doc.pathURI + ".swf";

    if (!FLfile.exists(swfURI)) {
        return _err("No SWF beside the .fla yet. Press Ctrl+Enter, or use Publish & Send.");
    }

    return _ok(FLfile.uriToPlatformPath(swfURI));
}

/**
 * Saves, publishes with the document's current profile, then resolves the SWF.
 */
function sw_publishAndGetSwfPath() {
    var doc = fl.getDocumentDOM();
    if (!doc) return _err("No document is open in Animate.");
    if (!doc.pathURI) return _err("Save the .fla first.");

    try {
        doc.save();
        doc.publish();
    } catch (e) {
        return _err("Publish failed: " + e);
    }

    return sw_getSwfPath();
}

/**
 * Exports the frame under the playhead as a PNG beside the .fla, named
 * <document>_f<frame>.png. Uses the document's current PNG publish settings,
 * which default to matching the stage, so no dialog appears.
 */
function sw_grabStill() {
    var doc = fl.getDocumentDOM();
    if (!doc) return _err("No document is open in Animate.");
    if (!doc.pathURI) return _err("Save the .fla first — an unsaved document has no folder to write into.");

    var frame = doc.getTimeline().currentFrame + 1;
    var uri = doc.pathURI.replace(/\.fla$/i, "") + "_f" + frame + ".png";

    try {
        // true = use current settings (no dialog), true = current frame only
        doc.exportPNG(uri, true, true);
    } catch (e) {
        return _err("PNG export failed: " + e);
    }

    if (!FLfile.exists(uri)) return _err("Animate did not write the PNG.");

    return _ok(FLfile.uriToPlatformPath(uri));
}

/**
 * Exports the current frame to a scratch PNG in the Animate config folder, for
 * the panel to put on the clipboard. Unlike sw_grabStill this needs no saved
 * .fla, since it never writes beside the document.
 */
function sw_grabStillTemp() {
    var doc = fl.getDocumentDOM();
    if (!doc) return _err("No document is open in Animate.");

    var uri = fl.configURI + "swivel_clipboard.png";

    try {
        FLfile.remove(uri);
    } catch (e) {}

    try {
        doc.exportPNG(uri, true, true);
    } catch (e) {
        return _err("PNG export failed: " + e);
    }

    if (!FLfile.exists(uri)) return _err("Animate did not write the PNG.");

    return _ok(FLfile.uriToPlatformPath(uri));
}

/** Name of the frontmost document, for the panel header. */
function sw_getDocumentName() {
    var doc = fl.getDocumentDOM();
    if (!doc) return _err("No document");
    return _ok(doc.name || "untitled");
}
