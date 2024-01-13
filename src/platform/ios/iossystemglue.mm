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

IosSystemGlue::IosSystemGlue(QObject* parent) :
    QObject(parent), m_requestBuildStop{false}
{
}

IosSystemGlue::~IosSystemGlue()
{
    if (m_spec.std_out) {
        fwrite("\n", sizeof(char), 1, m_spec.std_out);
        fflush(m_spec.std_out);
    }

    if (m_spec.std_err) {
        fwrite("\n", sizeof(char), 1, m_spec.std_err);
        fflush(m_spec.std_err);
    }
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

    spec.std_in = inReadEnd;
    spec.std_out = outWriteEnd;
    spec.std_err = errWriteEnd;

    consumerSpec.std_in = inWriteEnd;
    consumerSpec.std_out = outReadEnd;
    consumerSpec.std_err = errReadEnd;

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
    StdioSpec copy;

    if (spec.std_in || spec.std_out || spec.std_err) {
        copy.std_in = fdopen(dup(fileno(spec.std_in)), "r");
        copy.std_out = fdopen(dup(fileno(spec.std_out)), "w");
        copy.std_err = fdopen(dup(fileno(spec.std_err)), "w");
    } else {
        copy.std_in = fdopen(dup(fileno(m_spec.std_in)), "r");
        copy.std_out = fdopen(dup(fileno(m_spec.std_out)), "w");
        copy.std_err = fdopen(dup(fileno(m_spec.std_err)), "w");
    }

    for (const auto& command : cmds) {
        if (m_requestBuildStop) {
            break;
        }

        nosystem_stdin = copy.std_in;
        nosystem_stdout = copy.std_out;
        nosystem_stderr = copy.std_err;

        const auto stdcmd = command.toStdString();
        const int ret = nosystem_system(stdcmd.c_str());
        if (ret != 0)
            return false;
    }

    if (copy.std_in)
        fclose(copy.std_in);
    if (copy.std_out)
        fclose(copy.std_out);
    if (copy.std_err)
        fclose(copy.std_err);

    if (m_requestBuildStop) {
        m_requestBuildStop = false;
        return false;
    }

    return true;
}

// Blocking and hence shouldn't be called from the main or GUI threads
int IosSystemGlue::runCommand(const QString cmd, const StdioSpec spec)
{
    StdioSpec copy;

    if (spec.std_in || spec.std_out || spec.std_err) {
        copy.std_in = fdopen(dup(fileno(spec.std_in)), "r");
        copy.std_out = fdopen(dup(fileno(spec.std_out)), "w");
        copy.std_err = fdopen(dup(fileno(spec.std_err)), "w");
    } else {
        copy.std_in = fdopen(dup(fileno(m_spec.std_in)), "r");
        copy.std_out = fdopen(dup(fileno(m_spec.std_out)), "w");
        copy.std_err = fdopen(dup(fileno(m_spec.std_err)), "w");
    }

    nosystem_stdin = copy.std_in;
    nosystem_stdout = copy.std_out;
    nosystem_stderr = copy.std_err;

    const auto stdcmd = cmd.toStdString();
    const int ret = nosystem_system(stdcmd.c_str());
    qWarning() << "Return" << ret << "from command" << cmd;

    if (copy.std_in)
        fclose(copy.std_in);
    if (copy.std_out)
        fclose(copy.std_out);
    if (copy.std_err)
        fclose(copy.std_err);

    return ret;
}

void IosSystemGlue::killBuildCommands()
{
    m_requestBuildStop = true;
}

void IosSystemGlue::writeToStdIn(const QByteArray data)
{
    fwrite(data.constData(), sizeof(const char*), data.length(), m_consumerSpec.std_in);
    fflush(m_consumerSpec.std_in);
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

