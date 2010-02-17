//
//  AnimatedGifExampleViewController.h
//  AnimatedGifExample
//
//  Created by Stijn Spijker on 05-07-09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AnimatedGif.h"

@interface AnimatedGifExampleViewController : UIViewController <UITextFieldDelegate> {

	IBOutlet UIImageView *theAnimatedGif;
	UIImageView *animation;
}

@end

