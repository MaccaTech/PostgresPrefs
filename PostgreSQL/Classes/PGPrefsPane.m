//
//  PGPrefsPane.m
//  PostgresPrefs
//
//  Created by Francis McKenzie on 17/12/11.
//  Copyright (c) 2011-2020 Macca Tech Ltd. (http://macca.tech)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import "PGPrefsPane.h"

#pragma mark - Constants

NSInteger const PGDeleteServerCancelButton = 1234;
NSInteger const PGDeleteServerKeepFileButton = 2345;
NSInteger const PGDeleteServerDeleteFileButton = 3456;



#pragma mark - Interfaces

/**
 * Apply default styling to attributed string.
 */
@interface NSMutableAttributedString (DefaultAttributes)
- (void)setDefaultFont:(NSFont *)defaultFont;
- (void)setDefaultColor:(NSColor *)defaultColor;
- (void)setDefaultAlignment:(NSTextAlignment)alignment;
@end

/**
 * Category for searching all nested subviews.
 */
@interface NSView (Enumerate)
- (void)enumerateAllSubviewsUsingBlock:(void(^)(NSView *subview, BOOL *stop))block;
@end

@interface PGPrefsShowAndWaitPopover ()
@property (nonatomic, strong) dispatch_semaphore_t shownSemaphore;
@end

/**
 * Adds autolayout constraints to view for show/hide.
 */
@interface PGPrefsHiddenConstraints : NSObject
@property (weak, readonly) NSView *view;
@property (readonly) NSLayoutConstraint *zeroWidthConstraint;
@property (readonly) NSLayoutConstraint *zeroHeightConstraint;
@property (nonatomic) BOOL active;
- (instancetype)initWithView:(NSView *)view;
@end

@interface PGPrefsToggleImageView ()
@property PGPrefsHiddenConstraints *hiddenConstraints;
@end

@interface PGPrefsToggleButton ()
@property PGPrefsHiddenConstraints *hiddenConstraints;
@end

@interface PGPrefsPane ()

/// If YES, user events will not be sent to the controller (e.g. select server)
@property (nonatomic) BOOL updatingDisplay;
/// If NO, then all user controls will be greyed-out
@property (nonatomic) BOOL enabled;
/// If NO, then the start/stop button will be greyed-out
@property (nonatomic) BOOL startStopEnabled;
/// If NO, then the view log button will be greyed-out (if log doesn't exist)
@property (nonatomic) BOOL logEnabled;
/// If NO, then the editing server settings will be greyed-out (if server not editable)
@property (nonatomic) BOOL editEnabled;
/// Used to darken background when showing authorization popover.
@property (nonatomic) NSView *authorizationModalMask;

- (void)initAuthorization;

- (void)showStatusWithName:(NSString *)name colour:(NSColor *)colour image:(NSString *)image info:(NSString *)info startStopButton:(NSString *)startStopButton;
- (void)showStarted;
- (void)showStopped;
- (void)showStarting;
- (void)showStopping;
- (void)showDeleting;
- (void)showChecking;
- (void)showRetrying;
- (void)showUpdating;
- (void)showUnknown;
- (void)showDirtyInSettingsWindow:(PGServer *)server;
- (void)showSettingsInSettingsWindow:(PGServer *)server;
- (void)showSettingsInMainServerView:(PGServer *)server;
- (void)showStatusInMainServerView:(PGServer *)server;
- (void)showServerInMainServerView:(PGServer *)server;
- (void)showServerInServersTable:(PGServer *)server;
- (void)showServerRenameWindow:(PGServer *)server;
- (void)showServerSettingsWindow:(PGServer *)server;
- (void)showServerDeleteWindow:(PGServer *)server;

@end



#pragma mark - NSMutableAttributedString (DefaultAttributes)

@implementation NSMutableAttributedString (DefaultAttributes)
- (void)setDefaultFont:(NSFont *)defaultFont
{
    if (defaultFont) {
        [self setDefaultAttribute:NSFontAttributeName usingBlock:^(NSFont *oldFont, NSFont *__autoreleasing *newFont, NSRange range, BOOL *stop) {
            *newFont = oldFont ?: defaultFont;
            if ((*newFont).pointSize != defaultFont.pointSize) {
                *newFont = [NSFontManager.sharedFontManager convertFont:*newFont toSize:defaultFont.pointSize];
            }
        }];
    }
}
- (void)setDefaultColor:(NSColor *)defaultColor
{
    if (defaultColor) {
        [self setDefaultAttribute:NSForegroundColorAttributeName usingBlock:^(NSColor *oldColor, NSColor *__autoreleasing *newColor, NSRange range, BOOL *stop) {
            if (!oldColor) { *newColor = defaultColor; }
        }];
    }
}
- (void)setDefaultAlignment:(NSTextAlignment)alignment
{
    if (alignment) {
        [self setDefaultAttribute:NSParagraphStyleAttributeName usingBlock:^(NSParagraphStyle *oldStyle, NSParagraphStyle *__autoreleasing *newStyle, NSRange range, BOOL *stop) {
            if (oldStyle.alignment != alignment) {
                NSMutableParagraphStyle *mutableStyle = [[NSMutableParagraphStyle alloc] init];
                [mutableStyle setParagraphStyle:oldStyle];
                mutableStyle.alignment = alignment;
                *newStyle = mutableStyle;
            }
        }];
    }
}
- (void)setDefaultAttribute:(NSAttributedStringKey)attribute usingBlock:(void(^)(__kindof id oldValue, __kindof id *newValue, NSRange range, BOOL *stop))block
{
    NSRange entireRange = NSMakeRange(0, self.length);
    
    __block BOOL hasOneAttribute = NO;
    [self enumerateAttribute:attribute inRange:entireRange options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        hasOneAttribute = YES;
        id newValue = nil;
        block(value, &newValue, range, stop);
        if (newValue != nil && newValue != value) {
            [self removeAttribute:attribute range:range];
            [self addAttribute:attribute value:newValue range:range];
        }
    }];
    if (!hasOneAttribute) {
        id newValue = nil;
        block(nil, &newValue, entireRange, &hasOneAttribute);
        if (newValue != nil) {
            [self removeAttribute:attribute range:entireRange];
            [self addAttribute:attribute value:newValue range:entireRange];
        }
    }
}
@end



