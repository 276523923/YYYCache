//
//  YYYCache.m
//  MsgSendTestProject
//
//  Created by yyy on 2016/12/6.
//  Copyright © 2016年 yyy. All rights reserved.
//

#import "YYYCache.h"

@implementation YYYCache

- (instancetype)init {
    NSLog(@"Use \"initWithName\" or \"initWithPath\" to create YYCache instance.");
    return [self initWithPath:@""];
}

- (instancetype)initWithName:(NSString *)name {
    if (name.length == 0)
        return nil;
    NSString *cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [cacheFolder stringByAppendingPathComponent:name];
    return [self initWithPath:path];
}

- (instancetype)initWithPath:(NSString *)path {
    if (path.length == 0)
        return nil;
    YYYDiskCache *diskCache = [[YYYDiskCache alloc] initWithPath:path];
    if (!diskCache)
        return nil;
    NSString *name = [path lastPathComponent];
    YYYMemoryCache *memoryCache = [YYYMemoryCache new];
    memoryCache.name = name;

    self = [super init];
    _name = name;
    _diskCache = diskCache;
    _memoryCache = memoryCache;
    return self;
}

+ (instancetype)cacheWithName:(NSString *)name {
    return [[self alloc] initWithName:name];
}

+ (instancetype)cacheWithPath:(NSString *)path {
    return [[self alloc] initWithPath:path];
}

+ (instancetype)sharedCache {
    static YYYCache *yyy_shared_cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        yyy_shared_cache = [self cacheWithName:@"YYYSharedCache"];
    });
    return yyy_shared_cache;
}

- (BOOL)containsObjectForKey:(NSString *)key {
    return [_memoryCache containsObjectForKey:key] || [_diskCache containsObjectForKey:key];
}

- (void)containsObjectForKey:(NSString *)key withBlock:(void (^)(NSString *key, BOOL contains))block {
    if (!block)
        return;

    if ([_memoryCache containsObjectForKey:key]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            block(key, YES);
        });
    } else {
        [_diskCache containsObjectForKey:key withBlock:block];
    }
}

- (id <NSCoding>)objectForKey:(NSString *)key {
    id <NSCoding> object = [_memoryCache objectForKey:key];
    if (!object) {
        object = [_diskCache objectForKey:key];
        if (object) {
            [_memoryCache setObject:object forKey:key];
        }
    }
    return object;
}

- (void)objectForKey:(NSString *)key withBlock:(void (^)(NSString *key, id object))block {
    if (!block)
        return;
    id <NSCoding> object = [_memoryCache objectForKey:key];
    if (object) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            block(key, object);
        });
    } else {
        [_diskCache objectForKey:key withBlock:^(NSString *key, id <NSCoding> object) {
            if (object && ![self.memoryCache objectForKey:key]) {
                [self.memoryCache setObject:object forKey:key];
            }
            block(key, object);
        }];
    }
}

- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key withExpirationTime:(NSTimeInterval)time {
    [_memoryCache setObject:object forKey:key withExpirationTime:time];
    [_diskCache setObject:object forKey:key withExpirationTime:time];
}

- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key withExpirationTime:(NSTimeInterval)time block:(void (^)(void))block {
    [_memoryCache setObject:object forKey:key];
    [_diskCache setObject:object forKey:key withExpirationTime:time block:block];
}

- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key {
    [self setObject:object forKey:key withExpirationTime:0];
}

- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key withBlock:(void (^)(void))block {
    [self setObject:object forKey:key withExpirationTime:0 block:block];
}

- (void)removeObjectForKey:(NSString *)key {
    [_memoryCache removeObjectForKey:key];
    [_diskCache removeObjectForKey:key];
}

- (void)removeObjectForKey:(NSString *)key withBlock:(void (^)(NSString *key))block {
    [_memoryCache removeObjectForKey:key];
    [_diskCache removeObjectForKey:key withBlock:block];
}

- (void)removeAllObjects {
    [_memoryCache removeAllObjects];
    [_diskCache removeAllObjects];
}

- (void)removeAllObjectsWithBlock:(void (^)(void))block {
    [_memoryCache removeAllObjects];
    [_diskCache removeAllObjectsWithBlock:block];
}

- (void)removeAllObjectsWithProgressBlock:(void (^)(int removedCount, int totalCount))progress
    endBlock:(void (^)(BOOL error))end {
    [_memoryCache removeAllObjects];
    [_diskCache removeAllObjectsWithProgressBlock:progress endBlock:end];

}

- (NSString *)description {
    if (_name)
        return [NSString stringWithFormat:@"<%@: %p> (%@)", self.class, self, _name];
    else
        return [NSString stringWithFormat:@"<%@: %p>", self.class, self];
}
@end
