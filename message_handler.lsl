string HELP_STRING = "\ncommand : description\n.whois [name] : access any notes written about [name]\n.roll [sides] : roll a die with [sides] sides\n.music [stream] : set parcel stream\n.arrest [uuid]: submit a vote for Citizen's Arrest\n.drink : get a drink!\n.help : uh...";
list votes;
integer IM_BOOSTER = TRUE;//if TRUE, then all calls of llInstantMessage are instead routed through link message to another prim that will handle it

string getValue(list kv, string k)
{
    integer index = llListFindList(kv,[k]);
    if(~index)
        return llList2String(kv,index+1);
    return "";
}

///////////////////////////////////////////////////////////////////////////
///WaS fuctions

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

instantMessage(key id, string message)
{
    if(IM_BOOSTER)
        llMessageLinked(LINK_ALL_OTHERS,0,message,id);
    else
        llInstantMessage(id,message);    
}

tell(list credentials, string message, string entity)
{
    instantMessage(getValue(credentials,"corrade"),
    wasKeyValueEncode(
        [
            "command", "tell",
            "group", wasURLEscape(getValue(credentials,"group_name")),
            "password", wasURLEscape(getValue(credentials,"group_pass")),
            "message", message,
            "entity", entity,
            "target", wasURLEscape(getValue(credentials,"group_id"))
        ]
    )
);
}

groupSay(list credentials, string message)
{
    tell(credentials, message,"group");  
}

regionAlert(list credentials, string message)
{
    tell(credentials, message,"region"); 
}

integer numOfIndexes(list sort, list find)
{
    integer i;
    integer count;
    integer index;
    
    while(~index)
    {
        index = llListFindList(sort,find);
        if(~index)
        {
            count++;
            sort = llDeleteSubList(sort,0,index+1);    
        } 
    }
    
    return count;
}

list deleteEach(list sort, list find)
{
    integer i;
    integer index;
    
    while(~index)
    {
        index = llListFindList(sort,find);
        if(~index)
            sort = llDeleteSubList(sort,index-1,index+1);    
    }
    
    return sort;
}

makeAuthCheck(list credentials, string notification, string role)
{
    groupSay(credentials, "authorizing...");
    instantMessage(getValue(credentials,"corrade"),
    wasKeyValueEncode(
        [
            "command", "getmemberroles",
            "group", wasURLEscape(getValue(credentials,"group_name")),
            "password", wasURLEscape(getValue(credentials,"group_pass")),
            "group_id", wasURLEscape(getValue(credentials,"group_id")),
            "agent", wasURLEscape(getValue(credentials,"agent")),
            "notification", notification,
            "required_role",wasURLEscape(role),           
            "callback", wasURLEscape(getValue(credentials,"url"))
        ]
    )
);    
}

integer isInGroup(string group, list groups)
{
    if(~llListFindList(groups,[group]))
        return TRUE;
    return FALSE;    
}

setMusicURL(list credentials, string stream)
{
    groupSay(credentials, "Setting music stream...");
    instantMessage(getValue(credentials,"corrade"),
    wasKeyValueEncode(
        [
            "command", "setparceldata",
            "group", wasURLEscape(getValue(credentials,"group_name")),
            "password", wasURLEscape(getValue(credentials,"group_pass")),
            "data", wasListToCSV(["MusicURL", wasURLEscape(stream)]),
            "position", <128,128,0>
        ]
    )
);    
}

restartRegion(list credentials)
{
    instantMessage(getValue(credentials,"corrade"),
    wasKeyValueEncode(
        [
            "command", "restartregion",
            "group", wasURLEscape(getValue(credentials,"group_name")),
            "password", wasURLEscape(getValue(credentials,"group_pass")),
            "action", "restart"
        ]
    )
);    
}


