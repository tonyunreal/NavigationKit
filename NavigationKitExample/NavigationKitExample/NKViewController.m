//
//  NKViewController.m
//  NavigationKit
//
//  Created by Axel Moller on 12/11/2014.
//  Copyright (c) 2014 Axel Moller. All rights reserved.
//

#import "NKViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "NavigationKit.h"
#import "WGS84TOGCJ02.h"

@interface NKViewController () <CLLocationManagerDelegate, NavigationKitDelegate, AVSpeechSynthesizerDelegate>

@property (nonatomic, strong) CLLocationManager     *locationManager;
@property (nonatomic, strong) NavigationKit         *navigationKit;

@end

@implementation NKViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Ask for User location
    self.locationManager = [[CLLocationManager alloc] init];
    [self.locationManager setDelegate:self];
    [self.locationManager requestWhenInUseAuthorization];
	
    [self.sourceTextField setAttributedPlaceholder:[[NSAttributedString alloc] initWithString:self.sourceTextField.placeholder attributes:@{NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.6]}]];
    [self.destinationTextField setAttributedPlaceholder:[[NSAttributedString alloc] initWithString:self.destinationTextField.placeholder attributes:@{NSForegroundColorAttributeName: [[UIColor whiteColor] colorWithAlphaComponent:0.6]}]];

    // default audio session (media playback no music volume duck)
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:NULL];
    [session setActive:YES error:NULL];
    
    // start updating user location
    self.mapView.showsUserLocation = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

-(BOOL)prefersStatusBarHidden
{
    return NO;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    [textField resignFirstResponder];
    
    if([textField isEqual:self.sourceTextField]) {
        [self.destinationTextField becomeFirstResponder];
        return YES;
    }
    
    if([textField isEqual:self.destinationTextField]) {
        [self navigateFrom:self.sourceTextField.text to:self.destinationTextField.text];
        return YES;
    }
    
    return NO;
}

#pragma - MKMapViewDelegate

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    MKPolylineRenderer *routeLineRenderer = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline*)overlay];
    routeLineRenderer.strokeColor = [UIColor colorWithRed:0.000 green:0.620 blue:0.827 alpha:1];
    routeLineRenderer.lineWidth = 5;
    return routeLineRenderer;
}

-(void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    if(self.mapView.region.span.latitudeDelta > 0.01)
    {
        [self.mapView setRegion:MKCoordinateRegionMake(userLocation.coordinate, MKCoordinateSpanMake(0.002, 0.002)) animated:YES];
    }
}

#pragma mark - Navigation Methods

- (void)navigateFrom:(NSString *)source to:(NSString *)destination {
    NSLog(@"Looking up driving directions from \"%@\" to \"%@\"", source, destination);
    
    MKLocalSearchRequest *request =
    [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = destination;
    request.region = _mapView.region;
    
    MKLocalSearch *search =
    [[MKLocalSearch alloc]initWithRequest:request];
    
    [search startWithCompletionHandler:^(MKLocalSearchResponse
                                         *response, NSError *error) {
        if (response.mapItems.count == 0)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error Message" message:@"Could not find Destination address" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
        else
        {
            MKMapItem *item = [[response mapItems] firstObject];
            
            CLLocationCoordinate2D sourceCoordinate = self.mapView.userLocation.location.coordinate;
            CLLocationCoordinate2D destinationCoordinate = item.placemark.location.coordinate;

            NSLog(@"Began routing from {%f,%f} to {%f,%f}", sourceCoordinate.latitude, sourceCoordinate.longitude, destinationCoordinate.latitude, destinationCoordinate.longitude);

            // stop map view from updating user location
            self.mapView.showsUserLocation = NO;
            
            self.navigationKit = [[NavigationKit alloc] initWithSource:sourceCoordinate destination:destinationCoordinate transportType:MKDirectionsTransportTypeAutomobile directionsService:NavigationKitDirectionsServiceAppleMaps];
            [self.navigationKit setDelegate:self];
            
            [self.navigationKit calculateDirections];
        }
    }];
}

- (IBAction)cancelNavigation:(id)sender {
    NSLog(@"Cancel navigation");
    [self.navigationKit stopNavigation];
}

#pragma mark - Helper Methods

// Round up a distance by multiple
- (CLLocationDistance)roundedDistance:(CLLocationDistance)distance multiple:(int)multiple {
    return (multiple - (int)distance % multiple) + distance;
}

- (NSString *)formatDistance:(CLLocationDistance)distance abbreviated:(BOOL)abbreviated {
    
    CLLocationDistance roundedDistance = [self roundedDistance:distance multiple:100];
    
    if(distance < 100)
        roundedDistance = [self roundedDistance:distance multiple:50];
    
    if(distance < 50)
        roundedDistance = [self roundedDistance:distance multiple:10];
    
    if(roundedDistance < 1000)
        return [NSString stringWithFormat:@"%d%@", (int)roundedDistance, abbreviated ? @"\u7C73" : @"\u7C73"];
    else
        return [NSString stringWithFormat:@"%.01f%@", roundedDistance/1000, abbreviated ? @"\u516C\u91CC" : @"\u516C\u91CC"];
}

- (NSString *)sanitizedHTMLString:(NSString *)string {
    return [[[NSAttributedString alloc] initWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding]} documentAttributes:nil error:nil] string];
}

