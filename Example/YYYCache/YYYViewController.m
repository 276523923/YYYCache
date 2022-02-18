//
//  YYYViewController.m
//  YYYCache
//
//  Created by 276523923@qq.com on 04/25/2018.
//  Copyright (c) 2018 276523923@qq.com. All rights reserved.
//

#import "YYYViewController.h"
@import YYYCache;

@interface YYYViewController ()

@end

@implementation YYYViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    YYYCache *cache = [YYYCache sharedCache];
    
//    [cache setObject:@"1" forKey:@"1" withExpirationTime:10];
//    [cache setObject:@"1" forKey:@"2" withExpirationTime:10];
//    [cache setObject:@"1" forKey:@"3" withExpirationTime:1000];

    NSString *cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [cacheFolder stringByAppendingPathComponent:@"YYYSharedCache"];
    
    YYYKVStorage *storage = [[YYYKVStorage alloc] initWithPath:path type:YYYKVStorageTypeMixed];
    
    
    
    NSArray *array = [storage getItemForKeys:@[@"1",@"2",@"3",@"4"]];
    NSLog(@"%@",array);

    
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