#pragma mark - NSView (Enumerate)

@implementation NSView (Enumerate)
- (void)_enumerateAllSubviewsWithStop:(BOOL *)stop usingBlock:(void (^)(NSView *, BOOL *))block
{
    [self.subviews enumerateObjectsUsingBlock:^(NSView *subview, NSUInteger idx, BOOL *stopEnumerating)
     {
        block(subview, stop);
        if (!*stop) { [subview _enumerateAllSubviewsWithStop:stop usingBlock:block]; }
        *stopEnumerating = *stop;
    }];
}
- (void)enumerateAllSubviewsUsingBlock:(void (^)(NSView *, BOOL *))block
{
    BOOL stop = NO;
    [self _enumerateAllSubviewsWithStop:&stop usingBlock:block];
}
@end



#pragma mark - PGPrefsCenteredTextFieldCell

@implementation PGPrefsCenteredTextFieldCell

- (NSRect)adjustedFrameToVerticallyCenterText:(NSRect)rect
{
    NSAttributedString *string = self.attributedStringValue;
    CGFloat boundsHeight = [string boundingRectWithSize:rect.size options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading].size.height;
    NSInteger offset = floor((NSHeight(rect) - ceilf(boundsHeight))/2);
    NSRect centeredRect = NSInsetRect(rect, 0, offset);
    return centeredRect;
}
- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view
{
    [super drawInteriorWithFrame:[self adjustedFrameToVerticallyCenterText:frame] inView:view];
}

@end



#pragma mark - PGPrefsStoryboardTextView

@implementation PGPrefsStoryboardTextView
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _storyboardStyle = [self.attributedString attributesAtIndex:0 effectiveRange:nil];
    }
    return self;
}
- (void)setAttributedStringUsingStoryboardStyle:(NSAttributedString *)attributedString
{
    NSMutableAttributedString *mutableString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];
    [mutableString beginEditing];
    [mutableString setDefaultFont:_storyboardStyle[NSFontAttributeName]];
    [mutableString setDefaultColor:_storyboardStyle[NSForegroundColorAttributeName]];
    NSParagraphStyle *paragraphStyle = _storyboardStyle[NSParagraphStyleAttributeName];
    if (paragraphStyle) {
        [mutableString setDefaultAlignment:paragraphStyle.alignment];
    }
    [mutableString endEditing];
    [self.textStorage setAttributedString:mutableString];
}
@end



#pragma mark - PGPrefsCenteredTextView

@implementation PGPrefsCenteredTextView
- (void)layout
{
    if (self.textStorage.length > 0) {
        // This line is required on macOS High Sierra (but not Catalina)
        // to ensure proper vertical alignment when view is first shown.
        [self.layoutManager ensureLayoutForGlyphRange:NSMakeRange(0, self.attributedString.length)];

        NSScrollView *scrollView = (NSScrollView *) self.superview.superview;
        CGFloat textHeight = [self.layoutManager usedRectForTextContainer:self.textContainer].size.height;
        CGFloat viewHeight = scrollView.bounds.size.height;
        CGFloat insetHeight = MAX(0, floor((viewHeight - textHeight) / 2.0));
        scrollView.hasVerticalScroller = insetHeight < 0.1;
        self.textContainerInset = CGSizeMake(0, insetHeight);
    }

    [super layout];
}
@end



#pragma mark - PGPrefsNonClickableTextField

@implementation PGPrefsNonClickableTextField
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end



#pragma mark - PGPrefsSegmentedControl

@implementation PGPrefsSegmentedControl
- (SEL)action
{
    // This allows connected menu to popup instantly
    // (because no action is returned for menu button)
    return [self menuForSegment:self.selectedSegment] != nil ? nil : [super action];
}
@end



#pragma mark - PGPrefsShowAndWaitPopover

@implementation PGPrefsShowAndWaitPopover
- (void)showRelativeToRect:(NSRect)positioningRect ofView:(NSView *)positioningView preferredEdge:(NSRectEdge)preferredEdge waitUntilShownWithTimeout:(NSTimeInterval)timeout
{
    // Create semaphore
    dispatch_semaphore_t shownSemaphore;
    if (![NSThread isMainThread]) {
        self.delegate = self;
        self.shownSemaphore = shownSemaphore = dispatch_semaphore_create(0);
    }
    
    // Show popover
    MainThread(^{
        [self showRelativeToRect:positioningRect ofView:positioningView preferredEdge:preferredEdge];
    });
    
    // Block waiting for semaphore
    if (![NSThread isMainThread]) {
        intptr_t timedOut = dispatch_semaphore_wait(shownSemaphore, dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC));
        if (timedOut) {
            DLog(@"Timed out waiting for popover to appear");
        } else {
            // The popover should now be on the screen, but on macOS
            // Monterey it still isn't visible. Yield control so
            // UI runloop can finish drawing the popover.
            // Note: Apple developer support recommended this approach
            [NSThread sleepForTimeInterval:0.5];
        }
    }
}
- (void)popoverDidShow:(NSNotification *)notification
{
    self.shownSemaphore = nil;
}
- (void)setShownSemaphore:(dispatch_semaphore_t)shownSemaphore
{
    dispatch_semaphore_t previousShownSemaphore;
    
    if (_shownSemaphore == shownSemaphore) { return; }
    @synchronized (self) {
        if (_shownSemaphore == shownSemaphore) { return; }
        previousShownSemaphore = _shownSemaphore;
        _shownSemaphore = shownSemaphore;
    }
    
    // Signal
    if (previousShownSemaphore) {
        dispatch_semaphore_signal(previousShownSemaphore);
    }
}
- (void)dealloc
{
    // Signal
    if (_shownSemaphore) {
        dispatch_semaphore_signal(_shownSemaphore);
    }
}
@end



#pragma mark - PGPrefsToggleViews

@implementation PGPrefsToggleImageView
- (void)setHidden:(BOOL)hidden
{
    if (self.hidden == hidden) { return; }
    [super setHidden:hidden];
    if (!_hiddenConstraints) {
        _hiddenConstraints = [[PGPrefsHiddenConstraints alloc] initWithView:self];
    }
    _hiddenConstraints.active = hidden;
}
@end

