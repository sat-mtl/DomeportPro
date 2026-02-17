import QtQuick
import QtQuick.Controls
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

        PointLight {
            position: Qt.vector3d(0, 10, 10)
            brightness: 20.0
            color: "#fff"
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
                PrincipledMaterial {
                    baseColorMap: Texture {
                        sourceItem: textureDome
                    }
                    roughness: 0.5
                    metalness: 0.2
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

    Button {
        anchors.right: parent.right
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

    Button {
        anchors.left: parent.left
        text: "Play"
        onClicked:  Score.play()
    }

}