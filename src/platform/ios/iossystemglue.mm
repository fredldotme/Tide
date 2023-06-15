#include "iossystemglue.h"

#include <QCoreApplication>
#include <QDebug>
#include <QStandardPaths>
#include <QUrl>

#include <thread>

extern "C" {
#include <ios_system.h>
#include <ios_error.h>
}

IosSystemGlue::IosSystemGlue(QObject* parent) : QObject(parent)
{
    initializeEnvironment();
    joinMainThread = true;
}

IosSystemGlue::~IosSystemGlue()
{
    fwrite("\n", sizeof(char), 1, m_spec.stdout);
    fflush(m_spec.stdout);
    fwrite("\n", sizeof(char), 1, m_spec.stderr);
    fflush(m_spec.stderr);
}

void IosSystemGlue::setupStdIo()
{
    FILE* inWriteEnd = nullptr;
    FILE* outWriteEnd = nullptr;
    FILE* errWriteEnd = nullptr;

    FILE* inReadEnd = nullptr;
    FILE* outReadEnd = nullptr;
    FILE* errReadEnd = nullptr;

    int fdIn[2] = {0};
    int fdOut[2] = {0};
    int fdErr[2] = {0};

    pipe(fdIn);
    inReadEnd = fdopen(fdIn[0], "r");
    inWriteEnd = fdopen(fdIn[1], "w");

    pipe(fdOut);
    outReadEnd = fdopen(fdOut[0], "r");
    outWriteEnd = fdopen(fdOut[1], "w");

    pipe(fdErr);
    errReadEnd = fdopen(fdErr[0], "r");
    errWriteEnd = fdopen(fdErr[1], "w");

    setvbuf(inReadEnd , nullptr , _IOLBF , 1024);
    setvbuf(outWriteEnd , nullptr , _IOLBF , 1024);
    setvbuf(errWriteEnd , nullptr , _IOLBF , 1024);

    m_spec.stdin = inReadEnd;
    m_spec.stdout = outWriteEnd;
    m_spec.stderr = errWriteEnd;

    emit stdioWritersPrepared({inReadEnd, outWriteEnd, errWriteEnd});
    emit stdioCreated({inWriteEnd, outReadEnd, errReadEnd});
}

// Blocking and hence shouldn't be called from the main or GUI threads
bool IosSystemGlue::runBuildCommands(const QStringList cmds)
{
    for (const auto& cmd : cmds) {
        thread_stdin = m_spec.stdin;
        thread_stdout = m_spec.stdout;
        thread_stderr = m_spec.stderr;

        const auto stdcmd = cmd.toStdString();
        const int ret = ios_system(stdcmd.c_str());
        if (ret != 0)
            return false;
    }
    return true;
}

void IosSystemGlue::killBuildCommands()
{
    ios_kill();
}

void IosSystemGlue::copyToClipboard(const QString text)
{
    UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
    if (!pasteBoard)
        return;

    NSString *nsText = text.toNSString();
    pasteBoard.string = nsText;
}

void IosSystemGlue::share(const QString text, const QUrl url, const QRect pos) {
    NSMutableArray *sharingItems = [NSMutableArray new];

    if (!text.isEmpty()) {
        [sharingItems addObject:text.toNSString()];
    }

    if (url.isValid()) {
        [sharingItems addObject:url.toNSURL()];
    }

    UIViewController *qtViewController = [[UIApplication sharedApplication].keyWindow rootViewController];

    UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:sharingItems applicationActivities:nil];
    UIPopoverController *popup = [[UIPopoverController alloc] initWithContentViewController:activityController];
    [popup presentPopoverFromRect:CGRectMake(pos.x(), pos.y(), pos.width(), pos.height())
                           inView:qtViewController.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];

}