@implementation PGPrefsToggleButton
- (void)setHidden:(BOOL)hidden
{
    if (self.hidden == hidden) { return; }
    [super setHidden:hidden];
    if (!_hiddenConstraints) {
        _hiddenConstraints = [[PGPrefsHiddenConstraints alloc] initWithView:self];
    }
    _hiddenConstraints.active = hidden;
}
@end

@implementation PGPrefsHiddenConstraints
- (instancetype)initWithView:(NSView *)view
{
    self = [super init];
    if (self) {
        _view = view;
        _zeroWidthConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:0 constant:0];
        _zeroHeightConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:0 constant:0];
        [_view addConstraints:@[_zeroWidthConstraint, _zeroHeightConstraint]];
        _zeroWidthConstraint.active = _zeroHeightConstraint.active = _view.hidden;
    }
    return self;
}

- (BOOL)isActive
{
    return _zeroWidthConstraint.active || _zeroHeightConstraint.active;
}

- (void)setActive:(BOOL)active
{
    _zeroWidthConstraint.active = _zeroHeightConstraint.active = active;
}
@end

@implementation PGPrefsToggleEventsView
- (NSView *)hitTest:(NSPoint)point
{
    return _ignoresEvents ? nil : [super hitTest:point];
}
@end



#pragma mark - PGPrefsRenameWindow

@implementation PGPrefsRenameWindow
@end



#pragma mark - PGPrefsDeleteWindow

@implementation PGPrefsDeleteWindow
@end



#pragma mark - PGPrefsInfoWindow

@implementation PGPrefsInfoWindow
@end



#pragma mark - PGPrefsServerSettingsWindow

@implementation PGPrefsServerSettingsWindow
@end



#pragma mark - PGPrefsServersHeaderCell

@implementation PGPrefsServersHeaderCell
@end



#pragma mark - PGPrefsServersCell

@implementation PGPrefsServersCell
@end



#pragma mark - PGPrefsPane

@implementation PGPrefsPane

#pragma mark Lifecycle

- (void)mainViewDidLoad
{
    // Remove existing delegate
    if (self.controller) {
        DLog(@"Warning - controller already exists! Removing existing controller...");
        if (self.controller.viewController == self) self.controller.viewController = nil;
        self.controller = nil;
    }
    
    // Set servers menu
    [self.serversMenu setDelegate:self];
    [self.serversButtons setMenu:self.serversMenu forSegment:2];

    // Reset initial view states
    self.updatingDisplay = YES;
    self.logEnabled = YES;
    self.editEnabled = YES;
    self.startStopEnabled = YES;
    self.enabled = YES;
    self.updatingDisplay = NO;
    
    // Set new delegate
    self.controller = [[PGPrefsController alloc] initWithViewController:self];
    
    // Setup subview delegates
    self.serverSettingsWindow.usernameField.delegate = self;
    self.serverSettingsWindow.binDirectoryField.delegate = self;
    self.serverSettingsWindow.dataDirectoryField.delegate = self;
    self.serverSettingsWindow.logFileField.delegate = self;
    self.serverSettingsWindow.portField.delegate = self;
    
    // Wire up authorization
    [self initAuthorization];
    
    // Call delegate DidLoad method
    [self.controller viewDidLoad];
    
    // Fix text color on old macOS (High Sierra)
    [self setTextInfoColorIfNotCompatibleWithAssetCatalog:self.errorField];
    [self setTextInfoColorIfNotCompatibleWithAssetCatalog:self.deleteServerWindow.infoField];
    [self setTextInfoColorIfNotCompatibleWithAssetCatalog:self.errorWindow.titleField];
    [self setTextInfoColorIfNotCompatibleWithAssetCatalog:self.authInfoWindow.titleField];
    
    // Fix images unsupported on old macOS (High Sierra)
    [self setImageIfNotCompatibleWithAssetCatalog:self.splashLogo imageName:@"logo_big"];
}

- (void)willSelect
{
    [self.controller viewWillAppear];
}
- (void)didSelect
{
    [self.controller viewDidAppear];
    
    // Hack to get first responder to work
    // See http://stackoverflow.com/questions/24903165/mysterious-first-responder-change
    [self.mainView.window performSelector:@selector(makeFirstResponder:) withObject:self.serversTableView afterDelay:0.0];
}
- (void)willUnselect
{
    [self.controller viewWillDisappear];
}
- (void)didUnselect
{
    [self.controller viewDidDisappear];
}



#pragma mark Properties

- (void)refreshEnabled
{
    self.viewLogButton.enabled = self.enabled && self.logEnabled;
    self.renameServerButton.enabled = self.enabled && self.editEnabled;
    self.changeSettingsButton.enabled = self.enabled && self.editEnabled;
    self.startupAtLoginCell.enabled = self.enabled && self.editEnabled;
    self.startupAtBootCell.enabled = self.enabled && self.editEnabled;
    self.startupManualCell.enabled = self.enabled && self.editEnabled;
    self.startupMatrix.enabled = self.enabled && self.editEnabled;
    self.startStopButton.enabled = self.enabled && self.startStopEnabled;
    
    self.serversButtons.enabled = self.enabled;
    self.noServersButtons.enabled = YES; // Always enabled, not always visible
}
- (void)setEnabled:(BOOL)enabled
{
    if (enabled == _enabled) return;
    _enabled = enabled;
    
    [self refreshEnabled];
}
- (void)setStartStopEnabled:(BOOL)startStopEnabled
{
    if (startStopEnabled == _startStopEnabled) return;
    _startStopEnabled = startStopEnabled;
    
    [self refreshEnabled];
}
- (void)setLogEnabled:(BOOL)logEnabled
{
    if (logEnabled == _logEnabled) return;
    _logEnabled = logEnabled;

    [self refreshEnabled];
}
- (void)setEditEnabled:(BOOL)editEnabled
{
    if (editEnabled == _editEnabled) return;
    _editEnabled = editEnabled;
    
    [self refreshEnabled];
}

- (PGServerStartup)startup
{
    NSCell *cell = [self.startupMatrix selectedCell];
    if (cell == self.startupAtBootCell) return PGServerStartupAtBoot;
    else if (cell == self.startupAtLoginCell) return PGServerStartupAtLogin;
    else return PGServerStartupManual;
}

