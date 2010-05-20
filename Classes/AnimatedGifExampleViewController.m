//
//  AnimatedGifExampleViewController.m
//  AnimatedGifExample
//
//  Created by Stijn Spijker on 05-07-09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import "AnimatedGifExampleViewController.h"

@implementation AnimatedGifExampleViewController

//
// viewDidLoad
//
// Get's the animated gif, and places it on the view.
//
- (void)viewDidLoad
{
	[super viewDidLoad];
    
    // First example, a local file
    NSURL 			* firstUrl = 		[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"apple_logo_animated" ofType:@"gif"]];
    UIImageView 	* firstAnimation = 	[AnimatedGif getAnimationForGifAtUrl: firstUrl];
    
    // HTTP example..
    //NSURL * url = [NSURL URLWithString:@"http://www.gifs.net/Animation11/Food_and_Drinks/Fruits/Apple_jumps.gif"];
    
    // Magic line
    animation = [AnimatedGif getAnimationForGifAtUrl: url];
    
    // Add it to the view.
	[theAnimatedGif addSubview:animation];

    // Second example, through HTTP
    NSURL 		* secondUrl = 			[NSURL URLWithString:@"http://www.gifs.net/Animation11/Food_and_Drinks/Fruits/Apple_jumps.gif"];
    UIImageView * secondAnimation = 	[AnimatedGif getAnimationForGifAtUrl: secondUrl];

    
    // Add them to the view.
	[theFirstAnimatedGif addSubview:firstAnimation];
	[theSecondAnimatedGif addSubview:secondAnimation];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.

    [super didReceiveMemoryWarning];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	NSURL *url = [NSURL URLWithString:textField.text];
	if (url) {
		[animation removeFromSuperview];
		animation = [AnimatedGif getAnimationForGifAtUrl:url];
		[theAnimatedGif addSubview:animation];
	}
	
	[textField resignFirstResponder];
	return YES;
}

@end
