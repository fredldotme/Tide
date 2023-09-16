#include <QGuiApplication>
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
#include "wasmrunner.h"
#include "projectbuilder.h"
#include "autocompleter.h"
#include "projectcreator.h"
#include "cppformatter.h"
#include "searchandreplace.h"
#include "debugger.h"
#include "clangcompiler.h"

#include "platform/systemglue.h"

#include <signal.h>

int main(int argc, char *argv[])
{
#ifdef Q_OS_IOS
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
#elif defined(Q_OS_LINUX)
    const QString sysroot = QStringLiteral("/usr");
    QQuickStyle::setStyle("Material");
#endif
    //qputenv("LIBCLANG_DISABLE_CRASH_RECOVERY", "1");
    //qputenv("LLVM_DISABLE_CRASH_REPORT", "1");
    //qputenv("NOSYSTEM_DEBUG", "1");

    QGuiApplication app(argc, argv);
    app.setOrganizationDomain("fredl.me");
    app.setApplicationName("Tide");

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
    qmlRegisterType<DirectoryListing>("Tide", 1, 0, "DirectoryListing");
    qmlRegisterType<ProjectBuilder>("Tide", 1, 0, "ProjectBuilder");
    qmlRegisterType<AutoCompleter>("Tide", 1, 0, "AutoCompleter");
    qmlRegisterType<ProjectCreator>("Tide", 1, 0, "ProjectCreator");
    qmlRegisterType<ProjectList>("Tide", 1, 0, "ProjectList");
    qmlRegisterType<CppFormatter>("Tide", 1, 0, "CppFormatter");
    qmlRegisterType<SearchAndReplace>("Tide", 1, 0, "SearchAndReplace");
    qmlRegisterType<Debugger>("Tide", 1, 0, "Debugger");

    qmlRegisterUncreatableType<SystemGlue>("Tide", 1, 0, "IosSystemGlue", "Created in main() as 'iosSystem'.");
    qmlRegisterUncreatableType<StdioSpec>("Tide", 1, 0, "ProgramSpec", "StdioSpec is protocol between 'iosSystem' and 'Console'.");
    qmlRegisterUncreatableType<QSourceHighliter>("Tide", 1, 0, "SourceHighliter", "Use 'SyntaxHighlighter' instead.");
    qmlRegisterUncreatableType<InputMethodFixerInstaller>("Tide", 1, 0, "ImFixerInstaller", "Instantiated in main() as 'imFixer'.");
    qmlRegisterUncreatableType<PlatformIntegrationDelegate>("Tide", 1, 0, "IosKeyboardReactorDelegate", "Created in main() as 'oskReactor'.");
    qmlRegisterUncreatableType<SearchResult>("Tide", 1, 0, "SearchResult", "Created 'searchAndReplace'.");

    int ret;
    {
        SystemGlue iosSystemGlue;
        InputMethodFixerInstaller imFixer;
        PlatformIntegrationDelegate oskReactor;

        QFont standardFixedFont = QFontDatabase::systemFont(QFontDatabase::FixedFont);
        standardFixedFont.setPixelSize(14);
        standardFixedFont.setStyleHint(QFont::Monospace);

        engine.rootContext()->setContextProperty("standardFixedFont", standardFixedFont);
        engine.rootContext()->setContextProperty("imFixer", &imFixer);
        engine.rootContext()->setContextProperty("sysroot", sysroot);
        engine.rootContext()->setContextProperty("oskReactor", &oskReactor);
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
