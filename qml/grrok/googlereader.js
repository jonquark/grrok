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

if(Qt) {
    Qt.include("dump.js")
    Qt.include("htmlentities.js");
}

var state={
    'username':         null,
    'password':         null,
    'authtoken':        null,
    'token':            null,     //extra token required for making changes e.g. marking items read
    'categoryunread':   null,     //category unread counts (created by updateUnread() )
    'feedtree':         null,     //feeds arranged by category including unread count (created by makeFeedTree() )
    'feedlist':         null,     //feeds arranged in an associative array (key = id)
    'numStatusUpdates': 0,        //each time the state updates such that the app might want to redisplay we update this (get via getNumStatusUpdates)
    'showall':          false,    //boolean should all items be shown (or only those with unread stuff?)
    'feedcache':        {},        //as feed items are retrieved they are stored here for re-use
    'tracelevel':       2,         //1 = errors, 2 = key info, 3 = network traffic, 4 info, 5 high detail
    'closeIfEmpty':      false,     //Should pages close if they have no content to display
};

var requestsPending={
    'getToken'    :  false,
    'updateSubs'  :  false,
    'updateUnread':  false,
    'makeFeedTree':  false,
};

var responsesPending={
    'auth':          false,
    'getToken':      false,
    'updateSubs':    false,
    'updateUnread':  false,
};


var urls={
    "login":         "https://www.google.com/accounts/ClientLogin",
    "token":         "http://www.google.com/reader/api/0/token",
    "subscriptions": "http://www.google.com/reader/api/0/subscription/list?output=json",
    "unread":        "http://www.google.com/reader/api/0/unread-count?output=json",
    "edittag":       "http://www.google.com/reader/api/0/edit-tag?client=-",
    "markallread":   "http://www.google.com/reader/api/0/mark-all-as-read?client=-",
    "getfeed":       "http://www.google.com/reader/api/0/stream/contents/",
};

var constants={
    "ALL_CATEGORIES": "__grrok_allcategories",
}

//Clone the initial state so we can clear the state by recloning...
var initial_state            = JSON.parse(JSON.stringify(state));
var initial_requestsPending  = JSON.parse(JSON.stringify(requestsPending));
var initial_responsesPending = JSON.parse(JSON.stringify(responsesPending));


function trace(level, text) {
    if(level <= state['tracelevel']) {
        console.log(text+'\n');
    }
}


function clearState() {
    state            = JSON.parse(JSON.stringify(initial_state));
    requestsPending  = JSON.parse(JSON.stringify(initial_requestsPending));
    responsesPending = JSON.parse(JSON.stringify(initial_responsesPending));

    trace(2, "State Cleared");
}

function setLoginDetails(username, password) {
    state['username'] = username;
    state['password'] = password;
}

function login(callback) {
    if(responsesPending['auth']) {
        return;
    }
    responsesPending['auth'] = true;
    state['authtoken'] = null;

    var url = urls["login"];

    var params  = "Email="+encodeURIComponent(state['username']);
        params += "&Passwd="+encodeURIComponent(state['password']);
        params += "&service=reader&source=grrok-0.01";
        params += "&accountType=GOOGLE";


    trace(3, "url: "+url);
    trace(3, "params: "+params);

    var http = new XMLHttpRequest();
    http.open("POST", url, true);

    http.setRequestHeader("Content-type", "application/x-www-form-urlencoded");

    http.onreadystatechange = function() {//Call a function when the state changes.
                if (http.readyState == XMLHttpRequest.HEADERS_RECEIVED) {
                    trace(3, "Response Headers -->");
                    trace(3, http.getAllResponseHeaders());
                } else if (http.readyState == XMLHttpRequest.DONE) {
                    process_login(callback, http);
                }
    }
    http.send(params);
}

