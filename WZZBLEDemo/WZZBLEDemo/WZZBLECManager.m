//
//  WZZBLECManager.m
//  WZZBLEDemo
//
//  Created by 王泽众 on 2017/6/9.
//  Copyright © 2017年 wzz. All rights reserved.
//

#import "WZZBLECManager.h"

#define LOG_OPEN 1

static WZZBLECManager * manager;

#pragma mark - 中心
@interface WZZBLECManager ()<CBCentralManagerDelegate>
{
    CBCentralManager * cmanager;
    NSMutableArray <WZZBLEDeviceModel *>* deviceArr;//设备数组
    NSMutableArray <NSString *>* deviceUUIDArr;//设备uuid数组，保证设备的唯一
    
    //block
    //状态更新
    void(^_stateDidUpdatedBlock)(CBManagerState);
    //扫描到设备
    void(^_findDeviceBlock)(WZZBLEDeviceModel *);
    //扫描到设备数组
    void(^_findDeviceArrBlock)(NSArray <WZZBLEDeviceModel *>*);
    //连接设备
    void(^_connectOKBlock)();
    //连接失败
    void(^_connectFailBlock)();
    //断开连接
    void(^_disconnectBlock)();
}

@end

@implementation WZZBLECManager

//单例
+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[WZZBLECManager alloc] init];
        manager->cmanager = [[CBCentralManager alloc] initWithDelegate:manager queue:nil];
    });
    return manager;
}

//状态更新
- (void)stateUpdated:(void (^)(CBManagerState))aBlock {
    if (_stateDidUpdatedBlock != aBlock) {
        _stateDidUpdatedBlock = aBlock;
    }
}

//扫描设备
- (void)scanAllDeviceWithSuccessBlock:(void (^)(NSArray<WZZBLEDeviceModel *> *))sb
                     findADeviceBlock:(void (^)(WZZBLEDeviceModel *))adb {
    [self stopScan];
    [self removeAllDeviceFromArr];
    [cmanager scanForPeripheralsWithServices:nil options:nil];
    if (_findDeviceBlock != adb) {
        _findDeviceBlock = adb;
    }
    if (_findDeviceArrBlock != sb) {
        _findDeviceArrBlock = sb;
    }
}

//停止扫描
- (void)stopScan {
    [cmanager stopScan];
}

//连接设备
- (void)connectDevice:(WZZBLEDeviceModel *)model
         successBlock:(void (^)())sb
           filedBlock:(void (^)())fb {
    if (_connectOKBlock != sb) {
        _connectOKBlock = sb;
    }
    if (_connectFailBlock != fb) {
        _connectFailBlock = fb;
    }
    if ([self connectDevice]) {
        [cmanager cancelPeripheralConnection:[[self connectDevice] device]];
    }
    [self setConnectDevice:model];
    [cmanager connectPeripheral:model.device options:nil];
}

//给全局设备数组添加设备
- (void)addDeviceToArr:(WZZBLEDeviceModel *)model {
    if (!deviceArr) {
        deviceArr = [NSMutableArray array];
    }
    if (!deviceUUIDArr) {
        deviceUUIDArr = [NSMutableArray array];
    }
    NSString * uuidStr = model.device.identifier.UUIDString;
    if ([deviceUUIDArr containsObject:uuidStr]) {
        //替换
        [deviceArr replaceObjectAtIndex:[deviceUUIDArr indexOfObject:uuidStr] withObject:model];
    } else {
        [deviceArr addObject:model];
        [deviceUUIDArr addObject:uuidStr];
    }
}

//从全局设备数组删除设备
- (void)removeDeviceFromArr:(WZZBLEDeviceModel *)model {
    NSString * uuidStr = model.device.identifier.UUIDString;
    [deviceArr removeObjectAtIndex:[deviceUUIDArr indexOfObject:uuidStr]];
    [deviceUUIDArr removeObject:uuidStr];
}

//删除全部设备
- (void)removeAllDeviceFromArr {
    [deviceUUIDArr removeAllObjects];
    [deviceArr removeAllObjects];
}

#pragma mark - 蓝牙中心代理
//状态更新
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (_stateDidUpdatedBlock) {
        _stateDidUpdatedBlock(central.state);
    }
}

