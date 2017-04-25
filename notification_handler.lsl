list group_info;
string url;
key corrade;
string HELP_STRING = "\ncommand : description\n.whois [name] : access any notes written about [name]\n.roll [sides] : roll a die with [sides] sides\n.music [stream] : set parcel stream\n.arrest [uuid]: submit a vote for Citizen's Arrest\n.drink : get a drink!\n.help : uh...";
integer count;
key data_request;
integer successful_connections;
integer successful_purges;
string NOTECARD = "config";
integer line;
key line_request;
integer IM_BOOSTER;//if TRUE, then all calls of llInstantMessage are instead routed through link message to another prim that will handle it

///////////////////////////////////////////////////////////////////////////
///WaS fuctions

string wasKeyValueGet(string k, string data) {
    if(llStringLength(data) == 0) return "";
    if(llStringLength(k) == 0) return "";
    list a = llParseString2List(data, ["&", "="], []);
    integer i = llListFindList(llList2ListStrided(a, 0, -1, 2), [ k ]);
    if(i != -1) return llList2String(a, 2*i+1);
    return "";
}

string wasKeyValueEncode(list data) {
    integer i = llGetListLength(data);
    if (i % 2 != 0 || i == 0) return "";
    --i;
    do {
        data = llListInsertList(
            llDeleteSubList(
                data, 
                i-1, 
                i
            ),
            [ llList2String(data, i-1) + "=" + llList2String(data, i) ], 
            i-1
        );
        i -= 2;
    } while(i > 0);
    return llDumpList2String(data, "&");
}

string wasURLEscape(string i) {
    if(i == "") return "";
    string o = llGetSubString(i, 0, 0);
    i = llDeleteSubString(i, 0, 0);
    if(o == " ") return "+" + wasURLEscape(i);
    if(o == "\n") return "%0D%0A" + wasURLEscape(i);
    return llEscapeURL(o) + wasURLEscape(i); 
}

string wasURLUnescape(string i) {
    return llUnescapeURL(
        llDumpList2String(
            llParseString2List(
                llDumpList2String(
                    llParseString2List(
                        i, 
                        ["+"], 
                        []
                    ), 
                    " "
                ), 
                ["%0D%0A"], 
                []
            ), 
            "\n"
        )
    );
}

string wasListToCSV(list l) {
    list v = [];
    do {
        string a = llDumpList2String(
            llParseStringKeepNulls(
                llList2String(
                    l, 
                    0
                ), 
                ["\""], 
                []
            ),
            "\"\""
        );
        if(llParseStringKeepNulls(
            a, 
            [" ", ",", "\n", "\""], []
            ) != 
            (list) a
        ) a = "\"" + a + "\"";
        v += a;
        l = llDeleteSubList(l, 0, 0);
    } while(l != []);
    return llDumpList2String(v, ",");
} 
///////////////////////////////////////////////////////////////////////////


string getValue(list kv, string k)
{
    integer index = llListFindList(kv,[k]);
    if(~index)
        return llList2String(kv,index+1);
    return "";
}


instantMessage(key id, string message)
{
    if(IM_BOOSTER)
        llMessageLinked(IM_BOOSTER,0,message,id);
    else
        llInstantMessage(id,message);    
}

subscribe()
{
    integer i;
    integer len = llGetListLength(group_info);
    for(;i<len;i+=3)
    {
        instantMessage(corrade,
            wasKeyValueEncode(
        [
            "command", "notify",
            "group", wasURLEscape(llList2String(group_info,i+0)),
            "password", wasURLEscape(llList2String(group_info,i+1)),
            "action", "set",
            "type", "group",
            "URL", wasURLEscape(url),
            "callback", wasURLEscape(url)
        ]
            )
        );
    }
}

clear()
{
    integer i;
    integer len = llGetListLength(group_info);
    for(;i<len;i+=3)
    instantMessage(corrade,
            wasKeyValueEncode(
        [
            "command", "notify",
            "group", wasURLEscape(llList2String(group_info,i)),
            "password", wasURLEscape(llList2String(group_info,i+1)),
            "action", "purge",
            "callback", wasURLEscape(url)
        ]
            )
        );
}



string groupName2Key(string group)
{
    integer index = llListFindList(group_info,[group]);
    if(~index)
        return llList2String(group_info,index+2);
    else
        return "";
}

string groupName2Pass(string group)
{
    integer index = llListFindList(group_info,[group]);
    if(~index)
        return llList2String(group_info,index+1);
    else
        return "";
}



sendGroupMessage(list parameters)
{
    string group = wasURLUnescape(getValue(parameters,"group"));
    parameters += ["corrade",corrade,"group_name",wasURLEscape(group),"group_pass",wasURLEscape(groupName2Pass(group)),"group_id",groupName2Key(group),"url",wasURLEscape(url),"name",wasURLEscape(getValue(parameters,"firstname")+" "+getValue(parameters,"lastname"))];
    //string n = llDumpList2String(["corrade",corrade,"group_name",getValue(parameters,"group"),"group_pass",groupName2Pass(group),"group_id",groupName2Key(group),"name",getValue(parameters,"name"),"agent",agent,"chat_message",message,"url",url],"|");
    llMessageLinked(LINK_THIS,0,"notification",llDumpList2String(parameters,"|"));
}





///////////////////////////////////////////////////////////////////////////
//  Copyright (C) Wizardry and Steamworks 2014 - License: GNU GPLv3      //
//  Please see: http://www.gnu.org/licenses/gpl.html for legal details,  //
//  rights of fair usage, the disclaimer and warranty conditions.        //
///////////////////////////////////////////////////////////////////////////
 