function process_login(callback, http) {
    trace(3, "readystate: "+http.readyState+" status: "+http.status);
    trace(3, "response: "+http.responseText);

    var errorText;

    if( http.status === 200 )  {
        var authPos = http.responseText.indexOf('Auth=');
        if(authPos !== -1 ) {
            var authSubString = http.responseText.substring(authPos+5); //+5 to account for Auth=

            //Cut off any data after the auth string...
            authSubString = authSubString.substring(0, authSubString.indexOf("\n"));

            state['authtoken'] = "GoogleLogin auth="+authSubString;
            //showRequestInfo('authtoken: '+state['authtoken']);
        } else {
            trace(1, "Login: Unable to parse login response to obtain authtoken: "+http.responseText+" http status: "+http.status);

            if(http.responseText) {
                errorText = "Login Error: "+http.responseText+" (received http code: "+http.status+")";
            } else {
                errorText = "Login failed (received http code: "+http.status+")";
            }
            callback(10, errorText);
        }
    } else {
        trace(1, "Login Error: received http code: "+http.status+" full text: "+http.responseText);

        if(http.responseText) {
            errorText = "Login Error: "+http.responseText+" (received http code: "+http.status+")";
        } else {
            errorText = "Login failed (received http code: "+http.status+")";
        }
        callback(10, errorText);
    }

    responsesPending['auth'] = false;
    if (state['authtoken']) {
        if(!processPendingRequests(callback)) {
            //No other things to do, this action is done, fire callback saying ok
            callback(0);
        }
    }
}

function getToken(callback) {
    if(responsesPending['getToken']) {
        return;
    }
    if(!state['authtoken']) {
        requestsPending['getToken'] = true;
        processPendingRequests(callback);
        return;
    }

    responsesPending['getToken'] = true;

    var url = urls["token"];

    trace(2, "url: "+url);

    var http = new XMLHttpRequest();

    http.open("GET", url, true);
    http.setRequestHeader("Authorization", state['authtoken']);
    http.onreadystatechange = function() {
            if (http.readyState == XMLHttpRequest.HEADERS_RECEIVED) {
                trace(3,"Headers -->");
                trace(3,http.getAllResponseHeaders ());
            } else if (http.readyState == XMLHttpRequest.DONE) {
                process_getToken(callback, http);
            }
    }
    http.send();
}

function process_getToken(callback, httpreq) {
//    showRequestInfo("readystate: "+httpreq.readyState+" status: "+httpreq.status);
//    showRequestInfo("response: "+httpreq.responseText);

    if( httpreq.status === 200 )  {
        state['token'] = httpreq.responseText;
        trace(2, "Successfully retrieved edit token: "+state['token']);
    } else {
        trace(1, "Error during getToken: received http code: "+httpreq.status+" full text: "+httpreq.responseText);
        if(callback) {
            callback(20, "Error during getToken: received http code: "+httpreq.status+" full text: "+httpreq.responseText);
        }
    }

    responsesPending['getToken'] = false;

    if(state['token']) {
        if(!processPendingRequests(callback)) {
            //No other things to do, this action is done, fire callback saying ok
            if(callback) {
                callback(0);
            }
        }
    }
}

function processPendingRequests(callback) {
    trace(4, 'In pPR');
    var foundWork = false;

    if(!state['authtoken']) {
        foundWork = true;

        if(responsesPending['auth']) {
            return foundWork;
        }

        //Start the login process
        login(callback);
    } else if(requestsPending['getToken']) {
        foundWork = true;

        if(responsesPending['getToken']) {
            return foundWork;
        }
        getToken(callback);
    } else if(requestsPending['updateSubs']) {
        foundWork = true;

        if(responsesPending['updateSubs']) {
            return foundWork;
        }
        if(!state['token']) {
            //Get the editing token
            getToken(callback);
        } else {
            updateSubs(callback);
        }
    } else if(requestsPending['updateUnread']) {
        foundWork = true;

        if(responsesPending['updateUnread']) {
            return foundWork;
        }
        if(!state['token']) {
            //Get the editing token
            getToken(callback);
        } else if(!state['feedlist']) {
            //Need to update the subs first
            updateSubs(callback);
        } else {
            updateUnread(callback);
        }
    } else if(requestsPending['makeFeedTree']) {
        foundWork = true;

        if(!state['token']) {
            //Get the editing token
            getToken(callback);
        } else if(!state['feedlist']) {
            //Need to update the subs first
            updateSubs(callback);
        } else if(!state['categoryunread']) {
            //Need to get unread counts first
            updateUnread(callback);
        } else {
            makeFeedTree(callback);
        }
    }

    return foundWork;
}