- (void)setStartup:(PGServerStartup)startup
{
    switch (startup) {
        case PGServerStartupAtBoot:
            [self.startupMatrix selectCell:self.startupAtBootCell]; break;
        case PGServerStartupAtLogin:
            [self.startupMatrix selectCell:self.startupAtLoginCell]; break;
        default:
            [self.startupMatrix selectCell:self.startupManualCell]; break;
    }
}


#pragma mark PGServerSettings

- (void)controlTextDidChange:(NSNotification *)notification
{
    if (self.updatingDisplay) return;
    
    PGPrefsServerSettingsWindow *view = self.serverSettingsWindow;
    if (notification.object == view.usernameField) [self.controller userDidChangeSetting:PGServerUsernameKey value:view.usernameField.stringValue];
    else if (notification.object == view.binDirectoryField) [self.controller userDidChangeSetting:PGServerBinDirectoryKey value:view.binDirectoryField.stringValue];
    else if (notification.object == view.dataDirectoryField) [self.controller userDidChangeSetting:PGServerDataDirectoryKey value:view.dataDirectoryField.stringValue];
    else if (notification.object == view.logFileField) [self.controller userDidChangeSetting:PGServerLogFileKey value:view.logFileField.stringValue];
    else if (notification.object == view.portField) [self.controller userDidChangeSetting:PGServerPortKey value:view.portField.stringValue];
    else
        DLog(@"Unknown control: %@", notification.object);
}
- (IBAction)startupClicked:(id)sender
{
    if (self.updatingDisplay) return;
 
    [self.controller performSelector:@selector(userDidChangeServerStartup:) withObject:NSStringFromPGServerStartup(self.startup) afterDelay:0.1];
}

- (IBAction)viewLogClicked:(id)sender
{
    [self.controller userDidViewLog];
}



#pragma mark Authorization

- (BOOL)authorized
{
    return self.authorizationView.authorizationState == SFAuthorizationViewUnlockedState;
}

- (AuthorizationRef)authorization
{
    SFAuthorization *authorization = self.authorizationView.authorization;
    return authorization ? authorization.authorizationRef : nil;
}

- (void)initAuthorization
{
    AuthorizationRights *rights = self.controller.rights.authorizationRights;
    if (!rights) {
        DLog(@"No Authorization Rights!");
        [self.authorizationView removeFromSuperview];
        return;
    }

    self.authorizationView.authorizationRights = rights;
    self.authorizationView.delegate = self;
    [self.authorizationView updateStatus:nil];
    self.authorizationView.autoupdate = self.authorized;
    
    // For darkening background when auth popup shows
    NSView *authorizationModalMask = [[NSView alloc] init];
    authorizationModalMask.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    authorizationModalMask.frame = self.mainView.bounds;
    authorizationModalMask.wantsLayer = YES;
    authorizationModalMask.hidden = YES;
    authorizationModalMask.layer.opacity = 0.5;
    authorizationModalMask.layer.backgroundColor = [NSColor blackColor].CGColor;
    [self.mainView addSubview:authorizationModalMask positioned:NSWindowBelow relativeTo:self.authorizationView];
    _authorizationModalMask = authorizationModalMask;
}

- (AuthorizationRef)authorizeAndWait:(PGAuth *)auth
{
    if (self.authorized) return self.authorizationView.authorization.authorizationRef;
    
    // Disable clicks / keypresses
    ((PGPrefsToggleEventsView *) self.mainView).ignoresEvents = YES;
    
    if (auth.reason.count > 0) {
        DLog(@"Authorize: %@ %@", auth.reason[PGAuthReasonAction], auth.reason[PGAuthReasonTarget]);
        
        // Prepare content for popover
        NSMutableAttributedString *reason = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", auth.reason[PGAuthReasonAction]]];
        [reason appendAttributedString:[[NSAttributedString alloc] initWithString:auth.reason[PGAuthReasonTarget] attributes:@{NSFontAttributeName:[NSFontManager.sharedFontManager convertFont:[NSFont userFixedPitchFontOfSize:self.authInfoWindow.detailsView.font.pointSize] toHaveTrait:NSFontBoldTrait]}]];

        __block CGRect authorizationViewLockIconFrame;
        MainThread(^{
            // Configure popover
            [self showInfoInInfoWindow:self.authInfoWindow details:reason title:@"Authorization is required to:"];
            authorizationViewLockIconFrame = [self authorizationViewLockIconFrame];

            // Darken background
            self.authorizationModalMask.animator.hidden = NO;
        });
        
        // Show popover and block this (background) thread until shown
        [self.authPopover showRelativeToRect:authorizationViewLockIconFrame ofView:self.authorizationView preferredEdge:NSRectEdgeMaxY waitUntilShownWithTimeout:2.0];
    }

    // Authorize
    __block BOOL authorized;
    MainThread(^{
        self.authorizationView.flags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed;
        authorized = [self.authorizationView authorize:self];
        self.authorizationView.flags = authorized ? kAuthorizationFlagDefaults : kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights;
        [self.authorizationView updateStatus:nil];
    });
    
    // Hide popover, remove background darkening
    if (auth.reason.count > 0) {
        MainThread(^{
            [self.authPopover close];
            self.authorizationModalMask.animator.hidden = YES;
        });
    }

    // Re-enable clicks / keypresses, but discard any stalled while password prompt was shown
    ((PGPrefsToggleEventsView *) self.mainView).ignoresEvents = NO;
    [self.mainView.window discardEventsMatchingMask:NSEventMaskAny beforeEvent:nil];

    return authorized ? self.authorizationView.authorization.authorizationRef : nil;
}

- (void)deauthorize
{
    [self.authorizationView deauthorize:self.authorizationView.authorization];
    
    [self.mainView.window makeFirstResponder:self.serversTableView];
}

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view
{
    self.authorizationView.flags = kAuthorizationFlagDefaults;
    
    view.autoupdate = YES;
    [self.controller viewDidAuthorize:view.authorization.authorizationRef];
}

- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view
{
    view.autoupdate = NO;
    self.authorizationView.flags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights;
    
    [self.controller viewDidDeauthorize];
}

