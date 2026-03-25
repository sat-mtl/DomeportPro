import Score.UI as UI

Item {
    id: root
    property Node controlledObject: undefined

    property real speed: 1
    property real shiftSpeed: 2
    property real deadZone: 0.02

    property real moveSpeed: speed * 5
    property real forwardSpeed: 5
    property real backSpeed: 5
    property real rightSpeed: 5
    property real leftSpeed: 5
    property real upSpeed: 5
    property real downSpeed: 5

    property real lookSpeed: speed * 0.4
    property real lookUpSpeed: 0.4
    property real lookDownSpeed: 0.4
    property real lookLeftSpeed: 0.4
    property real lookRightSpeed: 0.4

    readonly property bool inputsNeedProcessing: status.moveForward | status.moveBack
                                                 | status.moveLeft | status.moveRight
                                                 | status.moveUp | status.moveDown
                                                 | status.lookUp | status.lookDown
                                                 | status.lookLeft | status.lookRight

    Component.onCompleted: {
        // // create a default gamepad device
        // let settings = {
        //     "Name": "Gamepad2",
        //     "Gamepad": true
        // }
        // Score.createDevice("Gamepad2", "2b9c9f9d-f0fa-41a0-8e7a-0eedd4c48b35", settings)
    }

    property bool shiftButton: false
    UI.AddressSource on shiftButton {
        address: "Gamepad:/button/a"
        receiveUpdates: true
    }
    onShiftButtonChanged: {
        console.log("shiftButton: ", shiftButton)
        if (shiftButton) shiftPressed()
        if (!shiftButton) shiftReleased()
    }

    property bool forwardButton: false
    UI.AddressSource on forwardButton {
        address: "Gamepad:/dpad/up"
        receiveUpdates: true
    }
    onForwardButtonChanged: {
        console.log("forwardButton: ", forwardButton)
        if (forwardButton) {
            forwardSpeed = moveSpeed
            forwardPressed()
        }
        if (!forwardButton) forwardReleased()
    }

    property bool backButton: false
    UI.AddressSource on backButton {
        address: "Gamepad:/dpad/down"
        receiveUpdates: true
    }
    onBackButtonChanged: {
        console.log("backButton: ", backButton)
        if (backButton) {
            backSpeed = moveSpeed
            backPressed()
        }
        if (!backButton) backReleased()
    }

    property bool leftButton: false
    UI.AddressSource on leftButton {
        address: "Gamepad:/dpad/left"
        receiveUpdates: true
    }
    onLeftButtonChanged: {
        console.log("leftButton: ", leftButton)
        if (leftButton) {
            leftSpeed = moveSpeed
            leftPressed()
        }
        if (!leftButton) leftReleased()
    }

    property bool rightButton: false
    UI.AddressSource on rightButton {
        address: "Gamepad:/dpad/right"
        receiveUpdates: true
    }
    onRightButtonChanged: {
        console.log("rightButton: ", rightButton)
        if (rightButton) {
            rightSpeed = moveSpeed
            rightPressed()
        }
        if (!rightButton) rightReleased()
    }

    property real forwardBackward: 0.0 // -1 is forward, 1 is backward
    UI.AddressSource on forwardBackward {
        address: "Gamepad:/stick/left/y"
        receiveUpdates: true
    }
    onForwardBackwardChanged: {
        console.log("forwardBackward: ", forwardBackward)
        if (forwardBackward < -deadZone) {
            forwardSpeed = -forwardBackward * moveSpeed
            forwardPressed()
        }
        if (forwardBackward > -deadZone) forwardReleased()

        if (forwardBackward > deadZone) {
            backSpeed = forwardBackward * moveSpeed
            backPressed()
        }
        if (forwardBackward < deadZone) backReleased()
    }

    property real leftRight: 0.0 // -1 is left, 1 is right
    UI.AddressSource on leftRight {
        address: "Gamepad:/stick/left/x"
        receiveUpdates: true
    }
    onLeftRightChanged: {
        console.log("leftRight: ", leftRight)
        if (leftRight < -deadZone) {
            leftSpeed = -leftRight * moveSpeed
            leftPressed()
        }
        if (leftRight > -deadZone) leftReleased()

        if (leftRight > deadZone) {
            rightSpeed = leftRight * moveSpeed
            rightPressed()
        }
        if (leftRight < deadZone) rightReleased()
    }

    property real up: 0.0 // 0 to 1 is up
    UI.AddressSource on up {
        address: "Gamepad:/trigger/right"
        receiveUpdates: true
    }
    onUpChanged: {
        console.log("up: ", up)

        if (up > deadZone) {
            upSpeed = up * moveSpeed
            upPressed()
        }
        if (up < deadZone) upReleased()
    }

    property real down: 0.0 // 0 to 1 is down
    UI.AddressSource on down {
        address: "Gamepad:/trigger/left"
        receiveUpdates: true
    }
    onDownChanged: {
        console.log("down: ", down)

        if (down > deadZone) {
            downSpeed = down * moveSpeed
            downPressed()
        }
        if (down < deadZone) downReleased()
    }

    property real lookUpDown: 0.0 // -1 is look up, 1 is look down
    UI.AddressSource on lookUpDown {
        address: "Gamepad:/stick/right/y"
        receiveUpdates: true
    }
    onLookUpDownChanged: {
        console.log("lookUpDown: ", lookUpDown)

        if (lookUpDown < -deadZone) {
            lookUpSpeed = -lookUpDown * lookSpeed
            lookUpPressed()
        }
        if (lookUpDown > -deadZone) lookUpReleased()

        if (lookUpDown > deadZone) {
            lookDownSpeed = lookUpDown * lookSpeed
            lookDownPressed()
        }
        if (lookUpDown < deadZone) lookDownReleased()
    }

    property real lookLeftRight: 0.0 // -1 is look left, 1 is look right
    UI.AddressSource on lookLeftRight {
        address: "Gamepad:/stick/right/x"
        receiveUpdates: true
    }
    onLookLeftRightChanged: {
        console.log("lookLeftRight: ", lookLeftRight)

        if (lookLeftRight < -deadZone) {
            lookLeftSpeed = -lookLeftRight * lookSpeed
            lookLeftPressed()
        }
        if (lookLeftRight > -deadZone) lookLeftReleased()

        if (lookLeftRight > deadZone) {
            lookRightSpeed = lookLeftRight * lookSpeed
            lookRightPressed()
        }
        if (lookLeftRight < deadZone) lookRightReleased()
    }

    function forwardPressed() {
        status.moveForward = true
        status.moveBack = false
    }

    function forwardReleased() {
        status.moveForward = false
    }

    function backPressed() {
        status.moveBack = true
        status.moveForward = false
    }

    function backReleased() {
        status.moveBack = false
    }

    function rightPressed() {
        status.moveRight = true
        status.moveLeft = false
    }

    function rightReleased() {
        status.moveRight = false
    }

    function leftPressed() {
        status.moveLeft = true
        status.moveRight = false
    }

    function leftReleased() {
        status.moveLeft = false
    }

    function upPressed() {
        status.moveUp = true
        status.moveDown = false
    }

    function upReleased() {
        status.moveUp = false
    }

    function downPressed() {
        status.moveDown = true
        status.moveUp = false
    }

    function downReleased() {
        status.moveDown = false
    }

    function shiftPressed() {
        status.shiftDown = true
    }

    function shiftReleased() {
        status.shiftDown = false
    }

    function lookUpPressed() {
        status.lookUp = true
        status.lookDown = false
    }

    function lookUpReleased() {
        status.lookUp = false
    }

    function lookDownPressed() {
        status.lookDown = true
        status.lookUp = false
    }

    function lookDownReleased() {
        status.lookDown = false
    }

    function lookLeftPressed() {
        status.lookLeft = true
        status.lookRight = false
    }

    function lookLeftReleased() {
        status.lookLeft = false
    }

    function lookRightPressed() {
        status.lookRight = true
        status.lookLeft = false
    }

    function lookRightReleased() {
        status.lookRight = false
    }

    FrameAnimation {
        id: updateTimer
        running: root.inputsNeedProcessing
        onTriggered: status.processInput(frameTime * 100)
    }

    QtObject {
        id: status

        property bool moveForward: false
        property bool moveBack: false
        property bool moveLeft: false
        property bool moveRight: false
        property bool moveUp: false
        property bool moveDown: false
        property bool lookUp: false
        property bool lookDown: false
        property bool lookLeft: false
        property bool lookRight: false
        property bool shiftDown: false

        function updatePosition(vector, speed, position)
        {
            if (shiftDown)
                speed *= root.shiftSpeed;
            else
                speed *= root.speed

            var direction = vector;
            var velocity = Qt.vector3d(direction.x * speed,
                                       direction.y * speed,
                                       direction.z * speed);
            controlledObject.position = Qt.vector3d(position.x + velocity.x,
                                                    position.y + velocity.y,
                                                    position.z + velocity.z);
        }

        function negate(vector) {
            return Qt.vector3d(-vector.x, -vector.y, -vector.z)
        }

        function processInput(frameDelta) {
            if (root.controlledObject == undefined)
                return;

            if (moveForward)
                updatePosition(root.controlledObject.forward, root.forwardSpeed * frameDelta, root.controlledObject.position);
            else if (moveBack)
                updatePosition(negate(root.controlledObject.forward), root.backSpeed * frameDelta, root.controlledObject.position);

            if (moveRight)
                updatePosition(root.controlledObject.right, root.rightSpeed * frameDelta, root.controlledObject.position);
            else if (moveLeft)
                updatePosition(negate(root.controlledObject.right), root.leftSpeed * frameDelta, root.controlledObject.position);

            if (moveDown)
                updatePosition(negate(root.controlledObject.up), root.downSpeed * frameDelta, root.controlledObject.position);
            else if (moveUp)
                updatePosition(root.controlledObject.up, root.upSpeed * frameDelta, root.controlledObject.position);
            
            if (lookUp) {
                var rotationVector = root.controlledObject.eulerRotation;
                // rotate y up
                var rotateY = root.lookUpSpeed * frameDelta
                rotationVector.x += rotateY
                controlledObject.setEulerRotation(rotationVector)
            } else if (lookDown) {
                var rotationVector = root.controlledObject.eulerRotation;
                // rotate y down
                var rotateY = -root.lookDownSpeed * frameDelta
                rotationVector.x += rotateY
                controlledObject.setEulerRotation(rotationVector)
            }

            if (lookLeft) {
                var rotationVector = root.controlledObject.eulerRotation;
                // rotate x left
                var rotateX = root.lookLeftSpeed * frameDelta
                rotationVector.y += rotateX
                controlledObject.setEulerRotation(rotationVector)
            } else if (lookRight) {
                var rotationVector = root.controlledObject.eulerRotation;
                // rotate x right
                var rotateX = -root.lookRightSpeed * frameDelta
                rotationVector.y += rotateX
                controlledObject.setEulerRotation(rotationVector)
            }
        }
    }
}