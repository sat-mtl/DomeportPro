import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers

import Score.UI as UI
import ca.qc.sat.qmlcomponents
import domeportpro

import "DomeportController.js" as Controller

// View — the DomeportPro user interface (3D scene + on-screen controls).
//
// Presentation only: user interactions set state on `domeportModel` or invoke a
// `Controller.*` action, and the model's change signals are routed back to the
// controller through the Connections blocks below. DomeportController.js is
// imported as a non-library resource, so its functions run in this component's
// scope and reach the element ids (dome, camera, transportButton, …), the
// injected `domeportModel` and the Score/Util context objects directly.
Item {
    id: view

    // The application state, injected by DomeportPro.qml.
    property var domeportModel

    Component.onCompleted: Controller.initialize()

    // ---- Route model changes to the controller ----
    Connections {
        target: domeportModel

        function onCurrentModeChanged() { Controller.applyMode() }
        function onSourceNameChanged() { Controller.applySourceName() }
        function onNdiSourceNameChanged() { Controller.applyNdiSourceName() }
        function onSpoutSourceNameChanged() { Controller.applySpoutSourceName() }
        function onSyphonSourceNameChanged() { Controller.applySyphonSourceName() }
        function onZoomChanged() { Controller.applyZoom() }
        function onImageFilePathChanged() { Controller.applyImageFilePath() }
        function onVideoFilePathChanged() { Controller.applyVideoFilePath() }
        function onCurrentFormatChanged() { Controller.applyFormat() }
        function onCurrentModelChanged() { Controller.applyModel() }
    }

    Connections {
        target: domeportModel.video

        function onVideoDurationMsecChanged() { Controller.applyVideoDuration() }
        function onPlayheadRequestMsecChanged() { Controller.applyPlayheadRequest() }
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
            property real cameraHeight: 150
            position: Qt.vector3d(0, cameraHeight, 400)
            eulerRotation: Qt.vector3d(30, 0, 0)
            clipNear: 1
            clipFar: 10000
            fieldOfView: domeportModel.cameraFov

            onPositionChanged: {
                if (!domeportModel.cameraFly) {
                    // keep camera height fixed
                    position.y = cameraHeight
                }
            }

            onEulerRotationChanged: {
                // restrict up/down camera motion from -90 to 90 degrees
                if (eulerRotation.x > 90) {
                    eulerRotation.x = 90
                }
                if (eulerRotation.x < -90) {
                    eulerRotation.x = -90
                }
            }
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
                            source: "resources/images/GridBlack.jpg"
                            generateMipmaps: true 
                            mipFilter: Texture.Linear
                        }
                    }
                    shadingMode: CustomMaterial.Unshaded
                    vertexShader: "resources/shaders/groundshader.vert"
                    fragmentShader: "resources/shaders/groundshader.frag"
                }

            ]
        }

        Model {
            id: dome
            source: "resources/models/sato210.mesh"
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
                    vertexShader: "resources/shaders/domeshader.vert"
                    fragmentShader: "resources/shaders/domeshader.frag"
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

    GamepadController {
        id: gamepadControl
        controlledObject: camera
        speed: 1.0
        shiftSpeed: 2.0
        lookSpeed: 0.8
    }
    
    UI.TextureSource {
        id: textureDome
        width: 4096
        height: 4096
        process: "rotate_zoom"
        port: 0
        visible: false
    }

    RowLayout {
        id: topRow
        anchors.top: parent.top
        width: parent.width - 2 * 12
        x: 12
        spacing: 12

        ColumnLayout {
            id: inputControls
            Layout.alignment: Qt.AlignTop | Qt.AlignLeft

            // Test pattern stays a dome-only control (it is not a video-input
            // backend). It drives the existing currentMode lifecycle.
            Button {
                text: "Test pattern"
                font.bold: domeportModel.testPatternMode
                onClicked: domeportModel.currentMode = "Test pattern"
            }

            // Shared multi-backend picker. Camera is intentionally omitted
            // (DomeportPro has no camera capture). Selecting a backend drives the
            // existing currentMode logic (Video file; Image file; NDI/Spout/
            // Syphon -> live), and picking a source feeds the existing sourceName
            // lifecycle (createNDI/Spout/SyphonInput). DOMEPORTPRO_BASIC collapses
            // the list to video and image file only.
            InputSourceSelector {
                id: inputSelector
                Layout.preferredWidth: 280
                allowedBackends: domeportModel.basicFeatures
                                 ? ["Video file", "Image file"]
                                 : ["Video file", "Image file", "NDI", "Spout", "Syphon"]
                sources: domeportModel.sourceList

                onBackendSelected: name => { domeportModel.currentMode = name }
                onSourceSelected: name => { domeportModel.sourceName = name }
                onVideoFileSelected: path => { domeportModel.videoFilePath = path }
                onImageFileSelected: path => { domeportModel.imageFilePath = path }
                onRefreshRequested: () => Controller.updateSources()
            }
        }

        RowLayout {
            id: configControls
            Layout.alignment: Qt.AlignRight

            Label {
                id: formatLabel
                text: "Format"
                color: Theme.textColor
            }

            ComboBox {
                id: formatSelector
                model: domeportModel.formatList
                onActivated: domeportModel.currentFormat = currentValue
                Component.onCompleted: {
                    let index = indexOfValue(domeportModel.currentFormat)
                    if (index >=0) {
                        currentIndex = index
                    }
                }
            }

            Label {
                id: modelSelectorLabel
                text: "Model"
                color: Theme.textColor
            }

            ComboBox {
                id:  modelSelector
                model: domeportModel.modelList
                onActivated: domeportModel.currentModel = currentValue
                Component.onCompleted: {
                    let index = indexOfValue(domeportModel.currentModel)
                    if (index >=0) {
                        currentIndex = index
                    }
                }
            }

            Label {
                id: zoomLabel
                text: "Zoom"
                horizontalAlignment: Text.AlignHCenter
                color: "#FFFFFF"
            }

            SpinBox {
                id: zoomSpinBox
                Layout.preferredWidth: 55
                from: domeportModel.zoomMin
                to: domeportModel.zoomMax
                value: domeportModel.zoom
                onValueModified: {
                    domeportModel.zoom = value
                }
                editable: true
            }

            Label {
                id: cameraFovLabel
                text: "Camera\nFoV"
                horizontalAlignment: Text.AlignHCenter
                color: Theme.textColor
            }

            SpinBox {
                id: cameraFovSpinBox
                Layout.preferredWidth: 50
                from: domeportModel.cameraFovMin
                to: domeportModel.cameraFovMax
                value: domeportModel.cameraFov
                onValueModified: {
                    domeportModel.cameraFov = value
                }
                editable: true
            }

            Button {
                id: flyButton
                text: { domeportModel.cameraFly ? "Walk" : "Fly" }
                Layout.preferredWidth: 50
                onClicked: Controller.toggleCameraFlyMode()
            }

            Button {
                id: transportButton
                visible: true
                text: "Stop"
                Layout.preferredWidth: 50
                onClicked: Controller.toggleTransport()
            }

            Button {
                text: "Debug"
                Layout.preferredWidth: 50
                Layout.alignment: Qt.AlignRight
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

    RowLayout {
        id: playbackControls
        anchors.bottom: parent.bottom
        width: parent.width - 2 * 12
        x: 12
        spacing: 12

        Slider {
            id: transportSlider
            Layout.fillWidth: true
            from: 0.0
            to: domeportModel.video.videoDurationMsec
            value: domeportModel.video.playheadMsec
            stepSize: 0.0
            onMoved: {
                domeportModel.video.playheadRequestMsec = value
            }
            visible: domeportModel.videoFileMode
        }

        Button {
            id: pauseButton
            text: "Pause"
            Layout.preferredWidth: 60
            onClicked: Controller.togglePause()
            visible: domeportModel.videoFileMode
        }

    }

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (drop) => Controller.handleFileDrop(drop)
    }
}
