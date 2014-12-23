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
    
    if ([path count] == 1)
    {
        // check where the only point on path is far enough
        CLLocationCoordinate2D coordinateX = [[path firstObject] MKCoordinateValue];
        if ([[[CLLocation alloc] initWithLatitude:coordinateX.latitude longitude:coordinateX.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude]] <= tolerance)
        {
            return YES;
        }
    }
    
    // iterate over all road paths
    for(int i = 0; i < [path count]-1; i++)
    {

        CLLocationCoordinate2D coordinate1 = [[path objectAtIndex:i] MKCoordinateValue];
        CLLocationCoordinate2D coordinate2 = [[path objectAtIndex:i+1] MKCoordinateValue];
        
        // why is there duplicate coordinates?
        if (coordinate1.latitude == coordinate2.latitude && coordinate1.longitude == coordinate2.longitude) continue;
        
        // to find the nearest point to "location" on this road
        // we calculate the distance from coordinate to coordinate1 as d1
        // the angle between lines co1-co and co1-co2 as alpha1
        // the angle between lines co2-co and co2-co1 as alpha2
        // then we use trianglar function
        //
        // if alpha1 and alpha2 are both within 0~M_PI_2
        // then d = d1 * sin(alpha1)
        // if alpha1 is larger than M_PI_2 then co1 is the nearest point
        // if alpha2 is larger than M_PI_2 then co2 is the nearest point
        CLLocationDegrees alpha1 = fabs(atan2(coordinate.longitude - coordinate1.longitude, coordinate.latitude - coordinate1.latitude) - atan2(coordinate2.longitude - coordinate1.longitude, coordinate2.latitude - coordinate1.latitude));
        CLLocationDegrees alpha2 = fabs(atan2(coordinate.longitude - coordinate2.longitude, coordinate.latitude - coordinate2.latitude) - atan2(coordinate1.longitude - coordinate2.longitude, coordinate1.latitude - coordinate2.latitude));
        
//        NSLog(@"alpha1 = %f, alpha2 = %f", alpha1, alpha2);

        // alpha1 and alpha2 should be converted from [0, M_PI*2] to [0, M_PI]
        if (alpha1 > M_PI) alpha1 = M_PI * 2.0 - alpha1;
        if (alpha2 > M_PI) alpha2 = M_PI * 2.0 - alpha2;
        
//        NSLog(@"alpha1 = %f, alpha2 = %f", alpha1, alpha2);
        
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
            //NSLog(@"path {%f, %f} - {%f, %f}, location {%f, %f}", coordinate1.latitude, coordinate1.longitude, coordinate2.latitude, coordinate2.longitude, coordinate.latitude, coordinate.longitude);
            //NSLog(@"{%f, %f, %f}", [[[CLLocation alloc] initWithLatitude:coordinate1.latitude longitude:coordinate1.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude]], [[[CLLocation alloc] initWithLatitude:coordinate2.latitude longitude:coordinate2.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude]], [[[CLLocation alloc] initWithLatitude:coordinate1.latitude longitude:coordinate1.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:coordinate2.latitude longitude:coordinate2.longitude]]);
            //NSLog(@"%f is no greater than %f", distance, tolerance);
            // distance is lesser than tolerance, location is on path
            result = YES;
            break;
        }
        //NSLog(@"%f is too far than %f", distance, tolerance);
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
    // somehow second and fourth quadrant is swapped, not sure why
    if (to.longitude > from.longitude && to.latitude < from.latitude)
    {
        // second quadrant
        //heading = 180.0 - heading;
        heading = 360.0 - heading;
    }
    else if (to.longitude < from.longitude && to.latitude < from.latitude)
    {
        // third quadrant
        heading = 180.0 + heading;
    }
    else if (to.longitude < from.longitude && to.latitude > from.latitude)
    {
        // fourth quadrant
        //heading = 360.0 - heading;
        heading = 180.0 - heading;
    }
    
    //NSLog(@"heading is %f", heading);
    
    return heading;
}

@end