- (UIImage *)imageForRouteStepManeuver:(NKRouteStepManeuver)maneuver {
    
    // Default to straight
    UIImage *image = [UIImage imageNamed:@"straight"];;
    
    switch (maneuver) {
        case NKRouteStepManeuverTurnSharpLeft:
            image = [UIImage imageNamed:@"turn-sharp-left"];
            break;
        case NKRouteStepManeuverUturnRight:
            image = [UIImage imageNamed:@"uturn-right"];
            break;
        case NKRouteStepManeuverTurnSlightRight:
            image = [UIImage imageNamed:@"turn-slight-right"];
            break;
        case NKRouteStepManeuverMerge:
            image = [UIImage imageNamed:@"merge"];
            break;
        case NKRouteStepManeuverRoundaboutLeft:
            image = [UIImage imageNamed:@"roundabout-left"];
            break;
        case NKRouteStepManeuverRoundaboutRight:
            image = [UIImage imageNamed:@"roundabout-right"];
            break;
        case NKRouteStepManeuverUturnLeft:
            image = [UIImage imageNamed:@"uturn-left"];
            break;
        case NKRouteStepManeuverTurnSlightLeft:
            image = [UIImage imageNamed:@"turn-slight-left"];
            break;
        case NKRouteStepManeuverTurnLeft:
            image = [UIImage imageNamed:@"turn-left"];
            break;
        case NKRouteStepManeuverRampRight:
            image = [UIImage imageNamed:@"ramp-right"];
            break;
        case NKRouteStepManeuverTurnRight:
            image = [UIImage imageNamed:@"turn-right"];
            break;
        case NKRouteStepManeuverForkRight:
            image = [UIImage imageNamed:@"fork-right"];
            break;
        case NKRouteStepManeuverStraight:
            image = [UIImage imageNamed:@"straight"];
            break;
        case NKRouteStepManeuverForkLeft:
            image = [UIImage imageNamed:@"fork-left"];
            break;
        case NKRouteStepManeuverTurnSharpRight:
            image = [UIImage imageNamed:@"turn-sharp-right"];
            break;
        case NKRouteStepManeuverRampLeft:
            image = [UIImage imageNamed:@"ramp-left"];
            break;
        default:
            break;
    }
    
    return image;
}

#pragma mark - NavigationKitDelegate

- (void)navigationKitError:(NSError *)error {
    NSLog(@"NavigationKit Error: %@", [error localizedDescription]);
}

- (void)navigationKitCalculatedRoute:(NKRoute *)route {
    NSLog(@"NavigationKit Calculated Route with %lu steps", (unsigned long)[route steps].count);
    
    // Start location updates
    [self.locationManager startUpdatingLocation];
    
    // Add Path to map
    [self.mapView addOverlay:[route polyline] level:MKOverlayLevelAboveRoads];
    [self.mapView setVisibleMapRect:[[route polyline] boundingMapRect] edgePadding:UIEdgeInsetsMake(110.0, 10.0, 10.0, 10.0) animated:YES];
    
    // Hide address input fields
    [UIView animateWithDuration:0.5 animations:^{
        [self.addressInputView setAlpha:0.0];
    }];
    
    // Start navigation
    [self.navigationKit startNavigation];
}

- (void)navigationKitStartedNavigation {
    NSLog(@"NavigationKit Started Navigation");
}

- (void)navigationKitStoppedNavigation {
    NSLog(@"NavigationKit Stopped Navigation");
    
    // Reset UI state
    [self.mapView removeOverlays:[self.mapView overlays]];
    
    [self.instructionLabel setText:nil];
    [self.distanceLabel setText:nil];
    [self.maneuverImageView setImage:nil];
    
    [UIView animateWithDuration:0.5 animations:^{
        [self.addressInputView setAlpha:1.0];
    }];
}

