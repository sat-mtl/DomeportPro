import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick3D
import QtQuick3D.Helpers

import Score.UI as UI

Window {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "DomeportSAT"
    color: "#1a1a2e"

    property bool running: true

    Item {
        id: domeportModel

        QtObject { id: videoMixer
            property var process_object : Score.find("Video Mixer");
            property var alpha1 : Score.inlet(process_object, 8);
            property var alpha2 : Score.inlet(process_object, 9);
            property var alpha3 : Score.inlet(process_object, 10);
        }

        QtObject { id: video
            property var process_object : Score.find("Video");
            property double videoDurationMsec: 0.0;
            onVideoDurationMsecChanged: {
                // resize interval to video duration
                Score.setIntervalDuration(Score.rootInterval(), Util.timevalFromMilliseconds(videoDurationMsec))
            }

            property double playheadRequestMsec: 0.0;
            onPlayheadRequestMsecChanged: {
                Score.scrub(playheadRequestMsec)
            }

            property double playheadMsec: 0.0;

            function onLoopDurationChanged(loopDuration) {
                const loopDurationMsec = Util.toMilliseconds(loopDuration)
                videoDurationMsec = loopDurationMsec
            }

            function onPositionChanged(position) {
                playheadMsec = videoDurationMsec * position % videoDurationMsec
            }

            Component.onCompleted: {
                process_object.loopDurationChanged.connect(onLoopDurationChanged)
                Score.rootInterval().durations.positionChanged.connect(onPositionChanged)
            }
        }

        property var modeList: [ "Test pattern", "NDI", "Video playback" ]
        property string currentMode: "Test pattern"
        onCurrentModeChanged: {
            console.log("changed mode: " + currentMode)
            if (currentMode === "Test pattern") {
                removeNDIInput()
                displayTestPattern()
            } else if (currentMode === "NDI") {
                removeNDIInput()
                if (ndiSourceName !== "") { createNDIInput(ndiSourceName) }
                displayNDI()
            } else if (currentMode === "Video playback") {
                removeNDIInput()
                displayVideoPlayback()
            }
        }

        property var ndiNamesList: [ "NDI sources..." ]

        property string ndiSourceName: ""
        onNdiSourceNameChanged: {
            if (ndiSourceName !== "") {
                console.log("updated NDI Source Name: " + ndiSourceName)
                removeNDIInput()
                createNDIInput(ndiSourceName)
                currentMode = "NDI"
            }
        }

        property string videoFilePath: ""
        onVideoFilePathChanged: {
            console.log("videoFilePath: " + videoFilePath)
            if (videoFilePath === "") return
            video.process_object.path = videoFilePath
            currentMode = "Video playback"
        }
    }

    function ndiAdded(factory, category, name, settings) {
        console.log("NDI added: " + name)
        const index = domeportModel.ndiNamesList.indexOf(name)
        if (index !== 1) {
            domeportModel.ndiNamesList.push(name)
            ndiSelector.model = domeportModel.ndiNamesList
        }
    }

    function ndiRemoved(factory, name) {
        console.log("NDI removed: " + name)
        const index = domeportModel.ndiNamesList.indexOf(name)
        if (index !== 1) {
            domeportModel.ndiNamesList.splice(index, 1);
            ndiSelector.model = domeportModel.ndiNamesList
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

    function displayTestPattern() {
        Score.setValue(videoMixer.alpha1, 1.0)
        Score.setValue(videoMixer.alpha2, 0.0)
        Score.setValue(videoMixer.alpha3, 0.0)
        Score.play()
    }

    function displayNDI() {
        Score.setValue(videoMixer.alpha1, 0.0)
        Score.setValue(videoMixer.alpha2, 1.0)
        Score.setValue(videoMixer.alpha3, 0.0)
        Score.play()
    }

    function displayVideoPlayback() {
        Score.setValue(videoMixer.alpha1, 0.0)
        Score.setValue(videoMixer.alpha2, 0.0)
        Score.setValue(videoMixer.alpha3, 1.0)
        Score.play()
    }

    function removeNDIInput() {
        Score.stop()
        try { Score.removeDevice("ndi_input"); } catch(_) {}
    }

    function createNDIInput(name) {
        console.log("Create NDI input: " + name)
        Score.stop()

        // create a NDI source
        let settings = {
            "Path": name
        }
        Score.createDevice("ndi_input", "ae78b7c6-6400-483e-b45b-fd6ff87ec700", settings)

        // attach NDI source to image inlet
        let ndiSource = Score.find("ndi source")
        let ndiSourceInlet = Score.port(ndiSource, "inputImage")
        Score.setAddress(ndiSourceInlet, "ndi_input:/")

        console.log("Created NDI input: " + name)
        Score.play()
    }

    function toggleTransport() {
        if (running) {
            console.log("stopping...")
            Score.stop()
        } else {
            console.log("starting...")
            Score.play()
        }
    }

    function togglePause() {
        if (running) {
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
        running = true
    }

    function onStop() {
        console.log("onStopped")
        transportButton.text = "Play"
        running = false
    }

    function onPause() {
        console.log("onPause")
        transportButton.text = "Play"
        pauseButton.text = "Unpause"
        running = false
    }

    Component.onCompleted: {
        Score.transport().play.connect(onPlay)
        Score.transport().stop.connect(onStop)
        Score.transport().pause.connect(onPause)
        registerNDIListener()
        Score.play()
    }

    View3D {
        id: view3d
        anchors.fill: parent
        environment: sceneEnvironment

        SceneEnvironment {
            id: sceneEnvironment
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            backgroundMode: SceneEnvironment.Color
            clearColor: "#555"
        }

        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 150, 400)
            eulerRotation: Qt.vector3d(30, 0, 0)
            clipNear: 1
            clipFar: 10000
            fieldOfView: 90
        }

        Model {
            id: groundPlane
            source: "#Rectangle"
            scale: Qt.vector3d(500, 500, 1)
            eulerRotation: Qt.vector3d(-90, 0, 0)
            position: Qt.vector3d(0, 0, 0)

            materials: [
                CustomMaterial {
                    property TextureInput tex: TextureInput {
                        enabled: true
                        texture: Texture {
                            source: "GridBlack.jpg"
                        }
                    }
                    shadingMode: CustomMaterial.Unshaded
                    vertexShader: "groundshader.vert"
                    fragmentShader: "groundshader.frag"
                }

            ]
        }

        Model {
            id: dome
            source: "sato210.mesh"
            position: Qt.vector3d(0, 0, 0)
            scale: Qt.vector3d(100., 100., 100.)

            materials: [
                CustomMaterial {
                    property TextureInput tex: TextureInput {
                        enabled: true
                        texture: Texture {
                            sourceItem: textureDome
                        }
                    }
                    shadingMode: CustomMaterial.Unshaded
                    vertexShader: "domeshader.vert"
                    fragmentShader: "domeshader.frag"
                }
            ]
        }
    }

    WasdController {
        id: wasdControl
        controlledObject: camera
        speed: 1.0
        shiftSpeed: 5.0
        mouseEnabled: true
    }
    
    UI.TextureSource {
        id: textureDome
        width: 4096
        height: 4096
        process: "equirectangular_to_domemaster"
        port: 0
        visible: false
    }

    RowLayout {
        id: topRow
        width: parent.width

        Button {
            id: transportButton
            text: "Stop"
            onClicked: toggleTransport()
        }

        ComboBox {
            id: modeSelector
            model: domeportModel.modeList
            onActivated: domeportModel.currentMode = currentValue
            Component.onCompleted: {
                let index = indexOfValue(domeportModel.currentMode)
                if (index >=0) {
                    currentIndex = index
                }
            }
        }

        ComboBox {
            id: ndiSelector
            Layout.minimumWidth: 200
            model: domeportModel.ndiNamesList
            onActivated: {
                domeportModel.ndiSourceName = currentText
                currentIndex = 0
                domeportModel.currentMode = "NDI"
                modeSelector.currentIndex = modeSelector.indexOfValue(domeportModel.currentMode)
            }
        }

        TextField {
            id: ndiSourceNameTextField
            text: domeportModel.ndiSourceName
            onEditingFinished: {
                domeportModel.ndiSourceName = text
                modeSelector.currentIndex = modeSelector.indexOfValue(domeportModel.currentMode)
            }
        }

        Button {
            text: "Toggle DebugView"
            onClicked: debugView.visible = !debugView.visible
            DebugView {
                id: debugView
                source: view3d
                visible: false
                anchors.top: parent.bottom
                anchors.right: parent.right
            }
        }
    }

    RowLayout {
        id:bottomRow
        width: parent.width
        anchors.bottom: parent.bottom

        Button {
            id: browseVideoButton
            text: "Browse..."
            onClicked:  videoFileDialog.open()
        }

        Label {
            id: videoFilePathLabel
            text: domeportModel.videoFilePath
            color: "#E5E5E7"
        }

        Slider {
            id: transportSlider
            Layout.minimumWidth: 800
            from: 0.0
            to: video.videoDurationMsec
            value: video.playheadMsec
            stepSize: 0.0
            onMoved: {
                video.playheadRequestMsec = value
            }
        }

        Button {
            id: pauseButton
            text: "Pause"
            onClicked: togglePause()
        }

    }

    FileDialog {
        id: videoFileDialog
        title: "Select Video File"
        nameFilters: ["Video Files (*.mp4 *.avi *.mov *.mkv *.webm)", "All Files (*)"]
        onAccepted: {
            if (!selectedFile) return
            var filePath = selectedFile.toString()
            if (filePath.startsWith("file://")) filePath = filePath.substring(7)
            domeportModel.videoFilePath = filePath
            domeportModel.currentMode = "Video playback"
            modeSelector.currentIndex = modeSelector.indexOfValue(domeportModel.currentMode)
        }
    }
}