// for notecard reading
 
// key-value data will be read into this list
list tuples = [];
 
default {
    state_entry() {
        if(llGetInventoryType("configuration") != INVENTORY_NOTECARD) {
            llSay(DEBUG_CHANNEL, "Sorry, could not find an inventory notecard.");
            return;
        }
        llGetNotecardLine("configuration", line);
    }
    dataserver(key id, string data) {
        if(data == EOF) state detect; // invariant, length(tuples) % 2 == 0
        if(data == "") jump continue;
        integer i = llSubStringIndex(data, "#");
        if(i != -1) data = llDeleteSubString(data, i, -1);
        list o = llParseString2List(data, ["="], []);
        // get rid of starting and ending quotes
        string k = llDumpList2String(
            llParseString2List(
                llStringTrim(
                    llList2String(
                        o, 
                        0
                    ), 
                STRING_TRIM), 
            ["\""], []
        ), "\"");
        string v = llDumpList2String(
            llParseString2List(
                llStringTrim(
                    llList2String(
                        o, 
                        1
                    ), 
                STRING_TRIM), 
            ["\""], []
        ), "\"");
        if(k == "" || v == "") jump continue;
        tuples += k;
        tuples += v;
@continue;
        llGetNotecardLine("configuration", ++line);
    }
    changed(integer change) {
        if(change & CHANGED_INVENTORY) {
            llResetScript();
        }
    }
}



state detect
{
    on_rez(integer start_param)
    {
        llResetScript();    
    }
    
    state_entry()
    {
        llOwnerSay("initializing...");
        llOwnerSay(llDumpList2String(tuples, ","));
        integer i;
        integer len = llGetListLength(tuples);
        for(;i<len;i+=2)
        {
            string k = llList2String(tuples,i);
            string v = llList2String(tuples,i+1); 
            if(k == "corrade")
                corrade = v;
            else
                group_info += [k]+llParseString2List(v,["|"],[]);  
        }
        llMessageLinked(LINK_ALL_OTHERS,-1,"","");
        llSetTimerEvent(2.0);  
    }
    
    link_message(integer sender_num, integer num, string str, key id)
    {
        if(sender_num != 1)
        {
            IM_BOOSTER = sender_num;
            llOwnerSay("IM Booster Prim detected.");
            state online;  
        }
    }
    
    timer()
    {
        state online;    
    }
    
}

state online
{
    state_entry()
    {
        llOwnerSay("Checking online status...");
        data_request = llRequestAgentData(corrade,DATA_ONLINE);  
    }
        
    
    dataserver(key id, string data)
    {
        if(id == data_request)
        {  
            if(!(integer)data)
            {
                llOwnerSay("Corrade is not currently connected! Trying again in 60 seconds...");
                llSetTimerEvent(60.0);
                return;    
            }
            llOwnerSay("Corrade is online. Requesting URL...");
            llRequestURL();
        }
        
    }
    
    timer()
    {
        llOwnerSay("Checking online status...");
        data_request = llRequestAgentData(corrade,DATA_ONLINE);    
    }
    
    http_request(key id, string method, string body)
    {
        body = wasURLUnescape(body);
        llHTTPResponse(id, 200, "Ok");
        
        if (method == URL_REQUEST_DENIED)
            llOwnerSay("Could not request URL! This is bad! Trying again in 60 seconds...");
        else if (method == URL_REQUEST_GRANTED) 
        {
            url = body;
            state active;
        }
    }
    
    changed(integer change)
    {
        if((change & CHANGED_REGION_START)||(change & CHANGED_INVENTORY))
            llResetScript();    
    }
}


state active
{
    on_rez(integer start_param)
    {
        llResetScript();    
    }
    
    state_entry()
    {
        llOwnerSay("URL acquired. Connecting to group chats...");
        subscribe();
        llSetTimerEvent(60.0); 
    }
    
    timer()
    {
        data_request = llRequestAgentData(corrade,DATA_ONLINE);
    }
    
     http_request(key id, string method, string body)
    {
        llHTTPResponse(id, 200, "Ok");
        list args = llParseString2List(body,["&"],[]);
        integer len = llGetListLength(args);
        integer i;
        list parameters;
        for(;i<len;i++)
            parameters += llParseString2List(llList2String(args,i),["="],[]);
       // llOwnerSay(llList2CSV(parameters)); 
        string command = wasURLUnescape(getValue(parameters,"command"));        
        string group = wasURLUnescape(getValue(parameters,"group"));
        key agent = wasURLUnescape(getValue(parameters,"agent"));
        
        if(command == "notify")//is a callback from notify command
        {
            string success = wasURLUnescape(getValue(parameters,"success"));
            if(success == "True")
            {
                llOwnerSay("successfully connected to: "+group);
                ++successful_connections;
                if(successful_connections == llGetListLength(group_info)/3)
                    llOwnerSay("all connections are active");
            }
            else
                llOwnerSay("unable to connect to: "+group);   
        }
        
        //else if(command == "getmemberroles")
           // llMessageLinked(LINK_THIS,-1,command,llDumpList2String(parameters,"|"));
                     
        else if(agent != corrade || command == "getmemberroles")//is a group chat notification
            sendGroupMessage(parameters);
    }
    
    dataserver(key id, string data)
    {
        if(id != data_request)
            return;
            
        if(!(integer)data)
        {
            llOwnerSay("Corrade is not currently connected! Resetting script...");
            llResetScript();
        }
    }
    
    changed(integer change)
    {
        if((change & CHANGED_REGION_START)||(change & CHANGED_INVENTORY)) 
            llResetScript();
    }
}