handleGroupMessage(string notification, integer auth)
{
    list args = llParseString2List(wasURLUnescape(notification),["|"],[]);
    key corrade = (key)getValue(args,"corrade");
    string name = getValue(args,"name");
    key agent = (key)getValue(args,"agent");
    string message = getValue(args,"message");
    string group = getValue(args,"group_name");
    string password = getValue(args,"group_pass");
    string group_id = getValue(args,"group_id");
    string url = getValue(args,"url");
    list credentials = ["corrade",corrade,"group_name",group,"group_pass",password,"group_id",group_id,"url",url,"agent",agent];
    integer index = llSubStringIndex(message," ");
    string command;
    string parameter;
    
    if(~index)
        command = llToLower(llGetSubString(message,0,index-1));
    else
        command = message;
    parameter = llToLower(llGetSubString(message,index+1,-1));
    if(command == ".help")
        groupSay(credentials, HELP_STRING);

    else if(command == ".whois")
    {
        if(parameter == "tommytom.jun")
            groupSay(credentials, "Man, I really hate that guy!");
        else if(parameter == "ritzu.clawtooth")
            groupSay(credentials, "Emperor of Xoan/Sim Owner/Edgedog Supreme");
        else if(parameter == "arkane.flux")
            groupSay(credentials, "Archmage of Xoan/Sim Owner/pretty cool guy!");
        else if(parameter == "zealous.nightfire")
            groupSay(credentials, "Lower Planes Admin and deer-est friend!"); 
        else
            groupSay(credentials, "/me shrugs");  
    }
    
    else if(command == ".test")
    {
        if(!auth)
            makeAuthCheck(credentials,notification,"Owners");
        else
            groupSay(credentials, "Hello, world!");
    }
    
    else if(command == ".test2")
    {
        if(!auth)
            makeAuthCheck(credentials,notification,"sdf");
        else
            groupSay(credentials, "Hello, world!");
    }
        
    else if(command == ".region")
    {
        if(!isInGroup(getValue(credentials,"group_id"),["Lower Planes Management","Magic, Inc."]))
            groupSay(credentials, "This function has been disabled for this group!");
        else if(!auth)
            makeAuthCheck(credentials,notification,"Owners");
        else
            regionAlert(credentials, parameter);
        
    }
    
    else if(command == ".reset")
    {
        restartRegion(credentials);
    }
    
    else if(command == ".music")
    {
        if(llListFindList(["Lower Planes Management","Magic, Inc."],[getValue(credentials,"group_name")]) == -1)
        {
            groupSay(credentials, "This function has been disabled for this group!");
            return;
        }
        setMusicURL(credentials,parameter); 
    }
    
    else if(command == ".arrest")
    {
        if(!isInGroup(getValue(credentials,"group_name"),["Lower Planes Management","Magic, Inc."]))
        {
            groupSay(credentials, "This function has been disabled for this group!");
            return;
        }
        
        else if(parameter == command)
        {
            groupSay(credentials, "Please specify an avatar UUID for this command.");
            return;    
        }

        integer index = llListFindList(votes,[agent]);
        if(~index && llList2String(votes,index+1) == parameter)
            groupSay(credentials, "You have already cast this vote, Citizen!");
        else
        {
            votes += [agent,parameter,llGetTime()];
            integer len = llGetListLength(votes);
            list counts = ["Once!","Twice!","Thrice!"];
            integer num = numOfIndexes(votes,[parameter]);
            groupSay(credentials, llList2String(counts,num-1));
            if(num == 3)
            {
                groupSay(credentials, "A temporary ban has been set for the entity '"+parameter+"' This incident has been reported to the administrators. Stay vigilant, Citizens!");
                votes = deleteEach(votes,[parameter]);
            } 
        } 
    }
        
    else if(command == ".roll")
    {
        integer die = (integer)parameter;
        if(parameter == "") {
            groupSay(credentials, "You must specify what size die to roll (example: [.roll 6])");
        } else if(die < 2 || die > 64)
            groupSay(credentials, "Value must be in range (2, 64).");
        else
        {
            integer rand = (integer)llFrand((float)parameter)+1;
            string msg = name + " rolls a "+(string)rand;
            if(rand == die)
                msg += " (critical hit!)";
            else if(rand == 1)
                msg += " (critical miss!)";
            groupSay(credentials, msg);   
        }
    }
    
    else if(command == ".drink")
    {
        integer rand = (integer)llFrand((float)llGetInventoryNumber(INVENTORY_OBJECT));
        groupSay(credentials, "/me slides a drink towards "+name);
        llGiveInventory(agent,llGetInventoryName(INVENTORY_OBJECT,rand));
    }
    
    else if(message == "/me shrugs")
    {
        list allowed = [llGetOwner(),(key)"1ad33407-a792-476d-a5e3-06007c0802bf"];
        if(~llListFindList(allowed,[(key)agent]));
            groupSay(credentials, message);
    }
    
    else if(llGetSubString(message,0,9) == "/me stares")
    {
        list allowed = [llGetOwner(),(key)"1ad33407-a792-476d-a5e3-06007c0802bf"];
        if(~llListFindList(allowed,[(key)agent]));
            groupSay(credentials, message);
    }
    
    else if(llGetSubString(message,0,11) == "/me snickers")
    {
        list allowed = [llGetOwner(),(key)"1ad33407-a792-476d-a5e3-06007c0802bf"];
        if(~llListFindList(allowed,[(key)agent]));
            groupSay(credentials, "/me also snickers");
    }
        
}