function updateSubs(callback) {
    if(responsesPending['updateSubs']) {
        return;
    }
    if(!state['authtoken']) {
        requestsPending['updateSubs'] = true;
        processPendingRequests(callback);
        return;
    }

    responsesPending['updateSubs'] = true;

    var url = urls["subscriptions"];

    trace(2, "url: "+url);

    var http = new XMLHttpRequest();

    http.open("GET", url, true);
    http.setRequestHeader("Authorization", state['authtoken']);
    http.onreadystatechange = function() {
            if (http.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                trace(3, "Headers -->");
                trace(3, http.getAllResponseHeaders ());
            } else if (http.readyState === XMLHttpRequest.DONE) {
                process_updateSubs(callback, http);
            }
    }
    http.send();
}

function process_updateSubs(callback, httpreq) {
    trace(3, "readystate: "+httpreq.readyState+" status: "+httpreq.status);
    trace(3, "response: "+httpreq.responseText);

    if( httpreq.status == 200 )  {
        var rawsubs=JSON.parse(httpreq.responseText);

        state['feedlist'] = {};

        for(var i = 0; i < rawsubs.subscriptions.length; i++) {
            var feedid = rawsubs.subscriptions[i].id;
            trace(4, "Setting feedlist key:"+feedid);
            state['feedlist'][feedid] = rawsubs.subscriptions[i];
        }
    } else {
        trace(1, "Update Subs Error: received http code: "+httpreq.status+" full text: "+httpreq.responseText);
        if(callback) {
            callback(30, "Update Subs Error: received http code: "+httpreq.status+" full text: "+httpreq.responseText);
        }
    }

    responsesPending['updateSubs'] = false;

    if(state['feedlist']) {
        if(!processPendingRequests(callback)) {
            //This action is complete (as there's no other requests to do, fire callback saying all ok
            if(callback) {
                callback(0);
            }
        }
    }
}


function updateUnread(callback) {
    if(responsesPending['updateUnread']) {
        return;
    }
    if(  (!state['authtoken'])
       ||(!state['feedlist'])) {
        requestsPending['updateUnread'] = true;
        processPendingRequests(callback);
        return;
    }

    responsesPending['updateUnread'] = true;

    var url = urls["unread"];

    trace(2, "url: "+url);

    var http = new XMLHttpRequest();

    http.open("GET", url, true);
    http.setRequestHeader("Authorization", state['authtoken']);
    http.onreadystatechange = function() {
            if (http.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                trace(3, "Headers -->");
                trace(3, http.getAllResponseHeaders ());
            } else if (http.readyState === XMLHttpRequest.DONE) {
                process_updateUnread(callback, http);
            }
    }
    http.send();
}

function process_updateUnread(callback, httpreq) {
    trace(3, "readystate: "+httpreq.readyState+" status: "+httpreq.status);
    trace(3, "response: "+httpreq.responseText);

    if( httpreq.status == 200 )  {
        var unreadresponse =JSON.parse(httpreq.responseText);
        state['categoryunread'] = {};

        for(var i = 0; i < unreadresponse.unreadcounts.length; i++) {
            //find the corresponding item in feedlist and add the unreadcount to it
            var founditem = false;
            var feedid = unreadresponse.unreadcounts[i].id;

            if(state['feedlist'][feedid]) {
                state['feedlist'][feedid].unreadcount = unreadresponse.unreadcounts[i].count;
                founditem = true;
            }

            if(!founditem) {
                state['categoryunread'][unreadresponse.unreadcounts[i].id] = unreadresponse.unreadcounts[i].count;
                trace(4, "Adding unread counts, failed to find: "+unreadresponse.unreadcounts[i].id);
            } else {
                trace(5, "Adding unread counts, found: "+unreadresponse.unreadcounts[i].id);
            }
        }
    } else {
        trace(1, "Updated Unread Error: received http code: "+httpreq.status+" full text: "+httpreq.responseText);
        if(callback) {
            callback(40, "Updated Unread Error: received http code: "+httpreq.status+" full text: "+httpreq.responseText);
        }
    }

    responsesPending['updateUnread'] = false;

    if(state['categoryunread']) {
        if(!processPendingRequests(callback)) {
            if(callback) {
                callback(0);
            }
        }
    }
}


