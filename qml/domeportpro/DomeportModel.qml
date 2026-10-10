import QtQuick

// Model — DomeportPro application state.
//
// Pure data: state properties plus thin QtObject wrappers around the
// ossia/score process objects and their inlets. It holds NO behaviour; every
// reaction to a state change lives in DomeportController.js and is wired to the
// model's change signals by DomeportView.qml (see its Connections blocks).
Item {
    id: domeportModel

    // ---- Transport ----
    property bool running: true

    // ---- Score process wrappers (process object + inlet handles) ----
    property QtObject rotateZoom: QtObject {
        property var process_object: Score.find("rotate_zoom")
        property var zoom: Score.inlet(process_object, 4)
    }

    property QtObject formatMixer: QtObject {
        property var process_object: Score.find("Video Mixer.1")
        property var alpha1: Score.inlet(process_object, 8)
        property var alpha2: Score.inlet(process_object, 9)
    }

    property QtObject equirectangularToDomemaster: QtObject {
        property var process_object: Score.find("equirectangular_to_domemaster")
        property var domemaster_master_output_fov_degrees: Score.inlet(process_object, 2)
    }

    property QtObject videoMixer: QtObject {
        property var process_object: Score.find("Video Mixer")
        property var alpha1: Score.inlet(process_object, 8)
        property var alpha2: Score.inlet(process_object, 9)
        property var alpha3: Score.inlet(process_object, 10)
        property var alpha4: Score.inlet(process_object, 11)
    }

    property QtObject video: QtObject {
        property var video_process_object: Score.find("Video")
        property var audio_process_object: undefined
        property double videoDurationMsec: 0.0
        property double playheadRequestMsec: 0.0
        property double playheadMsec: 0.0
    }

    property QtObject testPattern: QtObject {
        property var process_object: Score.find("test_pattern")
        property var index: Score.inlet(process_object, 0)
    }

    property QtObject image: QtObject {
        property var process_object: Score.find("image")
        property var path: Score.inlet(process_object, 5)
    }

    // ---- Format conversion (pro) ----
    // Video Mixer.1 already normalises every source to a domemaster, so the
    // conversion chain only handles the output side. conv_out is a clone of
    // Video Mixer.1: picking a format is the same alpha select the existing
    // format switch uses. t1 = domemaster passthrough, t2 = equirectangular,
    // t3 = cubemap atlas.
    property QtObject convOut: QtObject {
        property var process_object: Score.find("conv_out")
        property var alpha1: Score.inlet(process_object, 8)
        property var alpha2: Score.inlet(process_object, 9)
        property var alpha3: Score.inlet(process_object, 10)
    }

    property QtObject convDomeToEqui: QtObject {
        property var process_object: Score.find("conv_dome_to_equi")
        property var domemaster_input_fov_degrees: Score.inlet(process_object, 2)
    }

    property QtObject convEquiToCube: QtObject {
        property var process_object: Score.find("conv_equi_to_cube")
        property var layoutType: Score.inlet(process_object, 1)
    }

    property var conversionFormatList: ["Domemaster", "Equirectangular", "Cubemap"]
    property string conversionFormat: "Domemaster"

    property var cubemapLayoutList: ["Horizontal Strip (6x1)", "Vertical Cross (3x4)", "Horizontal Cross (4x3)"]
    property int cubemapLayout: 0

    // ---- Conversion output (pro) ----
    // Filled at startup from OutputBackends.available(Qt.platform.os): Spout
    // exists only on Windows and Syphon only on macOS, so the list is shorter
    // than three everywhere.
    property var outputBackendList: ["None"]
    property string outputBackend: "None"
    property string outputName: editionName
    property int outputRate: 30

    // The sink publishes a fixed WxH and the converted frame is scaled into it,
    // so the buffer has to carry the projection's own aspect or the result is
    // squashed: a domemaster is 1:1, an equirectangular 2:1, and a cubemap atlas
    // 6:1, 3:4 or 4:3 depending on the layout. Derived rather than typed in,
    // because getting it wrong is silent.
    readonly property int outputBase: 2048

    // Derived as exact integers from a cell/face size rather than by scaling a
    // float aspect: 2048/6 rounds to 341, which is not a square cube face and
    // which the sink then publishes as 340 anyway, so the UI and the stream
    // disagree and every face is skewed. A cubemap is sized from a 512-pixel
    // face so all three layouts tile exactly.
    readonly property int cubeFace: 512
    readonly property var outputSize: {
        if (conversionFormat === "Equirectangular")
            return { w: outputBase, h: outputBase / 2 }          // 2048 x 1024
        if (conversionFormat === "Cubemap") {
            if (cubemapLayout === 0) return { w: 6 * cubeFace, h: 1 * cubeFace }   // strip  3072 x 512
            if (cubemapLayout === 1) return { w: 3 * cubeFace, h: 4 * cubeFace }   // vcross 1536 x 2048
            return { w: 4 * cubeFace, h: 3 * cubeFace }                            // hcross 2048 x 1536
        }
        return { w: outputBase, h: outputBase }                  // domemaster 2048 x 2048
    }
    readonly property int outputWidth: outputSize.w
    readonly property int outputHeight: outputSize.h
    readonly property real outputAspect: outputWidth / outputHeight
    property bool outputActive: false
    property string outputStatus: ""

    // ---- Feature flags ----
    property bool advancedIo: false

    readonly property string editionName: advancedIo ? "Domeport Pro" : "Domeport"

    // ---- Input mode ----
    property string currentMode: "Test pattern"
    property bool testPatternMode: currentMode === "Test pattern"
    property bool imageMode: currentMode === "Image file"
    property bool videoFileMode: currentMode === "Video file"
    property bool ndiMode: currentMode === "NDI"
    property bool spoutMode: currentMode === "Spout"
    property bool syphonMode: currentMode === "Syphon"
    property bool liveMode: ndiMode || spoutMode || syphonMode

    // ---- Sources ----
    property var sourceList: [ "" ]
    property string sourceName: ""

    property var ndiNamesList: [ "NDI sources..." ]
    property var spoutNamesList: [ "Spout sources..." ]
    property var syphonList: []
    property var syphonNamesList: [ "Syphon sources..." ]

    property string ndiSourceName: ""
    property string spoutSourceName: ""
    property string syphonSourceName: ""

    // ---- Zoom ----
    property double zoomMin: 1
    property double zoomMax: 200
    property double zoom: 100

    // ---- Camera ----
    property double cameraFovMin: 45.0
    property double cameraFovMax: 120.0
    property double cameraFov: 90.0
    property bool cameraFly: false

    // ---- File paths ----
    property string imageFilePath: ""
    property string videoFilePath: ""

    // ---- Output format ----
    property var formatList: ["Equirectangular", "Domemaster"]
    property string currentFormat: "Equirectangular"

    // ---- Dome model ----
    property var modelList: ["210 degrees", "180 degrees"]
    property string currentModel: "210 degrees"
    property real currentModelFov: 210
}
