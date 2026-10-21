// SPDX-FileCopyrightText: 2026 TailsTalk 2 for Linux contributors
// SPDX-License-Identifier: GPL-3.0-only

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.neochat.libneochat

Kirigami.ApplicationWindow {
    id: root

    property TailsTalkClient client: TailsTalkClient {}
    property string errorMessage: ""
    property string selectedChannelId: ""
    property string selectedChannelName: ""
    property bool loggedIn: client.authenticated

    title: loggedIn ? "TailsTalk 2" : "TailsTalk 2 — Sign in"
    minimumWidth: Kirigami.Units.gridUnit * 55
    minimumHeight: Kirigami.Units.gridUnit * 30
    visible: true

    ListModel {
        id: messages
    }

    Connections {
        target: client

        function onLoginFailed(message) {
            root.errorMessage = message || "TailsTalk login failed"
        }

        function onRequestFailed(operation, status, message) {
            root.errorMessage = operation + " failed" + (status ? " (" + status + ")" : "") + ": " + message
        }

        function onDiscoveryChanged() {
            if (!root.selectedChannelId && client.channels.length > 0) {
                root.selectChannel(client.channels[0])
            }
        }

        function onMessagesFetched(items) {
            messages.clear()
            for (let index = items.length - 1; index >= 0; --index) {
                messages.append(items[index])
            }
        }

        function onMessageReceived(message) {
            if (message.channel === root.selectedChannelId || message.channel_id === root.selectedChannelId) {
                messages.append(message)
            }
        }
    }

    function selectChannel(channel) {
        if (!channel || !channel.id) {
            return
        }
        selectedChannelId = channel.id
        selectedChannelName = channel.name || channel.id
        messages.clear()
        client.fetchMessages(selectedChannelId)
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: root.loggedIn ? 1 : 0

        Item {
            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - Kirigami.Units.gridUnit * 8, Kirigami.Units.gridUnit * 30)
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Heading {
                    text: "TailsTalk 2"
                    level: 1
                    Layout.alignment: Qt.AlignHCenter
                }

                QQC2.Label {
                    text: "Sign in to your TailsTalk account"
                    Layout.alignment: Qt.AlignHCenter
                }

                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: root.errorMessage.length > 0
                    text: root.errorMessage
                    type: Kirigami.MessageType.Error
                    showCloseButton: true
                }

                QQC2.TextField {
                    id: email
                    Layout.fillWidth: true
                    placeholderText: "Email"
                    inputMethodHints: Qt.ImhEmailCharactersOnly
                }

                QQC2.TextField {
                    id: password
                    Layout.fillWidth: true
                    placeholderText: "Password"
                    echoMode: TextInput.Password
                    onAccepted: signIn.clicked()
                }

                QQC2.Button {
                    id: signIn
                    Layout.alignment: Qt.AlignHCenter
                    text: "Sign in"
                    enabled: email.text.length > 0 && password.text.length > 0
                    onClicked: {
                        root.errorMessage = ""
                        client.login(email.text, password.text)
                    }
                }
            }
        }

        RowLayout {
            spacing: 0

            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 17
                Layout.minimumWidth: Kirigami.Units.gridUnit * 14

                QQC2.ToolButton {
                    text: "Sign out"
                    onClicked: client.clearSession()
                }

                QQC2.Label {
                    text: "Servers and channels"
                    padding: Kirigami.Units.largeSpacing
                    font.bold: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: client.channels

                    delegate: QQC2.ItemDelegate {
                        required property var modelData
                        width: ListView.view.width
                        text: modelData.name || modelData.id
                        highlighted: modelData.id === root.selectedChannelId
                        onClicked: root.selectChannel(modelData)
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillHeight: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Kirigami.Heading {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    text: root.selectedChannelName || "Select a channel"
                    level: 2
                }

                ListView {
                    id: messageView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: Kirigami.Units.largeSpacing
                    clip: true
                    model: messages
                    delegate: QQC2.Label {
                        required property var modelData
                        width: messageView.width
                        text: (modelData.author && modelData.author.username ? modelData.author.username : (modelData.author_id || "User")) + ": " + (modelData.content || "")
                        wrapMode: Text.Wrap
                        padding: Kirigami.Units.smallSpacing
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.largeSpacing

                    QQC2.TextField {
                        id: composer
                        Layout.fillWidth: true
                        placeholderText: root.selectedChannelId ? "Write a message" : "Select a channel first"
                        enabled: root.selectedChannelId.length > 0
                        onAccepted: sendMessageButton.clicked()
                    }

                    QQC2.Button {
                        id: sendMessageButton
                        text: "Send"
                        enabled: composer.enabled && composer.text.trim().length > 0
                        onClicked: {
                            client.sendMessage(root.selectedChannelId, composer.text)
                            composer.clear()
                        }
                    }
                }
            }
        }
    }
}
