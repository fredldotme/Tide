#include "iosintegrationdelegate.h"

#include <QDebug>
#include <QGuiApplication>
#include <QtGui/qpa/qplatformnativeinterface.h>
#include <QRect>
#include <QQuickWindow>
#include <QWindow>

#import "UIKit/UIKit.h"
#import "UserNotifications/UserNotifications.h"

@interface TideIosKeyboardReactor : NSObject
@property IosIntegrationDelegate* qtDelegate;
- (id)initWithDelegate:(IosIntegrationDelegate*)delegate;
- (void)keyboardWillShow:(NSNotification*)notification;
- (void)keyboardDidChangeFrame:(NSNotification*)notification;
- (void)keyboardWillHide:(NSNotification*)notification;
- (void)keyboardDidHide:(NSNotification*)notification;
@end

@implementation TideIosKeyboardReactor
- (id) initWithDelegate:(IosIntegrationDelegate*)delegate {
    self = [super init];
    self->_qtDelegate = delegate;
    return self;
}

- (void)keyboardWillShow:(NSNotification*)notification {
    qDebug() << "WILL SHOW!";

    CGRect keyboardFrame = [[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];

    self->_qtDelegate->setOskVisible(keyboardFrame.size.height > 128);
    self->_qtDelegate->setOskRect(keyboardFrame.size.width, keyboardFrame.size.height);
}

- (void)keyboardDidShow:(NSNotification*)notification {
    qDebug() << "DID SHOW!";

    CGRect keyboardFrame = [[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];

    self->_qtDelegate->setOskRect(keyboardFrame.size.width, keyboardFrame.size.height);
}

- (void)keyboardDidChangeFrame:(NSNotification*)notification {
    qDebug() << "DID CHANGE FRAME!";
    CGRect keyboardFrame = [[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];

    qDebug() << keyboardFrame.origin.x << keyboardFrame.origin.y;
    qDebug() << keyboardFrame.size.width << keyboardFrame.size.height;

    //self->_qtDelegate->setOskRect(keyboardFrame.size.width, keyboardFrame.size.height);
}

- (void)keyboardWillHide:(NSNotification*)notification {
    qDebug() << "WILL HIDE!";
    CGRect keyboardFrame = [[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];

    qDebug() << keyboardFrame.origin.x << keyboardFrame.origin.y;
    qDebug() << keyboardFrame.size.width << keyboardFrame.size.height;

    self->_qtDelegate->setOskRect(keyboardFrame.size.width, 0);
}
- (void)keyboardDidHide:(NSNotification*)notification {
    qDebug() << "DID HIDE!";
    CGRect keyboardFrame = [[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];

    qDebug() << keyboardFrame.origin.x << keyboardFrame.origin.y;
    qDebug() << keyboardFrame.size.width << keyboardFrame.size.height;

    self->_qtDelegate->setOskVisible(false);
}
@end

@interface TideChildViewController : UIViewController <UIPointerInteractionDelegate>
- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region  API_AVAILABLE(ios(13.4));
@end

@implementation TideChildViewController
- (UIPointerStyle *)pointerInteraction:(UIPointerInteraction *)interaction styleForRegion:(UIPointerRegion *)region {
    UIPointerStyle *pointerStyle = nil;
    qDebug() << Q_FUNC_INFO;

    UIView *interactionView = interaction.view;
    if (interactionView) {
        //UITargetedPreview *targetPreview = [[UITargetedPreview alloc] initWithView:interactionView];
        //UIPointerEffect *hoverEffect = [UIPointerHoverEffect effectWithPreview:targetPreview];
        pointerStyle = [UIPointerStyle styleWithShape:[UIPointerShape shapeWithRoundedRect:(region.rect)] constrainedAxes:(UIAxisVertical)];
    }
    return pointerStyle;
}
@end

@interface TideUIPointerInteraction : UIPointerInteraction
@end

@implementation TideUIPointerInteraction
@end

@interface TideItemUIViewProxy : UIView
@end

@implementation TideItemUIViewProxy
@end

@interface TideAppDelegate : UIResponder <UIApplicationDelegate>
+ (TideAppDelegate*) sharedAppDelegate;
@end

@implementation TideAppDelegate
static TideAppDelegate* sharedAppDelegate = nil;
+(TideAppDelegate *) sharedAppDelegate {
    static TideAppDelegate *shared = nil;
    if (!shared)
        shared = [[TideAppDelegate alloc] init];
    return shared;
}
-(BOOL)canBecomeFirstResponder {
    return YES;
}
@end

IosIntegrationDelegate::IosIntegrationDelegate(QObject *parent)
    : QObject{parent}, m_oskVisible{false}, m_oskHeight{0}, m_item{nullptr}, m_hasKeyboard{false}
{
    static bool initialized = false;
    if (!initialized) {
        [[UIApplication sharedApplication] setDelegate:[TideAppDelegate sharedAppDelegate]];
        [[TideAppDelegate sharedAppDelegate] becomeFirstResponder];
        initialized = true;
    }

    TideIosKeyboardReactor* reactor = [[TideIosKeyboardReactor alloc] initWithDelegate:this];
    [[NSNotificationCenter defaultCenter] addObserver:reactor
                                             selector:@selector (keyboardWillShow:)
                                                 name: UIKeyboardWillShowNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:reactor
                                             selector:@selector (keyboardDidShow:)
                                                 name: UIKeyboardDidShowNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:reactor
                                             selector:@selector (keyboardDidChangeFrame:)
                                                 name: UIKeyboardDidChangeFrameNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:reactor
                                             selector:@selector (keyboardDidHide:)
                                                 name: UIKeyboardDidHideNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:reactor
                                             selector:@selector (keyboardWillHide:)
                                                 name: UIKeyboardWillHideNotification object: nil];
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
}

void IosIntegrationDelegate::setOskVisible(const bool val)
{
    if (this->m_oskVisible == val)
        return;

    this->m_oskVisible = val;
    emit oskVisibleChanged();
}

void IosIntegrationDelegate::setItem(QQuickItem* item)
{
    if (this->m_item == item)
        return;

    this->m_item = item;
    emit itemChanged();
}

void IosIntegrationDelegate::hookUpNativeView(QQuickItem* item)
{
    QWindow *window = static_cast<QWindow*>(item->window());
    UIView *view = static_cast<UIView*>(QGuiApplication::platformNativeInterface()->nativeResourceForWindow("uiview", window));
    if (!view)
        return;

    CGRect rect = CGRect();
    rect.origin.x = item->x();
    rect.origin.y = item->y();
    rect.size.width = item->width();
    rect.size.height = item->height();

    TideItemUIViewProxy* proxy = [[TideItemUIViewProxy alloc] initWithFrame:(rect)];
    if (!proxy)
        return;

    TideUIPointerInteraction* interaction = [[TideUIPointerInteraction alloc] init];
    proxy.userInteractionEnabled = TRUE;
    proxy.hidden = TRUE;
    [proxy addInteraction:interaction];

    QObject::connect(item, &QQuickItem::widthChanged, this, [=]() {
        CGRect rect = CGRect();
        rect.origin.x = item->x();
        rect.origin.y = item->y();
        rect.size.width = item->width();
        rect.size.height = item->height();
        [proxy setFrame:rect];
    });
    QObject::connect(item, &QQuickItem::heightChanged, this, [=]() {
        CGRect rect = CGRect();
        rect.origin.x = item->x();
        rect.origin.y = item->y();
        rect.size.width = item->width();
        rect.size.height = item->height();
        [proxy setFrame:rect];
    });
    QObject::connect(item, &QQuickItem::xChanged, this, [=]() {
        CGRect rect = CGRect();
        rect.origin.x = item->x();
        rect.origin.y = item->y();
        rect.size.width = item->width();
        rect.size.height = item->height();
        [proxy setFrame:rect];
    });
    QObject::connect(item, &QQuickItem::yChanged, this, [=]() {
        CGRect rect = CGRect();
        rect.origin.x = item->x();
        rect.origin.y = item->y();
        rect.size.width = item->width();
        rect.size.height = item->height();
        [proxy setFrame:rect];
    });

    qDebug() << "Adding proxy UIView for item" << item;
    [view addSubview:proxy];
}

QQuickItem* IosIntegrationDelegate::item()
{
    return this->m_item;
}
