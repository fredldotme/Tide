#include "gitclient.h"

#include <QDebug>
#include <QDir>
#include <QStandardPaths>

GitClient::GitClient(QObject *parent)
    : QObject{parent}
{
    QObject::connect(&m_runThread, &QThread::started, this, &GitClient::run, Qt::DirectConnection);
}

GitClient::~GitClient()
{
}

void GitClient::run()
{
    git_libgit2_init();
    m_func();

    m_busy = false;
    emit busyChanged();
    git_libgit2_shutdown();
}

void GitClient::clone(const QString& url, const QString& name)
{
    if (m_busy)
        return;

    const auto func = [=]() {
        const auto projectDirPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                                    QStringLiteral("/Projects/%1").arg(name);

        if (QDir(projectDirPath).exists()) {
            emit this->repoExists(projectDirPath);
            return;
        }

        emit this->repoCloneStarted(url, name);

        git_repository* cloned_repo = nullptr;
        int error = 0;

        git_clone_options clone_opts = GIT_CLONE_OPTIONS_INIT;
        git_checkout_options checkout_opts = GIT_CHECKOUT_OPTIONS_INIT;

        checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE;
        clone_opts.checkout_opts = checkout_opts;

        error = git_clone(&cloned_repo, url.toStdString().c_str(), projectDirPath.toStdString().c_str(), &clone_opts);

        if (error != 0) {
            const git_error *err = git_error_last();
            if (err) {
                const auto msg = QString::fromLocal8Bit(err->message, strlen(err->message));
                emit this->error(msg);
            } else {
                emit this->error("ERROR: no detailed info\n");
            }
        } else if (cloned_repo) {
            git_repository_free(cloned_repo);
            emit this->repoCloned(url, name);
        }
    };

    m_busy = true;
    emit busyChanged();

    m_func = func;
    m_runThread.start();
}
