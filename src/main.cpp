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

int main(int argc, char *argv[])
{
    const QString sysroot = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library/usr/lib/clang/14.0.0");
    qputenv("SYSROOT", sysroot.toUtf8().data());
    qputenv("CCC_OVERRIDE_OPTIONS", "#^--target=wasm32-wasi");

    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("iOS");

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

    qmlRegisterUncreatableType<IosSystemGlue>("Tide", 1, 0, "IosSystemGlue", "Created in main() as 'iosSystem'.");
    qmlRegisterUncreatableType<ImFixerInstaller>("Tide", 1, 0, "ImFixerInstaller", "Instantiated in main() as 'imFixer'.");
    qmlRegisterUncreatableType<ProgramSpec>("Tide", 1, 0, "ProgramSpec", "ProgramSpec is protocol between 'iosSystem' and 'Console'.");
    qmlRegisterUncreatableType<QSourceHighliter>("Tide", 1, 0, "SourceHighliter", "Use 'SyntaxHighlighter' instead.");

    IosSystemGlue iosSystemGlue;
    ImFixerInstaller imFixer;

    QFont fixedFont = QFontDatabase::systemFont(QFontDatabase::FixedFont);
    fixedFont.setPixelSize(16);

    engine.rootContext()->setContextProperty("fixedFont", fixedFont);
    engine.rootContext()->setContextProperty("imFixer", &imFixer);
    engine.rootContext()->setContextProperty("sysroot", sysroot);
    engine.rootContext()->setContextProperty("iosSystem", &iosSystemGlue);

    const QUrl url(u"qrc:/Tide/Main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
