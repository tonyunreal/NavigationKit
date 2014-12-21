//
//  CKGeometryUtility.m
//  NavigationKit
//
//  Created by Tony Borner on 12/18/14.
//  Copyright (c) 2014 CkStudio. All rights reserved.
//

#import "CKGeometryUtility.h"
#import <MapKit/MapKit.h>

@implementation CKGeometryUtility

+(BOOL)isLocation:(CLLocation *)location onPath:(NSArray *)path tolerance:(CLLocationDistance)tolerance
{
    BOOL result = NO;
    
//    NSLog(@"%@, %f", location, tolerance);
    
    // iterate over all points
    for(int i = 0; i < [path count]; i++)
    {

        CLLocationCoordinate2D coordinate = [[path objectAtIndex:i] MKCoordinateValue];
        
//        NSLog(@"%f, %f", coordinate.latitude, coordinate.longitude);
        
        // check if location is within the tolerated area from that point
        CLLocation *targetLocation = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
        if ([location distanceFromLocation:targetLocation] <= tolerance)
        {
//            NSLog(@"%f is no greater than %f", [location distanceFromLocation:targetLocation], tolerance);
            // distance is lesser than tolerance, location is on path
            result = YES;
            break;
        }
    }
    
    if (!result && tolerance > 20.0)
    {
        NSLog(@"location {%.3f, %.3f} is more than %.1f far from path", location.coordinate.latitude, location.coordinate.longitude, tolerance);
    }

    return result;
}

+(CLLocationDirection)geometryHeadingFrom:(CLLocationCoordinate2D)from to:(CLLocationCoordinate2D)to
{
    // calculate the horizontal/vertical delta from point A to point B
    CLLocationDistance deltaX = [[[CLLocation alloc] initWithLatitude:from.latitude longitude:from.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:from.latitude longitude:to.longitude]];
    CLLocationDistance deltaY = [[[CLLocation alloc] initWithLatitude:from.latitude longitude:from.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:to.latitude longitude:from.longitude]];
    
    // calculate the 0~90 angle with tan(heading) = x /y
    double heading = 0.0;
    if (deltaY != 0.0)
    {
        heading = atan(deltaX / deltaY) * 90.0 / M_PI_2;
    }
    
    // convert the angle into full Cartesian system
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
    
    //NSLog(@"heading is %f", heading);
    
    return heading;
}

@end
