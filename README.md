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
1. Switched to MKLocalSearch for better POI search results.
2. UI Improvements.
3. Supports encrypted GCJ02 coordinates within China.
4. Utilizes proper background modes and audio sessions to allow playing voice directions while the app is running in the background or when the user is listening to music.

License
-------
NavigationKit is available under the GPL license. See the LICENSE file for more info.
