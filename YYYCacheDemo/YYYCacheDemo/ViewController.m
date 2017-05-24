//
//  ViewController.m
//  YYYCacheDemo
//
//  Created by 叶越悦 on 2017/3/6.
//  Copyright © 2017年 叶越悦. All rights reserved.
//

#import "ViewController.h"
#import <YYYCache.h>

@interface ViewController ()

@property (nonatomic, strong) YYYCache *cache;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.cache = [[YYYCache alloc]initWithName:@"test"];
//    [self test];
    [self test1];
    [self test2];
}

- (void)test
{
    NSLog(@"1");
    NSMutableArray *array = [NSMutableArray array];
    for (NSInteger i = 0 ; i < 200;i ++)
    {
        NSString *str = [NSString stringWithFormat:@"//  Copyright © 2017年 叶越悦. All rights reserved. %@",@(i)];
        [array addObject:str];
        [self.cache setObject:str forKey:[@(i) stringValue]];
    }
    [self.cache setObject:array forKey:@"array"];
    NSLog(@"2");
}

- (void)test1
{
    NSLog(@"%s",__func__);
    NSMutableArray *array = [NSMutableArray array];
    for (NSInteger i = 0 ; i < 200;i ++)
    {
        id obj = [self.cache objectForKey:[@(i) stringValue]];
        if (obj)
        {
            [array addObject:obj];
        }
    }
    NSLog(@"%s",__func__);
}

- (void)test2
{
    NSLog(@"%s",__func__);
    NSMutableArray *array = [self.cache objectForKey:@"array"];
    NSLog(@"%s",__func__);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
