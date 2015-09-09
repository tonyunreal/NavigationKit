//
//  NKRoute.m
//  Pods
//
//  Created by Axel Möller on 11/12/14.
//  Copyright (c) 2014 Sendus Sverige AB. All rights reserved.
//

#import "NKRoute.h"
#import "NKRouteStep.h"

@implementation NKRoute

- (id)initWithMKRoute:(MKRoute *)route {
    self = [super init];
    
    if(self && route) {
        
        // Convert Polyline coordinates to GMSPath
        NSMutableArray *path = [NSMutableArray arrayWithCapacity:[[route steps] count]];
        for(MKRouteStep *routeStep in [route steps]) {
            
            NSInteger stepPoints = routeStep.polyline.pointCount;
            CLLocationCoordinate2D *coordinates = malloc(stepPoints * sizeof(CLLocationCoordinate2D));
            [routeStep.polyline getCoordinates:coordinates range:NSMakeRange(0, stepPoints)];
            
            for(int i = 0; i < stepPoints; i++) {
                [path addObject:[NSValue valueWithMKCoordinate:coordinates[i]]];
            }
        }
        
        self.path = path;
        
        // Save polyline
        self.polyline = [route polyline];
        
        // Convert array of MKRouteStep's to NKRouteStep's
        NSMutableArray *routeSteps = [[NSMutableArray alloc] init];
        
        for(MKRouteStep *step in [route steps]) {
            NKRouteStep *routeStep = [[NKRouteStep alloc] initWithMKRouteStep:step];
            [routeSteps addObject:routeStep];
        }
        
        self.steps = routeSteps;
        
        // Save expectedTravelTime
        self.expectedTravelTime = [route expectedTravelTime];
        self.distance = route.distance;
    }
    
    return self;
}

@end
