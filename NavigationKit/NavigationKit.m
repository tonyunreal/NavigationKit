//
//  NavigationKit.m
//  Pods
//
//  Created by Axel Möller on 11/12/14.
//  Copyright (c) 2014 Sendus Sverige AB. All rights reserved.
//

#import "NavigationKit.h"

#import "CKGeometryUtility.h"

#define NavigationKitErrorDomain @"com.navigationkit"

@interface NavigationKit ()

// Initializing
@property (nonatomic) CLLocationCoordinate2D source;
@property (nonatomic) CLLocationCoordinate2D destination;
@property (nonatomic) MKDirectionsTransportType transportType;
@property (nonatomic) NavigationKitDirectionsService directionsService;

// Objects for calculated route
@property (nonatomic, strong) NKRoute *route;

// Information to keep track of progress
@property (nonatomic) NSInteger currentStepInRoute;
@property (nonatomic) CLLocationDistance distanceToEndOfPath;
@property (nonatomic) CLLocationDistance distanceToEndOfRoute;
@property (nonatomic, strong) NSMutableArray *stepNotifications;
@property (nonatomic) CLLocationDirection heading;

@property (nonatomic, strong) NSDate *lastCalculatedDate;
@end

@implementation NavigationKit
@synthesize delegate;
static NSTimeInterval kMinTimeBetweenRecalculations = 10.f;

- (id)initWithSource:(CLLocationCoordinate2D)source destination:(CLLocationCoordinate2D)destination transportType:(MKDirectionsTransportType)transportType directionsService:(NavigationKitDirectionsService)directionsService {
    self = [super init];
    
    if(self) {
        _source = source;
        _destination = destination;
        _transportType = transportType;
        _directionsService = directionsService;
        _recalculatingTolerance = -1;
        _cameraAltitude = -1;
        _heading = -1;
    }
    
    return self;
}

- (void)calculateDirections
{
    [self calculateDirectionsWithHeading:-1];
}

- (void)calculateDirectionsWithHeading:(CLLocationDirection)heading {
    self.isNavigating = NO;
    self.route = nil;
    self.currentStepInRoute = 1;
    self.distanceToEndOfPath = 0;
    self.distanceToEndOfRoute = 0;
    self.stepNotifications = [[NSMutableArray alloc] init];
    self.lastCalculatedDate = [NSDate date];
    
    switch (self.directionsService) {
        case NavigationKitDirectionsServiceAppleMaps:
            [self calculateDirectionsAppleMapsWithHeading:heading];
            break;
        default:
        {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Invalid Directions Service", nil)
                                       };
            
            if([delegate respondsToSelector:@selector(navigationKitError:)])
                [delegate navigationKitError:[NSError errorWithDomain:NavigationKitErrorDomain code:-1 userInfo:userInfo]];
            break;
        }
    }
}

- (void)startNavigation {
    self.isNavigating = YES;
    self.heading = -1;
    if([delegate respondsToSelector:@selector(navigationKitStartedNavigation)])
        [delegate navigationKitStartedNavigation];
    
    // This might be a temporary fix, but for now, notify the delegate that we entered step "0"
    if([delegate respondsToSelector:@selector(navigationKitEnteredRouteStep:nextStep:)]) {
      NKRouteStep *firstStep = self.route.steps[self.currentStepInRoute];
      [delegate navigationKitEnteredRouteStep:firstStep nextStep:self.route.steps[1]];
    }
}

- (void)stopNavigation {
    self.isNavigating = NO;
    if([delegate respondsToSelector:@selector(navigationKitStoppedNavigation)])
        [delegate navigationKitStoppedNavigation];
}

- (void)recalculateNavigation {
    if ([[NSDate date] timeIntervalSinceDate:self.lastCalculatedDate] < kMinTimeBetweenRecalculations) return;

    if([delegate respondsToSelector:@selector(navigationKitStartedRecalculation)])
        [delegate navigationKitStartedRecalculation];
    
    [self stopNavigation];
    [self calculateDirectionsWithHeading:self.heading];
    [self startNavigation];
}

