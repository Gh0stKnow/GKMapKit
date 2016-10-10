//
//  ViewController.m
//  Mapkit
//  Created by GeXiaodong on 2016/9/21.
//  Copyright © 2016年 GeXiaodong. All rights reserved.
//

#import "ViewController.h"
//导入定位和地图的两个框架
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

// 遵守定位和地图的代理协议
@interface ViewController ()<CLLocationManagerDelegate,MKMapViewDelegate>

//位置管理者
@property (nonatomic, strong) CLLocationManager *localManager;
//地图
@property (nonatomic, strong) MKMapView *mapView;
//存放用户位置的数组
@property (nonatomic, strong) NSMutableArray *locationMutableArray;

// 状态指示
@property (nonatomic, strong) UITextView *textView;

// 移动距离
@property (nonatomic, assign) double meter;

// 过滤器
@property (nonatomic, assign) double meterFilter;

@property (nonatomic, strong) NSMutableArray * points;

// 遮罩物
@property (strong, nonatomic) MKCircle *transparentCircle;

@end

@implementation ViewController



#pragma mark - 位置管理者懒加载
- (CLLocationManager *)localManager
{
    if (_localManager == nil)
    {
        _localManager = [[CLLocationManager alloc]init];
        
        // 设置定位的精度
        [_localManager setDesiredAccuracy:kCLLocationAccuracyBest];
        
// 只在manager回调方法中生效
//        _localManager.distanceFilter = 100;
        
        // 设置代理
        _localManager.delegate = self;

        
        //如果没有授权则请求用户授权,
        //因为 requestAlwaysAuthorization 是 iOS8 后提出的,需要添加一个是否能响应的条件判断,防止崩溃 (respondsToSelector)
        if ([CLLocationManager authorizationStatus]==kCLAuthorizationStatusNotDetermined && [_localManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
            // 授权定位请求
            [_localManager requestAlwaysAuthorization];
        }
        
        //创建存放位置的数组
        _locationMutableArray = [[NSMutableArray alloc] init];
    }
    return _localManager;
}

#pragma mark

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //        初始化过滤器
    _meterFilter = 0;
    _points = [NSMutableArray array];
    
    //全屏显示地图并设置地图的代理
    _mapView = [[MKMapView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _mapView.delegate = self;
    
    //是否启用定位服务
    if ([CLLocationManager locationServicesEnabled]){
        NSLog(@"开始定位");
        //调用 startUpdatingLocation 方法后,会对应进入 didUpdateLocations 方法
        [self.localManager startUpdatingLocation];
    }
    else{
        
        NSLog(@"定位服务为关闭状态,无法使用定位服务");
    }
    

    
    [self.view addSubview:_mapView];
    
    
    // 添加显示gps信息
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 50, 200 ,180)];
    self.textView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.textView.textColor = [UIColor whiteColor];
    self.textView.font = [UIFont systemFontOfSize:14];
    self.textView.editable = NO;
    self.textView.selectable = NO;
    self.textView.userInteractionEnabled = NO;
    [self.view addSubview:_textView];
 
    
}




#pragma mark - MKMapViewDelegate
/**
 最重要的回调方法，此方法调用非常频繁
 更新用户位置，只要用户改变则调用此方法（包括第一次定位到用户位置）
 第一种画轨迹的方法:我们使用在地图上的变化来描绘轨迹,这种方式不用考虑从 CLLocationManager 取出的经纬度在 mapView 上显示有偏差的问题
 */


// 地图加载完成后调用
- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView
{
    // 用户位置追踪
    _mapView.userTrackingMode = MKUserTrackingModeFollow;
    _mapView.zoomEnabled = YES;
    _mapView.showsScale = YES;
    
}



