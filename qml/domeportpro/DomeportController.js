// Controller — all imperative logic for DomeportPro.
//
// Imported by DomeportView.qml as a NON-library JavaScript resource
// (`import "DomeportController.js" as Controller`). It therefore runs in the
// view's scope and resolves, without any parameter passing:
//   - `domeportModel`         the DomeportModel instance (view property)
//   - `dome`, `camera`,       the view element ids
//     `inputSelector`
//   - `Score`, `Util`         the ossia/score context objects
//   - `Qt`                    the QML global
//   - `OutputBackends`        DomeportView.qml's import of OutputBackends.js;
//                             a non-library resource shares the component's
//                             imports, so it needs no .import of its own
//
// Asset URLs (meshes/shaders/textures) are relative to this module directory
// (e.g. "resources/models/…").

// ---- Drag & drop file classification ----
var imageExtensions = [ ".jpg", ".jpeg", ".png", ".gif" ]
var videoExtensions = [ ".mkv", ".mov", ".mp4", ".h264", ".avi", ".hap", ".mpg", ".mpeg", ".imf", ".mxf", ".mts", ".m2ts", ".mj2", ".webm" ]

// ---- Dome model ----
function load210DegreesModel() {
    dome.source = "resources/models/sato210.mesh"
    Score.setValue(domeportModel.equirectangularToDomemaster.domemaster_master_output_fov_degrees, 210.0)
}

function load180DegreesModel() {
    dome.source = "resources/models/sato180.mesh"
    Score.setValue(domeportModel.equirectangularToDomemaster.domemaster_master_output_fov_degrees, 180.0)
}

// ---- NDI discovery ----
function ndiAdded(factory, category, name, settings) {
    console.log("NDI added: " + name)
    const index = domeportModel.ndiNamesList.indexOf(name)
    if (index === -1) {
        domeportModel.ndiNamesList.push(name)
    }
}

function ndiRemoved(factory, name) {
    console.log("NDI removed: " + name)
    const index = domeportModel.ndiNamesList.indexOf(name)
    if (index !== -1) {
        domeportModel.ndiNamesList.splice(index, 1);
    }
}

function registerNDIListener() {
    try {
        let ndiEnumerator = Score.enumerateDevices("ae78b7c6-6400-483e-b45b-fd6ff87ec700")
        ndiEnumerator.deviceAdded.connect(ndiAdded)
        ndiEnumerator.deviceRemoved.connect(ndiRemoved)
        ndiEnumerator.enumerate = true
    } catch (error) {
        console.log("Error registering NDI listener: " + error)
    }
}

// ---- Spout discovery ----
function spoutAdded(factory, category, name, settings) {
    console.log("Spout added: " + name)
    const index = domeportModel.spoutNamesList.indexOf(name)
    if (index !== 1) {
        domeportModel.spoutNamesList.push(name)
    }
}

function enumerateSpout() {
    domeportModel.spoutNamesList = [ "Spout sources..." ]
    try {
        let spoutEnumerator = Score.enumerateDevices("3c995cb6-052b-4c52-a8fd-841b33b81b29")
        spoutEnumerator.deviceAdded.connect(spoutAdded)
        spoutEnumerator.enumerate = true
    } catch (error) {
        console.log("Error enumerating Spout sources: " + error)
    }
}

// ---- Syphon discovery ----
function enumerateSyphon() {
    domeportModel.syphonList = []
    domeportModel.syphonNamesList = [ "Syphon sources..." ]
    try {
        let syphonEnumerator = Score.enumerateDevices("398cec01-c4ea-43b7-8281-d848748e0f68")
        syphonEnumerator.enumerate = true
        for (let dev of syphonEnumerator.devices) {
            domeportModel.syphonList.push(dev)
            domeportModel.syphonNamesList.push(dev.name)
            console.log("Syphon added: " + dev.name)
        }
    } catch (error) {
        console.log("Error enumerating Syphon sources: " + error)
    }
}

function updateSources() {
    if (domeportModel.currentMode === "NDI") {
        // since NDI sources are added and removed to the same list by callback
        // we need to force copy of ndiNamesList to trigger InputSourceSelector
        // comboBox model update
        domeportModel.sourceList = Array.from(domeportModel.ndiNamesList)
    } else if (domeportModel.currentMode === "Spout") {
        enumerateSpout()
        domeportModel.sourceList = domeportModel.spoutNamesList
    } else if (domeportModel.currentMode === "Syphon") {
        enumerateSyphon()
        domeportModel.sourceList = domeportModel.syphonNamesList
    }
}

