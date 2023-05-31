#include "openfilesmanager.h"

OpenFilesManager::OpenFilesManager(QObject *parent)
    : QObject{parent}
{

}

void OpenFilesManager::push(DirectoryListing listing)
{
    for (const auto& openFileListing : m_files) {
        if (listing.path == openFileListing.path)
            return;
    }

    m_files << listing;
    emit filesChanged();
}

void OpenFilesManager::close(const DirectoryListing listing)
{
    qsizetype index = m_files.size();
    bool removed = false;

    for (auto it = m_files.rbegin(); it != m_files.rend(); it++) {
        --index;
        if (it->path != listing.path)
            continue;

        emit closingFile(listing);
        m_files.removeAt(index);
        removed = true;
    }

    if (removed)
        emit filesChanged();
}

QVariantList OpenFilesManager::files()
{
    QVariantList ret;
    for (const auto& file : m_files) {
        ret << QVariant::fromValue(file);
    }
    return ret;
}
