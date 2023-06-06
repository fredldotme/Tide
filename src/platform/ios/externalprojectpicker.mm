#include "externalprojectpicker.h"

#import <MobileCoreServices/MobileCoreServices.h>

#include <QDir>
#include <QDirIterator>
#include <QGuiApplication>
#include <QWindow>
#include <QDebug>

#include "raiiexec.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DocumentPickerDelegate : NSObject<UINavigationControllerDelegate, UIDocumentPickerDelegate>
{
    ExternalProjectPicker *m_DocumentPicker;
}
@end

@implementation DocumentPickerDelegate

- (id) initWithObject:(ExternalProjectPicker *)documentPicker
{
    self = [super init];
    if (self) {
        m_DocumentPicker = documentPicker;
    }
    return self;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    qWarning() << "DERE:" << controller.documentPickerMode;
    if (controller.documentPickerMode == UIDocumentPickerModeOpen)
    {
        for (NSURL* obj in urls)
        {
            BOOL isAccess = [obj startAccessingSecurityScopedResource];
            if (!isAccess) {
                qWarning() << "Failed to access security-scoped resource";
                continue;
            }

            NSError *error = nil;
            NSData *bookmarkData = [obj bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
            if (error) {
                qWarning() << "Getting bookmark data failed:" << error;
                [obj stopAccessingSecurityScopedResource];
                continue;
            }

            QByteArray qBookmarkData = QByteArray::fromNSData(bookmarkData);
            Q_EMIT self->m_DocumentPicker->documentSelected(qBookmarkData);
            [obj stopAccessingSecurityScopedResource];
        }
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    qWarning() << "Project import cancelled";
}

@end

static DocumentPickerDelegate* pickerDelegate = nil;
static NSArray *utis = @[(NSString *)kUTTypeFolder];

ExternalProjectPicker::ExternalProjectPicker(QObject *parent) : QObject(parent)
{
    if (pickerDelegate)
        return;

    pickerDelegate = [[DocumentPickerDelegate alloc] initWithObject:this];
}

ExternalProjectPicker::~ExternalProjectPicker()
{
    if (pickerDelegate == nil)
        return;

    [pickerDelegate dealloc];
    pickerDelegate = nil;
}

void ExternalProjectPicker::startImport()
{
    UIView *view = reinterpret_cast<UIView*>(QGuiApplication::focusWindow()->winId());
    UIViewController *qtController = [[view window] rootViewController];

    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc]
        initWithDocumentTypes:utis inMode:UIDocumentPickerModeOpen];

    documentPicker.delegate = pickerDelegate;
    [qtController presentViewController:documentPicker animated:YES completion:nil];
}

// Open a file using the given sandbox data
QString ExternalProjectPicker::openBookmark(const QByteArray encodedData)
{
    NSData* bookmarkData = encodedData.toNSData();
    NSError* error = 0;
    BOOL stale = false;

    NSURL* url = [NSURL URLByResolvingBookmarkData:bookmarkData options:0 relativeToURL:nil bookmarkDataIsStale:&stale error:&error];
    if (!error && url)
    {
        [url startAccessingSecurityScopedResource];
        auto ret = QUrl::fromNSURL(url).toLocalFile();
        qDebug() << ret;
        return ret;
    }

    if (stale) {
        emit bookmarkStale(encodedData);
    }

    qWarning() << "Error occured opening file or path:" << error << encodedData;
    return QString();
}

bool ExternalProjectPicker::secureFile(const QString path)
{
    NSURL* url = [NSURL URLWithString:path.toNSString() relativeToURL:nil];
    if (url)
    {
        [url startAccessingSecurityScopedResource];
        auto ret = QUrl::fromNSURL(url).toLocalFile();
        qDebug() << ret;
        return true;
    }

    qWarning() << "Error occured securing external file";
    return false;
}

// Stop sandbox access
void ExternalProjectPicker::closeFile(QUrl url)
{
    NSURL* nsurl = url.toNSURL();
    if (nsurl)
    {
        [nsurl stopAccessingSecurityScopedResource];
        return;
    }

    qWarning() << "Fell through during closing of external file";
    return;
}

QString ExternalProjectPicker::getDirNameForBookmark(const QByteArray encodedData)
{
    const auto path = openBookmark(encodedData);
    if (path.isEmpty()) {
        qWarning() << "Failed to get name: path is empty";
        return QString();
    }

    QStringList parts = path.split(QDir::separator(), Qt::SkipEmptyParts);
    if (parts.isEmpty()) {
        qWarning() << "Failed to get name: path must have been empty";
        closeFile(QUrl(path));
        return QString();
    }

    closeFile(QUrl(path));
    return parts.takeLast();
}

QList<DirectoryListing> ExternalProjectPicker::listBookmarkContents(const QByteArray bookmark)
{
    const auto path = openBookmark(bookmark);
    if (path.isEmpty()) {
        qWarning() << "Failed to open bookmark";
        return QList<DirectoryListing>();
    }

    auto ret = listDirectoryContents(path, bookmark);
    closeFile(path);

    return ret;
}

QList<DirectoryListing> ExternalProjectPicker::listDirectoryContents(const QString path, const QByteArray bookmark)
{
    QList<DirectoryListing> ret;

    QDirIterator it(path, QDir::NoDot | QDir::AllEntries);
    while (it.hasNext()) {
        const auto next = it.next();
        qWarning() << next;

        DirectoryListing::ListingType type;
        QFileInfo info(next);

        if (info.isSymLink()) {
            type = DirectoryListing::Symlink;
        } else if (info.isDir()) {
            type = DirectoryListing::Directory;
        } else {
            type = DirectoryListing::File;
        }

        ret << DirectoryListing(type, next, bookmark);
    }

    return ret;
}