//发现设备，数据，信号
- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *,id> *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    WZZBLEDeviceModel * model = [[WZZBLEDeviceModel alloc] init];
    model.RSSI = RSSI;
    model.device = peripheral;
    model.name = peripheral.name;
    model.UUID = peripheral.identifier.UUIDString;
    model.extDic = [NSMutableDictionary dictionaryWithDictionary:advertisementData];
    [self addDeviceToArr:model];
    if (_findDeviceBlock) {
        _findDeviceBlock(model);
    }
    if (_findDeviceArrBlock) {
        _findDeviceArrBlock(deviceArr);
    }
}

//已连接设备
- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral {
    if (_connectOKBlock) {
        _connectOKBlock();
    }
}

//已断开连接设备
- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (_disconnectBlock) {
        _disconnectBlock();
    }
}

//连接设备失败
- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (_connectFailBlock) {
        _connectFailBlock();
    }
}

@end

@interface WZZBLEDeviceModel ()<CBPeripheralDelegate>
{
    //扫描完所有数据
    void(^_findAllData)();
    //扫描完服务
    void(^_findSevice)();
    //扫描完特征
    void(^_findChar)();
    //写数据返回block
    NSMutableDictionary <NSString *, void(^)(id)>* writeBackBlocks;
    //读数据返回block
    NSMutableDictionary <NSString *, void(^)(id)>* readBackBlocks;
    //通知数据返回block
    NSMutableDictionary <NSString *, void(^)(id)>* notifyBackBlocks;
}

@end

#pragma mark - 设备
@implementation WZZBLEDeviceModel

//扫描全部数据
- (void)scanAllDataWithFinishBlock:(void (^)())aBlock {
    [self scanAllServiceWithFinishBlock:^{
        __block int f = 0;
        for (int i = 0; i < self.device.services.count; i++) {
            [self scanCharWithService:self.device.services[i] finishBlock:^{
                f++;
                if (f >= self.device.services.count) {
                    //成功
                    if (aBlock) {
                        aBlock();
                    }
                }
            }];
        }
    }];
}

//扫描服务
- (void)scanAllServiceWithFinishBlock:(void (^)())aBlock {
    if (_findSevice != aBlock) {
        _findSevice = aBlock;
    }
    [self.device discoverServices:nil];
}

//扫描特征
- (void)scanCharWithService:(CBService *)sev finishBlock:(void (^)())aBlock {
    if (_findChar != aBlock) {
        _findChar = aBlock;
    }
    [self.device discoverCharacteristics:nil forService:sev];
}

//写数据
- (void)writeValue:(NSData *)value toChar:(CBCharacteristic *)charStr successBlock:(void (^)(id))sb {
    [writeBackBlocks setObject:sb forKey:charStr.UUID.UUIDString];
    [self.device writeValue:value forCharacteristic:charStr type:CBCharacteristicWriteWithResponse];
}

//读数据
- (void)readValueWithChar:(CBCharacteristic *)charStr successBlock:(void (^)(id))sb {
    [readBackBlocks setObject:sb forKey:charStr.UUID.UUIDString];
    [self.device readValueForCharacteristic:charStr];
}

//开启通知
- (void)openNotifyWithChar:(CBCharacteristic *)charStr handleDataBlock:(void (^)(id))sb {
    [readBackBlocks setObject:sb forKey:charStr.UUID.UUIDString];
    [self.device setNotifyValue:YES forCharacteristic:charStr];
}

//关闭通知
- (void)closeNotifyWithChar:(CBCharacteristic *)charStr {
    [readBackBlocks removeObjectForKey:charStr.UUID.UUIDString];
    [self.device setNotifyValue:NO forCharacteristic:charStr];
}

//16进制转data
- (NSData *)dataWith16Str:(NSString *)str {
    if (!str || [str length] == 0) {
        return nil;
    }
    
    NSMutableData *hexData = [[NSMutableData alloc] initWithCapacity:8];
    NSRange range;
    if ([str length] % 2 == 0) {
        range = NSMakeRange(0, 2);
    } else {
        range = NSMakeRange(0, 1);
    }
    for (NSInteger i = range.location; i < [str length]; i += 2) {
        unsigned int anInt;
        NSString *hexCharStr = [str substringWithRange:range];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexCharStr];
        
        [scanner scanHexInt:&anInt];
        NSData *entity = [[NSData alloc] initWithBytes:&anInt length:1];
        [hexData appendData:entity];
        
        range.location += range.length;
        range.length = 2;
    }
    
    return hexData;
}

//data转16进制
- (NSString *)str16WithData:(NSData *)data {
    if (!data || [data length] == 0) {
        return @"";
    }
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[data length]];
    
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%x", (dataBytes[i]) & 0xff];
            if ([hexStr length] == 2) {
                [string appendString:hexStr];
            } else {
                [string appendFormat:@"0%@", hexStr];
            }
        }
    }];
    
    return string;
}