// ---- Video-mixer routing ----
function displayTestPattern() {
    Score.setValue(domeportModel.videoMixer.alpha1, 1.0)
    Score.setValue(domeportModel.videoMixer.alpha2, 0.0)
    Score.setValue(domeportModel.videoMixer.alpha3, 0.0)
    Score.setValue(domeportModel.videoMixer.alpha4, 0.0)
    Score.play()
}

function displayImageFile() {
    Score.setValue(domeportModel.videoMixer.alpha1, 0.0)
    Score.setValue(domeportModel.videoMixer.alpha2, 1.0)
    Score.setValue(domeportModel.videoMixer.alpha3, 0.0)
    Score.setValue(domeportModel.videoMixer.alpha4, 0.0)
    Score.play()
}

function displayVideoFile() {
    Score.setValue(domeportModel.videoMixer.alpha1, 0.0)
    Score.setValue(domeportModel.videoMixer.alpha2, 0.0)
    Score.setValue(domeportModel.videoMixer.alpha3, 1.0)
    Score.setValue(domeportModel.videoMixer.alpha4, 0.0)
    Score.play()
}

function displayLiveSource() {
    Score.setValue(domeportModel.videoMixer.alpha1, 0.0)
    Score.setValue(domeportModel.videoMixer.alpha2, 0.0)
    Score.setValue(domeportModel.videoMixer.alpha3, 0.0)
    Score.setValue(domeportModel.videoMixer.alpha4, 1.0)
    Score.play()
}

function removeLiveInput() {
    Score.stop()
    try { Score.removeDevice("live_input"); } catch(_) {}
}

function propagateAudio(propagate) {
    if (domeportModel.video.audio_process_object) {
        let audioOut = Score.port(domeportModel.video.audio_process_object, "Audio Out")
        audioOut.propagate = propagate
    }
}

function createNDIInput(name) {
    console.log("Create NDI input: " + name)
    Score.stop()

    // create a NDI source
    let settings = {
        "Path": name
    }
    Score.createDevice("live_input", "ae78b7c6-6400-483e-b45b-fd6ff87ec700", settings)

    // attach NDI source to image inlet
    let liveSource = Score.find("live_source")
    let liveSourceInlet = Score.port(liveSource, "inputImage")
    Score.setAddress(liveSourceInlet, "live_input:/")

    console.log("Created NDI input: " + name)
    Score.play()
}

function createSpoutInput(name) {
    console.log("Create Spout input: " + name)
    Score.stop()

    // create a Spout source
    let settings = {
        "Path": name
    }
    Score.createDevice("live_input", "3c995cb6-052b-4c52-a8fd-841b33b81b29", settings)

    // attach Spout source to image inlet
    let liveSource = Score.find("live_source")
    let liveSourceInlet = Score.port(liveSource, "inputImage")
    Score.setAddress(liveSourceInlet, "live_input:/")

    console.log("Created Spout input: " + name)
    Score.play()
}

function createSyphonInput(name) {
    console.log("Create Syphon input: " + name)
    Score.stop()

    // create a Syphon source
    const index = domeportModel.syphonNamesList.indexOf(name)
    const settings = domeportModel.syphonList[index - 1].settings
    Score.createDevice("live_input", "398cec01-c4ea-43b7-8281-d848748e0f68", settings)

    // attach Syphon source to image inlet
    let liveSource = Score.find("live_source")
    let liveSourceInlet = Score.port(liveSource, "inputImage")
    Score.setAddress(liveSourceInlet, "live_input:/")

    console.log("Created Syphon input: " + name)
    Score.play()
}

// ---- Output-format helpers ----
function enableEquirectangular() {
    Score.setValue(domeportModel.formatMixer.alpha1, 1.0)
    Score.setValue(domeportModel.formatMixer.alpha2, 0.0)
}

function enableDomemaster() {
    Score.setValue(domeportModel.formatMixer.alpha1, 0.0)
    Score.setValue(domeportModel.formatMixer.alpha2, 1.0)
}

function setTestPatternIndex(newIndex) {
    Score.setValue(domeportModel.testPattern.index, newIndex)
}

// ---- Camera ----
function setCameraFly(enabled) {
    domeportModel.cameraFly = enabled
    if (!enabled)
        camera.position.y = camera.cameraHeight
}

// ---- Transport ----
function togglePause() {
    if (domeportModel.running) {
        console.log("pausing...")
        Score.pause()
    } else {
        console.log("unpausing...")
        Score.play()
    }
}

function onPlay() {
    console.log("onPlay")
    domeportModel.running = true
}

