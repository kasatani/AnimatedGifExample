//
//  AnimatedGif.m
//
//  Created by Stijn Spijker (http://www.stijnspijker.nl/) on 2009-07-03.
//  Based on gifdecode written april 2009 by Martin van Spanje, P-Edge media.
//  
//  Changes on gifdecode:
//  - Small optimizations (mainly arrays)
//  - Object Orientated Approach
//  - Added the Graphic Control Extension Frame for transparancy
//  - Changed header to GIF89a
//  - Added methods for ease-of-use
//  - Added animations with transparancy
//  - No need to save frames to the filesystem anymore
//
//  Changelog:
//
//  2010-01-24: Rework of the entire module, adding static methods, better memory management and URL asynchronous loading
//  2009-10-08: Added dealloc method, and removed leaks, by Pedro Silva
//  2009-08-10: Fixed double release for array, by Christian Garbers
//  2009-06-05: Initial Version
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//  

#import "AnimatedGif.h"

@implementation AnimatedGifFrame

@synthesize data, delay, disposalMethod, area, header, transparentColorIndex, backgroundColor;

- (id) init
{
	self = [super init];
	if (self != nil) {
		transparentColorIndex = -1;
	}
	return self;
}

- (void) dealloc
{
	[data release];
	[header release];
	[backgroundColor release];
	[super dealloc];
}


@end

@implementation AnimatedGif

static AnimatedGif * instance;

@synthesize imageView;

+ (AnimatedGif *) sharedInstance
{
    if (instance == nil)
    {
        instance = [[AnimatedGif alloc] init];
    }
    
    return instance;
}

+ (UIImageView *) getAnimationForGifAtUrl:(NSURL *)animationUrl
{   
    [[AnimatedGif sharedInstance] setImageView: [[UIImageView alloc] init]];
    
    // Asynchronous loading for URL's, else the GUI won't appear untill image is loaded.
    [[AnimatedGif sharedInstance] performSelector:@selector(asynchronousLoading:) withObject:[animationUrl retain] afterDelay:0.2];
    
    return [[AnimatedGif sharedInstance] imageView];
}

- (void) asynchronousLoading: (NSURL *) url
{
    NSData *data = [NSData dataWithContentsOfURL: url];
    [self decodeGIF: data];
    UIImageView *tempImageView = [self getAnimation];
    [imageView setImage: [tempImageView image]];
    [imageView sizeToFit];
    [imageView setAnimationImages: [tempImageView animationImages]];
    [imageView startAnimating];
    
    [url release];
}

// the decoder
// decodes GIF image data into separate frames
// based on the Wikipedia Documentation at:
//
// http://en.wikipedia.org/wiki/Graphics_Interchange_Format#Example_.gif_file
// http://en.wikipedia.org/wiki/Graphics_Interchange_Format#Animated_.gif
//
- (void)decodeGIF:(NSData *)GIFData
{
	GIF_pointer = GIFData;
    
    if (GIF_buffer != nil)
    {
        [GIF_buffer release];
    }
    
    if (GIF_global != nil)
    {
        [GIF_global release];
    }
    
    if (GIF_screen != nil)
    {
        [GIF_screen release];
    }
    
	[GIF_frames release];
	
    GIF_buffer = [[NSMutableData alloc] init];
	GIF_global = [[NSMutableData alloc] init];
	GIF_screen = [[NSMutableData alloc] init];
	GIF_frames = [[NSMutableArray alloc] init];
	
    // Reset file counters to 0 //
	dataPointer = 0;
	frameCounter = 0;
	
	[self GIFSkipBytes: 6]; // GIF89a, throw away
	[self GIFGetBytes: 7]; // Logical Screen Descriptor
	
    // Deep copy
	[GIF_screen setData: GIF_buffer];
	
    // Copy the read bytes into a local buffer on the stack
    // For easy byte access in the following lines.
    int length = [GIF_buffer length];
	unsigned char aBuffer[length];
	[GIF_buffer getBytes:aBuffer length:length];
	
	backgroundColorIndex = aBuffer[5];
	
	if (aBuffer[4] & 0x80) GIF_colorF = 1; else GIF_colorF = 0; 
	if (aBuffer[4] & 0x08) GIF_sorted = 1; else GIF_sorted = 0;
	GIF_colorC = (aBuffer[4] & 0x07);
	GIF_colorS = 2 << GIF_colorC;
	
	if (GIF_colorF == 1)
    {
		[self GIFGetBytes: (3 * GIF_colorS)];
        
        // Deep copy
		[GIF_global setData:GIF_buffer];
	}
	
	unsigned char bBuffer[1];
	while ([self GIFGetBytes:1] == YES)
    {
        [GIF_buffer getBytes:bBuffer length:1];
        
        if (bBuffer[0] == 0x3B)
        { // This is the end
            break;
        }
        
        switch (bBuffer[0])
        {
            case 0x21:
                // Graphic Control Extension (#n of n)
                [self GIFReadExtensions];
                break;
            case 0x2C:
                // Image Descriptor (#n of n)
                [self GIFReadDescriptor];
                break;
        }
	}
	
	// clean up stuff
	[GIF_buffer release];
    GIF_buffer = nil;
    
	[GIF_screen release];
    GIF_screen = nil;
        
	[GIF_global release];	
    GIF_global = nil;
}

