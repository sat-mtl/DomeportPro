import QtQuick
import QtQuick.Controls

import ca.qc.sat.qmlcomponents
import domeportpro

// Application root — composes the DomeportPro model and view.
//
// This is the single component instantiated by qml/Main.qml. An
// ApplicationWindow provides the overlay used by the SidePanel scrim, popups
// and the About dialog. All state lives in DomeportModel and all behaviour in
// DomeportController.js (driven by the view).
ApplicationWindow {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "Domeport Pro"
    color: Theme.backgroundColor

    DomeportModel {
        id: domeportModel
    }

    DomeportView {
        anchors.fill: parent
        domeportModel: domeportModel
        appWindow: root
    }
}