- (CGRect)authorizationViewLockIconFrame
{
    // Search for lock icon subview
    __block NSView *lockIcon = nil;
    [self.authorizationView enumerateAllSubviewsUsingBlock:^(NSView *subview, BOOL *stop) {
        if ([NSStringFromClass([subview class]) containsString:@"Lock"]) {
            lockIcon = subview;
            *stop = YES;
        }
    }];
    
    // Calculate its frame
    if (lockIcon) {
        if (lockIcon.superview == self.authorizationView) {
            return lockIcon.frame;
        } else {
            return [lockIcon.superview convertRect:lockIcon.frame toView:self.authorizationView];
        }
    } else {
        return CGRectZero;
    }
}



#pragma mark Apply/Revert Settings

- (IBAction)changeSettingsClicked:(id)sender
{
    [self.controller userWillEditSettings];
}
- (IBAction)resetSettingsClicked:(id)sender
{
    [self.controller userDidRevertSettings];
}
- (IBAction)applySettingsClicked:(id)sender
{
    [self.mainView.window endSheet:self.serverSettingsWindow returnCode:NSModalResponseOK];
}
- (IBAction)cancelSettingsClicked:(id)sender
{
    [self.mainView.window endSheet:self.serverSettingsWindow returnCode:NSModalResponseCancel];
}



#pragma mark Servers

- (IBAction)serversButtonClicked:(NSSegmentedControl *)sender
{
    [self.mainView.window makeFirstResponder:self.serversTableView];
    
    switch (sender.selectedSegment) {
        case 0:
            [self.controller userDidAddServer];
            break;
        case 1:
            [self.controller userDidDeleteServer];
            break;
        case 2:
            // Ignore - popup handled separately
            break;
        default:
            break; // Invalid segment
    }
}

- (IBAction)renameServerClicked:(id)sender
{
    [self showServerRenameWindow:self.server];
}

- (IBAction)cancelRenameServerClicked:(id)sender
{
    [self.mainView.window endSheet:self.renameServerWindow returnCode:NSModalResponseCancel];
}

- (IBAction)okRenameServerClicked:(id)sender
{
    if (![self.controller userCanRenameServer:self.renameServerWindow.nameField.stringValue]) return;
    
    [self.mainView.window endSheet:self.renameServerWindow returnCode:NSModalResponseOK];
}

- (IBAction)duplicateServerClicked:(id)sender
{
    [self.controller userDidDuplicateServer];
}

- (IBAction)refreshServersClicked:(id)sender
{
    [self.controller userDidRefreshServers];
}
     
- (void)menuWillOpen:(NSMenu *)menu
{
    [self.mainView.window makeFirstResponder:self.serversTableView];
    
}



#pragma mark Start/Stop

- (IBAction)startStopClicked:(id)sender
{
    [self.controller userDidStartStopServer];
}



#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    // Servers
    if (tableView == self.serversTableView) {
        NSInteger result = MAX(self.servers.count+1, 1);
        DLog(@"Servers Table Rows: %@", @(result));
        return result;
        
    // Search servers
    } else if (tableView == self.serverSettingsWindow.serversTableView) {
        NSInteger result = self.searchServers.count;
        DLog(@"Search Servers Table Rows: %@", @(result));
        return result;
    }
    
    return 0;
}
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors

{
    if (tableView != self.serverSettingsWindow.serversTableView) return;
    
    self.searchServers = [self.searchServers sortedArrayUsingDescriptors:tableView.sortDescriptors];
    [tableView reloadData];
}



#pragma mark Delete Confirmation

- (IBAction)cancelDeleteServerClicked:(id)sender
{
    [self.mainView.window endSheet:self.deleteServerWindow returnCode:PGDeleteServerCancelButton];
}

- (IBAction)deleteServerDeleteFileClicked:(id)sender
{
    [self.mainView.window endSheet:self.deleteServerWindow returnCode:PGDeleteServerDeleteFileButton];
}

- (IBAction)deleteServerKeepFileClicked:(id)sender
{
    [self.mainView.window endSheet:self.deleteServerWindow returnCode:PGDeleteServerKeepFileButton];
}

- (IBAction)deleteServerShowInFinderClicked:(id)sender
{
    [self.controller userDidDeleteServerShowInFinder];
}



#pragma mark NSTableViewDelegate

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    // Servers
    if (tableView == self.serversTableView) {
        return row == 0 ? 21 : 40;

    // Search servers
    } else if (tableView == self.serverSettingsWindow.serversTableView) {
        return 18;
    }
    return 44;
}
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    // Servers
    if (tableView == self.serversTableView) {
        if (row == 0) return NO;
        if (!self.updatingDisplay) [self.controller userDidSelectServer:self.servers[row-1]];
        // Always scroll to beginning of table when selecting top-most datacell
        // That way, header cell is visible, rather than tending to be 'off-screen'
        if (row == 1) [tableView scrollToBeginningOfDocument:self];
        return YES;
        
    // Search servers
    } else if (tableView == self.serverSettingsWindow.serversTableView) {
        [self.controller userDidSelectSearchServer:self.searchServers[row]];
        return YES;
    }
    
    return YES;
}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    // Servers
    if (tableView == self.serversTableView) {
        // Header
        if (row == 0) {
            PGPrefsServersHeaderCell *result = [tableView makeViewWithIdentifier:@"HeaderCell" owner:self];
            result.textField.stringValue = @"DATABASE SERVERS";
            result.refreshButton.hidden = !PGPrefsRefreshServersEnabled;
            return result;
            
        // Server
        } else {
            PGPrefsServersCell *result = [tableView makeViewWithIdentifier:@"DataCell" owner:self];
            PGServer *server = self.servers[row-1];
            [self configureServersCell:result forServer:server];
            return result;
        }
    
    // Search servers
    } else if (tableView == self.serverSettingsWindow.serversTableView) {
        
        PGServer *server = self.searchServers.count == 0 ? nil : self.searchServers[row];
        NSString *cellIdentifier = nil;
        NSString *value = nil;
        
        // Name
        if ([tableColumn.identifier isEqualToString:@"Name"]) {
            cellIdentifier = @"NameCell";
            value = server.shortName;
            
        // Domain
        } else if ([tableColumn.identifier isEqualToString:@"Domain"]) {
            cellIdentifier = @"DomainCell";
            value = server.domain;
            if (!NonBlank(value)) { value = @"-"; }
            
        // Unknown
        } else return nil;

        NSTableCellView *result = [tableView makeViewWithIdentifier:cellIdentifier owner:self];
        result.textField.stringValue = value?:@"";
        return result;
    }
    
    return nil;
}
- (void)configureServersCell:(PGPrefsServersCell *)cell forServer:(PGServer *)server
{
    // Name
    cell.textField.stringValue = server.shortName ?: @"Name Not Found";
    cell.externalIcon.hidden = !server.external;
    
    // Fix icon spacing on macOS prior to Big Sur
    // (because lock image is wider and looks too cramped)
    if (@available(macOS 11, *)) {
        // Do nothing
    } else {
        cell.externalIconSpacing.constant = server.external ? 5 : 2;
    }
    
    // Icon & Status
    NSString *statusText = NSStringFromPGServerStatus(server.status);
    NSString *imageName = nil;
    switch (server.status) {
        case PGServerStarted:
            if (NonBlank(server.settings.port)) statusText = [NSString stringWithFormat:@"%@ on port %@", statusText, server.settings.port];
            imageName = NSImageNameStatusAvailable;
            break;
        case PGServerStopped:
            imageName = NSImageNameStatusUnavailable;
            break;
        case PGServerRetrying: // Fall through
        case PGServerStarting: // Fall through
        case PGServerStopping: // Fall through
        case PGServerDeleting: // Fall through
        case PGServerUpdating:
            imageName = NSImageNameStatusPartiallyAvailable;
            break;
        default:
            imageName = NSImageNameStatusNone;
    }
    cell.statusTextField.stringValue = statusText;
    cell.imageView.image = [NSImage imageNamed:imageName];
}



