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

Page {
    id: itemListPage
    tools: itemListTools
    property string feedId: ""
    property string pageTitle: "Loading..."
    property int numStatusUpdates
    property bool loading: false

    anchors.margins: rootWindow.pageMargin

    ListModel {
        id: itemListModel
    }
    Component {
        id: listHeading

        Rectangle {
            width: parent.width
            height: 60
            radius: 10
            color: "lightgreen"
            clip: true

            Text {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

                text: pageTitle
                font.weight: Font.Bold
                font.pixelSize: 26
                elide: Text.ElideRight
            }
        }
    }


    ListView {
        id: listView
        anchors.fill: parent
        model: itemListModel
        header: listHeading

        delegate:  Item {
            id: listItem
            height: 88
            width: parent.width

            BorderImage {
                id: background
                anchors.fill: parent
                // Fill page borders
                anchors.leftMargin: -itemListPage.anchors.leftMargin
                anchors.rightMargin: -itemListPage.anchors.rightMargin
                visible: mouseArea.pressed
                source: "image://theme/meegotouch-list-background-pressed-center"
            }

            Row {
                anchors.left: parent.left
                anchors.right: drilldownarrow.left
                clip: true

                Column {
                    clip: true

                    Label {
                        id: mainText
                        text: model.title
                        font.weight: Font.Bold
                        font.pixelSize: 26
                        color: (model.unread) ? "#000033" : "#888888"
                        elide: Text.ElideRight
                    }

                    Label {
                        id: subText
                        text: model.subtitle
                        font.weight: Font.Light
                        font.pixelSize: 22
                        color: (model.unread) ? "#cc6633" : "#888888"
                        elide: Text.ElideRight
                        visible: text != ""
                    }
                }
            }

            Image {
                id: drilldownarrow
                source: "image://theme/icon-m-common-drilldown-arrow" + (theme.inverted ? "-inverse" : "")
                anchors.right: parent.right;
                anchors.verticalCenter: parent.verticalCenter
                visible: ((model.id != null)&&(model.id != "__grrok_get_more_items"))
            }


            MouseArea {
                id: mouseArea
                anchors.fill: background
                onClicked: {
                    if(model.id) {
                        if(model.id === "__grrok_get_more_items") {
                            getMoreItems();
                        } else {
                            var component = Qt.createComponent("Item.qml");
                            if (component.status == Component.Ready) {
                                pageStack.push(component, {feedId: feedId, itemId: model.id});
                            } else {
                                console.log("Error loading component:", component.errorString());
                            }
                        }
                    }
                }
            }
        }
    }
    ScrollDecorator {
        flickableItem: listView
    }

    Timer {
            id: delayedClose
            interval: 500; running: false; repeat: false
            onTriggered:  {
                itemListMenu.close(); pageStack.pop();
            }
        }

    function updateItemList(success, data) {
        itemListModel.clear();
        var gr = rootWindow.getGoogleReader();
        //console.log("success: "+gr.dump(success));
        //console.log("data: "+gr.dump(data));

        //stop the loading anim...
        loading = false;

        if(success)  {
            var emptyList = true;
            var showall =  gr.getShowAll();

            pageTitle = gr.html_entity_decode(data.title,'ENT_QUOTES');

            for(var i=0; i < data.items.length; i++) {
                if(showall || data.items[i].unread ) {
                    emptyList = false;

                    itemListModel.append({
                                             title:     gr.html_entity_decode(data.items[i].title,'ENT_QUOTES'),
                                             subtitle:  (data.items[i].updated && (data.items[i].updated > data.items[i].published))?
                                                            "Updated at: " +  gr.timestamp2date(data.items[i].updated)
                                                          : "Published at: " + gr.timestamp2date(data.items[i].published),
                                             id: data.items[i].id,
                                             unread: data.items[i].unread,
                                         });
                }
            }

            if(emptyList) {
                //Have we been told to close if we're empty?
                if(gr.getCloseIfEmpty()) {
                    //QML seems to get upset if we try and close here (page animation not yet completed?)
                    //So we'll close in a bit...
                    delayedClose.running = true;
                }

                if(showall ||(data.items.length == 0) ) {
                    itemListModel.append({
                                             title: "No items in feed",
                                             subtitle: "",
                                             id: null,
                                             unread: false,
                                         });
                } else {
                    itemListModel.append({
                                             title: "No unread items in feed",
                                             subtitle: "",
                                             id: null,
                                             unread: false,
                                         });
                }
            } else {
                //All necessary "closeIfEmpty" closes have occurred
                gr.setCloseIfEmpty(false);

                var unreadcount = gr.getFeedUnreadCount(feedId);

                if(showall || (unreadcount > data.items.length)) {
                    itemListModel.append({
                                             title: "Get More items...",
                                             subtitle: "",
                                             id:"__grrok_get_more_items",
                                             unread: (unreadcount > data.items.length),
                                         });
                }
            }
        }
    }

    function retrieveItemListData() {
        loading = true;
        var gr = rootWindow.getGoogleReader();
        gr.getFeedItems(feedId, false, updateItemList);
    }

    function getMoreItems() {
        loading = true;
        var gr = rootWindow.getGoogleReader();
        gr.getFeedItems(feedId, true, updateItemList);
    }

    onFeedIdChanged: {
        retrieveItemListData();
    }

    Component.onCompleted: {
        var gr = rootWindow.getGoogleReader();
        //gr.addStatusListener(itemListStatusListener);
        numStatusUpdates = gr.getNumStatusUpdates();
    }

    function markFeedReadCompleted(retcode, text) {
        if(retcode === 0) {
            retrieveItemListData();
        }
    }

    onStatusChanged: {
        var gr;

        if(status === PageStatus.Deactivating) {
            gr = rootWindow.getGoogleReader();
            numStatusUpdates = gr.getNumStatusUpdates();
        } else if (status === PageStatus.Activating) {
            gr = rootWindow.getGoogleReader();
            if(gr.getNumStatusUpdates() > numStatusUpdates) {
                numStatusUpdates = gr.getNumStatusUpdates();
                retrieveItemListData();
            }
        }
    }
    function startJumpToEntry() {
        var gr = rootWindow.getGoogleReader();

        //start the loading anim...
        loading=true;

        var lookingForItem = gr.pickEntry(null, feedId, null, true, true, completeJumpToEntry);

        if(!lookingForItem) {
            loading=false;
            itemListMenu.close(); pageStack.pop();
        }
    }

    function completeJumpToEntry(success, feedId, entryId) {
        //stop the loading anim...
        loading=false;

        if(success) {
            var component = Qt.createComponent("Item.qml");
            if (component.status === Component.Ready) {
                pageStack.push(component,  {categoryId: categoryId, feedId: feedId, itemId: entryId});
            } else {
                console.log("Error loading component:", component.errorString());
            }
        }
    }


    ToolBarLayout {
        id: itemListTools

        ToolIcon { iconId: "toolbar-back"; onClicked: { itemListMenu.close(); pageStack.pop();} }
        BusyIndicator {
            visible: loading
            running: loading
            platformStyle: BusyIndicatorStyle { size: 'medium' }
        }
        ToolIcon { iconId: "toolbar-down"; visible: !loading; onClicked: { startJumpToEntry(); } }
        ToolIcon { iconId: "toolbar-view-menu" ; onClicked: (itemListMenu.status == DialogStatus.Closed) ? itemListMenu.open() : itemListMenu.close() }
    }

    Menu {
        id: itemListMenu
        visualParent: pageStack

        MenuLayout {
            MenuItem {
                id: toggleUnread
                text: "Toggle Unread Only"
                onClicked: {
                    var gr = rootWindow.getGoogleReader();
                    var oldval = gr.getShowAll();
                    var newval = !oldval;
                    gr.setShowAll(newval);

                    //console.log("Updating categories with showAll: "+newval+"\n");
                    retrieveItemListData();
                }
            }

            MenuItem {
                id: markAllRead
                text: "Mark All Read"
                enabled: (feedId != "")
                onClicked: {
                    var gr = rootWindow.getGoogleReader();
                    gr.markFeedRead(feedId, markFeedReadCompleted);
                }
            }
        }
    }
}