function onStop() {
    console.log("onStopped")
    domeportModel.running = false
}

function onPause() {
    console.log("onPause")
    domeportModel.running = false
}

// ---- Video playhead / duration ----
function onVideoLoopDurationChanged(loopDuration) {
    const loopDurationMsec = Util.toMilliseconds(loopDuration)
    domeportModel.video.videoDurationMsec = loopDurationMsec
}

function onVideoPositionChanged(position) {
    domeportModel.video.playheadMsec = domeportModel.video.videoDurationMsec * position % domeportModel.video.videoDurationMsec
}

function applyVideoDuration() {
    // resize interval to video duration
    Score.setIntervalDuration(Score.rootInterval(), Util.timevalFromMilliseconds(domeportModel.video.videoDurationMsec))
}

function applyPlayheadRequest() {
    Score.scrub(domeportModel.video.playheadRequestMsec)
}

// ---- Model change reactions (wired via Connections in DomeportView.qml) ----
function applyMode() {
    console.log("changed mode: " + domeportModel.currentMode)
    removeLiveInput()
    propagateAudio(false)
    if (domeportModel.currentMode === "Test pattern") {
        displayTestPattern()
    } else if (domeportModel.currentMode === "Image file") {
        displayImageFile()
    } else if (domeportModel.currentMode === "Video file") {
        propagateAudio(true)
        displayVideoFile()
    } else if (domeportModel.currentMode === "NDI") {
        updateSources()
        domeportModel.sourceName = domeportModel.ndiSourceName
        if (domeportModel.ndiSourceName !== "") { createNDIInput(domeportModel.ndiSourceName) }
        displayLiveSource()
    } else if (domeportModel.currentMode === "Spout") {
        domeportModel.sourceName = domeportModel.spoutSourceName
        updateSources()
        if (domeportModel.spoutSourceName !== "") { createSpoutInput(domeportModel.spoutSourceName) }
        displayLiveSource()
    } else if (domeportModel.currentMode === "Syphon") {
        domeportModel.sourceName = domeportModel.syphonSourceName
        updateSources()
        if (domeportModel.syphonSourceName !== "") { createSyphonInput(domeportModel.syphonSourceName) }
        displayLiveSource()
    }
}

function applySourceName() {
    if (domeportModel.currentMode === "NDI") {
        domeportModel.ndiSourceName = domeportModel.sourceName
    } else if (domeportModel.currentMode === "Spout") {
        domeportModel.spoutSourceName = domeportModel.sourceName
    } else if (domeportModel.currentMode === "Syphon") {
        domeportModel.syphonSourceName = domeportModel.sourceName
    }
}

function applyNdiSourceName() {
    if (domeportModel.ndiSourceName !== "") {
        console.log("updated NDI Source Name: " + domeportModel.ndiSourceName)
        removeLiveInput()
        createNDIInput(domeportModel.ndiSourceName)
    }
}

function applySpoutSourceName() {
    if (domeportModel.spoutSourceName !== "") {
        console.log("updated Spout Source Name: " + domeportModel.spoutSourceName)
        removeLiveInput()
        createSpoutInput(domeportModel.spoutSourceName)
    }
}

function applySyphonSourceName() {
    if (domeportModel.syphonSourceName !== "") {
        console.log("updated Syphon Source Name: " + domeportModel.syphonSourceName)
        removeLiveInput()
        createSyphonInput(domeportModel.syphonSourceName)
    }
}

function applyZoom() {
    if (domeportModel.currentFormat === "Domemaster") {
        Score.setValue(domeportModel.rotateZoom.zoom, domeportModel.zoom / 100)
    } else if (domeportModel.currentFormat === "Equirectangular") {
        let zoomedFov = domeportModel.currentModelFov / (domeportModel.zoom / 100)
        if (zoomedFov < 360) {
            Score.setValue(domeportModel.equirectangularToDomemaster.domemaster_master_output_fov_degrees, zoomedFov)
            Score.setValue(domeportModel.rotateZoom.zoom, 1)
        } else {
            // treat as domemaster over 360 fov, so texture does not repeat
            Score.setValue(domeportModel.equirectangularToDomemaster.domemaster_master_output_fov_degrees, 360)
            let zoomFactor = 360 / zoomedFov
            Score.setValue(domeportModel.rotateZoom.zoom, zoomFactor)
        }
    }
    // Zoom re-aims the forward projection, so the conversion's inverse has to
    // follow it or the two stop being inverses of each other.
    applyConversionFov()
}

