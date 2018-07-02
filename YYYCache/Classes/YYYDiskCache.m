//
//  YYYDiskCache.m
//  MsgSendTestProject
//
//  Created by yyy on 2016/12/6.
//  Copyright © 2016年 yyy. All rights reserved.
//

#import "YYYDiskCache.h"
#import "YYYKVStorage.h"
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonCrypto.h>
#import <objc/runtime.h>
#import <time.h>

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)

static const int extended_data_key;

/// Free disk space in bytes.
static int64_t _YYYDiskSpaceFree() {
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (error)
        return -1;
    int64_t space = [[attrs objectForKey:NSFileSystemFreeSize] longLongValue];
    if (space < 0)
        space = -1;
    return space;
}

/// String's md5 hash.
static NSString *_YYYDiskNSStringMD5(NSString *string) {
    if (!string)
        return nil;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG) data.length, result);
    return [NSString stringWithFormat:
        @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        result[0], result[1], result[2], result[3],
        result[4], result[5], result[6], result[7],
        result[8], result[9], result[10], result[11],
        result[12], result[13], result[14], result[15]
    ];
}

/// weak reference for all instances
static NSMapTable *_yyyGlobalInstances;
static dispatch_semaphore_t _yyyGlobalInstancesLock;

static void _YYYDiskCacheInitGlobal() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _yyyGlobalInstancesLock = dispatch_semaphore_create(1);
        _yyyGlobalInstances = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
    });
}

static YYYDiskCache *_YYYDiskCacheGetGlobal(NSString *path) {
    if (path.length == 0)
        return nil;
    _YYYDiskCacheInitGlobal();
    dispatch_semaphore_wait(_yyyGlobalInstancesLock, DISPATCH_TIME_FOREVER);
    id cache = [_yyyGlobalInstances objectForKey:path];
    dispatch_semaphore_signal(_yyyGlobalInstancesLock);
    return cache;
}

static void _YYYDiskCacheSetGlobal(YYYDiskCache *cache) {
    if (cache.path.length == 0)
        return;
    _YYYDiskCacheInitGlobal();
    dispatch_semaphore_wait(_yyyGlobalInstancesLock, DISPATCH_TIME_FOREVER);
    [_yyyGlobalInstances setObject:cache forKey:cache.path];
    dispatch_semaphore_signal(_yyyGlobalInstancesLock);
}

@implementation YYYDiskCache {
    YYYKVStorage *_kv;
    NSMutableOrderedSet *_dbExpirationTime;
    dispatch_semaphore_t _lock;
    dispatch_queue_t _queue;
}

- (void)_trimRecursively {
    __weak typeof(self) _self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (_autoTrimInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        __strong typeof(_self) self = _self;
        if (!self)
            return;
        [self _trimInBackground];
        [self _trimRecursively];
    });
}

- (void)trimRecursivelyExpirationTime {
    if (!_dbExpirationTime || _dbExpirationTime.count == 0) {
        return;
    }

    NSNumber *expirationTime = nil;
    time_t currenttime = time(NULL);
    NSInteger count = 0;
    NSArray *array = _dbExpirationTime.array;
    for (NSInteger i = 0; i < array.count; i++) {
        expirationTime = array[i];
        if (currenttime < expirationTime.longLongValue) {
            break;
        } else {
            [_dbExpirationTime removeObject:expirationTime];
        }
        count++;
    }

    if (expirationTime == nil) {
        return;
    }
    long afterDelay = expirationTime.longValue - currenttime;
    if (count > 0 && afterDelay > 5)//有过期数据，过期时间超过5秒
    {
        [self trimInBackgroundExpirationTime];
    }
    __weak typeof(self) _self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (afterDelay * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        __strong typeof(_self) self = _self;
        if (!self)
            return;
        [self trimInBackgroundExpirationTime];
    });
}

- (void)trimInBackgroundExpirationTime {
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        if (!self)
            return;
        time_t currenttime = time(NULL);
        Lock();
        [self->_kv _dbDeleteItemsWithExpirationTimeEarlierThan:currenttime];
        Unlock();
    });
}

- (void)_trimInBackground {
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        if (!self)
            return;
        Lock();
        [self _trimToCost:self.costLimit];
        [self _trimToCount:self.countLimit];
        [self _trimToAge:self.ageLimit];
        [self _trimToFreeDiskSpace:self.freeDiskSpaceLimit];
        Unlock();
    });
}

- (void)_trimToCost:(NSUInteger)costLimit {
    if (costLimit >= INT_MAX)
        return;
    [_kv removeItemsToFitSize:(int) costLimit];

}

- (void)_trimToCount:(NSUInteger)countLimit {
    if (countLimit >= INT_MAX)
        return;
    [_kv removeItemsToFitCount:(int) countLimit];
}

- (void)_trimToAge:(NSTimeInterval)ageLimit {
    if (ageLimit <= 0) {
        [_kv removeAllItems];
        return;
    }
    long timestamp = time(NULL);
    if (timestamp <= ageLimit)
        return;
    long age = timestamp - ageLimit;
    if (age >= INT_MAX)
        return;
    [_kv removeItemsEarlierThanTime:(int) age];
}

