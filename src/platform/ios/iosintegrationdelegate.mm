#include "iosintegrationdelegate.h"

#include <QDebug>
#include <QRect>

#import "UIKit/UIKit.h"
#import "UserNotifications/UserNotifications.h"

@interface TideIosKeyboardReactor : NSObject
@property IosIntegrationDelegate* qtDelegate;
- (id)initWithDelegate:(IosIntegrationDelegate*)delegate;
- (void)keyboardDidHide:(NSNotification*)notification;
@end

@implementation TideIosKeyboardReactor

- (id) initWithDelegate:(IosIntegrationDelegate*)delegate {
    self = [super init];
    self->_qtDelegate = delegate;
    return self;
}

- (void)keyboardDidChangeFrame:(NSNotification*)notification {
    qDebug() << "DID CHANGE FRAME!";
    CGRect keyboardFrame = [[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];

    qDebug() << keyboardFrame.origin.x << keyboardFrame.origin.y;
    qDebug() << keyboardFrame.size.width << keyboardFrame.size.height;

    self->_qtDelegate->setOskRect(keyboardFrame.size.width, keyboardFrame.size.height);
}

- (void)keyboardDidHide:(NSNotification*)notification {
    qDebug() << "DID HIDE!";
    CGRect keyboardFrame = [[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];

    qDebug() << keyboardFrame.origin.x << keyboardFrame.origin.y;
    qDebug() << keyboardFrame.size.width << keyboardFrame.size.height;

    self->_qtDelegate->setOskVisible(false);
}

@end

IosIntegrationDelegate::IosIntegrationDelegate(QObject *parent)
    : QObject{parent}, m_oskVisible{false}, m_oskHeight{0}, m_item{nullptr}
{
    TideIosKeyboardReactor* reactor = [[TideIosKeyboardReactor alloc] initWithDelegate:this];
    [[NSNotificationCenter defaultCenter] addObserver:reactor
                                             selector:@selector (keyboardDidChangeFrame:)
                                                 name: UIKeyboardDidChangeFrameNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:reactor
                                             selector:@selector (keyboardDidHide:)
                                                 name: UIKeyboardDidHideNotification object: nil];
    int statusBarHeight = (int)[UIApplication sharedApplication].statusBarFrame.size.height;
    m_statusBarHeight = statusBarHeight;
}

void IosIntegrationDelegate::setOskRect(const int width, const int height)
{
    if (this->m_oskWidth != width) {
        this->m_oskWidth = width;
        emit oskWidthChanged();
    }
    if (this->m_oskHeight != height) {
        this->m_oskHeight = height;
        emit oskHeightChanged();
    }
    setOskVisible(this->m_oskWidth == this->m_item->width() && this->m_oskHeight > 128);
}

void IosIntegrationDelegate::setOskVisible(const bool val)
{
    if (this->m_oskVisible == val)
        return;

    this->m_oskVisible = val;
    emit oskVisibleChanged();
}

