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
import QtWebKit 1.0

Page {
    tools: aboutTools

    state: (screen.currentOrientation === Screen.Portrait) ? "portrait" : "landscape"

    states: [
        State {
            name: "landscape"
            PropertyChanges {
                target: logo
                anchors.leftMargin: 50
                anchors.topMargin: 50
            }
            AnchorChanges {
                target: logo
                anchors {
                    horizontalCenter: undefined

                    left: parent.left
                    top: parent.top
                }
            }
            AnchorChanges {
                target: aboutInfoContainer
                anchors {
                    horizontalCenter: undefined

                    left: logo.right
                    top: logo.top
                }
            }
            PropertyChanges {
                target: aboutInfoContainer
                anchors.leftMargin: 50
            }
        },
        State {
            name: "portrait"
            AnchorChanges {
                target: logo
                anchors {
                    left: undefined

                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }
            }
            AnchorChanges {
                target: aboutInfoContainer
                anchors {
                    left: undefined

                    top: logo.bottom
                    horizontalCenter: parent.horizontalCenter
                }
            }
            PropertyChanges {
                target: aboutInfoContainer
                anchors.topMargin: 50
            }
        }
    ]

    transitions: Transition {
        AnchorAnimation { duration: 500 }
    }


    Column {
        id: logo
        anchors {
            top: parent.top
            topMargin:  30
        }

        Image {
            width: 398
            height: 225
            source: "resources/grroklogo.png"
        }
    }

    Column {
        id: aboutInfoContainer


        Label {
            id: aboutInfo
            width: 350
            text:  qsTr("Version")+": 0.1.1<br/>"
                  +qsTr("Copyright")+": Jon Levell 2012<br/>"
                  +qsTr("Additional Material:")+'<ul style="padding-top: 0; margin-top:0">'
                  +'<li><a href="http://openclipart.org/detail/17864/stone-by-angelo_gemmi">Rock Image</a> - Angelo&nbsp;Gemmi</li></ul>'
                  +qsTr("Included example code:")+'<ul style="padding-top: 0; margin-top:0">'
                  +'<li><a href="http://phpjs.org/functions/get_html_translation_table">HTML Entity Parsing</a></li>'
                  +'<li><a href="http://www.developer.nokia.com/Community/Wiki/How-to_create_a_persistent_settings_database_in_Qt_Quick_%28QML%29">Save settings</a></li>'
                  +'<li><a href="http://www.openjs.com/scripts/others/dump_function_php_print_r.php">dump() debugging</a></li></ul>'
        }
    }

    ToolBarLayout {
        id: aboutTools

        ToolIcon { iconId: "toolbar-back"; onClicked: {pageStack.pop(); }  }
    }
}