function makeFeedTree(callback) {
    if(  (!state['authtoken'])
       ||(!state['feedlist'])
       ||(!state['categoryunread'])) {
        requestsPending['makeFeedTree'] = true;
        processPendingRequests(callback);
        return;
    }
    state['feedtree'] = {};
    requestsPending['makeFeedTree'] = false;

    for(var feedid in state['feedlist']) {
        if(state['feedlist'][feedid].categories && state['feedlist'][feedid].categories.length > 0) {
            for(var j = 0; j < state['feedlist'][feedid].categories.length; j++) {
                var category = state['feedlist'][feedid].categories[j];

                if(!state['feedtree'][category.id]) {
                    state['feedtree'][category.id]       = {};
                    state['feedtree'][category.id].label = category.label;
                    state['feedtree'][category.id].subscriptions = [];

                    if(state['categoryunread'][category.id]) {
                        state['feedtree'][category.id].unreadcount = parseInt(state['categoryunread'][category.id]);
                    } else {
                        state['feedtree'][category.id].unreadcount = 0;
                    }
                }
                state['feedtree'][category.id].subscriptions.push(state['feedlist'][feedid]);
            }
        } else {
            //No categories
            if(!state['feedtree']['uncategorised']) {
                state['feedtree']['uncategorised']  = {};
                state['feedtree']['uncategorised'].label = "Uncategorised Feeds";
                state['feedtree']['uncategorised'].subscriptions = [];
                state['feedtree']['uncategorised'].unreadcount = 0;
            }
            state['feedtree']['uncategorised'].subscriptions.push(state['feedlist'][feedid]);
            if(state['feedlist'][feedid].unreadcount) {
                state['feedtree']['uncategorised'].unreadcount += parseInt(state['feedlist'][feedid].unreadcount);
            }
        }
    }
    state['numStatusUpdates']++;

    if(callback) {
        callback(0);
    }
}


function getCategories() {
    return state['feedtree'];
}

function getFeedsForCategory(categoryId) {
    if(categoryId === constants['ALL_CATEGORIES']) {
        //Need to return an object with a subscriptions sub-object which is an array of feeds (like an entry in the feed table;
        var allcats = {}
        allcats.subscriptions = [];

        for(var feed in state['feedlist']) {
            allcats.subscriptions.push(state['feedlist'][feed]);
        }
        return allcats;
    }
    return state['feedtree'][categoryId];
}


//Indicates whether only unread items should be shown
function getShowAll() {
    return state['showall'];
}


//Sets whether only unread items should be shown
function setShowAll(showAll) {
    state['showall'] = showAll;
    state['numStatusUpdates']++;
}

function getFeedItems(feedid, cont, callback, force, callbackContext) {
    if(!state['authtoken']) {
        return false;
    }

    if(!force && !cont) {
        if(state['feedcache'][feedid]) {
            callback(true, state['feedcache'][feedid], callbackContext);
            return;
        }
    }

    var url = urls["getfeed"]+encodeURIComponent(feedid);

    if(cont) {
        if(state['feedcache'][feedid]) {
            url += "?c="+encodeURIComponent(state['feedcache'][feedid].continuation);
        } else {
            //Can't continue if we haven't started
            cont = false;
        }
    }

    trace(2, "url: "+url);

    var http = new XMLHttpRequest();

    http.open("GET", url, true);
    http.setRequestHeader("Authorization", state['authtoken']);
    http.onreadystatechange = function() {
            if (http.readyState == XMLHttpRequest.HEADERS_RECEIVED) {
                trace(3, "Headers -->");
                trace(3, http.getAllResponseHeaders ());
            } else if (http.readyState == XMLHttpRequest.DONE) {
                process_getFeedItems(http, feedid, cont, callback, callbackContext);
            }
    }
    http.send();
}