- (void)calculateActionForLocation:(CLLocation *)location {
    
    // If Turn-by-Turn navigation is not enabled, don't perform any calculations
    if(!self.isNavigating || location == nil || self.route == nil)
        return;
    
    // Calculate wether the user is anywhere on the path returned from the directions service (i.e. on route)
    // The default tolerance is 50m
    // Recalculate navigation if user is off path
    BOOL userOnPath = [CKGeometryUtility isCoordinate:location.coordinate onPath:self.route.path tolerance:self.recalculatingTolerance == -1 ? 100 : self.recalculatingTolerance];
    if(!userOnPath) {
        // Set source coordinate to the latest location
        self.source = [location coordinate];
        return [self recalculateNavigation];
    }
    
    // Calculate which step we are on the path
    // Initially ignore steps that we have already "seen", but if a step was not found then, iterate through all steps in route
    int currentStep = [self stepForLocation:location initialOffset:(int)self.currentStepInRoute];
    //NSLog(@"current step = %d", currentStep);
    
    // We can not currently find which step we are on
    if(currentStep == INT_MAX) {
      return;
    }
    
    NKRouteStep *currentRouteStep = self.route.steps[currentStep];
    NKRouteStep *nextRouteStep = [self.route steps].count - 1 > currentStep ? self.route.steps[currentStep + 1] : nil;
    
    // Calculate the driving distance to the end of the current path
    if([delegate respondsToSelector:@selector(navigationKitCalculatedDistanceToEndOfPath:)]) {
        self.distanceToEndOfPath = [self distanceToEndOfPath:[currentRouteStep path] location:location];
        [delegate navigationKitCalculatedDistanceToEndOfPath:self.distanceToEndOfPath];
    }

    if([delegate respondsToSelector:@selector(navigationKitCalculatedDistanceToEndOfRoute:)]) {
        self.distanceToEndOfRoute = [self distanceToEndOfRoute:currentRouteStep location:location];
        [delegate navigationKitCalculatedDistanceToEndOfRoute:self.distanceToEndOfRoute];
    }

    // Set the global variable 'currentStepInRoute' to 'currentStep' if updated
    // and notify delegate that text and voice instructions should be updated
    if(currentStep != self.currentStepInRoute) {
        self.currentStepInRoute = currentStep;
        
        // Notify delegate that we entered a new step
        if([delegate respondsToSelector:@selector(navigationKitEnteredRouteStep:nextStep:)])
            [delegate navigationKitEnteredRouteStep:currentRouteStep nextStep:nextRouteStep];
        
        // Notify delegate to notify the user that we have entered a step (e.g. Speech Synthesizing)
        if([delegate respondsToSelector:@selector(navigationKitCalculatedNotificationForStep:inDistance:)]) {
            [delegate navigationKitCalculatedNotificationForStep:currentRouteStep inDistance:self.distanceToEndOfPath];
            // If the distance to the next step is less than 100m, don't repeat this message
            // Messages are repeated when the user comes to the end of the road (see below)
            if(self.distanceToEndOfPath < 100)
                [self.stepNotifications addObject:currentRouteStep];
        }
    }
    
    // Speak instructions to the user if we are getting close to the end of the current step
    // Do not speak instructions of already considered spoken
    // It is considered close if:
    // Distance to end of path is less than or equal to 200m AND
    // Total distance of path is more than or equal to 1000m AND
    // OR if
    // Distance to end of path is less than or equal to 50m
    if ([self.stepNotifications indexOfObject:currentRouteStep] == NSNotFound) {
        if((self.distanceToEndOfPath <= 300.0 && currentRouteStep.distance >= 1000.0) ||
            self.distanceToEndOfPath <= 150.f) {
          [self notifyForStep:currentRouteStep];
        }
    }
    
    // Calculate the camera angle based on current step, heading and user settings
    if([delegate respondsToSelector:@selector(navigationKitCalculatedCamera:)]) {
        MKMapCamera *camera = nil;
        if(self.currentStepInRoute == 0)
            camera = [self defaultCamera:location];
        else
            camera = [self cameraForStep:currentRouteStep location:location];
        
        if(camera)
            [delegate navigationKitCalculatedCamera:camera];
    }
}

