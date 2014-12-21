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

+(BOOL)isCoordinate:(CLLocationCoordinate2D)coordinate onPath:(NSArray *)path tolerance:(CLLocationDistance)tolerance
{
    BOOL result = NO;
    
//    NSLog(@"%@, %f", location, tolerance);
    
    // iterate over all road paths
    for(int i = 0; i < [path count]-1; i++)
    {

        CLLocationCoordinate2D coordinate1 = [[path objectAtIndex:i] MKCoordinateValue];
        CLLocationCoordinate2D coordinate2 = [[path objectAtIndex:i+1] MKCoordinateValue];
        
        // to find the nearest point to "location" on this road
        // we calculate the distance from coordinate to coordinate1 as d1
        // the angle between lines co1-co and co1-co2 as alpha1
        // the angle between lines co-co2 and co1-co2 as alpha2
        // then we use trianglar function
        //
        // if alpha1 and alpha2 are both within 0~M_PI_2
        // then d = d1 * sin(alpha1)
        // if alpha1 is larger than M_PI_2 then co1 is the nearest point
        // if alpha2 is larger than M_PI_2 then co2 is the nearest point
        CLLocationDegrees alpha1 = abs(atan2(coordinate.longitude - coordinate1.longitude, coordinate.latitude - coordinate1.latitude) - atan2(coordinate2.longitude - coordinate1.longitude, coordinate2.latitude - coordinate1.latitude));
        CLLocationDegrees alpha2 = abs(atan2(coordinate2.longitude - coordinate.longitude, coordinate2.latitude - coordinate.latitude) - atan2(coordinate1.longitude - coordinate2.longitude, coordinate1.latitude - coordinate2.latitude));
        // alpha1 and alpha2 should be converted from [0, M_2_PI] to [0, M_PI]
        if (alpha1 > M_PI) alpha1 = M_2_PI - alpha1;
        if (alpha2 > M_PI) alpha2 = M_2_PI - alpha2;
        
        CLLocationDistance distance;
        if (alpha1 >= M_PI_2)
        {
            distance = [[[CLLocation alloc] initWithLatitude:coordinate1.latitude longitude:coordinate1.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude]];
        }
        else if (alpha2 >= M_PI_2)
        {
            distance = [[[CLLocation alloc] initWithLatitude:coordinate2.latitude longitude:coordinate2.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude]];
        }
        else
        {
            distance = [[[CLLocation alloc] initWithLatitude:coordinate1.latitude longitude:coordinate1.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude]] * sin(alpha1);
        }

        // check if location is within the tolerated area from that point
        if (distance <= tolerance)
        {
//            NSLog(@"%f is no greater than %f", d, tolerance);
            // distance is lesser than tolerance, location is on path
            result = YES;
            break;
        }
    }
    
    if (!result && tolerance > 20.0)
    {
        NSLog(@"location {%.3f, %.3f} is more than %.1f far from path", coordinate.latitude, coordinate.longitude, tolerance);
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
