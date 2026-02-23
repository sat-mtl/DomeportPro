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
    property var ndiNamesList: []
    property string ndiSourceName: ""
    property string testPatternName: "Test pattern"

    function ndiAdded(factory, category, name, settings) {
        console.log("NDI added: " + name)
        ndiNamesList.push(name)
        ndiSelector.model = [testPatternName, ...ndiNamesList]
    }

    function ndiRemoved(factory, name) {
        console.log("NDI removed: " + name)
        const index = ndiNamesList.indexOf(name)
        if (index !== 1) {
            ndiNamesList.splice(index, 1);
        }
        ndiSelector.model = [testPatternName, ...ndiNamesList]
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

    function removeCurrentNDIInput() {
        Score.stop()
        try { Score.removeDevice(ndiSourceName); } catch(_) {}
    }

    function createNDIInput(name) {
        console.log("Create NDI input: " + name)
        Score.stop()

        removeCurrentNDIInput()

        // create a NDI source
        let settings = {
            "Path": name
        }
        Score.createDevice(name, "ae78b7c6-6400-483e-b45b-fd6ff87ec700", settings)
        ndiSourceName = name

        // attach NDI source to image inlet
        let ndiSource = Score.find("ndi source")
        let ndiSourceInlet = Score.port(ndiSource, "inputImage")
        Score.setAddress(ndiSourceInlet, name + ":/")

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
            fieldOfView:90
        }

        Model {
            id: groundPlane
            source: "#Rectangle"
            scale: Qt.vector3d(500, 500, 1)
            eulerRotation: Qt.vector3d(-90, 0, 0)
            position: Qt.vector3d(0, 0, 0)
            castsShadows: false
            receivesShadows: true

            materials: [
                PrincipledMaterial {
                    baseColor: "#aaa"
                    roughness: 0.85
                    metalness: 0.0
                }
            ]
        }

        Model {
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
                    vertexShader: "customshader.vert"
                    fragmentShader: "customshader.frag"
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
            id: ndiSelector
            Layout.minimumWidth: 200
            model: [testPatternName, ...ndiNamesList]
            onCurrentIndexChanged: {
                if (currentIndex <= 0) {
                    removeCurrentNDIInput()
                    displayTestPattern()
                } else {
                    const ndiName = ndiNamesList[currentIndex - 1]
                    createNDIInput(ndiName)
                }
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
