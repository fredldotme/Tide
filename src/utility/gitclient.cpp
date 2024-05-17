#include "gitclient.h"

#include <QDebug>
#include <QDir>
#include <QStandardPaths>
#include <QThreadPool>

GitClient::GitClient(QObject *parent)
    : QObject{parent},
#if !defined(__EMSCRIPTEN__)
    m_repo{nullptr},
#endif
    m_busy{false}
{
    QObject::connect(this, &GitClient::repoOpened, this,
        [=](const QString path){
            refreshStatus();
        }, Qt::DirectConnection);

#if !defined(__EMSCRIPTEN__)
    QObject::connect(this, &GitClient::pathChanged, this,
        [=]() {
            if (m_repo) {
                git_repository_free(m_repo);
                m_repo = nullptr;
            }

            // Early return with the indication that a refresh is desired
            if (m_path.isEmpty()) {
                emit this->repoOpened(m_path);
                return;
            }

            git_repository_open_ext(&m_repo, m_path.toStdString().c_str(), 0, nullptr);
            emit this->repoOpened(m_path);
        }, Qt::DirectConnection);
#endif

#if !defined(__EMSCRIPTEN__)
    git_libgit2_init();
#endif
}

GitClient::~GitClient()
{
#if !defined(__EMSCRIPTEN__)
    if (m_repo) {
        git_repository_free(m_repo);
        m_repo = nullptr;
    }
    git_libgit2_shutdown();
#endif
}

GitClient::GitFileStatus GitClient::translateStatusFromBackend(const int status)
{
    switch (status) {
    case GIT_STATUS_CURRENT:
        return Current;
    case GIT_STATUS_WT_NEW:
    case GIT_STATUS_INDEX_NEW:
        return New;
    case GIT_STATUS_WT_DELETED:
    case GIT_STATUS_INDEX_DELETED:
        return Deleted;
    case GIT_STATUS_WT_MODIFIED:
    case GIT_STATUS_INDEX_MODIFIED:
        return Modified;
    case GIT_STATUS_WT_RENAMED:
    case GIT_STATUS_INDEX_RENAMED:
        return Renamed;
    case GIT_STATUS_WT_TYPECHANGE:
    case GIT_STATUS_INDEX_TYPECHANGE:
        return Typechange;
    case GIT_STATUS_IGNORED:
        return Ignored;
    case GIT_STATUS_CONFLICTED:
        return Conflicted;
    case GIT_STATUS_WT_UNREADABLE:
        return Unreadable;
    default:
        return Unknown;
    }
}

