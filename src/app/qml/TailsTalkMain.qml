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
    property string selectedServerId: ""
    property string editingMessageId: ""
    property bool loggedIn: client.authenticated
    property bool pollBusy: false
    property var visibleChannels: selectedServerId.length === 0
        ? client.channels
        : client.channels.filter(function(channel) {
            return (channel.server || channel.server_id) === selectedServerId
        })

    title: loggedIn ? "TailsTalk 2" : "TailsTalk 2 — Sign in"
    minimumWidth: Kirigami.Units.gridUnit * 55
    minimumHeight: Kirigami.Units.gridUnit * 30
    visible: true

    ListModel {
        id: messages
    }

    QQC2.Menu {
        id: messageMenu

        QQC2.MenuItem {
            text: "Edit message"
            onTriggered: {
                root.editingMessageId = root.contextMessageId
                composer.text = root.contextMessageContent
                composer.forceActiveFocus()
            }
        }

        QQC2.MenuItem {
            text: "Delete message"
            onTriggered: client.deleteMessage(root.selectedChannelId, root.contextMessageId)
        }
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
            if (!root.selectedServerId && client.servers.length > 0) {
                root.selectedServerId = root.objectId(client.servers[0])
            }
            if (!root.selectedChannelId && client.channels.length > 0) {
                if (root.visibleChannels.length > 0) {
                    root.selectChannel(root.visibleChannels[0])
                }
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

        function onMessageUpdated(message) {
            if (!message.channel || message.channel === root.selectedChannelId) {
                client.fetchMessages(root.selectedChannelId)
            }
        }

        function onMessageDeleted(channelId) {
            if (channelId === root.selectedChannelId) {
                client.fetchMessages(root.selectedChannelId)
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

    function objectId(object) {
        return object ? (object._id || object.id || "") : ""
    }

    function objectName(object) {
        return object ? (object.name || object.username || object.display_name || object._id || object.id || "Unnamed") : "Unnamed"
    }

    function selectServer(server) {
        selectedServerId = objectId(server)
        if (visibleChannels.length > 0) {
            selectChannel(visibleChannels[0])
        } else {
            selectedChannelId = ""
            selectedChannelName = ""
            messages.clear()
        }
    }

    function authorName(message) {
        if (message.author && (message.author.username || message.author.display_name)) {
            return message.author.username || message.author.display_name
        }
        var authorId = messageAuthorId(message)
        for (var index = 0; index < client.users.length; ++index) {
            var user = client.users[index]
            if (objectId(user) === authorId) {
                return user.username || user.display_name || authorId
            }
        }
        return authorId || "User"
    }

    function messageAuthorId(message) {
        return message ? (message.author_id || (message.author && (message.author._id || message.author.id)) || message.author || "") : ""
    }

    function pollVotes(poll, optionId) {
        return poll && poll.votes && poll.votes[optionId] ? poll.votes[optionId] : []
    }

    function pollClosed(poll) {
        return !poll || poll.closed || (poll.closes_at !== undefined && poll.closes_at <= Date.now())
    }

    property string contextMessageId: ""
    property string contextMessageContent: ""

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
                    text: "Servers · " + (client.connected ? "Connected" : "Reconnecting…")
                    padding: Kirigami.Units.largeSpacing
                    font.bold: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 8)
                    clip: true
                    model: client.servers

                    delegate: QQC2.ItemDelegate {
                        required property var modelData
                        width: ListView.view.width
                        text: root.objectName(modelData)
                        highlighted: root.objectId(modelData) === root.selectedServerId
                        onClicked: root.selectServer(modelData)
                    }
                }

                QQC2.Label {
                    text: "Channels"
                    padding: Kirigami.Units.largeSpacing
                    font.bold: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.visibleChannels

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
                    delegate: ColumnLayout {
                        required property var modelData
                        property var messageData: modelData
                        width: messageView.width

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: root.authorName(modelData) + ": " + (modelData.content || "")
                            wrapMode: Text.Wrap
                            padding: Kirigami.Units.smallSpacing
                        }

                        ColumnLayout {
                            visible: modelData.poll !== undefined
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.largeSpacing
                            Layout.rightMargin: Kirigami.Units.largeSpacing

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: modelData.poll ? modelData.poll.question : ""
                                font.bold: true
                                wrapMode: Text.Wrap
                            }

                            Repeater {
                                model: modelData.poll ? modelData.poll.options : []

                                delegate: QQC2.Button {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    enabled: !root.pollClosed(messageData.poll) && !root.pollBusy
                                    text: modelData.text + " · " + root.pollVotes(messageData.poll, modelData.id).length
                                    onClicked: client.votePoll(root.selectedChannelId,
                                                               messageData._id || messageData.id,
                                                               modelData.id,
                                                               root.pollVotes(messageData.poll, modelData.id).indexOf(client.userId) < 0)
                                }
                            }

                            QQC2.Label {
                                Layout.fillWidth: true
                                visible: root.pollClosed(modelData.poll)
                                text: "Poll closed"
                                opacity: 0.7
                            }

                            QQC2.Button {
                                visible: !root.pollClosed(messageData.poll) && root.messageAuthorId(messageData) === client.userId
                                text: "Close poll"
                                onClicked: client.closePoll(root.selectedChannelId, modelData._id || modelData.id)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: {
                                root.contextMessageId = modelData._id || modelData.id || ""
                                root.contextMessageContent = modelData.content || ""
                                messageMenu.popup()
                            }
                        }
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
                        visible: root.editingMessageId.length > 0
                        text: "Cancel"
                        onClicked: {
                            root.editingMessageId = ""
                            composer.clear()
                        }
                    }

                    QQC2.Button {
                        id: sendMessageButton
                        text: "Send"
                        enabled: composer.enabled && composer.text.trim().length > 0
                        onClicked: {
                            if (root.editingMessageId.length > 0) {
                                client.editMessage(root.selectedChannelId, root.editingMessageId, composer.text)
                                root.editingMessageId = ""
                            } else {
                                client.sendMessage(root.selectedChannelId, composer.text)
                            }
                            composer.clear()
                        }
                    }
                }
            }
        }
    }
}
