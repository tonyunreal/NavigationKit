//
//  CKGeometryUtility.m
//  NavigationKit
//
//  Created by Tony Borner on 12/18/14.
//  Copyright (c) 2014 Axel Moller. All rights reserved.
//

#import "CKGeometryUtility.h"
#import <MapKit/MapKit.h>

@implementation CKGeometryUtility

+(BOOL)isLocation:(CLLocation *)location onPath:(NSArray *)path tolerance:(CLLocationDistance)tolerance
{
    BOOL result = NO;
    
    NSLog(@"%@, %f", location, tolerance);
    
    // 循环检查所有点
    for(int i = 0; i < [path count]; i++)
    {

        CLLocationCoordinate2D coordinate = [[path objectAtIndex:i] MKCoordinateValue];
        
        NSLog(@"%f, %f", coordinate.latitude, coordinate.longitude);
        
        // 检查是否在范围内
        CLLocation *targetLocation = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
        if ([location distanceFromLocation:targetLocation] <= tolerance)
        {
            NSLog(@"%f is no greater than %f", [location distanceFromLocation:targetLocation], tolerance);
            // 距离未超出tolerance，说明在路径上
            result = YES;
            break;
        }
    }

    return result;
}

+(CLLocationDirection)geometryHeadingFrom:(CLLocationCoordinate2D)from to:(CLLocationCoordinate2D)to
{
    // 计算横纵坐标差距
    CLLocationDistance deltaX = [[[CLLocation alloc] initWithLatitude:from.latitude longitude:from.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:from.latitude longitude:to.longitude]];
    CLLocationDistance deltaY = [[[CLLocation alloc] initWithLatitude:from.latitude longitude:from.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:to.latitude longitude:from.longitude]];
    
    // 通过tan(heading) = x /y 计算出角度
    double heading = 0.0;
    if (deltaY != 0.0)
    {
        heading = atan(deltaX / deltaY) * 90.0 / M_PI_2;
    }
    
    // 根据象限来修正heading
    if (to.longitude > from.longitude && to.latitude < from.latitude)
    {
        heading = 180.0 - heading;
    }
    else if (to.longitude < from.longitude && to.latitude < from.latitude)
    {
        heading = 180.0 + heading;
    }
    else if (to.longitude < from.longitude && to.latitude > from.latitude)
    {
        heading = 360.0 - heading;
    }
    
    NSLog(@"heading is %f", heading);
    
    return heading;
}

@end
