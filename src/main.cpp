#include <QApplication>
#include <QFontDatabase>
#include <QFont>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStyleHints>
#include <QStandardPaths>

#include "linenumbershelper.h"
#include "syntaxhighlighter.h"
#include "platform/systemglue.h"
#include "fileio.h"
#include "bookmarkdb.h"
#include "console.h"
#include "openfilesmanager.h"
#include "sysrootmanager.h"
#include "runners/pyrunner.h"
#include "runners/wasmrunner.h"
#include "projectbuilder.h"
#include "autocompleter.h"
#include "projectcreator.h"
#include "cppformatter.h"
#include "searchandreplace.h"
#include "debugger.h"
#include "gitclient.h"

#include "platform/systemglue.h"

#include <signal.h>

int main(int argc, char *argv[])
{
#if defined(Q_OS_IOS)
    const QString sysroot = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library/wasi-sysroot");

    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                            QStringLiteral("/Runtimes/Linux");

    qputenv("SYSROOT", sysroot.toUtf8().data());
    QQuickStyle::setStyle("iOS");

    // Setup static initialization of LLVM tools
    {
        ClangCompiler setup;
    }
#elif defined(Q_OS_MACOS)
    const QString sysroot = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library/wasi-sysroot");

    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                            QStringLiteral("/Runtimes/Linux");

    qputenv("SYSROOT", sysroot.toUtf8().data());
    QQuickStyle::setStyle("iOS");

    qputenv("CLANG_RESOURCE_DIR", "/Users/alfredneumayer/Library/usr/lib/clang/17");
#elif defined(Q_OS_LINUX)
    const QString sysroot = QStringLiteral("/usr");
    QQuickStyle::setStyle("Material");
#endif
    //qputenv("LIBCLANG_DISABLE_CRASH_RECOVERY", "1");
    //qputenv("LLVM_DISABLE_CRASH_REPORT", "1");
    qputenv("NOSYSTEM_DEBUG", "1");

    QApplication app(argc, argv);
    app.setAutoSipEnabled(true);
    app.setOrganizationDomain("fredl.me");
    app.setApplicationName("Tide");

    // Set up PATH for macOS here
#if defined(Q_OS_MACOS)
    {
        const auto path = qgetenv("PATH");
        const auto mybins = qApp->applicationDirPath();
        const auto newpath = mybins + ":" + path;
        qputenv("PATH", newpath.toLocal8Bit());
    }
#endif

    auto styleHints = app.styleHints();
    styleHints->setUseHoverEffects(true);

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
    qmlRegisterType<PyRunner>("Tide", 1, 0, "PyRunner");
    qmlRegisterType<DirectoryListing>("Tide", 1, 0, "DirectoryListing");
    qmlRegisterType<ProjectBuilder>("Tide", 1, 0, "ProjectBuilder");
    qmlRegisterType<AutoCompleter>("Tide", 1, 0, "AutoCompleter");
    qmlRegisterType<ProjectCreator>("Tide", 1, 0, "ProjectCreator");
    qmlRegisterType<ProjectList>("Tide", 1, 0, "ProjectList");
    qmlRegisterType<CppFormatter>("Tide", 1, 0, "CppFormatter");
    qmlRegisterType<SearchAndReplace>("Tide", 1, 0, "SearchAndReplace");
    qmlRegisterType<Debugger>("Tide", 1, 0, "Debugger");
    qmlRegisterType<GitClient>("Tide", 1, 0, "GitClient");
    qmlRegisterType<PlatformIntegrationDelegate>("Tide", 1, 0, "PlatformIntegrationDelegate");

    qmlRegisterUncreatableType<SystemGlue>("Tide", 1, 0, "IosSystemGlue", "Created in main() as 'iosSystem'.");
    qmlRegisterUncreatableType<StdioSpec>("Tide", 1, 0, "ProgramSpec", "StdioSpec is protocol between 'iosSystem' and 'Console'.");
    qmlRegisterUncreatableType<QSourceHighliter>("Tide", 1, 0, "SourceHighliter", "Use 'SyntaxHighlighter' instead.");
    qmlRegisterUncreatableType<InputMethodFixerInstaller>("Tide", 1, 0, "ImFixerInstaller", "Instantiated in main() as 'imFixer'.");
    qmlRegisterUncreatableType<SearchResult>("Tide", 1, 0, "SearchResult", "Created 'searchAndReplace'.");

    int ret;
    {
        SystemGlue iosSystemGlue;
        InputMethodFixerInstaller imFixer;

        QFont standardFixedFont = QFontDatabase::systemFont(QFontDatabase::FixedFont);
        standardFixedFont.setPixelSize(14);
        standardFixedFont.setStyleHint(QFont::Monospace);

        engine.rootContext()->setContextProperty("standardFixedFont", standardFixedFont);
        engine.rootContext()->setContextProperty("imFixer", &imFixer);
        engine.rootContext()->setContextProperty("sysroot", sysroot);
        engine.rootContext()->setContextProperty("iosSystem", &iosSystemGlue);
        engine.rootContext()->setContextProperty("runtime", runtime);

        const QUrl url(u"qrc:/Tide/qml/Main.qml"_qs);
#ifdef Q_OS_IOS
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
            &app, []() { QCoreApplication::exit(-1); },
            Qt::QueuedConnection);
#endif
        engine.load(url);

        signal(SIGPIPE, SIG_IGN);
        ret = app.exec();
    }
    return ret;
}
