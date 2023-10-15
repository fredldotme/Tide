#include "gitclient.h"

#include <QDebug>
#include <QDir>
#include <QStandardPaths>
#include <QThreadPool>

GitClient::GitClient(QObject *parent)
    : QObject{parent}, m_repo{nullptr}
{
    QObject::connect(this, &GitClient::repoOpened, this,
        [=](const QString path){
            refreshStatus();
        }, Qt::DirectConnection);
    QObject::connect(this, &GitClient::pathChanged, this,
        [=]() {
            if (m_repo) {
                git_repository_free(m_repo);
                m_repo = nullptr;
            }
            if (m_path.isEmpty())
                return;

            git_repository_open_ext(&m_repo, m_path.toStdString().c_str(), 0, nullptr);
            emit this->repoOpened(m_path);
        }, Qt::DirectConnection);
    git_libgit2_init();
}

GitClient::~GitClient()
{
    if (m_repo) {
        git_repository_free(m_repo);
        m_repo = nullptr;
    }
    git_libgit2_shutdown();
}

void GitClient::refreshStatus()
{
    if (!m_repo)
        return;

    QVariantMap status;

    git_reference *head = NULL;
    int error = git_repository_head(&head, m_repo);

    const char* currentBranch = git_reference_shorthand(head);
    status.insert("currentBranch", QString::fromLocal8Bit(currentBranch));

    QVariantList remotesList;
    git_strarray remotes = {0};
    git_remote *remote = {0};
    git_remote_list(&remotes, m_repo);

    const char *name, *fetch, *push;
    for (int i = 0; i < (int) remotes.count; i++) {
        name = remotes.strings[i];
        git_remote_lookup(&remote, m_repo, name);
        fetch = git_remote_url(remote);
        push = git_remote_pushurl(remote);
        /* use fetch URL if no distinct push URL has been set */
        push = push ? push : fetch;

        QVariantMap entry;
        entry.insert("name", name);
        entry.insert("fetch", fetch);
        entry.insert("push", push);
        remotesList << entry;

        git_remote_free(remote);
    }
    status.insert("remotes", remotesList);

    QStringList branchesList;
    git_branch_iterator* branchiterator = nullptr;
    git_reference* ref = nullptr;
    git_branch_t branch;
    git_branch_iterator_new(&branchiterator, m_repo, GIT_BRANCH_LOCAL);
    while ((error = git_branch_next(&ref, &branch, branchiterator)) == 0) {
        if (ref) {
            const char* buf;
            git_branch_name(&buf, ref);

            if (buf) {
                const auto branchName = QString::fromLocal8Bit(buf);
                branchesList << branchName;
            }
        }
    };
    git_branch_iterator_free(branchiterator);
    status.insert("branches", branchesList);

    m_status = status;
    emit statusChanged();
}

void GitClient::clone(const QString& url, const QString& name)
{
    if (m_busy)
        return;

    const auto projectDirPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                                QStringLiteral("/Projects/%1").arg(name);

    if (QDir(projectDirPath).exists()) {
        emit this->repoExists(projectDirPath, name);
        return;
    }

    const auto func = [=]() {
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

        m_busy = false;
        emit this->busyChanged();
    };

    m_busy = true;
    emit busyChanged();

    QThreadPool::globalInstance()->start(func);
}

bool GitClient::hasRepo(const QString& path)
{
    if (path.isEmpty())
        return false;

    git_repository* repo;
    git_repository_open_ext(&repo, path.toStdString().c_str(), 0, nullptr);
    if (repo) {
        git_repository_free(repo);
        return true;
    } else {
        return false;
    }
}

void GitClient::stage(const QString& path)
{
    git_index *index;
    git_strarray array = {0};

    git_repository_index(&index, m_repo);
    git_index_add_all(index, &array, 0, nullptr, nullptr);

    git_index_write(index);
    git_index_free(index);
}

void GitClient::unstage(const QString& path)
{

}

QVariantList GitClient::logs(const QString branch)
{
    QVariantList ret;

    if (!m_repo)
        return ret;

    qDebug() << "Gathering logs from" << m_path << "at branch" << branch << "with repo" << m_repo;

    int i, count = 0, printed = 0, parents, last_arg;
    git_diff_options diffopts = GIT_DIFF_OPTIONS_INIT;
    git_oid oid;
    git_commit *commit = NULL;
    git_pathspec *ps = NULL;
    git_revwalk *walker = NULL;

    /** Use the revwalker to traverse the history. */
    git_revwalk_new(&walker, m_repo);
    git_revwalk_sorting(walker, GIT_SORT_TOPOLOGICAL | GIT_SORT_TIME);
    git_revwalk_push_head(walker);

    printed = count = 0;

    for (; !git_revwalk_next(&oid, walker); git_commit_free(commit)) {
        QVariantMap commitLog;

        git_commit_lookup(&commit, m_repo, &oid);
        parents = (int) git_commit_parentcount(commit);

        char buf[GIT_OID_SHA1_HEXSIZE + 1];
        int i, count;
        const git_signature *sig;
        const char *scan, *eol;

        git_oid_tostr(buf, sizeof(buf), git_commit_id(commit));
        const auto commitHash = QString::fromLocal8Bit(buf);
        commitLog.insert("commit", commitHash);

        QVariantList parents;
        if ((count = (int)git_commit_parentcount(commit)) > 1) {
            for (i = 0; i < count; ++i) {
                git_oid_tostr(buf, 8, git_commit_parent_id(commit, i));
                const auto parent = QString::fromLocal8Bit(buf);
                parents.push_back(parent);
            }
        }
        commitLog.insert("parents", parents);

        if ((sig = git_commit_author(commit)) != NULL) {
            const auto committer = QString::fromLocal8Bit(sig->name);
            const auto committerAddress = QString::fromLocal8Bit(sig->email);
            const auto commitDate = QDateTime::fromSecsSinceEpoch(sig->when.time);

            commitLog.insert("committer", committer);
            commitLog.insert("address", committerAddress);
            commitLog.insert("date", commitDate);
        }

        const char* commitSummary = git_commit_summary(commit);
        const char* commitMessage  = git_commit_message(commit);

        commitLog.insert("summary", QString::fromLocal8Bit(commitSummary));
        commitLog.insert("message", QString::fromLocal8Bit(commitMessage));

        ret << commitLog;
        qDebug() << "CommitLog:" << commitLog;
    }

    git_pathspec_free(ps);
    git_revwalk_free(walker);

    return ret;
}

