import QtQuick

import ca.qc.sat.qmlcomponents
import domeportpro

// Application root — composes the DomeportPro model and view.
//
// This is the single component instantiated by qml/Main.qml. It owns the
// window chrome and wires the model instance into the view; all state lives in
// DomeportModel and all behaviour in DomeportController.js (driven by the view).
Window {
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
    }
}
