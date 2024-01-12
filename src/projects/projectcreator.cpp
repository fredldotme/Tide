#include "projectcreator.h"

#include <QStandardPaths>
#include <QDir>
#include <QFile>

static const auto PROJECT_TEMPLATE_APP =
    QStringLiteral("TARGET = %1\n") +
    QStringLiteral("TEMPLATE = app\n\n") +
    QStringLiteral("#INCLUDEPATH += $$PWD/lib\n") +
    QStringLiteral("# Uncomment to enable threads:\n") +
    QStringLiteral("#CONFIG += threads\n") +
    QStringLiteral("SOURCES += \\\n    $$PWD/main.cpp");

static const auto PROJECT_TEMPLATE_LIB =
    QStringLiteral("TARGET = %1\n") +
    QStringLiteral("TEMPLATE = lib\n\n") +
    QStringLiteral("# Uncomment to enable threads:\n") +
    QStringLiteral("#CONFIG += threads\n") +
    QStringLiteral("SOURCES += \\\n    $$PWD/lib.cpp");

static const auto PROJECT_TEMPLATE_TIDEPLUGIN =
    QStringLiteral("TARGET = %1\n") +
    QStringLiteral("TEMPLATE = lib\n\n") +
    QStringLiteral("#INCLUDEPATH += $$PWD/lib\n") +
    QStringLiteral("# Uncomment to enable threads:\n") +
    QStringLiteral("#CONFIG += threads\n") +
    QStringLiteral("SOURCES += \\\n    $$PWD/main.cpp");

static const auto MAIN_TEMPLATE_APP =
    QStringLiteral("#include <stdio.h>\n\n") +
    QStringLiteral("int main(int argc, char *argv[]) {\n") +
    QStringLiteral("   printf(\"Hello World!\\n\");\n") +
    QStringLiteral("   return 0;\n") +
    QStringLiteral("}\n");

static const auto MAIN_TEMPLATE_LIB =
    QStringLiteral("#include \"lib.h\"\n\n") +
    QStringLiteral("int add(int a, int b) {\n") +
    QStringLiteral("   return a + b;\n") +
    QStringLiteral("}\n");

static const auto HEADER_TEMPLATE_LIB =
    QStringLiteral("#ifndef LIB_H\n") +
    QStringLiteral("#define LIB_H\n\n") +
    QStringLiteral("int add(int a, int b);\n\n") +
    QStringLiteral("#endif\n");

static const auto MAIN_TEMPLATE_TIDEPLUGIN =
    QStringLiteral("#include <stdio.h>\n\n") +
    QStringLiteral("int main(int argc, char *argv[]) {\n") +
    QStringLiteral("   printf(\"Hello World!\\n\");\n") +
    QStringLiteral("   return 0;\n") +
    QStringLiteral("}\n");

#define SUPPORTS_TIDE_PLUGINS 0

ProjectCreator::ProjectCreator(QObject *parent)
    : QObject{parent}
{

}

bool ProjectCreator::projectExists(const QString targetName)
{
    const auto projectDirPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                                QStringLiteral("/Projects/%1").arg(targetName);
    QDir projectDir(projectDirPath);
    return projectDir.exists();
}

void ProjectCreator::createProject(const QString targetName, const ProjectType projectType)
{
    if (projectExists(targetName))
        return;

    const auto implName = projectType == ProjectType::Application ?
                              QStringLiteral("main.cpp") : QStringLiteral("lib.cpp");
    const auto projectDirPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                                QStringLiteral("/Projects/%1").arg(targetName);
    QDir projectDir(projectDirPath);

    if (!projectDir.mkpath(projectDirPath)) {
        qWarning() << "Failed to create directory" << projectDirPath;
        return;
    }

    {
        const auto projectFilePath = projectDirPath + QDir::separator() + targetName + ".pro";
        QFile projectFile(projectFilePath);
        if (!projectFile.open(QFile::Text | QFile::WriteOnly)) {
            qWarning() << "Failed to create" << projectFilePath;
            return;
        }

        QString projectTemplate = PROJECT_TEMPLATE_APP;
        if (projectType == ProjectType::Library) {
            projectTemplate = PROJECT_TEMPLATE_LIB;
        } else if (projectType == ProjectType::TidePlugin) {
            projectTemplate = PROJECT_TEMPLATE_TIDEPLUGIN;
        }

        projectFile.write(projectTemplate.arg(targetName).toUtf8());
    }

    {
        const auto mainFilePath = projectDirPath + QDir::separator() + implName;
        QFile mainFile(mainFilePath);
        if (!mainFile.open(QFile::Text | QFile::WriteOnly)) {
            qWarning() << "Failed to create" << mainFilePath;
            return;
        }

        QString mainTemplate = MAIN_TEMPLATE_APP;
        if (projectType == ProjectType::Library) {
            mainTemplate = MAIN_TEMPLATE_LIB;
        } else if (projectType == ProjectType::TidePlugin) {
            mainTemplate = MAIN_TEMPLATE_TIDEPLUGIN;
        }

        mainFile.write(mainTemplate.toUtf8());
    }

    if (projectType == ProjectType::Library) {
        const auto libHeaderFilePath = projectDirPath + QDir::separator() + "lib.h";
        QFile mainFile(libHeaderFilePath);
        if (!mainFile.open(QFile::Text | QFile::WriteOnly)) {
            qWarning() << "Failed to create" << libHeaderFilePath;
            return;
        }

        QString headerTemplate = HEADER_TEMPLATE_LIB;

#if SUPPORTS_TIDE_PLUGINS
        if (projectType == ProjectType::TidePlugin) {
            headerTemplate = MAIN_TEMPLATE_TIDEPLUGIN;
        }
#endif
        mainFile.write(headerTemplate.toUtf8());
    }

    emit projectCreated();
}
