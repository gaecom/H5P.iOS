//
//  HLBLEManager.m
//  HLBluetoothDemo
//
//  Created by Harvey on 16/4/27.
//  Copyright © 2016年 Halley. All rights reserved.
//

#import "HLBLEManager.h"

// 发送数据时，需要分段的长度，部分打印机一次发送数据过长就会乱码，需要分段发送。这个长度值不同的打印机可能不一样，你需要调试设置一个合适的值（最好是偶数）
#define kLimitLength    146

@interface DCHLBLEManager ()<CBCentralManagerDelegate,CBPeripheralDelegate>

//@property (strong, nonatomic)   CBPeripheral                *connectedPerpheral;    /**< 当前连接的外设 */

@property (strong, nonatomic)   NSArray<CBUUID *>           *serviceUUIDs;          /**< 要查找服务的UUIDs */
@property (strong, nonatomic)   NSArray<CBUUID *>           *characteristicUUIDs;   /**< 要查找特性的UUIDs */

@property (assign, nonatomic)   BOOL             stopScanAfterConnected;  /**< 是否连接成功后停止扫描蓝牙设备 */

@property (assign, nonatomic)   NSInteger         writeCount;   /**< 写入次数 */
@property (assign, nonatomic)   NSInteger         responseCount; /**< 返回次数 */


@end

static DCHLBLEManager *instance = nil;

@implementation DCHLBLEManager

+ (instancetype)sharedInstance
{
    return [[self alloc] init];
}

- (instancetype)init {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super init];
        //蓝牙没打开时alert提示框
        NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey:@(YES)};
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:options];
        _limitLength = kLimitLength;
    });
    
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    
    return instance;
}

- (void)scanForPeripheralsWithServiceUUIDs:(NSArray<CBUUID *> *)uuids options:(NSDictionary<NSString *, id> *)options
{
    [_centralManager scanForPeripheralsWithServices:uuids options:options];
}

- (void)scanForPeripheralsWithServiceUUIDs:(NSArray<CBUUID *> *)uuids options:(NSDictionary<NSString *, id> *)options didDiscoverPeripheral:(HLDiscoverPeripheralBlock)discoverBlock
{
    _discoverPeripheralBlcok = discoverBlock;
    [_centralManager scanForPeripheralsWithServices:uuids options:options];
}

- (void)connectPeripheral:(CBPeripheral *)peripheral
           connectOptions:(NSDictionary<NSString *,id> *)connectOptions
   stopScanAfterConnected:(BOOL)stop
          servicesOptions:(NSArray<CBUUID *> *)serviceUUIDs
   characteristicsOptions:(NSArray<CBUUID *> *)characteristicUUIDs
            completeBlock:(HLBLECompletionBlock)completionBlock;
{
    //1.保存回调的block以及参数
    _completionBlock = completionBlock;
    _serviceUUIDs = serviceUUIDs;
    _characteristicUUIDs = characteristicUUIDs;
    _stopScanAfterConnected = stop;
    
    //3.开始连接新的蓝牙外设
    [_centralManager connectPeripheral:peripheral options:connectOptions];
    //4.设置代理
    peripheral.delegate = self;
}

- (void)discoverIncludedServices:(NSArray<CBUUID *> *)includedServiceUUIDs forService:(CBService *)service Peripheral:(CBPeripheral *)peripheral
{
    [peripheral discoverIncludedServices:includedServiceUUIDs forService:service];
}

- (void)stopScan
{
    [_centralManager stopScan];
    _discoverPeripheralBlcok = nil;
}

