#include "historymodel.h"
#include <QStandardPaths>
#include <QImage>
#include <QDebug>
#include <QUuid>
#include <QFile>
#include <QDateTime>

HistoryModel::HistoryModel(QObject *parent):
    QAbstractListModel(parent),
    QQuickImageProvider(QQuickImageProvider::Image),
    m_cacheLocation(QStandardPaths::standardLocations(QStandardPaths::HomeLocation).first() + "/.cache/ubcards.belohoub/"),
    m_settings(m_cacheLocation + "wallet.ini", QSettings::IniFormat)
{
    qDebug() << "History saved in" << m_settings.fileName();
}

int HistoryModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_settings.value("all").toStringList().count();
}

QVariant HistoryModel::data(const QModelIndex &index, int role) const
{
    QVariant ret;
    QString id = m_settings.value("all").toStringList().at(index.row());
    m_settings.beginGroup(id);
    switch (role) {
    case RoleText:
        ret = m_settings.value("text");
        break;
    case RoleType:
        ret = m_settings.value("type");
        break;
    case RoleName:
        ret = m_settings.value("name");
        break;
    case RoleIssuer:
        ret = m_settings.value("issuer");
        break;
    case RoleImageSource:
        ret = "image://history/" + id;
        break;
    case RoleTimestamp:
        ret = m_settings.value("timestamp").toDateTime().toString();
        break;
    }

    m_settings.endGroup();
    return ret;
}

QHash<int, QByteArray> HistoryModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles.insert(RoleText, "text");
    roles.insert(RoleType, "type");
    roles.insert(RoleName, "name");
    roles.insert(RoleIssuer, "issuer");
    roles.insert(RoleImageSource, "imageSource");
    roles.insert(RoleTimestamp, "timestamp");
    return roles;
}

void HistoryModel::add(const QString &text, const QString &type, const QString &name, const QString &issuer, const QImage &image)
{
    QString id = QUuid::createUuid().toString().remove(QRegExp("[{}]"));
    image.save(m_cacheLocation + id + ".jpg");

    beginInsertRows(QModelIndex(), 0, 0);

    QStringList all = m_settings.value("all").toStringList();
    all.prepend(id);
    m_settings.setValue("all", all);

    m_settings.beginGroup(id);
    m_settings.setValue("name", name);
    m_settings.setValue("issuer", issuer);
    m_settings.setValue("text", text);
    m_settings.setValue("type", type);
    m_settings.setValue("timestamp", QDateTime::currentDateTime());
    m_settings.endGroup();
    endInsertRows();
}

void HistoryModel::remove(int index)
{
    beginRemoveRows(QModelIndex(), index, index);
    QString id = m_settings.value("all").toStringList().at(index);
    QStringList all = m_settings.value("all").toStringList();
    all.removeAt(index);
    m_settings.setValue("all", all);
    m_settings.remove(id);
    QFile f(m_cacheLocation + id + ".jpg");
    f.remove();
    endRemoveRows();
}

QImage HistoryModel::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QImage image(m_cacheLocation + id + ".jpg");
    if (requestedSize.isValid()) {
        image = image.scaled(requestedSize);
        size->setWidth(requestedSize.width());
        size->setHeight(requestedSize.height());
    }
    return image;
}
