#include <QGuiApplication>
#include <QFontDatabase>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>

#include "externalprojectpicker.h"
#include "linenumbershelper.h"
#include "syntaxhighlighter.h"
#include "iossystemglue.h"
#include "fileio.h"
#include "bookmarkdb.h"
#include "console.h"
#include "openfilesmanager.h"
#include "sysrootmanager.h"
#include "wasmrunner.h"
#include "imfixerinstaller.h"
#include "projectbuilder.h"
#include "autocompleter.h"
#include "projectcreator.h"
#include "projectlist.h"
#include "iosintegrationdelegate.h""

int main(int argc, char *argv[])
{
    const QString sysroot = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library/usr/lib/clang/14.0.0");
    qputenv("SYSROOT", sysroot.toUtf8().data());
    qputenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasi");

    QQuickStyle::setStyle("iOS");
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    qmlRegisterType<ExternalProjectPicker>("Tide", 1, 0, "ExternalProjectPicker");
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

    qmlRegisterUncreatableType<IosSystemGlue>("Tide", 1, 0, "IosSystemGlue", "Created in main() as 'iosSystem'.");
    qmlRegisterUncreatableType<ImFixerInstaller>("Tide", 1, 0, "ImFixerInstaller", "Instantiated in main() as 'imFixer'.");
    qmlRegisterUncreatableType<ProgramSpec>("Tide", 1, 0, "ProgramSpec", "ProgramSpec is protocol between 'iosSystem' and 'Console'.");
    qmlRegisterUncreatableType<QSourceHighliter>("Tide", 1, 0, "SourceHighliter", "Use 'SyntaxHighlighter' instead.");
    qmlRegisterUncreatableType<IosIntegrationDelegate>("Tide", 1, 0, "IosKeyboardReactorDelegate", "Created in main() as 'oskReactor'.");

    IosSystemGlue iosSystemGlue;
    ImFixerInstaller imFixer;
    IosIntegrationDelegate oskReactor;

    QFont standardFixedFont = QFontDatabase::systemFont(QFontDatabase::FixedFont);
    standardFixedFont.setPixelSize(15);
    standardFixedFont.setStyleHint(QFont::Monospace);

    engine.rootContext()->setContextProperty("standardFixedFont", standardFixedFont);
    engine.rootContext()->setContextProperty("imFixer", &imFixer);
    engine.rootContext()->setContextProperty("sysroot", sysroot);
    engine.rootContext()->setContextProperty("iosSystem", &iosSystemGlue);
    engine.rootContext()->setContextProperty("oskReactor", &oskReactor);

    const QUrl url(u"qrc:/Tide/Main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
