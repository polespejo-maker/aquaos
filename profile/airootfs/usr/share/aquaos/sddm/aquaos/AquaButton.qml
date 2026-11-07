import QtQuick 2.0

/**
 * Botón redondeado del tema AquaOS (sin dependencias externas).
 */
Rectangle {
    id: button

    property alias text: label.text
    property alias font: label.font
    property color baseColor: "#0a84ff"
    property color hoverColor: "#0071e3"
    property color pressedColor: "#005bb5"
    property color textColor: "white"

    signal clicked()

    width: 200
    height: 42
    radius: 10
    color: area.pressed ? pressedColor : (area.containsMouse ? hoverColor : baseColor)

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: label
        anchors.centerIn: parent
        color: button.textColor
        font.family: "Inter"
        font.pixelSize: 14
        font.bold: true
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

    Keys.onReturnPressed: button.clicked()
    Keys.onEnterPressed: button.clicked()
}