//16进制转float
- (float)floatWith16:(NSString *)str16 {
//    char p[str16.length/2];
//    for (int i = 0; i < str16.length; i+=2) {
//        NSString * subStr = [NSString stringWithFormat:@"%c%c", [str16 characterAtIndex:i], [str16 characterAtIndex:i+1]];
//        p[i]
//    }
//    float * fp = (float *)p;
    return 0;
}

//字符串转相同16进制
- (UInt32)strToSame16WithStr:(NSString *)str {
    UInt32 bbb = 0x0;
    for (int i = 0; i < str.length; i++) {
        bbb += ([str characterAtIndex:i]-'0')*pow(16, str.length-i-1);
    }
    return bbb;
}

#pragma mark getset方法
- (NSMutableDictionary<NSString *,WZZBLEService *> *)sevDic {
    if (!_sevDic) {
        _sevDic = [NSMutableDictionary dictionary];
    }
    return _sevDic;
}

- (CBPeripheral *)device {
    if (!_device.delegate) {
        _device.delegate = self;
        writeBackBlocks = [NSMutableDictionary dictionary];
        readBackBlocks = [NSMutableDictionary dictionary];
        notifyBackBlocks = [NSMutableDictionary dictionary];
    }
    return _device;
}

#pragma mark 外设代理
//改变名字
- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
    _name = peripheral.name;
}

//读到RSSI
- (void)peripheral:(CBPeripheral *)peripheral
       didReadRSSI:(NSNumber *)RSSI
             error:(NSError *)error {
    _RSSI = RSSI;
}

//扫描到服务
- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverServices:(NSError *)error {
    for (int i = 0; i < peripheral.services.count; i++) {
        CBService * sev = peripheral.services[i];
        WZZBLEService * sevModel = [WZZBLEService alloc];
        sevModel.sev = sev;
        sevModel.name = sev.UUID.UUIDString;
        sevModel.charDic = [NSMutableDictionary dictionary];
        [self.sevDic setObject:sevModel forKey:sev.UUID.UUIDString];
    }
    if (_findSevice) {
        _findSevice();
    }
}

//扫描到特征
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (int i = 0; i < service.characteristics.count; i++) {
        CBCharacteristic * aChar = service.characteristics[i];
        WZZBLEChar * charModel = [[WZZBLEChar alloc] init];
        charModel.charName = aChar.UUID.UUIDString;
        charModel.aChar = aChar;
        WZZBLEService * sevModel = self.sevDic[service.UUID.UUIDString];
        [sevModel.charDic setObject:charModel forKey:aChar.UUID.UUIDString];
    }
    if (_findChar) {
        _findChar();
    }
#if LOG_OPEN
    NSLog(@"扫描到特征, %@", service.characteristics);
#endif
}

//已写数据
- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error {
#if LOG_OPEN
    NSLog(@"已写数据");
#endif
}

//更新了描述值
- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForDescriptor:(CBDescriptor *)descriptor
             error:(NSError *)error {
#if LOG_OPEN
    NSLog(@"更新了描述值");
#endif
}

//已写数据到特征
- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    if (writeBackBlocks[characteristic.UUID.UUIDString]) {
        void(^aBlock)(id) = writeBackBlocks[characteristic.UUID.UUIDString];
        if (aBlock) {
            aBlock(characteristic.value);
        }
    }
#if LOG_OPEN
    NSLog(@"已写数据到特征");
#endif
}

//特征的值更新了
- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    if (readBackBlocks[characteristic.UUID.UUIDString]) {
        void(^aBlock)(id) = readBackBlocks[characteristic.UUID.UUIDString];
        if (aBlock) {
            aBlock(characteristic.value);
        }
    }
#if LOG_OPEN
    NSLog(@"特征的值更新了");
#endif
}

//未知
- (void)peripheral:(CBPeripheral *)peripheral
 didModifyServices:(NSArray<CBService *> *)invalidatedServices {
#if LOG_OPEN
    NSLog(@"未知");
#endif
}

@end

#pragma mark - 服务
@implementation WZZBLEService

- (NSMutableDictionary<NSString *,WZZBLEChar *> *)charDic {
    if (!_charDic) {
        _charDic = [NSMutableDictionary dictionary];
    }
    return _charDic;
}

@end

#pragma mark - 特征
@implementation WZZBLEChar

@end
