#include <QApplication>
#include <QFontDatabase>
#include <QFont>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStyleHints>
#include <QStandardPaths>
#include <QLoggingCategory>
#include <QThreadPool>

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
#include "plugins/tidepluginmanager.h"

#include <signal.h>

int main(int argc, char *argv[])
{
    bool useQtVirtualKeyboard = false;

#if defined(Q_OS_IOS)
    const auto orgName = QStringLiteral("fredl.me");
    const auto appName = QStringLiteral("Tide");
    const auto gridUnitPx = 8;
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
    qputenv("NOSYSTEM_DEBUG", "1");

    // lld codepath enablement that causes proper memory cleanups
    //qputenv("LLD_IN_TEST", "1");
#elif defined(Q_OS_MACOS)
    const auto orgName = QStringLiteral("fredl.me");
    const auto appName = QStringLiteral("Tide");
    const auto gridUnitPx = 8;

    const QString sysroot = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library/wasi-sysroot");
    const QString library = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library");
    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                            QStringLiteral("/Runtimes/Linux");

    qputenv("SYSROOT", sysroot.toUtf8().data());

    QQuickStyle::setStyle("iOS");

    qputenv("CLANG_RESOURCE_DIR",
            QStringLiteral("%1/usr/lib/clang/18").arg(library).toStdString().c_str());
#elif defined(Q_OS_LINUX)
    const auto orgName = QStringLiteral("");
    const auto appName = QStringLiteral("tide.fredldotme");
    auto gridUnitPx = 8;

    const QString sysroot = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library/wasi-sysroot");
    const QString library = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library");
    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                            QStringLiteral("/Runtimes/Linux");

    qputenv("QT_QUICK_CONTROLS_STYLE", "Material");
    qputenv("SYSROOT", sysroot.toUtf8().data());
    qputenv("CLANG_RESOURCE_DIR",
            QStringLiteral("%1/usr/lib/clang/18").arg(library).toStdString().c_str());
    qputenv("QT_QPA_FONTDIR", "/snap/tide-ide/current/usr/share/fonts/truetype");

    if (qEnvironmentVariableIsSet("DESKTOP_FILE_HINT")) {
        qputenv("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1");
        const auto grid_unit = qgetenv("GRID_UNIT_PX");
        gridUnitPx = grid_unit.toInt();
        const auto scale = (qreal)gridUnitPx / (qreal) 8;
        qputenv("QT_SCALE_FACTOR", std::to_string(scale).c_str());
    }

    if (qgetenv("QT_IM_MODULE") == QByteArrayLiteral("maliitphablet")) {
        qputenv("QT_IM_MODULE", "maliit");
    } else {
        useQtVirtualKeyboard = true;
        qputenv("QT_IM_MODULE", "qtvirtualkeyboard");
        qputenv("QT_VIRTUALKEYBOARD_DESKTOP_DISABLE", "1");
    }
#elif defined(Q_OS_WASM)
    const auto orgName = QStringLiteral("");
    const auto appName = QStringLiteral("tide.fredldotme");
    const auto gridUnitPx = 8;

    const QString sysroot = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library/wasi-sysroot");
    const QString library = QStandardPaths::writableLocation(QStandardPaths::HomeLocation) +
                            QStringLiteral("/Library");
    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                            QStringLiteral("/Runtimes/Linux");
#endif

    QThreadPool::globalInstance()->setMaxThreadCount(32);
    QApplication app(argc, argv);
    app.setAutoSipEnabled(true);
    app.setOrganizationDomain(orgName);
    app.setApplicationName(appName);

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

    // Two reasons for pluginManager to be here:
    // - Be accessible from outside of QML
    // - Have it outlive the engine and its copied TidePlugin gadgets
    TidePluginManager pluginManager;
    int ret;

    {
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
        qmlRegisterType<TidePluginManager>("Tide", 1, 0, "TidePluginManager");
        
        qmlRegisterUncreatableType<SystemGlue>("Tide", 1, 0, "IosSystemGlue", "Created in main() as 'iosSystem'.");
        qmlRegisterUncreatableType<StdioSpec>("Tide", 1, 0, "ProgramSpec", "StdioSpec is protocol between 'iosSystem' and 'Console'.");
        qmlRegisterUncreatableType<QSourceHighliter>("Tide", 1, 0, "SourceHighliter", "Use 'SyntaxHighlighter' instead.");
        qmlRegisterUncreatableType<InputMethodFixerInstaller>("Tide", 1, 0, "ImFixerInstaller", "Instantiated in main() as 'imFixer'.");
        qmlRegisterUncreatableType<SearchResult>("Tide", 1, 0, "SearchResult", "Created 'searchAndReplace'.");
        qmlRegisterUncreatableType<TidePlugin>("Tide", 1, 0, "TidePlugin", "TidePlugin is created by 'TidePluginManager'");
        
        {
            SystemGlue iosSystemGlue;
            InputMethodFixerInstaller imFixer;

#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
            QFont standardFixedFont = QFontDatabase::systemFont(QFontDatabase::FixedFont);
#else
            QFont standardFixedFont("Ubuntu Mono");
#endif
            standardFixedFont.setPixelSize(14);
            standardFixedFont.setStyleHint(QFont::Monospace);
            engine.addImportPath(":/");
            engine.rootContext()->setContextProperty("useQtVirtualKeyboard", useQtVirtualKeyboard);
            engine.rootContext()->setContextProperty("standardFixedFont", standardFixedFont);
            engine.rootContext()->setContextProperty("imFixer", &imFixer);
            engine.rootContext()->setContextProperty("sysroot", sysroot);
            engine.rootContext()->setContextProperty("iosSystem", &iosSystemGlue);
            engine.rootContext()->setContextProperty("pluginManager", &pluginManager);
            engine.rootContext()->setContextProperty("gridUnitPx", gridUnitPx);
            //engine.rootContext()->setContextProperty("runtime", runtime);
            
            const QUrl url(u"qrc:/Tide/qml/Main.qml"_qs);
#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
            QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                             &app, []() { QCoreApplication::exit(-1); },
                             Qt::QueuedConnection);
#endif
            engine.load(url);
            
            signal(SIGPIPE, SIG_IGN);
#if !defined(Q_OS_IOS) && !defined(Q_OS_WASM)
            setsid();
#endif
            ret = app.exec();
        }
    }
    return ret;
}
