//Copyright Jon Levell, 2012
//
//This file is part of Grrok.
//
//Grrok is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
//Free Software Foundation, either version 2 of the License, or (at your option) any later version.
//Grrok is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//You should have received a copy of the GNU General Public License along with Grrok (on a Maemo/Meego system there is a copy
//in /usr/share/common-licenses. If not, see http://www.gnu.org/licenses/.

import QtQuick 1.1
import com.nokia.meego 1.0
import "googlereader.js" as GoogleReader
import "settings.js" as Settings

PageStackWindow {
    id: rootWindow
    property int feedStatusUpdates: 0

    function getGoogleReader() {
        return GoogleReader;
    }
    function settingsObject() {
        return Settings;
    }

    function feedStateUpdated() {
        feedStatusUpdates++;
    }
    property int pageMargin: 16

    initialPage: mainPage

    MainPage {
        id: mainPage
    }
}