- (void)cancelPeripheralConnection:(CBPeripheral*)peripheral
{
    if (peripheral) {
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}



- (void)NotifyValueforCharacteristic:(CBCharacteristic *)characteristic Peripheral:(CBPeripheral *)peripheral{
    [peripheral setNotifyValue:true forCharacteristic:characteristic];
}


- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic
                        Peripheral:(CBPeripheral *)peripheral
                   completionBlock:(HLValueForCharacteristicBlock)completionBlock
{
    _valueForCharacteristicBlock = completionBlock;
    [self readValueForCharacteristic:characteristic Peripheral:peripheral];
}
- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic
                        Peripheral:(CBPeripheral *)peripheral;
{
    [peripheral readValueForCharacteristic:characteristic];
}

- (void)writeValue:(NSData *)data Peripheral:(CBPeripheral *)peripheral forCharacteristic:(CBCharacteristic *)characteristic type:(CBCharacteristicWriteType)type
{
    _writeCount = 0;
    _responseCount = 0;
    // iOS 9 以后，系统添加了这个API来获取特性能写入的最大长度
    if ([peripheral respondsToSelector:@selector(maximumWriteValueLengthForType:)]) {
        if (@available(iOS 9.0, *)) {
            _limitLength = [peripheral maximumWriteValueLengthForType:type];//CBCharacteristicWriteWithoutResponse
        } else {
            // Fallback on earlier versions
        }
    }
    
    // 如果_limitLength 小于等于0，则表示不用分段发送
    if (_limitLength <= 0) {
        [peripheral writeValue:data forCharacteristic:characteristic type:type];
        _writeCount ++;
        return;
    }
    
    if (data.length <= _limitLength) {
        [peripheral writeValue:data forCharacteristic:characteristic type:type];
        _writeCount ++;
    } else {
        NSInteger index = 0;
        for (index = 0; index < data.length - _limitLength; index += _limitLength) {
            NSData *subData = [data subdataWithRange:NSMakeRange(index, _limitLength)];
            [peripheral writeValue:subData forCharacteristic:characteristic type:type];
            _writeCount++;
        }
        NSData *leftData = [data subdataWithRange:NSMakeRange(index, data.length - index)];
        if (leftData) {
            [peripheral writeValue:leftData forCharacteristic:characteristic type:type];
            _writeCount++;
        }
    }
}

- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic Peripheral:(CBPeripheral *)peripheral type:(CBCharacteristicWriteType)type completionBlock:(HLWriteToCharacteristicBlock)completionBlock
{
    _writeToCharacteristicBlock = completionBlock;
    [self writeValue:data Peripheral:peripheral forCharacteristic:characteristic type:type];
//    BOOL is =  peripheral.canSendWriteWithoutResponse;    
}
- (void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral{
    
}


- (void)readValueForDescriptor:(CBDescriptor *)descriptor
                    Peripheral:(CBPeripheral *)peripheral
               completionBlock:(HLValueForDescriptorBlock)completionBlock
{
    _valueForDescriptorBlock = completionBlock;
    [self readValueForDescriptor:descriptor Peripheral:peripheral];
}
- (void)readValueForDescriptor:(CBDescriptor *)descriptor Peripheral:(CBPeripheral *)peripheral
{
    [peripheral readValueForDescriptor:descriptor];
}


- (void)writeValue:(NSData *)data Peripheral:(CBPeripheral *)peripheral  forDescriptor:(CBDescriptor *)descriptor completionBlock:(HLWriteToDescriptorBlock)completionBlock
{
    _writeToDescriptorBlock = completionBlock;
    [self writeValue:data Peripheral:peripheral forDescriptor:descriptor];
}
- (void)writeValue:(NSData *)data Peripheral:(CBPeripheral *)peripheral forDescriptor:(CBDescriptor *)descriptor
{
    [peripheral writeValue:data forDescriptor:descriptor];
}

- (void)readRSSICompletionBlock:(HLGetRSSIBlock)getRSSIBlock Peripheral:(CBPeripheral *)peripheral
{
    _getRSSIBlock = getRSSIBlock;
    [peripheral readRSSI];
}

- (BOOL)isScaning{
    return [_centralManager isScanning];
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kCentralManagerStateUpdateNoticiation object:@{@"central":central}];
    
    if (_stateUpdateBlock) {
        _stateUpdateBlock(central);
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    if (_discoverPeripheralBlcok) {
        _discoverPeripheralBlcok(central, peripheral, advertisementData, RSSI);
    }
}

#pragma mark ---------------- 连接外设成功和失败的代理 ---------------
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (_stopScanAfterConnected) {
        [_centralManager stopScan];
    }
    
    if (_discoverServicesBlock) {
        _discoverServicesBlock(peripheral, peripheral.services,nil);
    }
    
    if (_completionBlock) {
        _completionBlock(HLOptionStageConnection,peripheral,nil,nil,nil);
    }
    
    [peripheral discoverServices:_serviceUUIDs];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    if (_discoverServicesBlock) {
        _discoverServicesBlock(peripheral, peripheral.services,error);
    }
    
    if (_completionBlock) {
        _completionBlock(HLOptionStageConnection,peripheral,nil,nil,error);
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    if(_disconnectBlock){
        _disconnectBlock(peripheral, error);
        return;
    }
}

#pragma mark ---------------- 发现服务的代理 -----------------
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error
{
    if (error) {
        if (_completionBlock) {
            _completionBlock(HLOptionStageSeekServices,peripheral,nil,nil,error);
        }
        return;
    }
    
    if (_completionBlock) {
        _completionBlock(HLOptionStageSeekServices,peripheral,nil,nil,nil);
    }
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:_characteristicUUIDs forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(nullable NSError *)error
{
    if (error) {
        if (_discoverdIncludedServicesBlock) {
            _discoverdIncludedServicesBlock(peripheral,service,nil,error);
        }
        return;
    }
    
    if (_discoverdIncludedServicesBlock) {
        _discoverdIncludedServicesBlock(peripheral,service,service.includedServices,error);
    }
}

#pragma mark ---------------- 服务特性的代理 --------------------
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error
{
    if (error) {
        if (_completionBlock) {
            _completionBlock(HLOptionStageSeekCharacteristics,peripheral,service,nil,error);
        }
        return;
    }
    
    if (_discoverCharacteristicsBlock) {
        _discoverCharacteristicsBlock(peripheral,service,service.characteristics,nil);
    }
    
    if (_completionBlock) {
        _completionBlock(HLOptionStageSeekCharacteristics,peripheral,service,nil,nil);
    }
    
//    for (CBCharacteristic *character in service.characteristics) {
//        [peripheral discoverDescriptorsForCharacteristic:character];
//        [peripheral readValueForCharacteristic:character];
//    }

}
//订阅特征值是否成功
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (error) {
        if (_notifyCharacteristicBlock) {
            _notifyCharacteristicBlock(peripheral,characteristic,error);
        }
        return;
    }
    if (_notifyCharacteristicBlock) {
        _notifyCharacteristicBlock(peripheral,characteristic,nil);
    }
}

// 读取特性中的值
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        if (_valueForCharacteristicBlock) {
            _valueForCharacteristicBlock(characteristic,nil,error);
        }
        return;
    }
    NSData *data = characteristic.value;
//    if (data.length > 0) {
//        const unsigned char *hexBytesLight = [data bytes];
//        NSString * battery = [NSString stringWithFormat:@"%02x", hexBytesLight[0]];
//        NSLog(@"batteryInfo:%@",battery);        
//    }
    
    if (_valueForCharacteristicBlock) {
        _valueForCharacteristicBlock(characteristic,data,nil);
    }
}

