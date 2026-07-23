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

    // ---- Feature flags ----
    property bool basicFeatures: false

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
