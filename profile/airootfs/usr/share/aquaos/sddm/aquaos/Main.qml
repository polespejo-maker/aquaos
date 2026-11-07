/***************************************************************************
 *  AquaOS · tema de inicio de sesión para SDDM
 *
 *  Inspirado en el tema "maldives" de SDDM (MIT), adaptado al estilo de
 *  AquaOS: fondo Ventura, tarjeta translúcida y acento azul #0a84ff.
 *
 *  Requiere SDDM con QML (SddmComponents 2.0). No usa QtGraphicalEffects
 *  para que funcione con los paquetes mínimos de la ISO.
 ***************************************************************************/

import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: container
    width: 640
    height: 480

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int sessionIndex: session.index
    property color accent: "#0a84ff"

    TextConstants { id: textConstants }

    Connections {
        target: sddm

        onLoginSucceeded: {
            errorMessage.color = container.accent;
            errorMessage.text = textConstants.loginSucceeded;
        }

        onLoginFailed: {
            password.text = "";
            errorMessage.color = "#ff453a";
            errorMessage.text = textConstants.loginFailed;
        }
    }

    // --- fondo -------------------------------------------------------------
    Background {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        onStatusChanged: {
            if (status == Image.Error && source != config.defaultBackground)
                source = config.defaultBackground;
        }
    }

    // Oscurecido suave para que el texto y la tarjeta se lean bien.
    Rectangle {
        anchors.fill: parent
        color: "#26000000"
    }

    // --- reloj -------------------------------------------------------------
    Clock {
        id: clock
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 44

        color: "white"
        timeFont.family: "Inter"
        timeFont.pointSize: 54
        timeFont.weight: Font.Light
        dateFont.family: "Inter"
        dateFont.pointSize: 15
        dateFont.weight: Font.Light

        visible: width > 0
    }

    // --- sombra de la tarjeta ---------------------------------------------
    Rectangle {
        anchors.centerIn: card
        width: card.width + 12
        height: card.height + 12
        radius: 30
        color: "#22000000"
    }

    // --- tarjeta -----------------------------------------------------------
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 380
        height: mainColumn.implicitHeight + 64
        radius: 24
        color: "#eef7f7fa"
        border.color: "#66ffffff"
        border.width: 1

        Column {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 32
            spacing: 12

            // Avatar circular con la inicial del usuario.
            Item {
                width: 84
                height: 84
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#4facfe" }
                        GradientStop { position: 1.0; color: container.accent }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: name.text !== "" ? name.text.charAt(0).toUpperCase() : "A"
                        color: "white"
                        font.family: "Inter"
                        font.pixelSize: 36
                        font.bold: true
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "AquaOS"
                color: "#1c1c1e"
                font.family: "Inter"
                font.pixelSize: 22
                font.bold: true
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: sddm.hostName
                color: "#6e6e73"
                font.family: "Inter"
                font.pixelSize: 12
            }

            // --- usuario ---------------------------------------------------
            Column {
                width: parent.width
                spacing: 5
                topPadding: 4

                Text {
                    text: textConstants.userName
                    color: "#3a3a3c"
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.bold: true
                }

                TextBox {
                    id: name
                    width: parent.width
                    height: 40
                    radius: 10

                    color: "#ffffff"
                    borderColor: "#d1d1d6"
                    focusColor: container.accent
                    hoverColor: container.accent
                    textColor: "#1c1c1e"
                    text: userModel.lastUser

                    font.family: "Inter"
                    font.pixelSize: 14

                    KeyNavigation.backtab: loginButton
                    KeyNavigation.tab: password

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex);
                            event.accepted = true;
                        }
                    }
                }
            }

            // --- contraseña ------------------------------------------------
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: textConstants.password
                    color: "#3a3a3c"
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.bold: true
                }

                PasswordBox {
                    id: password
                    width: parent.width
                    height: 40
                    radius: 10

                    color: "#ffffff"
                    borderColor: "#d1d1d6"
                    focusColor: container.accent
                    hoverColor: container.accent
                    textColor: "#1c1c1e"
                    image: ""

                    font.family: "Inter"
                    font.pixelSize: 14

                    KeyNavigation.backtab: name
                    KeyNavigation.tab: session

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            sddm.login(name.text, password.text, sessionIndex);
                            event.accepted = true;
                        }
                    }
                }
            }

            // --- error -----------------------------------------------------
            Text {
                id: errorMessage
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: textConstants.prompt
                color: "#8e8e93"
                font.family: "Inter"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            // --- botón de entrar -------------------------------------------
            AquaButton {
                id: loginButton
                width: parent.width
                height: 42
                text: textConstants.login
                baseColor: container.accent
                onClicked: sddm.login(name.text, password.text, sessionIndex)

                KeyNavigation.backtab: session
                KeyNavigation.tab: name
            }

            // --- sesión ----------------------------------------------------
            Column {
                width: parent.width
                spacing: 5
                topPadding: 2

                Text {
                    text: textConstants.session
                    color: "#3a3a3c"
                    font.family: "Inter"
                    font.pixelSize: 11
                    font.bold: true
                }

                ComboBox {
                    id: session
                    width: parent.width
                    height: 36

                    color: "#ffffff"
                    borderColor: "#d1d1d6"
                    focusColor: container.accent
                    hoverColor: container.accent
                    menuColor: "#ffffff"
                    textColor: "#1c1c1e"
                    arrowColor: "#8e8e93"
                    arrowIcon: "angle-down.png"

                    model: sessionModel
                    index: sessionModel.lastIndex

                    font.family: "Inter"
                    font.pixelSize: 12

                    KeyNavigation.backtab: password
                    KeyNavigation.tab: loginButton
                }
            }

            // --- apagar / reiniciar ----------------------------------------
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 30
                topPadding: 4

                Text {
                    text: textConstants.shutdown
                    color: container.accent
                    font.family: "Inter"
                    font.pixelSize: 12

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sddm.powerOff()
                    }
                }

                Text {
                    text: textConstants.reboot
                    color: container.accent
                    font.family: "Inter"
                    font.pixelSize: 12

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sddm.reboot()
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (name.text === "")
            name.focus = true;
        else
            password.focus = true;
    }
}