#pragma mark PGPrefsViewController

- (void)prefsController:(PGPrefsController *)controller willEditServerSettings:(PGServer *)server
{
    [self showServerSettingsWindow:server];
}
- (void)prefsController:(PGPrefsController *)controller didChangeServers:(NSArray *)servers
{
    self.updatingDisplay = YES;
 
    DLog(@"Servers: %@", @(servers.count));
    
    PGServer *server = [self selectedServer];
    self.servers = servers;
    [self.serversTableView reloadData];
    [self selectServer:server];
    
    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didChangeSelectedServer:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self selectServer:server];
    [self showServerInMainServerView:server];
    
    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didChangeServerStatus:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    if ([self selectedServer] == server) [self showStatusInMainServerView:server];
    
    [self showServerInServersTable:server];
    
    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didChangeServerSetting:(NSString *)setting server:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self showDirtyInSettingsWindow:server];

    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didChangeServerSettings:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self showSettingsInSettingsWindow:server];
    
    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didApplyServerSettings:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self selectServer:server];
    [self showSettingsInMainServerView:server];
    [self showServerInServersTable:server];

    self.updatingDisplay = NO;
}

- (void)prefsController:(PGPrefsController *)controller didRevertServerSettings:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self showSettingsInSettingsWindow:server];
    [self.serverSettingsWindow.serversTableView deselectAll:self];

    self.updatingDisplay = NO;
}
- (void)prefsController:(PGPrefsController *)controller didRevertServerStartup:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    if (server.settings.startup != self.startup) [self performSelector:@selector(showServerStartup:) withObject:server afterDelay:0.0];
    
    self.updatingDisplay = NO;
    
}
- (void)prefsController:(PGPrefsController *)controller didChangeSearchServers:(NSArray *)servers
{
    self.updatingDisplay = YES;
    
    NSArray *sortDescriptors = self.serverSettingsWindow.serversTableView.sortDescriptors;
    
    if (sortDescriptors.count == 0) sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"shortName" ascending:YES]];
    
    self.searchServers = [servers sortedArrayUsingDescriptors:sortDescriptors];
    self.serverSettingsWindow.serversTableView.sortDescriptors = sortDescriptors;
    
    [self.serverSettingsWindow.serversTableView reloadData];
    
    self.updatingDisplay = NO;
}
- (void)prefsController:(PGPrefsController *)controller willConfirmDeleteServer:(PGServer *)server
{
    self.updatingDisplay = YES;
    
    [self showServerDeleteWindow:server];
    
    self.updatingDisplay = NO;
}



#pragma mark Private

- (NSUInteger)rowForServer:(PGServer *)server
{
    NSUInteger result = [self.servers indexOfObject:server];
    return result == NSNotFound ? result : result+1;
}

- (PGServer *)selectedServer
{
    if (self.servers.count == 0) return nil;
    
    NSInteger row = self.serversTableView.selectedRow;
    
    if (row < 0 || row-1 >= self.servers.count) return nil;
    
    return self.servers[row-1];
}

