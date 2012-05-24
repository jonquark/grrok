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
    id: categoriesPage
    tools: categoriesTools
    anchors.margins: rootWindow.pageMargin

    property int numStatusUpdates
    property bool loading: false

    ListModel {
        id: categoriesModel
    }

    ListView {
        id: listView
        anchors.fill: parent

        model: categoriesModel

        delegate:  Item {
            id: listItem
            height: 88
            width: parent.width

            BorderImage {
                id: background
                anchors.fill: parent
                // Fill page borders
                anchors.leftMargin: -categoriesPage.anchors.leftMargin
                anchors.rightMargin: -categoriesPage.anchors.rightMargin
                visible: mouseArea.pressed
                source: "image://theme/meegotouch-list-background-pressed-center"
            }

            Row {
                anchors.fill: parent

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        id: mainText
                        text: model.title
                        font.weight: Font.Bold
                        font.pixelSize: 26
                        color: (model.unreadcount > 0) ? "#000033" : "#888888";

                    }

                    Label {
                        id: subText
                        text: model.subtitle
                        font.weight: Font.Light
                        font.pixelSize: 22
                        color: (model.unreadcount > 0) ? "#cc6633" : "#888888"

                        visible: text != ""
                    }
                }
            }

            Image {
                source: "image://theme/icon-m-common-drilldown-arrow" + (theme.inverted ? "-inverse" : "")
                anchors.right: parent.right;
                anchors.verticalCenter: parent.verticalCenter
                visible: ((model.categoryId != null)? true: false)
            }

            MouseArea {
                id: mouseArea
                anchors.fill: background
                onClicked: {
                    showCategory(model.categoryId);
                }
            }
        }
    }
    ScrollDecorator {
        flickableItem: listView
    }

    function updateCategories() {
        var gr = rootWindow.getGoogleReader();
        var categories = gr.getCategories();
        var showAll = gr.getShowAll();
        categoriesModel.clear();

        if(categories) {
            var someCategories = false;
            var totalUnreadCount = 0;

            //first add all the categories with unread itens
            for(var category in categories) {
                someCategories = true;

                if(categories[category].unreadcount > 0) {
                    totalUnreadCount += categories[category].unreadcount;

                    categoriesModel.append({
                                               title:        gr.html_entity_decode(categories[category].label,'ENT_QUOTES'),
                                               subtitle:    "Unread: " + categories[category].unreadcount,
                                               unreadcount:  categories[category].unreadcount,
                                               categoryId:   category
                                           });
                }
            }

            //then if we are showing all categories, add the ones with no unread items
            if(showAll) {
                for(var cat in categories) {
                    if(categories[cat].unreadcount === 0) {
                        categoriesModel.append({
                                                   title:       gr.html_entity_decode(categories[cat].label,'ENT_QUOTES'),
                                                   subtitle:    "Unread: 0",
                                                   unreadcount:  0,
                                                   categoryId:   cat
                                               });
                    }
                }
            }

            if(   (totalUnreadCount > 0)
               || ((showAll) && someCategories)) {
                //Add the "All category"
                categoriesModel.insert(0, {
                                           title: qsTr("All Categories"),
                                           subtitle: "Unread: " + totalUnreadCount,
                                           categoryId: gr.constants['ALL_CATEGORIES'],
                                           unreadcount: totalUnreadCount,
                                       });
            } else if (someCategories) {
                //There are categories they just don't have unread items
                categoriesModel.append({
                                           title: qsTr("No categories have unread items"),
                                           subtitle: "",
                                           categoryId: null,
                                           unreadcount: 0,
                                       });
            } else {
                //There are no categories
                categoriesModel.append({
                                           title: qsTr("No categories to display"),
                                           subtitle: "",
                                           categoryId: null,
                                           unreadcount: 0,
                                       });
            }
        }
    }

    Component.onCompleted: {
        var gr = rootWindow.getGoogleReader();
        //gr.addStatusListener(categoriesStatusListener);
        numStatusUpdates = gr.getNumStatusUpdates();
        updateCategories();
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
                updateCategories();
            }
        }
    }

    function showCategory(categoryId) {
        if(categoryId != null) {
            console.log("Loading feeds for "+categoryId+"\n");
            var component = Qt.createComponent("Feeds.qml");
            if (component.status == Component.Ready) {
                pageStack.push(component, {categoryId: categoryId});
            } else {
                console.log("Error loading component:", component.errorString());
            }
        }
    }

    function jumpToChosenCategory() {
        var gr = rootWindow.getGoogleReader();
        showCategory(gr.pickCategory());
    }

    ToolBarLayout {
        id: categoriesTools

        ToolIcon { iconId: "toolbar-back"; onClicked: {categoriesMenu.close(); pageStack.pop(); } }
        BusyIndicator {
            visible: loading
            running: loading
            platformStyle: BusyIndicatorStyle { size: 'medium' }
        }
        ToolIcon { iconId: "toolbar-down"; visible: !loading; onClicked: { jumpToChosenCategory(); } }
        ToolIcon { iconId: "toolbar-view-menu" ; onClicked: (categoriesMenu.status === DialogStatus.Closed) ? categoriesMenu.open() : categoriesMenu.close() }
    }

    Menu {
        id: categoriesMenu
        visualParent: pageStack

        MenuLayout {
            MenuItem {
                id: toggleUnread
                text: qsTr("Toggle Unread Only")
                onClicked: {
                    var gr = rootWindow.getGoogleReader();
                    var oldval = gr.getShowAll();
                    var newval = !oldval;
                    gr.setShowAll(newval);

                    //console.log("Updating categories with showAll: "+newval+"\n");
                    updateCategories();
                }
            }
        }
        MenuLayout {
            MenuItem {
                id: about
                text: qsTr("About Grrok")
                onClicked: {
                    var component = Qt.createComponent("About.qml");
                    if (component.status == Component.Ready) {
                        pageStack.push(component);
                    } else {
                        console.log("Error loading component:", component.errorString());
                    }
                }
            }
        }
    }
}
