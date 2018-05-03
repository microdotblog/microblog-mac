//
//  RFInstagramController.h
//  Snippets
//
//  Created by Manton Reece on 5/2/18.
//  Copyright © 2018 Riverfold Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RFInstagramController : NSWindowController <NSCollectionViewDelegate, NSCollectionViewDataSource>

@property (strong, nonatomic) IBOutlet NSTextField* summaryField;
@property (strong, nonatomic) IBOutlet NSTextField* hostnameField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator* progressBar;
@property (strong, nonatomic) IBOutlet NSCollectionView* collectionView;

@property (strong, nonatomic) NSString* path;
@property (strong, nonatomic) NSString* folder;
@property (strong, nonatomic) NSArray* photos; // NSDictionary

- (instancetype) initWithFile:(NSString *)path;

@end