function endsWith(str, suffix) {
    return str.indexOf(suffix, str.length - suffix.length) !== -1;
}

function appendFeedItemsToCacheEntry(feedid, extrafeedjson) {
    if(!state['feedcache'][feedid]) {
        state['feedcache'][feedid] = extrafeedjson;
    } else {
        state['feedcache'][feedid].continuation = extrafeedjson.continuation;
        state['feedcache'][feedid].items = state['feedcache'][feedid].items.concat(extrafeedjson.items);
    }
}

function process_getFeedItems(http, feedid, cont, callback, callbackContext) {
    trace(3, "readystate: "+http.readyState+" status: "+http.status);
    trace(3, "response: "+http.responseText);

    if( http.status == 200 )  {
        var feedjson=JSON.parse(http.responseText);

        for(var i=0; i < feedjson.items.length; i++) {
            feedjson.items[i].unread=true;

            if(feedjson.items[i].categories) {
                for( var j=0; j < feedjson.items[i].categories.length; j++) {
                    if(endsWith(feedjson.items[i].categories[j], "/state/com.google/read")) {
                         feedjson.items[i].unread=false;
                    }
                }
            }
        }

        if(cont) {
            appendFeedItemsToCacheEntry(feedid, feedjson);
        } else {
            state['feedcache'][feedid] = feedjson;
        }
        callback(true, state['feedcache'][feedid], callbackContext);
    } else {
        callback(false, "HTTP Error code: "+http.status, callbackContext);
    }
}

function getFeedUnreadCount(feedid) {    
    if(state['feedlist'][feedid]) {
        return state['feedlist'][feedid].unreadcount;
    }

    //Hmm it's all gone wrong
    trace(1, "Couldn't find unread count for feed: "+feedid);
    return 0;
}

function timestamp2date(timestamp){
    var a = new Date(timestamp*1000);
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var year = a.getFullYear();
    var month = months[a.getMonth()];
    var date = a.getDate();
    var hour = a.getHours();
    var min = a.getMinutes();
    var time  =      ((hour < 10)? "0" : "") + hour;
        time += ':'+ ((min  < 10)? "0" : "") + min;
        time +=      " on "+date+' '+month+' '+year;

    return time;
}

function reduceCategoryUnreadCount(categoryid, readitems) {
    if(state['feedtree'][categoryid]) {
        state['feedtree'][categoryid].unreadcount -= readitems;

        if(state['feedtree'][categoryid].unreadcount < 0) {
            trace(1, "When marking feed as read: "+feedid+". Category: "+categoryid+
                     " unread count dropped to "+state['feedtree'][categoryid].unreadcount);
            state['feedtree'][categoryid].unreadcount = 0;
        }
    }
}

//This function does NOT update the feedcache (it doesn't know which entries were
//read: the cache must be updated separately
function reduceFeedUnreadCount(feedid, readitems) {
    if(state['feedlist'][feedid]) {
        state['feedlist'][feedid].unreadcount -= readitems;

        if(state['feedlist'][feedid].categories && state['feedlist'][feedid].categories.length > 0) {
            for(var j = 0; j < state['feedlist'][feedid].categories.length; j++) {
                var category = state['feedlist'][feedid].categories[j];

                reduceCategoryUnreadCount(category.id, readitems);
            }
        } else {
            //No categories
            reduceCategoryUnreadCount('uncategorised', readitems);
        }
    }
}

