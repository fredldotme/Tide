#include <QGuiApplication>
#include <QFontDatabase>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>

#include "linenumbershelper.h"
#include "syntaxhighlighter.h"
#include "platform/systemglue.h"
#include "fileio.h"
#include "bookmarkdb.h"
#include "console.h"
#include "openfilesmanager.h"
#include "sysrootmanager.h"
#include "wasmrunner.h"
#include "projectbuilder.h"
#include "autocompleter.h"
#include "projectcreator.h"

#include "platform/systemglue.h"

int main(int argc, char *argv[])
{
#ifdef Q_OS_IOS
    const QString sysroot = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library/usr/lib/clang/14.0.0");
    qputenv("SYSROOT", sysroot.toUtf8().data());
    qputenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasi");
    QQuickStyle::setStyle("iOS");
#elif defined(Q_OS_LINUX)
    const QString sysroot = QStringLiteral("/usr");
#endif

    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    qmlRegisterType<ProjectPicker>("Tide", 1, 0, "ExternalProjectPicker");
    qmlRegisterType<LineNumbersHelper>("Tide", 1, 0, "LineNumbersHelper");
    qmlRegisterType<SyntaxHighlighter>("Tide", 1, 0, "SyntaxHighlighter");
    qmlRegisterType<FileIo>("Tide", 1, 0, "FileIo");
    qmlRegisterType<BookmarkDb>("Tide", 1, 0, "BookmarkDb");
    qmlRegisterType<Console>("Tide", 1, 0, "Console");
    qmlRegisterType<OpenFilesManager>("Tide", 1, 0, "OpenFilesManager");
    qmlRegisterType<SysrootManager>("Tide", 1, 0, "SysrootManager");
    qmlRegisterType<WasmRunner>("Tide", 1, 0, "WasmRunner");
    qmlRegisterType<DirectoryListing>("Tide", 1, 0, "DirectoryListing");
    qmlRegisterType<ProjectBuilder>("Tide", 1, 0, "ProjectBuilder");
    qmlRegisterType<AutoCompleter>("Tide", 1, 0, "AutoCompleter");
    qmlRegisterType<ProjectCreator>("Tide", 1, 0, "ProjectCreator");
    qmlRegisterType<ProjectList>("Tide", 1, 0, "ProjectList");

    qmlRegisterUncreatableType<SystemGlue>("Tide", 1, 0, "IosSystemGlue", "Created in main() as 'iosSystem'.");
    qmlRegisterUncreatableType<StdioSpec>("Tide", 1, 0, "ProgramSpec", "StdioSpec is protocol between 'iosSystem' and 'Console'.");
    qmlRegisterUncreatableType<QSourceHighliter>("Tide", 1, 0, "SourceHighliter", "Use 'SyntaxHighlighter' instead.");
    qmlRegisterUncreatableType<InputMethodFixerInstaller>("Tide", 1, 0, "ImFixerInstaller", "Instantiated in main() as 'imFixer'.");
    qmlRegisterUncreatableType<PlatformIntegrationDelegate>("Tide", 1, 0, "IosKeyboardReactorDelegate", "Created in main() as 'oskReactor'.");

    int ret;
    {
        SystemGlue iosSystemGlue;
        InputMethodFixerInstaller imFixer;
        PlatformIntegrationDelegate oskReactor;

        QFont standardFixedFont = QFontDatabase::systemFont(QFontDatabase::FixedFont);
        standardFixedFont.setPixelSize(15);
        standardFixedFont.setStyleHint(QFont::Monospace);

        engine.rootContext()->setContextProperty("standardFixedFont", standardFixedFont);
        engine.rootContext()->setContextProperty("imFixer", &imFixer);
#ifdef Q_OS_IOS
        engine.rootContext()->setContextProperty("sysroot", sysroot);
#endif
        engine.rootContext()->setContextProperty("oskReactor", &oskReactor);
        engine.rootContext()->setContextProperty("iosSystem", &iosSystemGlue);

        const QUrl url(u"qrc:/Tide/qml/Main.qml"_qs);
#ifdef Q_OS_IOS
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
            &app, []() { QCoreApplication::exit(-1); },
            Qt::QueuedConnection);
#endif
        engine.load(url);

        ret = app.exec();
    }
    return ret;
}