// 
// Returns a subframe as NSMutableData.
// Returns nil when frame does not exist.
//
// Use this to write a subframe to the filesystems (cache etc);
- (NSData*) getFrameAsDataAtIndex:(int)index
{
	if (index < [GIF_frames count])
	{
		return ((AnimatedGifFrame *)[GIF_frames objectAtIndex:index]).data;
	}
	else
	{
		return nil;
	}
}

// 
// Returns a subframe as an autorelease UIImage.
// Returns nil when frame does not exist.
//
// Use this to put a subframe on your GUI.
- (UIImage*) getFrameAsImageAtIndex:(int)index
{
    NSData *frameData = [self getFrameAsDataAtIndex: index];
    UIImage *image = nil;
    
    if (frameData != nil)
    {
		image = [UIImage imageWithData:frameData];
    }
    
    return image;
}

//
// This method converts the arrays of GIF data to an animation, counting
// up all the seperate frame delays, and setting that to the total duration
// since the iPhone Cocoa framework does not allow you to set per frame
// delays.
//
// Returns nil when there are no frames present in the GIF, or
// an autorelease UIImageView* with the animation.
- (UIImageView*) getAnimation
{
	if ([GIF_frames count] > 0)
	{
        if (imageView != nil)
        {
            // This sets up the frame etc for the UIImageView by using the first frame.
            [imageView setImage:[self getFrameAsImageAtIndex:0]];
            [imageView sizeToFit];
        }
        else
        {
            imageView = [[UIImageView alloc] initWithImage:[self getFrameAsImageAtIndex:0]];
        }

		
		// Add all subframes to the animation
		NSMutableArray *array = [[NSMutableArray alloc] init];
		for (int i = 0; i < [GIF_frames count]; i++)
		{		
			[array addObject: [self getFrameAsImageAtIndex:i]];
		}
		
		NSMutableArray *overlayArray = [[NSMutableArray alloc] init];
		UIImage *firstImage = [array objectAtIndex:0];
		CGSize size = firstImage.size;
		CGRect rect = CGRectZero;
		rect.size = size;
		
		UIGraphicsBeginImageContext(size);
		CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextScaleCTM(ctx, 1.0, -1.0);
        CGContextTranslateCTM(ctx, 0.0, -size.height);
		
		int i = 0;
		int disposalMethod = 0;
		for (UIImage *image in array) {
			AnimatedGifFrame *frame = [GIF_frames objectAtIndex:i];
			switch (disposalMethod) {
				case 1:
					// Do not dispose
					break;
				case 2:
					// Restore to background color
					if (frame.transparentColorIndex >= 0 && 
						frame.transparentColorIndex == backgroundColorIndex) {
						CGContextClearRect(ctx, frame.area);
					} else {
						CGContextSetFillColorWithColor(ctx, [frame.backgroundColor CGColor]);
						CGContextFillRect(ctx, frame.area);
					}
					break;
				case 3:
					// TODO Restore to previous
					break;
			}
			CGContextDrawImage(ctx, rect, image.CGImage);
			[overlayArray addObject:UIGraphicsGetImageFromCurrentImageContext()];
			disposalMethod = frame.disposalMethod;
			i++;
		}
		UIGraphicsEndImageContext();
		
		[imageView setAnimationImages:overlayArray];
		
		[overlayArray release];
        [array release];
		
		// Count up the total delay, since Cocoa doesn't do per frame delays.
		double total = 0;
		for (AnimatedGifFrame *frame in GIF_frames) {
			total += frame.delay;
		}
		
		// GIFs store the delays as 1/100th of a second,
        // UIImageViews want it in seconds.
		[imageView setAnimationDuration:total/100];
		
		// Repeat infinite
		[imageView setAnimationRepeatCount:0];
		
        [imageView startAnimating];
        [imageView autorelease];
        
		return imageView;
	}
	else
	{
		return nil;
	}
}

