// SPDX-FileCopyrightText: 2026 TailsTalk 2 for Linux contributors
// SPDX-License-Identifier: GPL-3.0-only

#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QObject>
#include <QUrl>
#include <QWebSocket>

#include <functional>

class QNetworkReply;

/**
 * Native TailsTalk 2 transport.
 *
 * This deliberately owns only the protocol/session layer.  It never stores a
 * password; callers provide it only to login(), and the returned session token
 * is kept in memory until clearSession() is called.
 */
class TailsTalkClient final : public QObject
{
    Q_OBJECT

public:
    explicit TailsTalkClient(QObject *parent = nullptr);

    QUrl apiUrl() const;
    void setApiUrl(const QUrl &url);

    QUrl eventsUrl() const;
    void setEventsUrl(const QUrl &url);

    bool isAuthenticated() const;
    QString userId() const;
    QString sessionToken() const;

    Q_INVOKABLE void login(const QString &email, const QString &password, const QString &friendlyName = QStringLiteral("TailsTalk 2 for Linux"));
    Q_INVOKABLE void discover();
    Q_INVOKABLE void sendMessage(const QString &channelId, const QString &content);
    Q_INVOKABLE void clearSession();

Q_SIGNALS:
    void loginSucceeded(const QString &userId, const QJsonObject &user);
    void loginFailed(const QString &message);
    void discoverySucceeded(const QJsonArray &servers, const QJsonArray &channels, const QJsonArray &users);
    void discoveryFailed(const QString &message);
    void messageReceived(const QJsonObject &message);
    void messageSent(const QJsonObject &message);
    void requestFailed(const QString &operation, int status, const QString &message);
    void authenticatedChanged();

private:
    QNetworkRequest request(const QString &path) const;
    void connectEvents();
    void handleReply(QNetworkReply *reply, const QString &operation, std::function<void(const QJsonValue &)> success);

    QNetworkAccessManager m_network;
    QWebSocket m_events;
    QUrl m_apiUrl = QUrl(QStringLiteral("https://tails1154.com:9961/api"));
    QUrl m_eventsUrl = QUrl(QStringLiteral("wss://tails1154.com:9961/events"));
    QString m_userId;
    QString m_token;
};