-(void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation{
    
    // 显示gps相关信息
    [self showStatusWith:userLocation.location];
    
    
    //
    //        NSString *latitude = [NSString stringWithFormat:@"%3.5f",userLocation.coordinate.latitude];
    //        NSString *longitude = [NSString stringWithFormat:@"%3.5f",userLocation.coordinate.longitude];
    //        NSLog(@"更新的用户位置:纬度:%@, 经度:%@",latitude,longitude);
    //        NSLog(@"horizontalAccuracy=%f",userLocation.location.horizontalAccuracy);
    
    //        设置地图显示范围(如果不进行区域设置会自动显示区域范围并指定当前用户位置为地图中心点)
    MKCoordinateSpan span = MKCoordinateSpanMake(0.002, 0.002);
    MKCoordinateRegion region = MKCoordinateRegionMake(userLocation.location.coordinate, span);

    [_mapView setRegion:region animated:true];
    
    userLocation.title = @"黑格用户";
    userLocation.subtitle= @"晓东儿";
    
    
    // 判断gps精度区间
    if ((userLocation.location.horizontalAccuracy > 0) && (userLocation.location.horizontalAccuracy <30))
    {
        
        
        if (_locationMutableArray.count != 0) {
            
            //从位置数组中取出最新的位置数据
            NSString *locationStr = _locationMutableArray.lastObject;
            NSArray *temp = [locationStr componentsSeparatedByString:@","];
            NSString *latitudeStr = temp[0];
            NSString *longitudeStr = temp[1];
            CLLocationCoordinate2D startCoordinate = CLLocationCoordinate2DMake([latitudeStr doubleValue], [longitudeStr doubleValue]);
            
            //当前确定到的位置数据
            CLLocationCoordinate2D endCoordinate;
            endCoordinate.latitude = userLocation.coordinate.latitude;
            endCoordinate.longitude = userLocation.coordinate.longitude;
            
            
            
            
            //移动距离的计算
            double meters = [self calculateDistanceWithStart:startCoordinate end:endCoordinate];
            NSLog(@"移动的距离为%f米",meters);
            
            
            
            // 距离过滤器
            // if (1)
            _meterFilter = _meterFilter + _meter;
            
            if (_meterFilter >= 10)
                
            {

                
                NSLog(@"添加进位置数组");
                
                NSString *locationString = [NSString stringWithFormat:@"%f,%f",userLocation.coordinate.latitude, userLocation.coordinate.longitude];
                [_locationMutableArray addObject:locationString];
                
                //开始绘制轨迹
                CLLocationCoordinate2D pointsToUse[2];
                pointsToUse[0] = startCoordinate;
                pointsToUse[1] = endCoordinate;
                
                // 调用 addOverlay 方法后,会进入 rendererForOverlay 方法,完成轨迹的绘制
                MKPolyline *lineOne = [MKPolyline polylineWithCoordinates:pointsToUse count:2];
                
                
                [_mapView addOverlay:lineOne];

                // 重置距离滤器
                _meterFilter = 0;
                
            }
            
        }else{
            //* 数组为空的情况 */
            //存放位置的数组,如果数组包含的对象个数为0,那么说明是第一次进入,将当前的位置添加到位置数组
            NSString *locationString = [NSString stringWithFormat:@"%f,%f",userLocation.coordinate.latitude, userLocation.coordinate.longitude];
            [_locationMutableArray addObject:locationString];
        }
    } else {
        NSLog(@"不添加进位置数组,精度太低");
    }
}




-(MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay{
    
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"
    
    
    //* 轨迹线 */
    if ([overlay isKindOfClass:[MKPolyline class]]){
     
        MKPolylineView *polyLineView = [[MKPolylineView alloc] initWithPolyline:overlay];
        polyLineView.lineWidth = 10; //折线宽度
        polyLineView.strokeColor = [UIColor yellowColor];
        
        return (MKOverlayRenderer *)polyLineView;
    }
    
    
    //* 半透明蒙版 */
    if ([overlay isKindOfClass:[MKCircle class]]){

        MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc] initWithCircle:overlay];
        circleRenderer.fillColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:.2];
        return circleRenderer;
    }
    
#pragma clang diagnostic pop
    
    return nil;
}


#pragma mark - CLLocationManagerDelegate
/**
 *  当前定位授权状态发生改变时调用
 *
 *  @param manager 位置管理者
 *  @param status  授权的状态
 */
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    
    
    
    
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:{
            NSLog(@"用户还未进行授权");
            break;
        }
        case kCLAuthorizationStatusDenied:{
            // 判断当前设备是否支持定位和定位服务是否开启
            if([CLLocationManager locationServicesEnabled]){
                
                NSLog(@"用户不允许程序访问位置信息或者手动关闭了位置信息的访问，帮助跳转到设置界面");
                
                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                
                
                // iOS10 不允许打开系统设置scheme，在这里做了判断
                if ([[UIApplication sharedApplication] canOpenURL:url]) {
                    [[UIApplication sharedApplication] openURL: url];
                }
            }else{
                NSLog(@"定位服务关闭,弹出系统的提示框,点击设置可以跳转到定位服务界面进行定位服务的开启"); 
            }
            
            
            break;
        }
        case kCLAuthorizationStatusRestricted:{
            NSLog(@"受限制的");
            break;
        }
        case kCLAuthorizationStatusAuthorizedAlways:{
            NSLog(@"授权允许在前台和后台均可使用定位服务");
            break;
        }
        case kCLAuthorizationStatusAuthorizedWhenInUse:{
            NSLog(@"授权允许在前台可使用定位服务");
            break;
        }
            
        default:
            break;
    }
}


