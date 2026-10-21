// SPDX-FileCopyrightText: 2026 TailsTalk 2 for Linux contributors
// SPDX-License-Identifier: GPL-3.0-only

#include "tailstalkclient.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QUrlQuery>

#include <algorithm>

TailsTalkClient::TailsTalkClient(QObject *parent)
    : QObject(parent)
{
    m_heartbeatTimer.setInterval(std::chrono::seconds(30));
    m_pongTimer.setSingleShot(true);
    m_pongTimer.setInterval(std::chrono::seconds(10));
    m_reconnectTimer.setSingleShot(true);

    connect(&m_heartbeatTimer, &QTimer::timeout, this, &TailsTalkClient::sendHeartbeat);
    connect(&m_pongTimer, &QTimer::timeout, this, [this] {
        if (m_events.state() == QAbstractSocket::ConnectedState) {
            m_events.close();
        }
    });
    connect(&m_reconnectTimer, &QTimer::timeout, this, &TailsTalkClient::connectEvents);

    connect(&m_events, &QWebSocket::connected, this, [this] {
        m_reconnectDelayMs = 1000;
        m_heartbeatTimer.start();
        m_pongTimer.stop();
        Q_EMIT connectionStateChanged();
    });
    connect(&m_events, &QWebSocket::disconnected, this, [this] {
        m_heartbeatTimer.stop();
        m_pongTimer.stop();
        Q_EMIT connectionStateChanged();
        if (m_shouldReconnect && isAuthenticated()) {
            scheduleReconnect();
        }
    });
    connect(&m_events, &QWebSocket::textMessageReceived, this, [this](const QString &text) {
        const auto document = QJsonDocument::fromJson(text.toUtf8());
        if (!document.isObject()) {
            return;
        }
        const auto event = document.object();
        const auto type = event.value(QStringLiteral("type")).toString();
        if (type == QStringLiteral("Ping")) {
            QJsonObject pong{{QStringLiteral("type"), QStringLiteral("Pong")}, {QStringLiteral("data"), event.value(QStringLiteral("data"))}};
            m_events.sendTextMessage(QString::fromUtf8(QJsonDocument(pong).toJson(QJsonDocument::Compact)));
        } else if (type == QStringLiteral("Pong")) {
            m_pongTimer.stop();
        } else if (type == QStringLiteral("Error")) {
            Q_EMIT requestFailed(QStringLiteral("events"), 0, event.value(QStringLiteral("error")).toString(event.value(QStringLiteral("data")).toString()));
            m_events.close();
        } else if (type == QStringLiteral("Ready")) {
            const auto servers = event.value(QStringLiteral("servers")).toArray();
            const auto channels = event.value(QStringLiteral("channels")).toArray();
            const auto users = event.value(QStringLiteral("users")).toArray();
            m_servers = servers.toVariantList();
            m_channels = channels.toVariantList();
            m_users = users.toVariantList();
            Q_EMIT discoverySucceeded(servers, channels, users);
            Q_EMIT discoveryChanged();
        } else if (type == QStringLiteral("Message")) {
            Q_EMIT messageReceived(event);
        }
    });
    connect(&m_events, &QWebSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
        Q_EMIT requestFailed(QStringLiteral("events"), 0, m_events.errorString());
    });
}

QUrl TailsTalkClient::apiUrl() const
{
    return m_apiUrl;
}

void TailsTalkClient::setApiUrl(const QUrl &url)
{
    m_apiUrl = url.adjusted(QUrl::StripTrailingSlash);
}

QUrl TailsTalkClient::eventsUrl() const
{
    return m_eventsUrl;
}

void TailsTalkClient::setEventsUrl(const QUrl &url)
{
    m_eventsUrl = url;
}

bool TailsTalkClient::isAuthenticated() const
{
    return !m_token.isEmpty() && !m_userId.isEmpty();
}

bool TailsTalkClient::isConnected() const
{
    return m_events.state() == QAbstractSocket::ConnectedState;
}

QString TailsTalkClient::userId() const
{
    return m_userId;
}

QString TailsTalkClient::sessionToken() const
{
    return m_token;
}

QVariantList TailsTalkClient::servers() const
{
    return m_servers;
}

QVariantList TailsTalkClient::channels() const
{
    return m_channels;
}

QVariantList TailsTalkClient::users() const
{
    return m_users;
}

QNetworkRequest TailsTalkClient::request(const QString &path) const
{
    // QUrl::resolved() treats a leading slash as an absolute path and would
    // silently drop the configured /api prefix.
    auto url = m_apiUrl;
    auto basePath = url.path();
    if (!basePath.endsWith(QLatin1Char('/'))) {
        basePath += QLatin1Char('/');
    }
    const QUrl relativeUrl(path);
    auto relativePath = relativeUrl.path();
    while (relativePath.startsWith(QLatin1Char('/'))) {
        relativePath.remove(0, 1);
    }
    url.setPath(basePath + relativePath);
    url.setQuery(relativeUrl.query(QUrl::FullyEncoded));
    QNetworkRequest result(url);
    result.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    result.setRawHeader("accept", "application/json");
    if (!m_token.isEmpty()) {
        result.setRawHeader("x-session-token", m_token.toUtf8());
    }
    return result;
}