- (void)selectServer:(PGServer *)server
{
    NSUInteger row = [self.servers indexOfObject:server];
    if (row == NSNotFound) return;
    
    [self.serversTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
    
    [self.mainView.window makeFirstResponder:self.serversTableView];
}

- (void)showStatusWithName:(NSString *)name colour:(NSColor *)colour image:(NSString *)image info:(NSString *)info startStopButton:(NSString *)startStopButton
{
    NSString *imagePath = [[self bundle] pathForResource:image ofType:@"png"];
    
    self.statusField.stringValue = name;
    self.statusField.textColor = colour;
    self.statusImage.image = [[NSImage alloc] initWithContentsOfFile:imagePath];
    if (info) self.infoField.stringValue = info;
    if (startStopButton) self.startStopButton.title = startStopButton;
}
- (void)showStarted
{
    [self showStatusWithName:@"Running"
                      colour:PGServerStartedColor
                       image:PGServerStartedImage
                        info:@"The PostgreSQL Database Server is started and ready for client connections.\nTo shut down the server, use the \"Stop PostgreSQL\" button."
             startStopButton:@"Stop PostgreSQL"];
}

- (void)showStopped
{
    [self showStatusWithName:@"Stopped"
                      colour:PGServerStoppedColor
                       image:PGServerStoppedImage
                        info:@"The PostgreSQL Database Server is currently stopped.\nTo start it, use the \"Start PostgreSQL\" button."
             startStopButton:@"Start PostgreSQL"];
}

- (void)showStarting
{
    [self showStatusWithName:@"Starting..."
                      colour:PGServerStartingColor
                       image:PGServerStartingImage
                        info:nil
             startStopButton:nil];
}

- (void)showStopping
{
    [self showStatusWithName:@"Stopping..."
                      colour:PGServerStoppingColor
                       image:PGServerStoppingImage
                        info:nil
             startStopButton:nil];
}

- (void)showDeleting
{
    [self showStatusWithName:@"Removing..."
                      colour:PGServerDeletingColor
                       image:PGServerDeletingImage
                        info:nil
             startStopButton:nil];
}

- (void)showChecking
{
    [self showStatusWithName:@"Checking..."
                      colour:PGServerCheckingColor
                       image:PGServerCheckingImage
                        info:@"The running status of the PostgreSQL Database Server is currently being checked."
             startStopButton:@"PostgreSQL"];
}

- (void)showRetrying
{
    [self showStatusWithName:@"Retrying..."
                      colour:PGServerRetryingColor
                       image:PGServerRetryingImage
                        info:@"The PostgreSQL Database Server has failed to start. Please view the log for details."
             startStopButton:@"Stop PostgreSQL"];
}

- (void)showUpdating
{
    [self showStatusWithName:@"Updating..."
                      colour:PGServerUpdatingColor
                       image:PGServerUpdatingImage
                        info:@"The running status of the PostgreSQL Database Server is not currently known.\nPlease check the server settings and try again."
             startStopButton:@"PostgreSQL"];
}

- (void)showUnknown
{
    [self showStatusWithName:@"Unknown"
                      colour:PGServerStatusUnknownColor
                       image:PGServerStatusUnknownImage
                        info:@"The running status of the PostgreSQL Database Server is not currently known.\nPlease check the server settings and try again."
             startStopButton:@"PostgreSQL"];
}

- (void)showError:(NSString *)details title:(NSString *)title
{
    // No error
    if (!details) {
        self.errorField.stringValue = @"";
        self.errorView.hidden = YES;
        self.infoField.hidden = NO;
        
    // Error
    } else {
        self.errorField.stringValue = details;
        self.errorView.hidden = NO;
        self.infoField.hidden = YES;
    }
    
    [self showInfoInInfoWindow:self.errorWindow details:(details ? [[NSAttributedString alloc] initWithString:details] : nil) title:title];
}
- (void)showInfoInInfoWindow:(PGPrefsInfoWindow *)window details:(NSAttributedString *)details title:(NSString *)title
{
    [window.detailsView setAttributedStringUsingStoryboardStyle:details];
    window.titleField.stringValue = title ?: @"";
    
    // This line is required on macOS High Sierra (but not Catalina)
    // to ensure the new string is displayed when then window is shown
    // just before showing the authorization password prompt.
    [window.detailsView setNeedsLayout:YES];
}

- (void)showDirtyInSettingsWindow:(PGServer *)server
{
    self.serverSettingsWindow.revertSettingsButton.enabled = server.dirty;
    self.serverSettingsWindow.applySettingsButton.enabled = server.dirty;
    
    PGServerSettings *settings = server.dirtySettings;
    self.serverSettingsWindow.invalidUsernameImage.hidden = !settings.invalidUsername;
    self.serverSettingsWindow.invalidBinDirectoryImage.hidden = !settings.invalidBinDirectory;
    self.serverSettingsWindow.invalidDataDirectoryImage.hidden = !settings.invalidDataDirectory;
    self.serverSettingsWindow.invalidLogFileImage.hidden = !settings.invalidLogFile;
    self.serverSettingsWindow.invalidPortImage.hidden = !settings.invalidPort;
}
- (void)focusInvalidInSettingsWindow:(PGServer *)server
{
    // Focus on problem field
    NSControl *focus = self.serverSettingsWindow.serversTableView;
    PGServerSettings *settings = server.dirtySettings;
    if (settings.invalidBinDirectory)
        focus = self.serverSettingsWindow.binDirectoryField;
    else if (settings.invalidDataDirectory)
        focus = self.serverSettingsWindow.dataDirectoryField;
    [self.serverSettingsWindow makeFirstResponder:focus];
}
- (void)showSettingsInSettingsWindow:(PGServer *)server
{
    PGServerSettings *settings = server.dirtySettings;
    self.serverSettingsWindow.usernameField.stringValue = settings.username?:@"";
    self.serverSettingsWindow.binDirectoryField.stringValue = settings.binDirectory?:@"";
    self.serverSettingsWindow.dataDirectoryField.stringValue = settings.dataDirectory?:@"";
    self.serverSettingsWindow.logFileField.stringValue = settings.logFile?:@"";
    self.serverSettingsWindow.portField.stringValue = settings.port?:@"";
    
    self.serverSettingsWindow.invalidUsernameImage.hidden = !settings.invalidUsername;
    self.serverSettingsWindow.invalidBinDirectoryImage.hidden = !settings.invalidBinDirectory;
    self.serverSettingsWindow.invalidDataDirectoryImage.hidden = !settings.invalidDataDirectory;
    self.serverSettingsWindow.invalidLogFileImage.hidden = !settings.invalidLogFile;
    self.serverSettingsWindow.invalidPortImage.hidden = !settings.invalidPort;
    
    [self showDirtyInSettingsWindow:server];
}
- (void)showSettingsInMainServerView:(PGServer *)server
{
    PGServerSettings *settings = server.settings;
    self.usernameField.stringValue = settings.username?:@"";
    self.binDirectoryField.stringValue = settings.binDirectory?:@"";
    self.dataDirectoryField.stringValue = settings.dataDirectory?:@"";
    self.logFileField.stringValue = settings.logFile?:@"";
    self.portField.stringValue = settings.port?:@"";
    
    self.invalidUsernameImage.hidden = !settings.invalidUsername;
    self.invalidBinDirectoryImage.hidden = !settings.invalidBinDirectory;
    self.invalidDataDirectoryImage.hidden = !settings.invalidDataDirectory;
    self.invalidLogFileImage.hidden = !settings.invalidLogFile;
    self.invalidPortImage.hidden = !settings.invalidPort;
    
    self.logEnabled = server.daemonLogExists;
    self.editEnabled = server.editable;
    self.startStopEnabled = server.actionable;
    
    [self showServerStartup:self.server];
}
- (void)showServerStartup:(PGServer *)server;
{
    self.startup = server.settings.startup;
}
- (void)showStatusInMainServerView:(PGServer *)server
{
    [self showError:server.error title:[NSString stringWithFormat:@"Unable to %@", NSStringFromPGServerActionVerb(server.errorDomain)]];
    [self showSettingsInMainServerView:server]; // Validity might have changed
    
    switch (server.status) {
        case PGServerStarted: [self showStarted]; break;
        case PGServerStarting: [self showStarting]; break;
        case PGServerStopping: [self showStopping]; break;
        case PGServerStopped: [self showStopped]; break;
        case PGServerDeleting: [self showDeleting]; break;
        case PGServerRetrying: [self showRetrying]; break;
        case PGServerUpdating: [self showUpdating]; break;
        default: [self showUnknown]; break;
    }
    
    self.logEnabled = server.daemonLogExists;
    self.editEnabled = server.editable;
    self.startStopEnabled = server.actionable;
    
    self.startStopButton.hidden = server.status == PGServerStatusUnknown;
    self.enabled = !server.processing;
    
    if (server.processing) [self.statusSpinner startAnimation:self];
    else [self.statusSpinner stopAnimation:self];
}

- (void)showServerInMainServerView:(PGServer *)server
{
    DLog(@"%@", server);
    
    self.server = server;
    
    // No server
    if (!server) {
        [self.serverNoServerTabs selectTabViewItemWithIdentifier:@"noserver"];
        self.authorizationView.hidden = YES;
        self.serversButtons.hidden = YES;
        self.noServersButtons.hidden = NO;
        
        // Reset buttons
        self.editEnabled = YES;
        self.logEnabled = YES;
        self.startStopEnabled = YES;
        self.startup = PGServerStartupManual;
        
        // Disable everything except "Add server" button
        self.enabled = NO;
        
    // Server
    } else {
        [self.serverNoServerTabs selectTabViewItemWithIdentifier:@"server"];
        self.authorizationView.hidden = NO;
        self.serversButtons.hidden = NO;
        self.noServersButtons.hidden = YES;
        
        [self showSettingsInMainServerView:server];
        [self showStatusInMainServerView:server];
    }
}

- (void)showServerInServersTable:(PGServer *)server
{
    NSUInteger row = [self rowForServer:server];
    
    if (row == NSNotFound) return;
    
    [self.serversTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)showServerSettingsWindow:(PGServer *)server
{
    [self.serverSettingsWindow.serversTableView deselectAll:self];
    [self.serverSettingsWindow.serversTableView scrollRowToVisible:0];
    [self showSettingsInSettingsWindow:server];
    [self focusInvalidInSettingsWindow:server];
    
    weakify(self);
    [self.mainView.window beginSheet:self.serverSettingsWindow completionHandler:^(NSModalResponse returnCode) {
        strongify(self);
        
        [self.serverSettingsWindow orderOut:self];
        
        // Cancelled
        if (returnCode == NSModalResponseCancel) {
            [self.controller userDidCancelSettings];
            
        // Apply
        } else {
            [self.controller userDidApplySettings];
        }
    }];

    [self.serverSettingsWindow orderFront:self];
}

- (void)showServerRenameWindow:(PGServer *)server
{
    self.renameServerWindow.nameField.stringValue = server.name;
    
    weakify(self);
    [self.mainView.window beginSheet:self.renameServerWindow completionHandler:^(NSModalResponse returnCode) {
        strongify(self);
        
        [self.renameServerWindow orderOut:self];
        
        // Cancelled
        if (returnCode == NSModalResponseCancel) {
            [self.controller userDidCancelRenameServer];
            
        // Apply
        } else {
            [self.controller userDidRenameServer:self.renameServerWindow.nameField.stringValue];
        }
    }];

    [self.renameServerWindow orderFront:self];
}

- (void)showServerDeleteWindow:(PGServer *)server
{
    self.deleteServerWindow.daemonFile.stringValue = [server.daemonFile lastPathComponent];
    self.deleteServerWindow.daemonDir.stringValue = [NSString stringWithFormat:@"In: %@", [server.daemonFile stringByDeletingLastPathComponent]];
    
    weakify(self);
    [self.mainView.window beginSheet:self.deleteServerWindow completionHandler:^(NSModalResponse returnCode) {
        strongify(self);
        
        [self.deleteServerWindow orderOut:self];
        
        // Cancelled
        if (returnCode == PGDeleteServerCancelButton) {
            [self.controller userDidCancelDeleteServer];
        
        // Keep File
        } else if (returnCode == PGDeleteServerKeepFileButton) {
            [self.controller userDidDeleteServerKeepFile];
            
        // Delete File
        } else {
            [self.controller userDidDeleteServerDeleteFile];
        }
    }];

    [self.deleteServerWindow orderFront:self];
}

- (void)showInfoWindow:(PGPrefsInfoWindow *)window
{
    weakify(self);
    [self.mainView.window beginSheet:window completionHandler:^(NSModalResponse returnCode) {
        strongify(self);
        
        [window orderOut:self];
    }];
    
    [window orderFront:self];
}
- (void)closeInfoWindow:(PGPrefsInfoWindow *)window
{
    [self.mainView.window endSheet:window];
}

- (IBAction)showErrorWindowClicked:(id)sender
{
    if (self.errorWindow.detailsView.string.length == 0) { return; }
    
    [self showInfoWindow:self.errorWindow];
}
- (IBAction)closeErrorWindowClicked:(id)sender
{
    [self closeInfoWindow:self.errorWindow];
}

// Fix for macOS High Sierra (not compatible with asset catalog colors)
- (void)setTextInfoColorIfNotCompatibleWithAssetCatalog:(NSTextField *)textField
{
    if (textField.textColor.type == NSColorTypeCatalog &&
        !textField.textColor.colorNameComponent) {
        textField.textColor = PGServerInfoColor;
    }
}

// Fix for macOS High Sierra (not compatible with asset catalog images)
- (void)setImageIfNotCompatibleWithAssetCatalog:(NSImageView *)imageView imageName:(NSString *)imageName
{
    if (!imageView.image) {
        imageView.image = [NSImage imageNamed:imageName];
    }
}

@end