/**
 我们并没有把从 CLLocationManager 取出来的经纬度放到 mapView 上显示
 原因:
 我们在此方法中取到的经纬度依据的标准是地球坐标,但是国内的地图显示按照的标准是火星坐标
 MKMapView 不用在做任何的处理,是因为 MKMapView 是已经经过处理的
 也就导致此方法中获取的坐标在 mapView 上显示是有偏差的
 解决的办法有很多种,可以上网就行查询,这里就不再多做赘述
 */

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // 设备的当前位置
    CLLocation *currLocation = [locations lastObject];

    NSString *latitude = [NSString stringWithFormat:@"纬度:%3.5f",currLocation.coordinate.latitude];
    NSString *longitude = [NSString stringWithFormat:@"经度:%3.5f",currLocation.coordinate.longitude];
    NSString *altitude = [NSString stringWithFormat:@"高度值:%3.5f",currLocation.altitude];
    NSString *speed = [NSString stringWithFormat:@"速度:%3.5f",currLocation.speed];

    NSLog(@"位置发生改变:纬度:%@,经度:%@,高度:%@,速度:%@",latitude,longitude,altitude,speed);

//    [manager stopUpdatingLocation];
}



//定位失败的回调方法
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"无法获取当前位置 error : %@",error.localizedDescription);
}



#pragma mark - 显示详细状态
- (void)showStatusWith:(CLLocation *)location
{
    NSMutableString *info = [[NSMutableString alloc] init];
    [info appendString:@"coordinate:\n"];
    [info appendString:[NSString stringWithFormat:@"纬度%.4f, 经度%.4f\n", location.coordinate.latitude,location.coordinate.longitude]];
    
    [info appendString:@"速度:\n"];
    
    double speed = location.speed > 0 ? location.speed : 0;
    [info appendString:[NSString stringWithFormat:@"<%.2fm/s(%.2fkm/h)>\n", speed, speed * 3.6]];
    
    [info appendString:@"gps误差:\n"];
    [info appendString:[NSString stringWithFormat:@"%.2fm\n", location.horizontalAccuracy]];
    
    [info appendString:@"高度:\n"];
    [info appendString:[NSString stringWithFormat:@"%.2fm\n", location.altitude]];
    
    [info appendString:@"移动距离:\n"];
    [info appendString:[NSString stringWithFormat:@"%.2fm\n", _meter]];
    
    _textView.text = info;
}

#pragma mark - 添加半透明覆盖层
- (void)addTransparentOverlay{
    self.transparentCircle = [MKCircle circleWithCenterCoordinate:CLLocationCoordinate2DMake(39.905, 116.398) radius:100000000];
    [self.mapView addOverlay:self.transparentCircle level:1];
}


#pragma mark - 经纬度求距离
- (double)calculateDistanceWithStart:(CLLocationCoordinate2D)start end:(CLLocationCoordinate2D)end {
    
    double meter = 0;
    
    double startLongitude = start.longitude;
    double startLatitude = start.latitude;
    double endLongitude = end.longitude;
    double endLatitude = end.latitude;
    
    double radLatitude1 = startLatitude * M_PI / 180.0;
    double radLatitude2 = endLatitude * M_PI / 180.0;
    double a = fabs(radLatitude1 - radLatitude2);
    double b = fabs(startLongitude * M_PI / 180.0 - endLongitude * M_PI / 180.0);
    
    double s = 2 *asin(sqrt(pow(sin(a/2),2) + cos(radLatitude1) * cos(radLatitude2) * pow(sin(b/2),2)));
    s = s * 6378137;
    
    meter = round(s * 10000) / 10000;
    self.meter = meter;
    return meter;
}


@end