function applyImageFilePath() {
    console.log("imageFilePath: " + domeportModel.imageFilePath)
    if (domeportModel.imageFilePath === "") return
    Score.stop()
    Score.setValue(domeportModel.image.path, domeportModel.imageFilePath)
    domeportModel.currentMode = "Image file"
    Score.play()
}

function applyVideoFilePath() {
    console.log("videoFilePath: " + domeportModel.videoFilePath)
    if (domeportModel.videoFilePath === "") return
    Score.stop()
    Score.remove(domeportModel.video.audio_process_object)
    domeportModel.video.video_process_object.path = domeportModel.videoFilePath
    domeportModel.video.audio_process_object = 
        Score.createProcess(Score.rootInterval(), "Sound file", domeportModel.videoFilePath)
    domeportModel.video.audio_process_object.loops = true
    domeportModel.currentMode = "Video file"
    Score.play()
}

function applyFormat() {
    console.log("changed format: " + domeportModel.currentFormat)
    if (domeportModel.currentFormat === "Equirectangular") {
        setTestPatternIndex(0)
        enableEquirectangular()
    } else if (domeportModel.currentFormat === "Domemaster") {
        setTestPatternIndex(1)
        enableDomemaster()
    }
    // The effective FOV depends on which branch is live, so the inverse has to
    // be re-told after a format change too.
    applyConversionFov()
}

// ---- Format conversion (pro) ----
// conv_out is a clone of Video Mixer.1, so a format is selected the same way
// the dome's own format switch does it: one alpha to 1, the rest to 0.
function applyConversionFormat() {
    const f = domeportModel.conversionFormat
    console.log("changed conversion format: " + f)
    Score.setValue(domeportModel.convOut.alpha1, f === "Domemaster" ? 1.0 : 0.0)
    Score.setValue(domeportModel.convOut.alpha2, f === "Equirectangular" ? 1.0 : 0.0)
    Score.setValue(domeportModel.convOut.alpha3, f === "Cubemap" ? 1.0 : 0.0)
    // The sink's frame size is derived from the format, and a device carries the
    // size it was created with, so a live output has to be rebuilt.
    if (domeportModel.outputActive)
        applyConversionOutput()
}

function applyCubemapLayout() {
    Score.setValue(domeportModel.convEquiToCube.layoutType, domeportModel.cubemapLayout)
    // Layout changes the atlas aspect, hence the sink's size.
    if (domeportModel.outputActive && domeportModel.conversionFormat === "Cubemap")
        applyConversionOutput()
}

// The inverse projection only inverts the forward one when it is told the same
// FOV, so it follows the dome model rather than keeping its own setting.
// The FOV the domemaster leaving Video Mixer.1 actually has, which is not the
// dome model's whenever zoom is in play: in Equirectangular mode applyZoom
// re-aims equirectangular_to_domemaster at modelFov / (zoom/100), clamped at
// 360. In Domemaster mode the conversion shader is bypassed (t2 passthrough)
// and zoom goes to rotate_zoom instead, so the master keeps the model's FOV.
function effectiveDomemasterFov() {
    if (domeportModel.currentFormat !== "Equirectangular")
        return domeportModel.currentModelFov
    const z = domeportModel.zoom / 100
    if (z <= 0)
        return domeportModel.currentModelFov
    return Math.min(360, domeportModel.currentModelFov / z)
}

// The inverse only inverts the forward projection when both are told the same
// angle, so this has to track the effective FOV, not the dome model. Pinning it
// to modelFov made any zoom != 100 shear the conversion output.
function applyConversionFov() {
    Score.setValue(domeportModel.convDomeToEqui.domemaster_input_fov_degrees,
                   effectiveDomemasterFov())
}

// ---- Conversion output device (pro) ----
// Returns true when no conv_output device is left in the document.
//
// score refuses to remove a device while the score is executing and only says
// so through qWarning (EditContext.device.cpp:229-236, "Call Score.stop()
// first."), so a removal attempted mid-playback silently does nothing: the sink
// keeps streaming, the name stays taken, and the next createDevice is refused
// in turn. Stop first, then verify -- a device that is still there after this
// has to be reported, not assumed gone.
function stopConversionOutput() {
    Score.stop()
    try { Score.removeDevice("conv_output") } catch(_) {}

    if (Score.device("conv_output")) {
        domeportModel.outputActive = true
        domeportModel.outputStatus = "Could not stop the output: the device is still running."
        console.error("conversion output: removeDevice left conv_output in place")
        return false
    }
    domeportModel.outputActive = false
    return true
}