- (void)navigationKitStartedRecalculation {
    NSLog(@"NavigationKit Started Recalculating Route");
    
    // Remove overlays
    [self.mapView removeOverlays:[self.mapView overlays]];
}

- (void)navigationKitEnteredRouteStep:(NKRouteStep *)step nextStep:(NKRouteStep *)nextStep {
    NSLog(@"NavigationKit Entered New Step");
    [self.instructionLabel setText:[self sanitizedHTMLString:[nextStep instructions]]];
    
    // Set maneuver icon if available
    [self.maneuverImageView setImage:[self imageForRouteStepManeuver:[nextStep maneuver]]];
}

- (void)navigationKitCalculatedDistanceToEndOfPath:(CLLocationDistance)distance {
    NSString *formattedDistance = [self formatDistance:distance abbreviated:YES];
    [self.distanceLabel setText:formattedDistance];
}

- (void)navigationKitCalculatedNotificationForStep:(NKRouteStep *)step inDistance:(CLLocationDistance)distance {
    NSLog(@"NavigationKit Calculated Notification \"%@\" (in %f meters)", [step instructions], distance);
    
    NSString *message = [NSString stringWithFormat:@"%@\u540E，%@", [self formatDistance:distance abbreviated:NO], [self sanitizedHTMLString:[step instructions]]];
    
    // switching to a appropriate audio session for foreground playback
    // ipod music should duck in volume but not be stopped
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:NO error:NULL];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:NULL];
    [session setActive:YES error:NULL];
    
    // play voice directions
    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:message];
    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:[[NSLocale currentLocale] localeIdentifier]];
    [utterance setRate:0.15];
    
    AVSpeechSynthesizer *speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
    [speechSynthesizer speakUtterance:utterance];
    speechSynthesizer.delegate = self;
}

- (void)navigationKitCalculatedCamera:(MKMapCamera *)camera {
    [self.mapView setCamera:camera animated:YES];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *location = [locations firstObject];

    // !!IMPORTANT!!
    //
    // ALL digital maps of regions within the People's Republic of China
    // are encrypted with GCJ02 coordinates instead of WGS84 coordinates.
    //
    // To properly show a location or path on a Chinese map, we must first
    // convert GPS coordinates into GCJ coordinates. This is done by using
    // an open-source library called WGS84TOGCJ02.
    //
    // My version of this library automatically checks whether the coordinates
    // are within China or not. So unless the user is driving across the
    // Chinese border into or out of an adjacent country, our navigation
    // example "should" be fine no matter which country the user is in.
    //
    // Another critial notice is that Apple Maps handles this encryption
    // requirement automatically within Map Kit. So the only part we should
    // take caution of is where we use Core Location instead of Map Kit.
    //
    // Notice that we didn't convert the coordinates when using self.mapView.
    // userLocation or MKLocalSearch.
    
    CLLocationCoordinate2D realCoordinate = [WGS84TOGCJ02 transformFromWGSToGCJ:location.coordinate];
    location = [[CLLocation alloc] initWithLatitude:realCoordinate.latitude longitude:realCoordinate.longitude];
    
    [self.navigationKit calculateActionForLocation:location];

    // our own implementation of showing user location
    //MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    MKUserLocation *annotationForUserLocation = [[MKUserLocation alloc] init];
    annotationForUserLocation.coordinate = realCoordinate;
    annotationForUserLocation.title = @"Your Location";
    [self.mapView addAnnotation:annotationForUserLocation];

    // pretty awkward way to remove the blue dot from its old location
    NSMutableArray *annotationToBeRemoved = [NSMutableArray arrayWithCapacity:1];
    for (id<MKAnnotation> annotation in self.mapView.annotations)
    {
        if ([annotation isKindOfClass:[MKUserLocation class]])
        {
            MKUserLocation *userLocation = (MKUserLocation *)annotation;
            if (userLocation.coordinate.latitude != annotationForUserLocation.coordinate.latitude || userLocation.coordinate.longitude != annotationForUserLocation.coordinate.longitude)
            {
                [annotationToBeRemoved addObject:userLocation];
            }
        }
    }
    if ([annotationToBeRemoved count] > 0)
    {
        [self.mapView removeAnnotations:annotationToBeRemoved];
    }
}

#pragma mark - AVSpeechSynthesizerDelegate

-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
    // after speech ended, switchs back to a normal audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:NO error:NULL];
    [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:NULL];
    [session setActive:YES error:NULL];
}

@end