- (void)GIFReadExtensions
{
	// 21! But we still could have an Application Extension,
	// so we want to check for the full signature.
	unsigned char cur[1], prev[1];
    [self GIFGetBytes:1];
    [GIF_buffer getBytes:cur length:1];
    
	while (cur[0] != 0x00)
    {
		
		// TODO: Known bug, the sequence F9 04 could occur in the Application Extension, we
		//       should check whether this combo follows directly after the 21.
		if (cur[0] == 0x04 && prev[0] == 0xF9)
		{
			[self GIFGetBytes:5];

			AnimatedGifFrame *frame = [[AnimatedGifFrame alloc] init];
			
			unsigned char buffer[5];
			[GIF_buffer getBytes:buffer length:5];
			frame.disposalMethod = (buffer[0] & 0x1c) >> 2;
			BOOL transparent = buffer[0] & 0x01;
			NSLog(@"flags=%x, dm=%x", (int)(buffer[0]), frame.disposalMethod);
			
			// We save the delays for easy access.
			frame.delay = (buffer[1] | buffer[2] << 8);
			
			if (transparent) {
				frame.transparentColorIndex = (int)buffer[3];
			}
			
			unsigned char board[8];
			board[0] = 0x21;
			board[1] = 0xF9;
			board[2] = 0x04;
			
			for(int i = 3, a = 0; a < 5; i++, a++)
			{
				board[i] = buffer[a];
			}
			
			frame.header = [NSData dataWithBytes:board length:8];
            
			[GIF_frames addObject:frame];
			[frame release];
			break;
		}
		
		prev[0] = cur[0];
        [self GIFGetBytes:1];
		[GIF_buffer getBytes:cur length:1];
	}	
}