function markFeedRead(feedid, callback) {
    /* Mark all the remaining items read */
    var url = urls["markallread"];

    var params  = "s="+encodeURIComponent(feedid);
    params += "&T="+encodeURIComponent(state['token']);


    trace(2,"url: "+url);
    trace(2,"params: "+params);

    var http = new XMLHttpRequest();
    http.open("POST", url, true);
    http.setRequestHeader("Authorization", state['authtoken']);
    http.setRequestHeader("Content-type", "application/x-www-form-urlencoded");

    http.onreadystatechange = function() {//Call a function when the state changes.
                if (http.readyState == XMLHttpRequest.HEADERS_RECEIVED) {
                    trace(3,"Headers -->");
                    trace(3, http.getAllResponseHeaders ());
                } else if (http.readyState == XMLHttpRequest.DONE) {
                    process_markFeedRead(feedid, http, callback);
                }
    }
    http.send(params);
}

function process_markFeedRead(feedid, httpreq, callback) {
//    showRequestInfo("readystate: "+httpreq.readyState+" status: "+httpreq.status);
//    showRequestInfo("response: "+httpreq.responseText);

    if( httpreq.status === 200 )  {
        trace(4, "Successfully marked feed read: "+feedid);

        var oldunreadcount = 0;
        if(state['feedlist'][feedid]) {
            oldunreadcount = state['feedlist'][feedid].unreadcount;
            reduceFeedUnreadCount(feedid, oldunreadcount)
        }
        if(state['feedcache'][feedid]) {
            for(var i=0; i < state['feedcache'][feedid].items.length; i++) {
                state['feedcache'][feedid].items[i].unread=false;
            }
        }

        state['numStatusUpdates']++;

        if(callback) {
            callback(0, "");
        }
    } else {
        trace(1, "Error: received http code: "+httpreq.status+" full text: "+httpreq.responseText);

        if(callback) {
            callback(httpreq.status, "Error: received http code: "+httpreq.status+" full text: "+httpreq.responseText);
        }
    }
}

function markEntryRead(feedid, entryid, markread, callback) {
    var url = urls["edittag"];

    var params  = "i="+encodeURIComponent(entryid);

    if(markread) {
        params += "&a=";
    } else {
        params += "&r=";
    }
    params += encodeURIComponent("user/-/state/com.google/read");

    params += '&ac=edit-tags';
    params += "&T="+encodeURIComponent(state['token']);


    trace(2,"url: "+url);
    trace(2,"params: "+params);

    //Optimistically change our unread counts, if the request fails, we'll undo it
    updateLocalState_markEntryRead(feedid, entryid, markread);

    var http = new XMLHttpRequest();
    http.open("POST", url, true);
    http.setRequestHeader("Authorization", state['authtoken']);
    http.setRequestHeader("Content-type", "application/x-www-form-urlencoded");

    http.onreadystatechange = function() {//Call a function when the state changes.
                if (http.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                    trace(3,"Headers -->");
                    trace(3, http.getAllResponseHeaders ());
                } else if (http.readyState === XMLHttpRequest.DONE) {
                    process_markEntryRead(feedid, entryid, markread, callback, http);
                }
    }
    http.send(params);
}


function updateLocalState_markEntryRead(feedid, entryid, isRead) {
    if(state['feedlist'][feedid]) {
        reduceFeedUnreadCount(feedid, ((isRead)?1:(-1)));
    }
    if(state['feedcache'][feedid]) {
        for(var i=0; i < state['feedcache'][feedid].items.length; i++) {
            if(state['feedcache'][feedid].items[i].id == entryid) {
                state['feedcache'][feedid].items[i].unread = !(isRead);
            }
        }
    }

    state['numStatusUpdates']++;
}

