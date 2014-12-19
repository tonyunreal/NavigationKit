//
//  WGS84TOGCJ02.h
//  NavigationKit
//
//  Created by Tony Borner on 12/18/14.
//  Copyright (c) 2014 CkStudio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface WGS84TOGCJ02 : NSObject

// Converts a WGS84 coordinate into GCJ02 coordinate
+(CLLocationCoordinate2D)transformFromWGSToGCJ:(CLLocationCoordinate2D)wgsLoc;

//
// NOTICE: You are not required to call the method below if you are simply
// converting WGS84 coordinates into GCJ02 coordinates, since the transform
// method calls it automatically. This method is exposed for convenience only.
//

// Checks if a coordinate is outside of China.
+(BOOL)isLocationOutOfChina:(CLLocationCoordinate2D)location;

// Get the "fixed" coordinate when using CLReversedGeocoder within Beijing.
// Please notice this method doesn't really work properly.
+(CLLocationCoordinate2D)fixedBeijingPoiCoordinate:(CLLocationCoordinate2D)location;
@end