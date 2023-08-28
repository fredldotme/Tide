#include "iossystemglue.h"

#include <QCoreApplication>
#include <QDebug>
#include <QStandardPaths>
#include <QUrl>

#include <thread>

extern "C" {
#include <unistd.h>
#include <no_system/nosystem.h>
}

#import <UIKit/UIKit.h>

IosSystemGlue::IosSystemGlue(QObject* parent) : QObject(parent)
{
}

IosSystemGlue::~IosSystemGlue()
{
    fwrite("\n", sizeof(char), 1, m_spec.stdout);
    fflush(m_spec.stdout);
    fwrite("\n", sizeof(char), 1, m_spec.stderr);
    fflush(m_spec.stderr);
}

StdioSpec IosSystemGlue::consumerSpec()
{
    return m_consumerSpec;
}

std::pair<StdioSpec, StdioSpec> IosSystemGlue::setupPipes()
{
    StdioSpec spec, consumerSpec;

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

    spec.stdin = inReadEnd;
    spec.stdout = outWriteEnd;
    spec.stderr = errWriteEnd;

    consumerSpec.stdin = inWriteEnd;
    consumerSpec.stdout = outReadEnd;
    consumerSpec.stderr = errReadEnd;

    return std::make_pair(spec, consumerSpec);
}

void IosSystemGlue::setupStdIo()
{
    auto pair = setupPipes();
    m_spec = pair.first;
    m_consumerSpec = pair.second;

    emit stdioWritersPrepared(m_spec);
    emit stdioCreated(m_consumerSpec);
}

// Blocking and hence shouldn't be called from the main or GUI threads
bool IosSystemGlue::runBuildCommands(const QStringList cmds, const StdioSpec spec)
{
    if (spec.stdin || spec.stdout || spec.stderr) {
        nosystem_stdin = spec.stdin;
        nosystem_stdout = spec.stdout;
        nosystem_stderr = spec.stderr;
    } else {
        nosystem_stdin = m_spec.stdin;
        nosystem_stdout = m_spec.stdout;
        nosystem_stderr = m_spec.stderr;
    }

    for (const auto& command : cmds) {
        const auto stdcmd = command.toStdString();
        const int ret = nosystem_system(stdcmd.c_str());
        if (ret != 0)
            return false;
    }
    return true;
}

void IosSystemGlue::killBuildCommands()
{
}

void IosSystemGlue::writeToStdIn(const QByteArray data)
{
    fwrite(data.constData(), sizeof(const char*), data.length(), m_consumerSpec.stdin);
    fflush(m_consumerSpec.stdin);
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

void IosSystemGlue::changeDir(const QString path)
{
    chdir(path.toStdString().c_str());
}
