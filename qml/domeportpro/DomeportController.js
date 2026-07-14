// Controller — all imperative logic for DomeportPro.
//
// Imported by DomeportView.qml as a NON-library JavaScript resource
// (`import "DomeportController.js" as Controller`). It therefore runs in the
// view's scope and resolves, without any parameter passing:
//   - `domeportModel`         the DomeportModel instance (view property)
//   - `dome`, `camera`,       the view element ids
//     `transportButton`,
//     `pauseButton`,
//     `inputSelector`
//   - `Score`, `Util`         the ossia/score context objects
//   - `Qt`                    the QML global
//
// Asset URLs (meshes/shaders) live one directory up (qml/), hence the "../".

// ---- Drag & drop file classification ----
var imageExtensions = [ ".jpg", ".jpeg", ".png", ".gif" ]
var videoExtensions = [ ".mkv", ".mov", ".mp4", ".h264", ".avi", ".hap", ".mpg", ".mpeg", ".imf", ".mxf", ".mts", ".m2ts", ".mj2", ".webm" ]

// ---- Dome model ----
function load210DegreesModel() {
    dome.source = "../sato210.mesh"
    Score.setValue(domeportModel.equirectangularToDomemaster.domemaster_master_output_fov_degrees, 210.0)
}

function load180DegreesModel() {
    dome.source = "../sato180.mesh"
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
        domeportModel.sourceList = domeportModel.ndiNamesList
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
function toggleCameraFlyMode() {
    if (domeportModel.cameraFly) {
        domeportModel.cameraFly = false
        camera.position.y = camera.cameraHeight
    } else {
        domeportModel.cameraFly = true
    }
}

// ---- Transport ----
function toggleTransport() {
    if (domeportModel.running) {
        console.log("stopping...")
        Score.stop()
    } else {
        console.log("starting...")
        Score.play()
    }
}

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
    transportButton.text = "Stop"
    pauseButton.text = "Pause"
    domeportModel.running = true
}

function onStop() {
    console.log("onStopped")
    transportButton.text = "Play"
    domeportModel.running = false
}

function onPause() {
    console.log("onPause")
    transportButton.text = "Play"
    pauseButton.text = "Unpause"
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
    if (domeportModel.currentMode === "Test pattern") {
        displayTestPattern()
    } else if (domeportModel.currentMode === "Image file") {
        displayImageFile()
    } else if (domeportModel.currentMode === "Video file") {
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
    domeportModel.video.process_object.path = domeportModel.videoFilePath
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
            inputSelector.currentBackend = "Image file"
            inputSelector.imageFilePath = filePath
        }
        if (videoExtensions.some(extension => filePath.endsWith(extension))) {
            console.log("Dropped video file: ", filePath)
            inputSelector.currentBackend = "Video file"
            inputSelector.videoFilePath = filePath
        }
    }
}

// ---- Lifecycle ----
function initialize() {
    const domeportProBasic = Util.environmentVariable("DOMEPORTPRO_BASIC")
    if (domeportProBasic) {
        domeportModel.basicFeatures = true
        console.log("Basic features enabled")
    }

    // wire the Video process' loop duration and the transport playhead
    if (domeportModel.video.process_object) {
        domeportModel.video.process_object.loopDurationChanged.connect(onVideoLoopDurationChanged)
        Score.rootInterval().durations.positionChanged.connect(onVideoPositionChanged)
    }

    Score.transport().play.connect(onPlay)
    Score.transport().stop.connect(onStop)
    Score.transport().pause.connect(onPause)
    registerNDIListener()
    Score.play()
}