void GitClient::refreshStatus()
{
    QVariantMap status;

#if !defined(__EMSCRIPTEN__)
    if (!m_repo) {
        m_status = status;
        emit statusChanged();
        return;
    }

    git_reference *head = NULL;
    int error = git_repository_head(&head, m_repo);
    
    if (error) {
        m_status = status;
        emit statusChanged();
        return;
    }

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
    while ((git_branch_next(&ref, &branch, branchiterator)) == 0) {
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

    refreshStage();
#endif

    m_status = status;
    emit statusChanged();
}

#if !defined(__EMSCRIPTEN__)
QVariantMap GitClient::gitEntryToVariant(const git_status_entry *s)
{
    QVariantMap ret;

    if (!s) {
        qWarning() << "No valid git status entry";
        return ret;
    }

    bool staged;
    git_diff_delta* delta = nullptr;

    if (s->index_to_workdir) {
        delta = s->index_to_workdir;
        staged = false;
    }
    else if (s->head_to_index) {
        delta = s->head_to_index;
        staged = true;
    }

    if (!delta) {
        qWarning() << "Invalid git status";
        return ret;
    }

    const auto path = QString::fromLocal8Bit(delta->new_file.path,
                                             strlen(delta->new_file.path));

    // Old path existing implies a difference between old and new
    if (delta->old_file.path) {
        const auto old_path = QString::fromLocal8Bit(delta->old_file.path,
                                                     strlen(delta->old_file.path));
        if (old_path != path)
            ret.insert("oldPath", old_path);
    }

    ret.insert("status", QVariant(translateStatusFromBackend(s->status)));
    ret.insert("path", path);
    ret.insert("staged", staged);

    qDebug() << ret;
    return ret;
}
#endif

bool GitClient::hasCommittable()
{
    for (const auto& entry : m_files) {
        const auto entryValue = entry.value<QVariantMap>();
        const auto status = entryValue.value("status").toInt();
        if (status != GitFileStatus::Unknown && !(status & GitFileStatus::Current)) {
            return true;
        }
    }

    return false;
}

bool GitClient::hasStagedFiles()
{
    for (const auto& entry : m_files) {
        const auto entryValue = entry.value<QVariantMap>();
        const auto staged = entryValue.value("staged").toBool();
        if (staged)
            return true;
    }

    return false;
}

void GitClient::refreshStage()
{
#if !defined(__EMSCRIPTEN__)
    git_status_list *status;
    git_status_list_new(&status, m_repo, nullptr);

    size_t i, maxi = git_status_list_entrycount(status);
    int header = 0, changes_in_index = 0;
    int changed_in_workdir = 0, rm_in_workdir = 0;
    const git_status_entry *s;
    bool stageChanged = false;

    /** Print index changes. */
    QVariantList newFileStates;

    for (i = 0; i < maxi; ++i) {
        s = git_status_byindex(status, i);

        if (s->status == GIT_STATUS_CURRENT)
            continue;

        stageChanged = true;
        const auto entry = gitEntryToVariant(s);
        if (!entry.empty())
            newFileStates << entry;
    }
    m_files = newFileStates;
    emit filesChanged();

    if (stageChanged)
        emit hasStagedFilesChanged();

    emit hasCommittableChanged();
#endif
}

void GitClient::clone(const QString& url, const QString& name)
{
#if !defined(__EMSCRIPTEN__)
    if (m_busy) {
        qWarning() << "GitClient is currently busy";
        return;
    }

    const auto projectDirPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                                QStringLiteral("/Projects/%1").arg(name);

    if (QDir(projectDirPath).exists()) {
        qWarning() << projectDirPath << "exists already";
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
                emit this->error("ERROR: no detailed info");
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
#endif
}

bool GitClient::hasRepo(const QString& path)
{
#if !defined(__EMSCRIPTEN__)
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
#endif
    return false;
}

void GitClient::checkHasUncommitted(const QString& path)
{
#if !defined(__EMSCRIPTEN__)
    const auto check = [=]() {
        if (path.isEmpty())
            return;

        git_repository* repo;
        git_repository_open_ext(&repo, path.toStdString().c_str(), 0, nullptr);
        if (repo) {
            git_status_list *status;
            git_status_list_new(&status, repo, nullptr);

            size_t i, maxi = git_status_list_entrycount(status);
            int changes_in_index = 0;
            const git_status_entry *s;
            bool hasUncommitted = false;

            for (i = 0; i < maxi; ++i) {
                s = git_status_byindex(status, i);

                if (s->status == GIT_STATUS_CURRENT)
                    continue;

                hasUncommitted = true;
                break;
            }

            git_repository_free(repo);
            emit hasUncommittedChecked(path, hasUncommitted);
        } else {
            emit hasUncommittedChecked(path, false);
        }
    };
    QThreadPool::globalInstance()->start(check);
#else
    emit hasUncommittedChecked(path, false);
#endif
}

QString GitClient::branch(const QString& path)
{
#if !defined(__EMSCRIPTEN__)
    if (path.isEmpty())
        return QString();

    git_repository* repo;
    git_repository_open_ext(&repo, path.toStdString().c_str(), 0, nullptr);
    if (repo) {
        git_reference *head = NULL;
        int error = git_repository_head(&head, repo);

        if (error) {
            git_repository_free(repo);
            return QString();
        }

        const auto branch = git_reference_shorthand(head);
        const auto branchName = QString::fromUtf8(branch);

        git_repository_free(repo);
        return branchName;
    } else {
        return QString();
    }
#endif
    return QString();
}

void GitClient::stage(const QString& path)
{
#if !defined(__EMSCRIPTEN__)    
    char* val[1] = { strdup(path.toStdString().data()) };

    git_index *index;
    git_strarray array = {0};
    array.count = 1;
    array.strings = val;
    git_repository_index(&index, m_repo);

    git_index_add_all(index, &array, 0, nullptr, nullptr);
    git_index_write(index);
    git_index_free(index);

    free((void*) val[0]);

    refreshStage();
#endif
}

void GitClient::unstage(const QString& path)
{
#if !defined(__EMSCRIPTEN__)
    char* val[1] = { strdup(path.toStdString().data()) };

    git_index *index;
    git_strarray array = {0};
    array.count = 1;
    array.strings = val;
    git_repository_index(&index, m_repo);

    git_index_remove_all(index, &array, nullptr, nullptr);
    git_index_write(index);
    git_index_free(index);

    free((void*) val[0]);

    refreshStage();
#endif
}

void GitClient::resetStage()
{

}

void GitClient::commit(const QString& summary, const QString& body)
{
#if !defined(__EMSCRIPTEN__)
    auto message = summary.toStdString() + "\n\n" + body.toStdString();
    const char *comment = message.data();
    int err;

    git_oid commit_oid,tree_oid;
    git_tree *tree;
    git_index *index;
    git_object *parent = NULL;
    git_reference *ref = NULL;
    git_signature *signature;

    err = git_revparse_ext(&parent, &ref, m_repo, "HEAD");
    if (err == GIT_ENOTFOUND) {
        err = 0;
    } else if (err != 0) {
        const git_error *err = git_error_last();
        if (err) {
            const auto errStr = QString::fromLocal8Bit(err->message);
            emit error(QStringLiteral("Error %1: %2").arg(QString::number(err->klass), errStr));
        } else {
            emit error("Unknown error");
        }
    }

    git_repository_index(&index, m_repo);
    git_index_write_tree(&tree_oid, index);
    git_index_write(index);
    git_tree_lookup(&tree, m_repo, &tree_oid);
    git_signature_now(&signature,
                      m_name.toStdString().data(),
                      m_email.toStdString().data());

    git_commit_create_v(
        &commit_oid,
        m_repo,
        "HEAD",
        signature,
        signature,
        NULL,
        comment,
        tree,
        parent ? 1 : 0,
        parent);

    git_index_free(index);
    git_signature_free(signature);
    git_tree_free(tree);
    git_object_free(parent);
    git_reference_free(ref);

    refreshStatus();
    checkHasUncommitted(m_path);
#endif
}

QVariantList GitClient::logs(const QString branch)
{
    QVariantList ret;

#if !defined(__EMSCRIPTEN__)
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
        const auto commitTimestamp = git_commit_time(commit);

        commitLog.insert("summary", QString::fromLocal8Bit(commitSummary));
        commitLog.insert("message", QString::fromLocal8Bit(commitMessage));
        commitLog.insert("timestamp", QDateTime::fromMSecsSinceEpoch(commitTimestamp * 1000));

        ret << commitLog;
        qDebug() << "CommitLog:" << commitLog;
    }

    git_pathspec_free(ps);
    git_revwalk_free(walker);
#endif

    return ret;
}