- (void)_trimToFreeDiskSpace:(NSUInteger)targetFreeDiskSpace {
    if (targetFreeDiskSpace == 0)
        return;
    int64_t totalBytes = [_kv getItemsSize];
    if (totalBytes <= 0)
        return;
    int64_t diskFreeBytes = _YYYDiskSpaceFree();
    if (diskFreeBytes < 0)
        return;
    int64_t needTrimBytes = targetFreeDiskSpace - diskFreeBytes;
    if (needTrimBytes <= 0)
        return;
    int64_t costLimit = totalBytes - needTrimBytes;
    if (costLimit < 0)
        costLimit = 0;
    [self _trimToCost:(int) costLimit];
}

- (NSString *)_filenameForKey:(NSString *)key {
    NSString *filename = nil;
    if (_customFileNameBlock)
        filename = _customFileNameBlock(key);
    if (!filename)
        filename = _YYYDiskNSStringMD5(key);
    return filename;
}

- (void)_appWillBeTerminated {
    Lock();
    _kv = nil;
    Unlock();
}

#pragma mark - public

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
}

- (instancetype)init {
    @throw [NSException exceptionWithName:@"YYYDiskCache init error" reason:@"YYYDiskCache must be initialized with a path. Use 'initWithPath:' or 'initWithPath:inlineThreshold:' instead." userInfo:nil];
    return [self initWithPath:@"" inlineThreshold:0];
}

- (instancetype)initWithPath:(NSString *)path {
    return [self initWithPath:path inlineThreshold:1024 * 20]; // 20KB
}

- (instancetype)initWithPath:(NSString *)path
    inlineThreshold:(NSUInteger)threshold {
    self = [super init];
    if (!self)
        return nil;

    YYYDiskCache *globalCache = _YYYDiskCacheGetGlobal(path);
    if (globalCache)
        return globalCache;

    YYYKVStorageType type;
    if (threshold == 0) {
        type = YYYKVStorageTypeFile;
    } else if (threshold == NSUIntegerMax) {
        type = YYYKVStorageTypeSQLite;
    } else {
        type = YYYKVStorageTypeMixed;
    }

    YYYKVStorage *kv = [[YYYKVStorage alloc] initWithPath:path type:type];
    if (!kv)
        return nil;

    _kv = kv;
    _path = path;
    _lock = dispatch_semaphore_create(1);
    _queue = dispatch_queue_create("com.ibireme.cache.yyydisk", DISPATCH_QUEUE_CONCURRENT);
    _inlineThreshold = threshold;
    _countLimit = NSUIntegerMax;
    _costLimit = NSUIntegerMax;
    _ageLimit = DBL_MAX;
    _freeDiskSpaceLimit = 0;
    _autoTrimInterval = 60;

    Lock();
    NSMutableArray *array = [_kv _dbGetAllExpirationTime];
    Unlock();
    _dbExpirationTime = [NSMutableOrderedSet orderedSet];
    if (array.count) {
        [_dbExpirationTime addObjectsFromArray:array];
        [self trimRecursivelyExpirationTime];
    }
    [self _trimRecursively];
    _YYYDiskCacheSetGlobal(self);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appWillBeTerminated) name:UIApplicationWillTerminateNotification object:nil];
    return self;
}

- (BOOL)containsObjectForKey:(NSString *)key {
    if (!key)
        return NO;
    Lock();
    BOOL contains = [_kv itemExistsForKey:key];
    Unlock();
    return contains;
}

- (void)containsObjectForKey:(NSString *)key withBlock:(void (^)(NSString *key, BOOL contains))block {
    if (!block)
        return;
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        BOOL contains = [self containsObjectForKey:key];
        block(key, contains);
    });
}

- (id <NSCoding>)objectForKey:(NSString *)key {
    if (!key)
        return nil;
    Lock();
    YYYKVStorageItem *item = [_kv getItemForKey:key];
    Unlock();
    if (!item.value)
        return nil;
    if (item.expirationTime > 0) {
        NSTimeInterval now = CACurrentMediaTime();
        if (item.expirationTime < now) {
            [_kv removeItemForKey:key];
            return nil;
        }
    }
    id object = nil;
    if (_customUnarchiveBlock) {
        object = _customUnarchiveBlock(item.value);
    } else {
        @try {
            object = [NSKeyedUnarchiver unarchiveObjectWithData:item.value];
        }
        @catch (NSException *exception) {
            // nothing to do...
        }
    }
    if (object && item.extendedData) {
        [YYYDiskCache setExtendedData:item.extendedData toObject:object];
    }
    return object;
}

- (void)objectForKey:(NSString *)key withBlock:(void (^)(NSString *key, id <NSCoding> object))block {
    if (!block)
        return;
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        id <NSCoding> object = [self objectForKey:key];
        block(key, object);
    });
}