- (void) GIFReadDescriptor
{	
	[self GIFGetBytes:9];
    
    // Deep copy
	NSMutableData *GIF_screenTmp = [NSMutableData dataWithData:GIF_buffer];
	
	unsigned char aBuffer[9];
	[GIF_buffer getBytes:aBuffer length:9];
	
	CGRect rect;
	rect.origin.x = ((int)aBuffer[1] << 8) | aBuffer[0];
	rect.origin.y = ((int)aBuffer[3] << 8) | aBuffer[2];
	rect.size.width = ((int)aBuffer[5] << 8) | aBuffer[4];
	rect.size.height = ((int)aBuffer[7] << 8) | aBuffer[6];

	AnimatedGifFrame *frame = [GIF_frames lastObject];
	frame.area = rect;
	
	if (aBuffer[8] & 0x80) GIF_colorF = 1; else GIF_colorF = 0;
	
	unsigned char GIF_code, GIF_sort;
	
	if (GIF_colorF == 1)
    {
		GIF_code = (aBuffer[8] & 0x07);
        
		if (aBuffer[8] & 0x20)
        {
            GIF_sort = 1;
        }
        else
        {
        	GIF_sort = 0;
        }
	}
    else
    {
		GIF_code = GIF_colorC;
		GIF_sort = GIF_sorted;
	}
	
	int GIF_size = (2 << GIF_code);
	
	size_t blength = [GIF_screen length];
	unsigned char bBuffer[blength];
	[GIF_screen getBytes:bBuffer length:blength];
	
	bBuffer[4] = (bBuffer[4] & 0x70);
	bBuffer[4] = (bBuffer[4] | 0x80);
	bBuffer[4] = (bBuffer[4] | GIF_code);
	
	if (GIF_sort)
    {
		bBuffer[4] |= 0x08;
	}
	
    NSMutableData *GIF_string = [NSMutableData dataWithData:[[NSString stringWithString:@"GIF89a"] dataUsingEncoding: NSUTF8StringEncoding]];
	[GIF_screen setData:[NSData dataWithBytes:bBuffer length:blength]];
    [GIF_string appendData: GIF_screen];

	NSData *colorTable;
	if (GIF_colorF == 1)
    {
		[self GIFGetBytes:(3 * GIF_size)];
		colorTable = GIF_buffer;
	}
    else
    {
        colorTable = GIF_global;
	}
	unsigned char bgColorBuffer[3];
	[colorTable getBytes:bgColorBuffer range:NSMakeRange(backgroundColorIndex * 3, 3)];
	frame.backgroundColor = [UIColor colorWithRed:(float)bgColorBuffer[0] / 255
											green:(float)bgColorBuffer[1] / 255
											 blue:(float)bgColorBuffer[2] / 255
											alpha:1];
	[GIF_string appendData:colorTable];
	
	// Add Graphic Control Extension Frame (for transparancy)
	[GIF_string appendData:frame.header];
	
	char endC = 0x2c;
	[GIF_string appendBytes:&endC length:sizeof(endC)];
	
	size_t clength = [GIF_screenTmp length];
	unsigned char cBuffer[clength];
	[GIF_screenTmp getBytes:cBuffer length:clength];
	
	cBuffer[8] &= 0x40;
	
	[GIF_screenTmp setData:[NSData dataWithBytes:cBuffer length:clength]];
	
	[GIF_string appendData: GIF_screenTmp];
	[self GIFGetBytes:1];
	[GIF_string appendData: GIF_buffer];
	
	while (true)
    {
		[self GIFGetBytes:1];
		[GIF_string appendData: GIF_buffer];
		
		unsigned char dBuffer[1];
		[GIF_buffer getBytes:dBuffer length:1];
		
		long u = (long) dBuffer[0];
        
		if (u != 0x00)
        {
			[self GIFGetBytes:u];
			[GIF_string appendData: GIF_buffer];
        }
        else
        {
            break;
        }

	}
	
	endC = 0x3b;
	[GIF_string appendBytes:&endC length:sizeof(endC)];
	
	// save the frame into the array of frames
	frame.data = GIF_string;
}

/* Puts (int) length into the GIF_buffer from file, returns whether read was succesfull */
- (bool) GIFGetBytes: (int) length
{
    if (GIF_buffer != nil)
    {
        [GIF_buffer release]; // Release old buffer
        GIF_buffer = nil;
    }
    
	if ([GIF_pointer length] >= dataPointer + length) // Don't read across the edge of the file..
    {
		GIF_buffer = [[GIF_pointer subdataWithRange:NSMakeRange(dataPointer, length)] retain];
        dataPointer += length;
		return YES;
	}
    else
    {
        return NO;
	}
}

/* Skips (int) length bytes in the GIF, faster than reading them and throwing them away.. */
- (bool) GIFSkipBytes: (int) length
{
    if ([GIF_pointer length] >= dataPointer + length)
    {
        dataPointer += length;
        return YES;
    }
    else
    {
    	return NO;
    }

}

- (void) dealloc
{
    if (GIF_buffer != nil)
    {
	    [GIF_buffer release];
    }
    
    if (GIF_screen != nil)
    {
		[GIF_screen release];
    }
        
    if (GIF_global != nil)
    {
        [GIF_global release];
    }
    
	[GIF_frames release];

	[super dealloc];
}
@end