void TailsTalkClient::login(const QString &email, const QString &password, const QString &friendlyName)
{
    stopReconnect();
    m_shouldReconnect = true;
    QJsonObject payload{{QStringLiteral("email"), email}, {QStringLiteral("password"), password}, {QStringLiteral("friendly_name"), friendlyName}};
    auto *reply = m_network.post(request(QStringLiteral("/auth/session/login")), QJsonDocument(payload).toJson(QJsonDocument::Compact));
    handleReply(reply, QStringLiteral("login"), [this](const QJsonValue &value) {
        const auto result = value.toObject();
        const auto token = result.value(QStringLiteral("token")).toString();
        const auto id = result.value(QStringLiteral("user_id")).toString();
        if (token.isEmpty() || id.isEmpty()) {
            Q_EMIT loginFailed(QStringLiteral("TailsTalk returned an invalid session"));
            return;
        }
        m_token = token;
        m_userId = id;
        Q_EMIT authenticatedChanged();
        auto *userReply = m_network.get(request(QStringLiteral("/users/%1").arg(id)));
        handleReply(userReply, QStringLiteral("user profile"), [this](const QJsonValue &userValue) {
            Q_EMIT loginSucceeded(m_userId, userValue.toObject());
            connectEvents();
            discover();
        });
    });
}

void TailsTalkClient::discover()
{
    if (!isAuthenticated()) {
        Q_EMIT discoveryFailed(QStringLiteral("Not authenticated"));
        return;
    }
    connectEvents();
}

void TailsTalkClient::fetchMessages(const QString &channelId)
{
    if (!isAuthenticated()) {
        Q_EMIT requestFailed(QStringLiteral("fetch messages"), 401, QStringLiteral("Not authenticated"));
        return;
    }
    auto url = QUrl(QStringLiteral("/channels/%1/messages").arg(channelId));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("limit"), QStringLiteral("50"));
    url.setQuery(query);
    auto *reply = m_network.get(request(url.toString()));
    handleReply(reply, QStringLiteral("fetch messages"), [this](const QJsonValue &value) {
        Q_EMIT messagesFetched(value.toArray().toVariantList());
    });
}

void TailsTalkClient::connectEvents()
{
    if (!m_shouldReconnect || !isAuthenticated()) {
        return;
    }
    if (m_events.state() == QAbstractSocket::ConnectedState || m_events.state() == QAbstractSocket::ConnectingState) {
        return;
    }
    QUrl url(m_eventsUrl);
    QUrlQuery query(url);
    query.addQueryItem(QStringLiteral("version"), QStringLiteral("1"));
    query.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
    query.addQueryItem(QStringLiteral("token"), m_token);
    url.setQuery(query);
    m_events.open(url);
}

void TailsTalkClient::scheduleReconnect()
{
    if (!m_shouldReconnect || !isAuthenticated() || m_reconnectTimer.isActive()) {
        return;
    }
    m_reconnectTimer.start(m_reconnectDelayMs);
    m_reconnectDelayMs = std::min(m_reconnectDelayMs * 2, 30000);
}

void TailsTalkClient::stopReconnect()
{
    m_reconnectTimer.stop();
    m_reconnectDelayMs = 1000;
}

void TailsTalkClient::sendHeartbeat()
{
    if (!isConnected()) {
        return;
    }
    const auto timestamp = QDateTime::currentMSecsSinceEpoch();
    QJsonObject ping{{QStringLiteral("type"), QStringLiteral("Ping")}, {QStringLiteral("data"), timestamp}};
    m_events.sendTextMessage(QString::fromUtf8(QJsonDocument(ping).toJson(QJsonDocument::Compact)));
    m_pongTimer.start();
}

void TailsTalkClient::sendMessage(const QString &channelId, const QString &content)
{
    if (!isAuthenticated()) {
        Q_EMIT requestFailed(QStringLiteral("send message"), 401, QStringLiteral("Not authenticated"));
        return;
    }
    QJsonObject payload{{QStringLiteral("content"), content}};
    auto *reply = m_network.post(request(QStringLiteral("/channels/%1/messages").arg(channelId)), QJsonDocument(payload).toJson(QJsonDocument::Compact));
    handleReply(reply, QStringLiteral("send message"), [this](const QJsonValue &value) {
        Q_EMIT messageSent(value.toObject());
    });
}

void TailsTalkClient::clearSession()
{
    m_shouldReconnect = false;
    stopReconnect();
    m_events.close();
    m_token.clear();
    m_userId.clear();
    m_servers.clear();
    m_channels.clear();
    m_users.clear();
    Q_EMIT authenticatedChanged();
    Q_EMIT connectionStateChanged();
    Q_EMIT discoveryChanged();
}

void TailsTalkClient::handleReply(QNetworkReply *reply, const QString &operation, std::function<void(const QJsonValue &)> success)
{
    connect(reply, &QNetworkReply::finished, this, [this, reply, operation, success = std::move(success)] {
        const auto status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto document = QJsonDocument::fromJson(reply->readAll());
        const auto value = document.isObject() ? QJsonValue(document.object()) : QJsonValue(document.array());
        if (reply->error() != QNetworkReply::NoError || status < 200 || status >= 300) {
            const auto message = value.toObject().value(QStringLiteral("error")).toString(reply->errorString());
            Q_EMIT requestFailed(operation, status, message);
            if (operation == QStringLiteral("login")) {
                Q_EMIT loginFailed(message);
            }
        } else {
            success(value);
        }
        reply->deleteLater();
    });
}
