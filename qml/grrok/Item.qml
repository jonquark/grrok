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
    id: itemPage
    tools: itemTools
    property string categoryId: ""
    property string feedId:     ""
    property string itemId:     ""
    property string url:        ""
    property bool   unread: true
    property bool   loading: false
    property bool   nextStaysInFeed: true
    property bool   nextStaysInCategory: true

    anchors.margins: 0

    Flickable {
        id: flick
        width: parent.width;
        height: parent.height
        contentWidth: itemView.width
        contentHeight: itemView.height
        interactive: true
        clip: true

        signal newWindowRequested(string url)

        WebView {
            id: itemView
            transformOrigin: Item.TopLeft
            settings.standardFontFamily: "Arial"
            settings.defaultFontSize: 22
            preferredWidth: flick.width
            preferredHeight: flick.height

/*            onUrlChanged: {
                console.log("In onURLChanged: "+url);
                if (String(url).substr(0, 6) !== "file:/") {
                    Qt.openUrlExternally(url);
                    console.log("About to trigger back");
                    //itemView.back.setEnabled(true);
                    itemView.back.trigger();
                }
            }*/

            // I think we want onNavigationRequested ?
            // https://bugs.webkit.org/show_bug.cgi?id=72976
            // Most of the oddness inside the flickable is an attempt to hack around it following the example of:
            // http://osdir.com/ml/kde-commits/2011-12/msg03459.html
            // https://projects.kde.org/projects/extragear/base/plasma-mobile/repository/revisions/8ea2f26344f7968d90678035bf800ec9deb02c7f/entry/applications/about/package/contents/ui/FlickableWebView.qml
 /*           newWindowComponent: Component {
                Item {
                    id: newPageComponent

                    WebView {
                        id: newWindow

                        onUrlChanged: {

                            if (url != "") {
                                flick.newWindowRequested(url)

                                var newObject = Qt.createQmlObject('import QtQuick 1.0; Item {}', itemView);
                                newPageComponent.parent = newObject
                                newObject.destroy();
                            }
                        }
                    }
                }
            }
            newWindowParent: itemView */
        }
    }

    ScrollDecorator {
        flickableItem: flick
    }

    function updateItem(success, data) {
        //Stop the loading anim
        loading = false;

        var gr = rootWindow.getGoogleReader();
//        console.log("success: "+gr.dump(success));
//        console.log("data: "+gr.dump(data));

        if(success)  {
            var entryHTML = "";
            for(var i=0; i < data.items.length; i++) {
                if(data.items[i].id == itemId) {
                    if(data.items[i].content && data.items[i].content.content) {
                        entryHTML = data.items[i].content.content;
                    } else if(data.items[i].summary && data.items[i].summary.content) {
                        entryHTML = data.items[i].summary.content;
                    } else {
                        console.log("Failed to parse item: "+gr.dump(data.items[i]));
                        entryHTML = "<p>Failed to parse item</p>";
                    }

                    unread = data.items[i].unread;

                    if(   data.items[i].alternate
                       && data.items[i].alternate[0]
                       && data.items[i].alternate[0].href) {
                        url = data.items[i].alternate[0].href;
                    }

                    break;
                }
            }
            var headerHTML  = '<div style="background-color: #66CCFF; padding: 0.8em; border-radius: 10px; margin-bottom: 0.5em">';
            headerHTML +=  "<strong>Feed Title:</strong>"+data.title+"<br/>";
            headerHTML +=  "<strong>Entry Title:</strong>"+data.items[i].title+"</div>";
            itemView.html = headerHTML+entryHTML;
        }
    }

    function retrieveItemData() {
        //start the loading anim
        loading = true;

        var gr = rootWindow.getGoogleReader();
        gr.getFeedItems(feedId, false, updateItem);
    }

    onItemIdChanged: {
        retrieveItemData();
    }

    function startJumpToEntry() {
        var gr = rootWindow.getGoogleReader();

        var lookingForItem = gr.pickEntry(categoryId, feedId, itemId, nextStaysInFeed, nextStaysInCategory, completeJumpToEntry);

        if(!lookingForItem) {
            loading=false;
            //No more items... close the item page..and parents should close too if empty
            gr.setCloseIfEmpty(true);
            itemMenu.close();            
            pageStack.pop();
        }
    }

    function completeJumpToEntry(success, feedid, entryid) {
         if(success) {
            feedId = feedid;
            itemId = entryid;
        }
    }

    ToolBarLayout {
        id: itemTools

        ToolIcon { iconId: "toolbar-back"; onClicked: { itemMenu.close(); pageStack.pop(); }  }

        BusyIndicator {
            visible: loading
            running: loading
            platformStyle: BusyIndicatorStyle { size: 'medium' }
        }
        ToolIcon { iconId: "toolbar-down"; visible: !loading;
            onClicked: {
                if(unread) {
                    var gr = rootWindow.getGoogleReader();
                    gr.markEntryRead(feedId, itemId, true);
                    unread = false;
                }
                startJumpToEntry();
            } }
        ToolIcon { iconId: "toolbar-view-menu" ; onClicked: (itemMenu.status === DialogStatus.Closed) ? itemMenu.open() : itemMenu.close() }
    }

    Menu {
        id: itemMenu
        visualParent: pageStack

        MenuLayout {
            MenuItem {
                id: toggleUnread
                text: ((unread)? qsTr("Mark item read") : qsTr("Mark item unread"))
                onClicked: {
                    var gr = rootWindow.getGoogleReader();
                    gr.markEntryRead(feedId, itemId, unread, null);

                    unread = !unread;
                }
            }

            MenuItem {
                id: openInBrowser
                text: qsTr("Open in Web Browser")
                enabled: (url && (url != "")) ? true: false
                onClicked: {
                    Qt.openUrlExternally(url);
                }
            }

            MenuItem {
                id: nextMode
                visible: false
                enabled: false
                text: ((nextStaysInFeed)? qsTr("Next Button: Stay in Feed"):
                                          ((nextStaysInCategory) ? qsTr("Next Button: Stay in Category") :
                                                                   qsTr("Next Button: Any Category")))
                onClicked: {
                    if(nextStaysInFeed) {
                        //Change to category
                        nextStaysInCategory = true;
                        nextStaysInFeed = false;
                    } else if(nextStaysInCategory) {
                        //Change to no restriction
                        nextStaysInCategory = false;
                        nextStaysInFeed = false;
                    } else {
                        //Change to stay in feed
                        nextStaysInCategory = true;
                        nextStaysInFeed = true;
                    }
                }
            }
        }
    }
}
