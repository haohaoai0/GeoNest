#include <QtCore/QByteArray>
#include <QtCore/QLibraryInfo>
#include <QtCore/QString>
#include <QtCore/QtGlobal>
#include <QtXml/QDomDocument>

extern "C" const char *GeoNestQt6OhosProbe()
{
    static QByteArray payload;

    QDomDocument doc(QStringLiteral("geonest"));
    QDomElement root = doc.createElement(QStringLiteral("qt6OhosProbe"));
    root.setAttribute(QStringLiteral("qtVersion"), QString::fromLatin1(qVersion()));
    root.setAttribute(QStringLiteral("prefixPath"), QLibraryInfo::path(QLibraryInfo::PrefixPath));
    doc.appendChild(root);

    payload = doc.toString(0).toUtf8();
    return payload.constData();
}
