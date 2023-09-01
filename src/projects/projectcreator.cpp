#include "projectcreator.h"

#include <QStandardPaths>
#include <QDir>
#include <QFile>

static const auto PROJECT_TEMPLATE =
    QStringLiteral("TARGET = %1\n\n") +
    QStringLiteral("#INCLUDEPATH += $$PWD/lib\n") +
    QStringLiteral("# Uncomment to enable threads:\n") +
    QStringLiteral("#CONFIG += threads\n") +
    QStringLiteral("SOURCES += \\\n    $$PWD/main.cpp");

static const auto MAIN_TEMPLATE =
    QStringLiteral("#include <stdio.h>\n\n") +
    QStringLiteral("int main(int argc, char *argv[]) {\n") +
    QStringLiteral("   printf(\"Hello World!\\n\");\n") +
    QStringLiteral("   return 0;\n") +
    QStringLiteral("}\n");

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

void ProjectCreator::createProject(const QString targetName)
{
    if (projectExists(targetName))
        return;

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
        projectFile.write(PROJECT_TEMPLATE.arg(targetName).toUtf8());
    }

    {
        const auto mainFilePath = projectDirPath + QDir::separator() + "main.cpp";
        QFile mainFile(mainFilePath);
        if (!mainFile.open(QFile::Text | QFile::WriteOnly)) {
            qWarning() << "Failed to create" << mainFilePath;
            return;
        }
        mainFile.write(MAIN_TEMPLATE.toUtf8());
    }

    emit projectCreated();
}