#pragma mark ---------------- 发现服务特性描述的代理 ------------------
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (error) {
        if (_completionBlock) {
            _completionBlock(HLOptionStageSeekdescriptors,peripheral,nil,characteristic,error);
        }
    }else{
        if (_completionBlock) {
            _completionBlock(HLOptionStageSeekdescriptors,peripheral,nil,characteristic,nil);
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error
{
    if (error) {
        if (_valueForDescriptorBlock) {
            _valueForDescriptorBlock(descriptor,nil,error);
        }
    }else{
        NSData *data = descriptor.value;
        if (_valueForDescriptorBlock) {
            _valueForDescriptorBlock(descriptor,data,nil);
        }
    }
}

#pragma mark ---------------- 写入数据的回调 --------------------
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error
{
    if (error) {
        if (_writeToDescriptorBlock) {
            _writeToDescriptorBlock(descriptor, error);
        }
    }else{
        if (_writeToDescriptorBlock) {
            _writeToDescriptorBlock(descriptor, nil);
        }
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (!_writeToCharacteristicBlock) {
        return;
    }
    
    _responseCount ++;
    if (_writeCount != _responseCount) {
        return;
    }
    
    _writeToCharacteristicBlock(characteristic,error);
}

#pragma mark ---------------- 获取信号之后的回调 ------------------

# if  __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    if (_getRSSIBlock) {
        _getRSSIBlock(peripheral,peripheral.RSSI,error);
    }
}
#else
- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    if (_getRSSIBlock) {
        _getRSSIBlock(peripheral,RSSI,error);
    }
}
#endif



@end