- (void)notifyForStep:(NKRouteStep *)currentRouteStep {
  if ([delegate respondsToSelector:@selector(navigationKitCalculatedNotificationForStep:inDistance:)]) {
    [delegate navigationKitCalculatedNotificationForStep:currentRouteStep inDistance:self.distanceToEndOfPath];
    [self.stepNotifications addObject:currentRouteStep];
    if (currentRouteStep == self.route.steps.lastObject) {
      [self stopNavigation];
    }
  }
}

- (CLLocationDistance)distanceToEndOfRoute:(NKRouteStep *)curStep location:(CLLocation *)location {
  CLLocationDistance totalDistance = [self distanceToEndOfPath:curStep.path location:location];
  for (NSUInteger i = self.route.steps.count - 1; i > self.currentStepInRoute; i--) {
    NKRouteStep *step = self.route.steps[i];
    totalDistance += [self pathDistance:step.path];
  }
  return totalDistance;
}

- (CLLocationDistance)pathDistance:(NSArray *)path {
  CLLocationDistance totalDistance = 0;
  for(NSUInteger i = 0; i < path.count - 1; i++) {
    CLLocationDistance distance = [[self locationFromCoordinate:[path[i] MKCoordinateValue]]
        distanceFromLocation:[self locationFromCoordinate:[path[i + 1] MKCoordinateValue]]];
    totalDistance += distance;
  }

  return totalDistance;
}

#pragma mark - The inner workings (Math, Algorithms, Easy)

- (void)calculateDirectionsAppleMapsWithHeading:(CLLocationDirection)heading {
    
    MKDirectionsRequest *directionsRequest = [[MKDirectionsRequest alloc] init];
    
    MKPlacemark *source = [[MKPlacemark alloc] initWithCoordinate:self.source addressDictionary:nil];
    MKPlacemark *destination = [[MKPlacemark alloc] initWithCoordinate:self.destination addressDictionary:nil];
    
    [directionsRequest setSource:[[MKMapItem alloc] initWithPlacemark:source]];
    [directionsRequest setDestination:[[MKMapItem alloc] initWithPlacemark:destination]];
    directionsRequest.transportType = self.transportType;
    directionsRequest.requestsAlternateRoutes = YES;
    
    MKDirections *directions = [[MKDirections alloc] initWithRequest:directionsRequest];
    
    [directions calculateDirectionsWithCompletionHandler:^(MKDirectionsResponse *response, NSError *error) {
        if(error) {
            if([delegate respondsToSelector:@selector(navigationKitError:)])
                [delegate navigationKitError:error];
            return;
        }

        // both of these are NKRoute objects
        NSMutableArray *allRoutes = [NSMutableArray arrayWithCapacity:[response.routes count]];
        NSMutableArray *noturnRoutes = [NSMutableArray arrayWithCapacity:[response.routes count]];
        for (MKRoute *route in response.routes)
        {
            // converts to NKRoute so we don't need to deal with C arrays
            NKRoute *nkRoute = [[NKRoute alloc] initWithMKRoute:route];
            
            // add nkRoute to all routes
            [allRoutes addObject:nkRoute];
            
            // Check every route and find better ones based on current heading
            //
            // Why? because being told constantly to turn around when driving
            // is not fun. :-/
            //
            if (heading >= 0.0)
            {
                // first two points from the route
                NSUInteger pos1 = 0;
                NSUInteger pos2 = 1;
                CLLocationCoordinate2D point1 = [nkRoute.path[pos1] MKCoordinateValue];
                CLLocationCoordinate2D point2 = [nkRoute.path[pos2] MKCoordinateValue];
                
                // check if the two points are too close
                BOOL shouldSkipHeadingCheck = NO;
                while ([[[CLLocation alloc] initWithLatitude:point1.latitude longitude:point1.longitude] distanceFromLocation:[[CLLocation alloc] initWithLatitude:point2.latitude longitude:point2.longitude]] < 15)
                {
                    // all paths are too short so it doesn't matter
                    if ([nkRoute.path count] <= pos2 + 1)
                    {
                        // no other steps
                        shouldSkipHeadingCheck = YES;
                        break;
                    }
                    else
                    {
                        // check next step
                        point1 = [nkRoute.path[++pos1] MKCoordinateValue];
                        point2 = [nkRoute.path[++pos2] MKCoordinateValue];
                    }
                }
                
                if (!shouldSkipHeadingCheck)
                {
                    // calculate heading from point1 to point2
                    CLLocationDirection targetHeading = [CKGeometryUtility geometryHeadingFrom:point1 to:point2];
                    
                    // turning left or right is ok
                    // turning more than 120 degrees is not
                    double deltaHeading = fabs(targetHeading - heading);
                    // deltaHeading should be 0~360
                    if (deltaHeading >= 120.0 && deltaHeading <= 360.0 - 120.0)
                    {
                        // turning more than 120 degrees, this path is not ok
                        nkRoute = nil;
                    }
                }
                
                // adds this satisfying route as one of our options
                if (nkRoute != nil)
                {
                    [noturnRoutes addObject:nkRoute];
                }
            } // end of if (heading)
        }
        
        if ([noturnRoutes count] > 0)
        {
            // some routes don't involve turning around
            // even if this could result in longer drive time
            // this could still potentially be better
            allRoutes = noturnRoutes;
        }
        
        // we still need to sort the routes by predicted travel time
        //
        // so the user wouldn't see stupid route that tells them to travel
        // through a long path then turn around multiple times
        //
        self.route = [[allRoutes sortedArrayUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"expectedTravelTime" ascending:YES]]] firstObject];
        
        if([delegate respondsToSelector:@selector(navigationKitCalculatedRoute:)])
            [delegate navigationKitCalculatedRoute:self.route];
    }];
}

