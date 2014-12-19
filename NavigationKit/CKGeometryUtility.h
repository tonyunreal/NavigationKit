//
//  CKGeometryUtility.h
//  NavigationKit
//
//  Created by Tony Borner on 12/18/14.
//  Copyright (c) 2014 CkStudio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface CKGeometryUtility : NSObject

+(BOOL)isLocation:(CLLocation *)location onPath:(NSArray *)path tolerance:(CLLocationDistance)tolerance;

+(CLLocationDirection)geometryHeadingFrom:(CLLocationCoordinate2D)from to:(CLLocationCoordinate2D)to;

@end
