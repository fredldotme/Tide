#include "searchandreplace.h"

#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QQmlEngine>

SearchAndReplace::SearchAndReplace(QObject *parent)
    : QObject{parent}
{

}

QVariantList SearchAndReplace::suggestions(const QString find, QString sourceRoot)
{
    QVariantList ret;

    if (sourceRoot.isEmpty() || find.isEmpty())
        return ret;

    {
        QFileInfo sourceRootInfo(sourceRoot);
        if (sourceRootInfo.isFile())
            sourceRoot = sourceRootInfo.absolutePath();
    }

    qDebug() << "Find" << find << "in" << sourceRoot;

    QDirIterator it(sourceRoot, QDir::AllEntries | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const auto path = it.next();
        const auto parts = path.split(QDir::separator(), Qt::SkipEmptyParts);
        const auto name = parts.length() > 0 ? parts.last() : "";
        qDebug() << name;

        int occurances = 0;

        {
            QFile fileToSearch(path);
            if (!fileToSearch.open(QFile::ReadOnly))
                continue;

            const auto buffer = fileToSearch.readAll();

            const static auto findOccurances = [](const QByteArray& buffer, const QString& needle) {
                int occurances = 0;
                const auto buf = buffer.toStdString();
                const auto ndl = needle.toStdString();
                if (needle.length() == 0) return 0;
                for (size_t offset = buf.find(ndl); offset != std::string::npos;
                     offset = buf.find(ndl, offset + ndl.length())) {
                    ++occurances;
                }
                return occurances;
            };
            occurances = findOccurances(buffer, find);
            qDebug() << "Occurances in" << path << ":" << occurances;
        }

        SearchResult* obj = new SearchResult;
        QQmlEngine::setObjectOwnership(obj, QQmlEngine::JavaScriptOwnership);
        obj->path = path;
        obj->name = name;
        obj->from = find;
        obj->occurances = occurances;

        ret << QVariant::fromValue(obj);
    }

    return ret;
}

void SearchAndReplace::replace(const QStringList files, const QString from, const QString to)
{
    for (auto file : files) {
        if (QFileInfo(file).isDir()) {
            QDirIterator it(file, QDir::AllEntries | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
            while (it.hasNext()) {
                const auto nextFile = it.next();
                replace(QStringList{nextFile}, from, to);
            }

            continue;
        }

        qDebug() << "Replacing" << from << "to" << to << "in" << file;

        QByteArray contents;

        {
            QFile fileObj(file);
            if (!fileObj.open(QFile::ReadOnly)) {
                qWarning() << "Failed to open file" << file << "read-only";
                continue;
            }
            contents = fileObj.readAll().replace(from.toUtf8(), to.toUtf8());
        }

        {

            QFile fileObj(file);
            if (!fileObj.open(QFile::ReadWrite | QFile::Truncate)) {
                qWarning() << "Failed to open file" << file << "read-write";
                continue;
            }
            if (fileObj.write(contents) < contents.length()) {
                qWarning() << "Failed to write find-replace result";
                continue;
            }
        }
    }
}
