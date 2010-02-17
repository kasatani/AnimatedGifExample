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
    
    // Local example
    NSURL * url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"apple_logo_animated" ofType:@"gif"]];
    
    // HTTP example..
    //NSURL * url = [NSURL URLWithString:@"http://www.gifs.net/Animation11/Food_and_Drinks/Fruits/Apple_jumps.gif"];
    
    // Magic line
    UIImageView * animation = [AnimatedGif getAnimationForGifAtUrl: url];
    
    // Add it to the view.
	[theAnimatedGif addSubview:animation];
    
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.

    [super didReceiveMemoryWarning];
}

@end
