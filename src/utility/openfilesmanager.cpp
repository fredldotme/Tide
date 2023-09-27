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
        break;
    }

    if (removed)
        emit filesChanged();
}

void OpenFilesManager::closeAllBut(const DirectoryListing listing)
{
    bool removed = false;

    for (auto it = m_files.begin(); it != m_files.end();) {
        if (it->path == listing.path) {
            it++;
            continue;
        }

        emit closingFile(listing);
        it = m_files.erase(it);
        removed = true;
    }

    if (removed) {
        m_files.squeeze();
        emit filesChanged();
    }
}

void OpenFilesManager::closeAllByBookmark(QByteArray bookmark)
{
    std::vector<DirectoryListing> listings;

    for (const auto& file : m_files) {
        if (file.bookmark != bookmark)
            continue;
        listings.push_back(file);
    }

    for (const auto& listing : listings) {
        close(listing);
    }
}

QVariantList OpenFilesManager::files()
{
    QVariantList ret;
    for (const auto& file : m_files) {
        ret << QVariant::fromValue(file);
    }
    return ret;
}

DirectoryListing OpenFilesManager::open(const QString path)
{
    DirectoryListing listing(DirectoryListing::File, path);
    return listing;
}