clean()
{
    integer i;
    @start;
    integer len = llGetListLength(votes);
    for(i=0;i<len;i+=3)
    {
        float time = llGetTime();
        if(time-(float)llList2String(votes,i+2) >= 60.0)
        {
            votes = llDeleteSubList(votes,i,i+2);
            jump start;
        }
    }
}

list uWasURLUnescapeList(list l)
{
    integer i;
    integer len = llGetListLength(l);
    for(;i<len;i++)
        l += wasURLUnescape(llList2String(l,i));
    return llList2List(l,len+1,-1);
}

default
{
    on_rez(integer start_param)
    {
        llResetScript();    
    }
        
    state_entry()
    {
        llMessageLinked(LINK_ALL_OTHERS,-1,"","");
    }
    
    link_message(integer sender_num, integer num, string str, key id)
    {
        if(sender_num != 1)
        {
            IM_BOOSTER = sender_num;
            llOwnerSay("IM Booster Prim detected."); 
        }
        else if(str == "config")
        {
            ;    
        }
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
        llSetTimerEvent(60.0);    
    }
    
    link_message(integer sender_num, integer num, string str, key id)
    {
            if(sender_num != 1)
                return;
            list args = llParseString2List(id,["|"],[]);
            integer len = llGetListLength(args);
            integer i;
            list parameters;
            for(;i<len;i++)
                parameters += llList2String(args,i);  
            string command = wasURLUnescape(getValue(parameters,"command"));        
         
            if(command == "getmemberroles")//is an auth check
            {   
                list roles = llCSV2List(wasURLUnescape(getValue(parameters,"data")));
                string required = wasURLUnescape(getValue(parameters,"required_role"));
                string notification = getValue(parameters,"notification");
                if(~llListFindList(roles,[required]))
                    handleGroupMessage(notification,TRUE);
                else
                {
                    integer i;
                    integer len = llGetListLength(parameters);
                    list args;
                    for(;i<len;i++)
                        args += wasURLUnescape(llList2String(parameters,i));
                    groupSay(uWasURLUnescapeList(parameters),"You do not have the required group role to use this function.");
                }
            }
            else
                handleGroupMessage(id,FALSE);
    }
    
    timer()
    {
        clean();    
    }
    
    changed(integer change)
    {
        if(change & CHANGED_INVENTORY)
            llResetScript();    
    }
}
