//
//  ViewController.m
//  WZZBLEDemo
//
//  Created by 王泽众 on 16/8/31.
//  Copyright © 2016年 wzz. All rights reserved.
//

#import "ViewController.h"
#import "WZZBLECManager.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>
{
    NSMutableArray <WZZBLEDeviceModel *>* dataArr;
}

@property (weak, nonatomic) IBOutlet UITableView *mainTableView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    dataArr = [NSMutableArray array];
    //初始化中心模式
    [_mainTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [[WZZBLECManager shareInstance] stateUpdated:^(CBManagerState state) {
        NSLog(@"state:%ld\nCBManagerStateUnknown = 0,\nCBManagerStateResetting,\nCBManagerStateUnsupported,\nCBManagerStateUnauthorized,\nCBManagerStatePoweredOff,\nCBManagerStatePoweredOn,", state);
    }];
}

- (IBAction)scan:(id)sender {
    [[WZZBLECManager shareInstance] scanAllDeviceWithSuccessBlock:^(NSArray<WZZBLEDeviceModel *> *deviceArr) {
        dataArr = [NSMutableArray arrayWithArray:deviceArr];
        [_mainTableView reloadData];
    } findADeviceBlock:^(WZZBLEDeviceModel *aDevice) {
        
    }];
}

- (IBAction)temClick:(id)sender {
    WZZBLEDeviceModel * model = [[WZZBLECManager shareInstance] connectDevice];
    WZZBLEService * sev = model.sevDic[@"FFF0"];
    [model writeValue:[model dataWith16Str:@"0200000000"] toChar:[sev.charDic[@"FFF2"] aChar] successBlock:^(id resp) {
        NSLog(@"--->resp:%@", [model str16WithData:resp]);
    }];
}

- (IBAction)heartClick:(id)sender {
    WZZBLEDeviceModel * model = [[WZZBLECManager shareInstance] connectDevice];
    WZZBLEService * sev = model.sevDic[@"FFF0"];
    [model openNotifyWithChar:[sev.charDic[@"FFF3"] aChar] handleDataBlock:^(id resp) {
        NSLog(@"--->resp:%@", [model str16WithData:resp]);
    }];
}

#pragma mark - tableview代理
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return dataArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    WZZBLEDeviceModel * model = dataArr[indexPath.row];
    [cell.textLabel setText:[NSString stringWithFormat:@"%@->%@", model.name, model.RSSI]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[WZZBLECManager shareInstance] stopScan];
    [[WZZBLECManager shareInstance] connectDevice:dataArr[indexPath.row] successBlock:^{
        NSLog(@"连接成功");
        WZZBLEDeviceModel * model = dataArr[indexPath.row];
        [model scanAllDataWithFinishBlock:^{
            NSLog(@"扫描完成");
        }];
    } filedBlock:^{
        NSLog(@"连接失败");
    }];
}

@end
