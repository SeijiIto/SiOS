//
//  LMGameControllerManager.m
//  SiOS
//
//  Created by Adam Bell on 12/22/2013.
//
//

#import "LMGameControllerManager.h"

#import <GameController/GameController.h>

#import "../SNES9XBridge/Snes9xMain.h"

@implementation LMGameControllerManager(Privates)

#pragma mark Game Controller Handling

- (void)LM_setupController
{
	if([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0f)
	{
		NSArray* controllers = [GCController controllers];
		// Grab first controller
		// TODO: Add support for multiple controllers
		_gameController = [controllers firstObject];
		
		[self LM_setupController:_gameController forPlayerIndex:0];
		if (_gameController) {
			[self.delegate gameControllerManagerGamepadDidConnect:self];
		} else {
			[self.delegate gameControllerManagerGamepadDidDisconnect:self];
		}
	}
}

- (void)LM_setupController:(GCController *)aController forPlayerIndex:(int)aPlayerIndex {

	aController.playerIndex = aPlayerIndex;
	
	// callback block creation helper block
	GCControllerButtonValueChangedHandler (^buttonValueChangeHandlerWithButtonConstant)(int) = ^(int buttonConstant) {
		buttonConstant += (aPlayerIndex * (kSIOS_2PX - kSIOS_1PX)); // shift it up if not for first player
		GCControllerButtonValueChangedHandler result = ^(GCControllerButtonInput *button, float value, BOOL pressed) {
			if (pressed) {
				SISetControllerPushButton(buttonConstant);
			} else {
				SISetControllerReleaseButton(buttonConstant);
			}
		};
		return result;
	};
	
	// helper block to setup up,down,left,right handlers for a element that has these button properties
	void (^setupDirectionalElement)(id) = ^(id directionalElement){
		[directionalElement up].valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PUp);
		[directionalElement down].valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PDown);
		[directionalElement left].valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PLeft);
		[directionalElement right].valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PRight);
	};
	
	if (aController) {
		GCGamepad *gamepad = _gameController.gamepad;
		
		if (_gameController.extendedGamepad) {
			gamepad = (id)_gameController.extendedGamepad;

			GCExtendedGamepad* extendedGamepad = _gameController.extendedGamepad;
			extendedGamepad.leftTrigger.valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PSelect);
			extendedGamepad.rightTrigger.valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PStart);
			setupDirectionalElement(extendedGamepad.leftThumbstick);
		}

		// You should swap A+B / X+Y because it feels awkward on Gamepad
		gamepad.buttonA.valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PB);
		gamepad.buttonB.valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PA);
		gamepad.buttonX.valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PY);
		gamepad.buttonY.valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PX);

		setupDirectionalElement(gamepad.dpad);
		
		gamepad.leftShoulder.valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PL);
		gamepad.rightShoulder.valueChangedHandler = buttonValueChangeHandlerWithButtonConstant(kSIOS_1PR);
		
	}
	
	// setup pause button
	
	_gameController.controllerPausedHandler = ^(GCController *controller) {
		SEL optionsSelector = @selector(LM_options:);
		UIViewController *topViewController = [[[[UIApplication sharedApplication] windows] firstObject] rootViewController];
		while (topViewController.presentedViewController) {
			topViewController = topViewController.presentedViewController;
		}
		if ([topViewController respondsToSelector:optionsSelector]) {
			[topViewController performSelector:optionsSelector withObject:nil afterDelay:0.0];
		}
	};
}

@end

#pragma mark -

@implementation LMGameControllerManager

- (BOOL)gameControllerConnected {
	BOOL result = (_gameController != nil);
	return result;
}

+ (instancetype)sharedInstance {
  static dispatch_once_t p = 0;
  
  __strong static id _sharedInstance = nil;
  
  dispatch_once(&p, ^{
    _sharedInstance = [[self alloc] init];
  });
  
  return _sharedInstance;
}

+ (BOOL)gameControllersMightBeAvailable {
	if ([GCController class] != nil) {
		return YES;
	}
	return NO;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		[GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
			[self LM_setupController];
		}];
		
		[self LM_setupController];
		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
		[defaultCenter addObserver:self
						  selector:@selector(LM_setupController)
							  name:GCControllerDidConnectNotification
							object:nil];
		[defaultCenter addObserver:self
						  selector:@selector(LM_setupController)
							  name:GCControllerDidDisconnectNotification
							object:nil];
		[defaultCenter addObserver:self
						  selector:@selector(LM_setupController)
							  name:UIApplicationDidBecomeActiveNotification
							object:nil];
		
	}
	return self;
}

- (void)dealloc {
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter removeObserver:self
							 name:GCControllerDidConnectNotification
						   object:nil];
	[defaultCenter removeObserver:self
							 name:GCControllerDidDisconnectNotification
						   object:nil];
	[defaultCenter removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

@end
