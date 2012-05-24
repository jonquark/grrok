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
    function openFile(file) {
        var component = Qt.createComponent(file)
        if (component.status === Component.Ready)
            pageStack.push(component);
        else
            console.log("Error loading component:", component.errorString());
    }

    property bool loading: false

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
                target: loginBox
                anchors {
                    horizontalCenter: undefined

                    left: logo.right
                    top: logo.top
                }
            }
            PropertyChanges {
                target: loginBox
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
                target: loginBox
                anchors {
                    left: undefined

                    top: logo.bottom
                    horizontalCenter: parent.horizontalCenter
                }
            }
            PropertyChanges {
                target: loginBox
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
        id: loginBox

        Label {
            id: usernameLabel
            text: qsTr("Username:")
        }
        TextField {
            id: username
            text: ""
        }
        Label {
            id: passwordLabel
            text: qsTr("Password:")
        }
        TextField {
            id: password
            echoMode: TextInput.PasswordEchoOnEdit
        }
    }
    Button{
        id: loginButton
        anchors {
            top: loginBox.bottom
            topMargin: 20
            horizontalCenter: loginBox.horizontalCenter
        }
        text: qsTr("Login")
        onClicked: {
            //Disable all the login box..
            var settings = rootWindow.settingsObject();

            settings.set("username", username.text);
            settings.set("password", password.text);

            startLogin();
        }
        enabled: true
    }

    BusyIndicator {
        visible: loading
        running: loading
        anchors {
            top: loginButton.bottom
            topMargin: 20
            horizontalCenter: loginButton.horizontalCenter
        }
        platformStyle: BusyIndicatorStyle { size: 'large' }
    }

    function feedTreeCreated(retcode, text) {
        var settings = rootWindow.settingsObject();

        //stop the loading anim
        loading = false;

        //re-enable all the login box items showing keyboard, if login failed
        enableLoginBox((retcode !== 0));

        if(retcode) {
            console.log("Feedtree creation failed:"+retcode+", :"+text);

            //login failed....don't autlogin
            settings.set("dologin", "false");

            //Let the user know
            loginErrorDialogText.text = text;
            loginErrorDialog.open();
        } else {
            //Login succeeded, auto login next Time
            settings.set("dologin", "true");

            //Now show the categories View
            openFile('Categories.qml');
        }
    }

    function disableLoginBox() {
        username.enabled = false;
        password.enabled = false;
        loginButton.enabled = false;
        loginButton.text = qsTr("Login in progress");
    }

    function enableLoginBox(focus) {
        username.enabled = true;
        password.enabled = true;
        loginButton.enabled = true;
        loginButton.text = qsTr("Login");
        if(focus) {
            password.forceActiveFocus();
        }
    }

    function startLogin() {
        //Disable all the login box items
        disableLoginBox();

        //Start the loading anim
        loading = true;

        var gr = rootWindow.getGoogleReader();
        gr.clearState();
        gr.setLoginDetails(username.text, password.text);
        gr.makeFeedTree(feedTreeCreated);
    }

    //Dialog for login errors
     Dialog {
       id: loginErrorDialog
       title: Rectangle {
         id: titleField
         height: 2
         width: parent.width
         color: "red"
       }

       content:Item {
         id: loginErrorDialogContents
         height: 50
         width: parent.width
         Text {
           id: loginErrorDialogText
           font.pixelSize: 22
           anchors.centerIn: parent
           color: "white"
           text: "Hello Dialog"
         }
       }

       buttons: ButtonRow {
         style: ButtonStyle { }
           anchors.horizontalCenter: parent.horizontalCenter
           Button {text: "OK"; onClicked: loginErrorDialog.accept()}
         }
       }

    Component.onCompleted: {
        var settings = rootWindow.settingsObject();
        settings.initialize();
        username.text = settings.get("username", "");
        password.text = settings.get("password", "");
        var dologin = settings.get("dologin", "false");

        if(dologin === "true") {
            startLogin();
        }
    }
}