function startConversionOutput() {
    const d = OutputBackends.descriptor(domeportModel.outputBackend)
    if (!d) {
        domeportModel.outputStatus = ""
        return
    }

    const name = domeportModel.outputName.length > 0 ? domeportModel.outputName
                                                     : d.defaultName
    const settings = OutputBackends.makeSettings(
        name, domeportModel.outputWidth, domeportModel.outputHeight,
        domeportModel.outputRate)

    Score.stop()
    Score.createDevice("conv_output", d.uuid, settings)

    // createDevice does not report failure -- look for the result. The usual
    // cause is a missing runtime (NDI is dlopen'd, never linked, and is not
    // bundled: its licence forbids shipping it with a GPLv3 app), and without
    // this check the tab would claim to be streaming into nothing.
    if (!Score.device("conv_output")) {
        domeportModel.outputActive = false
        domeportModel.outputStatus =
            "Could not create the " + domeportModel.outputBackend + " output."
            + (domeportModel.outputBackend === "NDI"
               ? " Is the NDI runtime installed?" : "")
        console.error("conversion output: device creation failed for "
                      + domeportModel.outputBackend)
        Score.play()
        return
    }

    // An outlet writes to its address only while it is not cabled; conv_out's
    // outlet feeds nothing in the document, so this is what publishes the
    // converted frame.
    const outlet = Score.outlet(domeportModel.convOut.process_object, 0)
    Score.setAddress(outlet, "conv_output:/")

    domeportModel.outputActive = true
    domeportModel.outputStatus = domeportModel.outputBackend + " output \"" + name + "\" is live."
    console.log("conversion output started: " + domeportModel.outputBackend + " / " + name)
    Score.play()
}

function applyConversionOutput() {
    // A failed teardown leaves the name taken, so creating would be refused and
    // the UI would describe a sink that is not the one actually streaming.
    if (!stopConversionOutput()) {
        Score.play()
        return
    }
    if (domeportModel.outputBackend === "None") {
        domeportModel.outputStatus = ""
        Score.play()
        return
    }
    startConversionOutput()
}

function applyModel() {
    console.log("changed model: " + domeportModel.currentModel)
    if (domeportModel.currentModel === "210 degrees") {
        domeportModel.currentModelFov = 210
        load210DegreesModel()
    } else if (domeportModel.currentModel === "180 degrees") {
        domeportModel.currentModelFov = 180
        load180DegreesModel()
    }
    applyConversionFov()
}

// ---- Drag & drop ----
function handleFileDrop(drop) {
    if (drop.hasUrls) {
        var filePath = new URL(drop.urls[0]).pathname.substr(Qt.platform.os === "windows" ? 1 : 0);
        // Align the selector's backend with the dropped file type BEFORE setting
        // the path: the shared InputSourceSelector re-emits backendSelected with
        // its current backend on every path change, which would otherwise clobber
        // the mode back to whatever the combo last showed (e.g. an image dropped
        // after a video would snap back to "Video file").
        if (imageExtensions.some(extension => filePath.endsWith(extension))) {
            console.log("Dropped image file: ", filePath)
            inputSelector.imageFilePath = ""
            inputSelector.currentBackend = "Image file"
            inputSelector.imageFilePath = filePath
        }
        if (videoExtensions.some(extension => filePath.endsWith(extension))) {
            console.log("Dropped video file: ", filePath)
            inputSelector.videoFilePath = ""
            inputSelector.currentBackend = "Video file"
            inputSelector.videoFilePath = filePath
        }
    }
}

// ---- Lifecycle ----
function initialize() {
    domeportModel.advancedIo = !!Util.environmentVariable("SAT_ADVANCED_IO")
    console.log(domeportModel.advancedIo ? "Advanced I/O enabled"
                                         : "Basic features only")

    // wire the Video process' loop duration and the transport playhead
    if (domeportModel.video.video_process_object) {
        domeportModel.video.video_process_object.loopDurationChanged.connect(onVideoLoopDurationChanged)
        Score.rootInterval().durations.positionChanged.connect(onVideoPositionChanged)
    }

    Score.transport().play.connect(onPlay)
    Score.transport().stop.connect(onStop)
    Score.transport().pause.connect(onPause)
    registerNDIListener()

    // Only offer the sinks that can exist here: Spout is Windows-only and
    // Syphon macOS-only, in score and in the protocols themselves.
    domeportModel.outputBackendList = OutputBackends.available(Qt.platform.os)
    applyConversionFormat()
    applyCubemapLayout()
    applyConversionFov()

    Score.play()
}
