import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

        property var modeList: [ "Test pattern", "NDI" ]
        property string currentMode: "Test pattern"
        onCurrentModeChanged: {
            console.log("changed mode: " + currentMode)
            if (currentMode === "Test pattern") {
                removeNDIInput()
                displayTestPattern()
            } else if (currentMode === "NDI") {
                removeNDIInput()
                createNDIInput(ndiSourceName)
            }
        }

        property var ndiNamesList: [ "NDI sources..." ]

        property string ndiSourceName: ""
        onNdiSourceNameChanged: {
            console.log("Updated NDI Source Name: " + ndiSourceName)
            removeNDIInput()
            createNDIInput(ndiSourceName)
            currentMode = "NDI"
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
        console.log(index)
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
        domeportModel.ndiSourceName = name

        // attach NDI source to image inlet
        let ndiSource = Score.find("ndi source")
        let ndiSourceInlet = Score.port(ndiSource, "inputImage")
        Score.setAddress(ndiSourceInlet, "ndi_input:/")

        // display NDI source
        Score.setValue(videoMixer.alpha1, 0.0)
        Score.setValue(videoMixer.alpha2, 1.0)

        console.log("Created NDI input: " + name)
        Score.play()
    }

    Item {
        QtObject { id: videoMixer
            property var process_object : Score.find("Video Mixer");
            property var alpha1 : Score.inlet(process_object, 8);
            property var alpha2 : Score.inlet(process_object, 9);
        }
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

    function onPlay() {
        console.log("onPlay")
        transportButton.text = "Stop"
        running = true
    }

    function onStop() {
        console.log("onStopped")
        transportButton.text = "Play"
        running = false
    }

    Component.onCompleted: {
        Score.transport().play.connect(onPlay)
        Score.transport().stop.connect(onStop)
        registerNDIListener()
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
            onClicked:  toggleTransport()
        }

        ComboBox {
            id: modeSelector
            model: domeportModel.modeList
            onActivated: {
                console.log("selected mode: " + currentText)
                domeportModel.currentMode = currentText
            }
        }

        ComboBox {
            id: ndiSelector
            Layout.minimumWidth: 200
            model: domeportModel.ndiNamesList
            onActivated: {
                console.log("selected NDI: " + currentText)
                domeportModel.ndiSourceName = currentText
                currentIndex = 0
            }
        }

        TextField {
            id: ndiSourceNameTextField
            text: domeportModel.ndiSourceName
            onEditingFinished: {
                domeportModel.ndiSourceName = text
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
}