// Generate a CLLocation from a CLLocationCoordinate2D
- (CLLocation *)locationFromCoordinate:(CLLocationCoordinate2D)coordinate {
    return [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
}

// Figure out what step of the route a location is on
- (int)stepForLocation:(CLLocation *)location initialOffset:(int)initialOffset {
    
    int step = INT_MAX;
    
    for(int i = initialOffset; i < self.route.steps.count; i++) {
        NKRouteStep *routeStep = self.route.steps[i];
        //NSLog(@"step %d", i);
        if([CKGeometryUtility isCoordinate:location.coordinate onPath:[routeStep path] tolerance:15]) {
            step = i;
            break;
        }
    }
    
    if(step != INT_MAX)
        return step;
    
    for(NKRouteStep *routeStep in self.route.steps) {
        //NSLog(@"step %d", (int)[self.route.steps indexOfObject:routeStep]);
        if([CKGeometryUtility isCoordinate:location.coordinate onPath:[routeStep path] tolerance:15]) {
            step = (int)[self.route.steps indexOfObject:routeStep];
            break;
        }
    }
    
    return step;
}

// Calculate the distance (meters) from a location to the last point in a route step
- (CLLocationDistance)distanceToEndOfPath:(NSArray *)path location:(CLLocation *)location {
    
    CLLocationDistance totalDistance = 0.0;
    
    // If it's a straight road, get the distance between me and the last point
    if([path count] == 2)
        return [location distanceFromLocation:[self locationFromCoordinate:[path[1] MKCoordinateValue]]];
    
    // Find the closest point
    CLLocationDistance smallestDistance = INT_MAX;
    int closestPoint = INT_MAX;
    
    for(int i = 0; i < [path count]; i++) {
        CLLocationDistance distance = [[self locationFromCoordinate:[path[i] MKCoordinateValue]] distanceFromLocation:location];
        if(distance < smallestDistance) {
            smallestDistance = distance;
            closestPoint = i;
        }
    }
    
    // Find the total distance from the closest point to the last point
    if(closestPoint == [path count])
        return smallestDistance;
    
    for(int i = closestPoint; i < [path count]-1; i++) {
        CLLocationDistance distance = [[self locationFromCoordinate:[path[i] MKCoordinateValue]] distanceFromLocation:[self locationFromCoordinate:[path[i + 1] MKCoordinateValue]]];
        totalDistance += distance;
    }
    
    return totalDistance;
}

- (BOOL)string:(NSString *)string findSubstring:(NSString *)substring {
    return [string rangeOfString:[substring lowercaseString]].location != NSNotFound;
}

// The Default camera (for step 0, where we don't really have a heading yet)
- (MKMapCamera *)defaultCamera:(CLLocation *)location {
  return [MKMapCamera cameraLookingAtCenterCoordinate:location.coordinate
                                    fromEyeCoordinate:location.coordinate
                                          eyeAltitude:self.cameraAltitude == -1 ? 500 : self.cameraAltitude];
}

// Calculate the camera based on the users settings
- (MKMapCamera *)cameraForStep:(NKRouteStep *)step location:(CLLocation *)location {
    
    // Find the two closest points in step based on current location
    int i, first, second;
    first = second = INT_MAX;
    CLLocationDistance firstDistance, secondDistance;
    firstDistance = secondDistance = INT_MAX;
    
    for(i = 0; i < [step.path count]; i++) {
        CLLocationDistance distance = [[self locationFromCoordinate:[step.path[i] MKCoordinateValue]] distanceFromLocation:location];
        
        if(distance < firstDistance) {
            second = first;
            first = i;
            secondDistance = firstDistance;
            firstDistance = distance;
        }
        
        else if(distance < secondDistance && distance != first) {
            second = i;
            secondDistance = distance;
        }
    }
    
    // return null if we failed to find locations
    if(first == INT_MAX || second == INT_MAX)
        return nil;

    // Get heading
    // Sort it so we calculate heading based on points in order, regardless of which one is closest
    int firstOccurance = first < second ? first : second;
    int secondOccurance = first < second ? second : first;
    // Get heading
    CLLocationDirection heading = [CKGeometryUtility geometryHeadingFrom:[step.path[firstOccurance] MKCoordinateValue]
                                                                      to:[step.path[secondOccurance] MKCoordinateValue]];

    CLLocationCoordinate2D coordinateWithOffset = [NavigationKit coordinate:location.coordinate atDistance:200
                                                                    bearing:heading];

    MKMapCamera *newCamera = [MKMapCamera camera];
    
    [newCamera setCenterCoordinate:coordinateWithOffset];
    [newCamera setPitch:60];
    [newCamera setHeading:heading];
    self.heading = heading;
    [newCamera setAltitude:self.cameraAltitude == -1 ? 500 : self.cameraAltitude];
    
    return newCamera;
}

+ (double)radiansFromDegrees:(double)degrees {
    return degrees * (M_PI / 180.0);
}

+ (double)degreesFromRadians:(double)radians {
    return radians * (180.0 / M_PI);
}

// Calculate a CLLocationCoordinate2D at n meters ahead of a location with bearing
+ (CLLocationCoordinate2D)coordinate:(CLLocationCoordinate2D)fromCoordinate atDistance:(double)distance bearing:
    (double)bearing {
    
    double distanceRadians = (distance / 1000) / 6371.0; // 6371 is the earths radius in km
    double bearingRadians = [self radiansFromDegrees:bearing];
    double fromLatitudeRadians = [self radiansFromDegrees:fromCoordinate.latitude];
    double fromLongitudeRadians = [self radiansFromDegrees:fromCoordinate.longitude];
    
    double toLatitudeRadians = asin(sin(fromLatitudeRadians) * cos(distanceRadians) + cos(fromLatitudeRadians) * sin(distanceRadians) * cos(bearingRadians));
    double toLongitudeRadians = fromLongitudeRadians + atan2(sin(bearingRadians) * sin(distanceRadians) * cos(fromLatitudeRadians), cos(distanceRadians) - sin(fromLatitudeRadians) * sin(toLatitudeRadians));
    
    // Adjust toLongitudeRadians to be in the range -180 - +180
    toLongitudeRadians = fmod((toLongitudeRadians + 3 * M_PI), (2 * M_PI)) - M_PI;
    
    CLLocationCoordinate2D toCoordinate;
    toCoordinate.latitude = [self degreesFromRadians:toLatitudeRadians];
    toCoordinate.longitude = [self degreesFromRadians:toLongitudeRadians];
    
    return toCoordinate;
}

@end