function process_markEntryRead(feedid, entryid, markread, callback, httpreq) {
//    showRequestInfo("readystate: "+httpreq.readyState+" status: "+httpreq.status);
//    showRequestInfo("response: "+httpreq.responseText);

    if( httpreq.status == 200 )  {
        trace(4, "Successfully marked feed read: "+feedid);

        if(callback) {
            callback(0, "");
        }
    } else {
        trace(1, "Error: received http code: "+httpreq.status+" full text: "+httpreq.responseText);

        //Undo our "optimistic" state change
        updateLocalState_markEntryRead(feedid, entryid, !markread);

        if(callback) {
            callback(httpreq.status, "Error: received http code: "+httpreq.status+" full text: "+httpreq.responseText);
        }
    }
}

function getNumStatusUpdates() {
    return state['numStatusUpdates'];
}


function pickEntryFromFeed(feedId, itemId, callback) {
    var context = {
        'callback': callback,
        'feedId': feedId,
        'itemId': itemId
    };


    getFeedItems(feedId, false, process_pickEntryFromFeed, false, context);
}

//Picks the newest unread item in the feed after the "current" item
//If the there are no unread items after the current item or no current item is supplied, picks the first unread
function process_pickEntryFromFeed(success, feeditems, context)
{
    var doneCallback = false;

    if(success) {
        var itemId = context['itemId'];
        var firstUnread = null;
        var foundSuppliedItem = false;

        for(var i=0; i< feeditems.items.length; i++) {
            if(itemId && !foundSuppliedItem) {
                if(feeditems.items[i].id === itemId) {
                    foundSuppliedItem = true;
                }
            }

            if(feeditems.items[i].unread) {
                if(foundSuppliedItem) {
                    //First unread item after the supplied item...definitely the one we want
                    context['callback'](true, context['feedId'], feeditems.items[i].id);
                    doneCallback = true
                    break;
                } else if(firstUnread == null) {
                    //First unread item, if there aren't any in the feed after the supplied one, we'll use this
                    firstUnread = feeditems.items[i];
                }
            }
        }

        if(!doneCallback && firstUnread && (itemId !== firstUnread.id) ) {
            context['callback'](true, context['feedId'], firstUnread.id);
        }
    }

    if(!doneCallback) {
        context['callback'](false);
    }
}

//any of *Id args can be null
function pickEntry(categoryId, feedId, itemId, lockFeed, lockCategory, callback) {
    var entrydetails;

    if(feedId && (state['feedlist'][feedId].unreadcount > 0)) {
            pickEntryFromFeed(feedId, itemId, callback);
            return true;
    }

    if(!lockFeed) {
        if(categoryId  && (categoryId !== constants['ALL_CATEGORIES'])) {
            if(categoryId in state['feedtree']) {
                for(var i=0; i<state['feedtree'][categoryId].subscriptions.length; i++ ) {
                    if(state['feedtree'][categoryId].subscriptions[i].unreadcount > 0) {
                        pickEntryFromFeed(state['feedtree'][categoryId].subscriptions[i].id, itemId, callback);
                        return true;
                    }
                }
            }
        }

        if(!lockCategory || (categoryId === constants['ALL_CATEGORIES'])) {
            for(feedId in state['feedlist']) {
                if(state['feedlist'][feedId].unreadcount > 0) {
                    pickEntryFromFeed(feedId, itemId, callback);
                    return true;
                }
            }
        }
    }
    return false;
}


function pickCategory() {
    for(var categoryId in state['feedtree']) {
        if(state['feedtree'][categoryId].unreadcount >0 ) {
            return categoryId;
        }
    }
    return null;
}


function pickFeed(categoryId) {
    if(categoryId && (categoryId !== constants['ALL_CATEGORIES'])) {
        for(var i=0; i<state['feedtree'][categoryId].subscriptions.length; i++ ) {
            if(state['feedtree'][categoryId].subscriptions[i].unreadcount > 0) {
                return state['feedtree'][categoryId].subscriptions[i].id;
            }
        }
    } else {
        for(var feedId in state['feedlist']) {
            if(state['feedlist'][feedId].unreadcount > 0) {
                return feedId;
            }
        }
    }

    return null;
}

function getCloseIfEmpty() {
    return state['closeIfEmpty'];
}

function setCloseIfEmpty(newState) {
    state['closeIfEmpty'] = newState;
}