- (void)setObject:(nullable id <NSCoding>)object forKey:(NSString *)key withExpirationTime:(NSTimeInterval)extime {
    if (!key)
        return;
    if (!object) {
        [self removeObjectForKey:key];
        return;
    }

    NSData *extendedData = [YYYDiskCache getExtendedDataFromObject:object];
    NSData *value = nil;
    if (_customArchiveBlock) {
        value = _customArchiveBlock(object);
    } else {
        @try {
            value = [NSKeyedArchiver archivedDataWithRootObject:object];
        }
        @catch (NSException *exception) {
            // nothing to do...
        }
    }
    if (!value)
        return;
    NSString *filename = nil;
    if (_kv.type != YYYKVStorageTypeSQLite) {
        if (value.length > _inlineThreshold) {
            filename = [self _filenameForKey:key];
        }
    }

    Lock();
    [_kv saveItemWithKey:key value:value filename:filename expirationTime:extime extendedData:extendedData];
    if (extime > 0) {
        time_t currenttime = time(NULL);
        extime += currenttime;
        NSInteger i = 0;
        for (; i < _dbExpirationTime.count; i++) {
            NSNumber *number = _dbExpirationTime[i];
            if (number.intValue > extime) {
                break;
            }
        }
        [_dbExpirationTime insertObject:@(extime) atIndex:i];
        if (i == 0) {
            [self trimRecursivelyExpirationTime];
        }
    }
    Unlock();

}

- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key {
    [self setObject:object forKey:key withExpirationTime:0];
}

- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key withExpirationTime:(NSTimeInterval)time block:(void (^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        [self setObject:object forKey:key withExpirationTime:time];
        if (block)
            block();
    });
}

- (void)setObject:(id <NSCoding>)object forKey:(NSString *)key withBlock:(void (^)(void))block {
    [self setObject:object forKey:key withExpirationTime:0 block:block];
}

- (void)removeObjectForKey:(NSString *)key {
    if (!key)
        return;
    Lock();
    [_kv removeItemForKey:key];
    Unlock();
}

- (void)removeObjectForKey:(NSString *)key withBlock:(void (^)(NSString *key))block {
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        [self removeObjectForKey:key];
        if (block)
            block(key);
    });
}

- (void)removeAllObjects {
    Lock();
    [_kv removeAllItems];
    Unlock();
}

- (void)removeAllObjectsWithBlock:(void (^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        [self removeAllObjects];
        if (block)
            block();
    });
}

- (void)removeAllObjectsWithProgressBlock:(void (^)(int removedCount, int totalCount))progress
    endBlock:(void (^)(BOOL error))end {
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        if (!self) {
            if (end)
                end(YES);
            return;
        }
        Lock();
        [self->_kv removeAllItemsWithProgressBlock:progress endBlock:end];
        Unlock();
    });
}

- (NSInteger)totalCount {
    Lock();
    int count = [_kv getItemsCount];
    Unlock();
    return count;
}

- (void)totalCountWithBlock:(void (^)(NSInteger totalCount))block {
    if (!block)
        return;
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        NSInteger totalCount = [self totalCount];
        block(totalCount);
    });
}

- (NSInteger)totalCost {
    Lock();
    int count = [_kv getItemsSize];
    Unlock();
    return count;
}

- (void)totalCostWithBlock:(void (^)(NSInteger totalCost))block {
    if (!block)
        return;
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        NSInteger totalCost = [self totalCost];
        block(totalCost);
    });
}

- (void)trimToCount:(NSUInteger)count {
    Lock();
    [self _trimToCount:count];
    Unlock();
}

- (void)trimToCount:(NSUInteger)count withBlock:(void (^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        [self trimToCount:count];
        if (block)
            block();
    });
}

- (void)trimToCost:(NSUInteger)cost {
    Lock();
    [self _trimToCost:cost];
    Unlock();
}

- (void)trimToCost:(NSUInteger)cost withBlock:(void (^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        [self trimToCost:cost];
        if (block)
            block();
    });
}

- (void)trimToAge:(NSTimeInterval)age {
    Lock();
    [self _trimToAge:age];
    Unlock();
}

- (void)trimToAge:(NSTimeInterval)age withBlock:(void (^)(void))block {
    __weak typeof(self) _self = self;
    dispatch_async(_queue, ^{
        __strong typeof(_self) self = _self;
        [self trimToAge:age];
        if (block)
            block();
    });
}

+ (NSData *)getExtendedDataFromObject:(id)object {
    if (!object)
        return nil;
    return (NSData *) objc_getAssociatedObject(object, &extended_data_key);
}

+ (void)setExtendedData:(NSData *)extendedData toObject:(id)object {
    if (!object)
        return;
    objc_setAssociatedObject(object, &extended_data_key, extendedData, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)description {
    if (_name)
        return [NSString stringWithFormat:@"<%@: %p> (%@:%@)", self.class, self, _name, _path];
    else
        return [NSString stringWithFormat:@"<%@: %p> (%@)", self.class, self, _path];
}

- (BOOL)errorLogsEnabled {
    Lock();
    BOOL enabled = _kv.errorLogsEnabled;
    Unlock();
    return enabled;
}

- (void)setErrorLogsEnabled:(BOOL)errorLogsEnabled {
    Lock();
    _kv.errorLogsEnabled = errorLogsEnabled;
    Unlock();
}

@end
