//
//  WZZBLECManager.h
//  WZZBLEDemo
//
//  Created by 王泽众 on 2017/6/9.
//  Copyright © 2017年 wzz. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreBluetooth;
@class WZZBLEDeviceModel;
@class WZZBLEService;
@class WZZBLEChar;

#pragma mark - 中心
@interface WZZBLECManager : NSObject

@property (nonatomic, strong) WZZBLEDeviceModel * connectDevice;

/**
 单例
 */
+ (instancetype)shareInstance;

/**
 蓝牙状态更新
 */
- (void)stateUpdated:(void(^)(CBManagerState state))aBlock;

/**
 扫描
 */
- (void)scanAllDeviceWithSuccessBlock:(void(^)(NSArray <WZZBLEDeviceModel *>* deviceArr))sb
                     findADeviceBlock:(void(^)(WZZBLEDeviceModel * aDevice))adb;

/**
 停止扫描
 */
- (void)stopScan;

/**
 连接设备
 */
- (void)connectDevice:(WZZBLEDeviceModel *)model successBlock:(void(^)())sb filedBlock:(void(^)())fb;

@end

#pragma mark - 设备
@interface WZZBLEDeviceModel : NSObject

/**
 名称
 */
@property (nonatomic, strong) NSString * name;

/**
 信号
 */
@property (nonatomic, strong) NSNumber * RSSI;

/**
 唯一标识
 */
@property (nonatomic, strong) NSString * UUID;

/**
 设备
 */
@property (nonatomic, strong) CBPeripheral * device;

/**
 扩展
 */
@property (nonatomic, strong) NSMutableDictionary * extDic;

/**
 服务
 @{@"service_uuid":WZZBLEService_model}
 WZZBLEService_model.charDic = @{@"char_uuid":WZZBLEChar_model}
 */
@property (nonatomic, strong) NSMutableDictionary <NSString *, WZZBLEService *>* sevDic;

/**
 扫描全部数据（递归扫描所有服务和特征）
 */
- (void)scanAllDataWithFinishBlock:(void(^)())aBlock;

/**
 扫描服务
 */
- (void)scanAllServiceWithFinishBlock:(void(^)())aBlock;

/**
 扫描特征
 */
- (void)scanCharWithService:(CBService *)sev finishBlock:(void(^)())aBlock;

/**
 写数据
 */
- (void)writeValue:(NSData *)value toChar:(CBCharacteristic *)charStr successBlock:(void(^)(id resp))sb;

/**
 读数据
 */
- (void)readValueWithChar:(CBCharacteristic *)charStr successBlock:(void (^)(id resp))sb;

/**
 开启通知
 */
- (void)openNotifyWithChar:(CBCharacteristic *)charStr handleDataBlock:(void(^)(id resp))sb;

/**
 关闭通知
 */
- (void)closeNotifyWithChar:(CBCharacteristic *)charStr;

/**
 字符串转16进制data
 */
- (NSData *)dataWith16Str:(NSString *)str;

/**
 16进制data转字符串
 */
- (NSString *)str16WithData:(NSData *)data;

/**
 16进制转float
 */
- (float)floatWith16:(NSString *)str16;

@end

#pragma mark - 服务
@interface WZZBLEService : NSObject

@property (nonatomic, strong) CBService * sev;
@property (nonatomic, strong) NSString * name;
@property (nonatomic, strong) NSMutableDictionary <NSString *, WZZBLEChar *>* charDic;

@end

#pragma mark - 特征
@interface WZZBLEChar : NSObject

@property (nonatomic, strong) CBCharacteristic * aChar;
@property (nonatomic, strong) NSString * charName;

@end
