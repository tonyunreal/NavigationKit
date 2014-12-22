NavigationKit
=============

![Project Icon](http://i900.photobucket.com/albums/ac203/tonyunreal/car.png)

A Turn-by-Turn driving directions library created with Apple Maps API.

Forked and improved by Tony Borner (tonyunreal) .

Summary
-------
This is a fork of Axel Moller's NavigationKit project. You can find the original [here](https://github.com/sendus/NavigationKit).

Improvements over Original (Library)
------------------------------------
1. Removed dependancy on Google Maps (unavailable in China, and that the original implementation isn't perfectly based on GMS anyway).
2. The library now takes current car heading direction into account when recalculating new routes. (Experimental)

Improvements over Original (Example Project)
--------------------------------------------
1. Removed dependancy on CocoaPods.
2. Switched to MKLocalSearch for better POI search results.
3. UI Improvements.
4. Supports encrypted GCJ02 coordinates within China.
5. Changed directions narrator to Chinese language while keeping every piece of the code moonspeak free. ;)
6. Utilizes proper background modes and audio sessions to allow playing voice directions while the app is running in the background or when the user is listening to music.

Todos
-----
1. Improves current heading calculation by either checking coordinates history in the past few seconds, or somehow retrieve this information from Apple's Core Location framework.
2. More testing on the GCJ02 convertion algorithm, plus the country boundary check is against a simple rectangular region, could result in some serious problems within India or the Korean peninsula.
3. The library should expose more information from Apple's routing service, such as predicted travel time, road conditions and current road names.
4. The library should expose all routes to the UI instead of offering only one route.
5. Separates routing calculation routine from navigation routine. Because the UI could show multiple routes to the user, and only enters navigation mode (with narrative directions) after user explicitly allowing so. The camera should be dramatically different between routing/navigation modes too.

License
-------
NavigationKit is available under the GPL license. See the LICENSE file for more info.
