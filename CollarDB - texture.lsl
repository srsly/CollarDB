//CollarDB - texture - 3.525
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.
//color

//set textures by uuid, and save uuids instead of texture names to DB

//on getting texture command, give menu to choose which element, followed by menu to pick texture

list g_lElements;
string s_CurrentElement = "";
list g_lTextures;
string g_sParentMenu = "Appearance";
string g_sSubMenu = "Textures";
string g_sDBToken = "textures";

integer iLength;
list lButtons;
list g_lNewButtons;//is this used? 2010/01/14 Starship

//dialog handles
key g_kElementID;
key g_ktextureID;

// Textures in Notecard for Non Full Perm textures
key g_ktexcardID;
string g_noteName = "";
integer g_noteLine;
list g_textures = [];
list g_read = [];

integer g_iAppLock = FALSE;
string g_sAppLockToken = "AppLock";

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;


integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
//5000 block is reserved for IM slaves

string UPMENU = "^";

key g_kWearer;

Debug(string sStr)
{
    //llOwnerSay(llGetScriptName() + ": " + sStr);
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) {
        llOwnerSay(sMsg);
    } else {
            llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer) {
            llOwnerSay(sMsg);
        }
    }
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

TextureMenu(key kID, integer iPage)
{
    //create a list
    list lButtons;
    string sPrompt = "Choose the texture to apply.";
    //build a button list with the dances, and "More"
    //get number of anims
    integer iNumTex = llGetInventoryNumber(INVENTORY_TEXTURE);
    integer n;
    for (n=0;n<iNumTex;n++)
    {
        string sName = llGetInventoryName(INVENTORY_TEXTURE,n);
        lButtons += [sName];
    }
    integer iNoteTex = llGetListLength(g_textures);
    for (n=0;n<iNoteTex;n=n+2)
    {
        string sName = llList2String(g_textures,n);
        lButtons += [sName];
    }
    g_ktextureID = Dialog(kID, sPrompt, lButtons, [UPMENU], iPage);
}

ElementMenu(key kAv)
{
    string sPrompt = "Pick which part of the collar you would like to retexture";
    lButtons = llListSort(g_lElements, 1, TRUE);
    g_kElementID = Dialog(kAv, sPrompt, lButtons, [UPMENU], 0);
}

string ElementType(integer iLinkNum)
{
    string sDesc = (string)llGetObjectDetails(llGetLinkKey(iLinkNum), [OBJECT_DESC]);
    //prim desc will be elementtype~notexture(maybe)
    list lParams = llParseString2List(sDesc, ["~"], []);
    if ((~(integer)llListFindList(lParams, ["notexture"])) || sDesc == "" || sDesc == " " || sDesc == "(No Description)")
    {
        return "notexture";
    }
    else
    {
        return llList2String(llParseString2List(sDesc, ["~"], []), 0);
    }
}

LoadTextureSettings()
{
    //loop through links, setting each's color according to entry in textures list
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    for (n = 2; n <= iLinkCount; n++)
    {
        string sElement = ElementType(n);
        integer iIndex = llListFindList(g_lTextures, [sElement]);
        string sTex = llList2String(g_lTextures, iIndex + 1);
        //llOwnerSay(llList2String(g_lTextures, iIndex + 1));
        if (iIndex != -1)
        {
            //set link to new texture
            list lParams=llGetLinkPrimitiveParams(n, [ PRIM_TEXTURE, ALL_SIDES]);
            integer iSides=llGetListLength(lParams);
            integer iSide;
            list lTemp=[];
            for (iSide = 0; iSide < iSides; iSide = iSide +4)
            {
                lTemp += [PRIM_TEXTURE, iSide/4, sTex] + llList2List(lParams, iSide+1, iSide+3);
            }
            llSetLinkPrimitiveParamsFast(n, lTemp);
        }
    }
}

integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}

SetElementTexture(string sElement, key kTex)
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    for (n = 2; n <= iLinkCount; n++)
    {
        string thiselement = ElementType(n);
        if (thiselement == sElement)
        {
            list lParams=llGetLinkPrimitiveParams(n, [ PRIM_TEXTURE, ALL_SIDES]);
            integer iSides=llGetListLength(lParams);
            integer iSide;
            list lTemp=[];
            for (iSide = 0; iSide < iSides; iSide = iSide +4)
            {
                lTemp += [PRIM_TEXTURE, iSide/4, kTex] + llList2List(lParams, iSide+1, iSide+3);
            }
            llSetLinkPrimitiveParamsFast(n, lTemp);
        }
    }

    //change the textures list entry for the current element
    integer iIndex;
    iIndex = llListFindList(g_lTextures, [sElement]);
    if (iIndex == -1)
    {
        g_lTextures += [s_CurrentElement, kTex];
    }
    else
    {
        g_lTextures = llListReplaceList(g_lTextures, [kTex], iIndex + 1, iIndex + 1);
    }
    //save to httpdb
    llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sDBToken + "=" + llDumpList2String(g_lTextures, "~"), NULL_KEY);
}

loadNoteCards(string param)
{
    if (g_noteName != "" &&  param == "EOF")
    {
        g_read += [g_noteName];
        g_textures = llListSort(g_textures,2,TRUE);
    }
        
    if (g_noteName == "" &&  param == "")
    {
        g_read = [];
        g_textures = [];
    }
        
    if ((g_noteName != "" &&  param == "EOF") || (g_noteName == "" &&  param == ""))
    {
        integer iNumNote = llGetInventoryNumber(INVENTORY_NOTECARD);
        integer n;
        for (n=0;n<iNumNote;n++)
        {
            string sName = llGetInventoryName(INVENTORY_NOTECARD,n);
            if (StartsWith(llToLower(sName),"~cdbt_"))
            {
                if (llListFindList(g_read,[sName]) == -1)
                {
                    n=iNumNote;                
                    g_noteName = sName;
                    g_noteLine = 0;
                    g_ktexcardID = llGetNotecardLine(g_noteName, g_noteLine);
                }
            }
            
        }    
    }
}


default
{
    state_entry()
    {
        loadNoteCards("");
        g_kWearer = llGetOwner();
        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        string sPrefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (sPrefix != "")
        {
            g_sDBToken = sPrefix + g_sDBToken;
        }

        //loop through non-root prims, build element list
        integer n;
        integer iLinkCount = llGetNumberOfPrims();

        //root prim is 1, so start at 2
        for (n = 2; n <= iLinkCount; n++)
        {
            string sElement = ElementType(n);
            if (!(~llListFindList(g_lElements, [sElement])) && sElement != "notexture")
            {
                g_lElements += [sElement];
                //llSay(0, "added " + sElement + " to g_lElements");
            }
        }
        // we need to unify the initialization of the menu system for 3.5
        llSleep(1.0);
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        //owner, secowner, group, and wearer may currently change colors
        if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER && sStr == "textures")
        {
            if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
            {
                Notify(kID,"You are not allowed to change the textures.", FALSE);
                llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kID);
            }
            else if (g_iAppLock)
            {
                Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
            }

            else
            {
                s_CurrentElement = "";
                ElementMenu(kID);
            }
        }
        else if (llGetSubString(sStr,0,13) == "lockappearance")
        {
            if (iNum == COMMAND_OWNER)
            {
                if(llGetSubString(sStr, -1, -1) == "0")
                {
                    g_iAppLock  = FALSE;
                }
                else
                {
                    g_iAppLock  = TRUE;
                }
            }
        }        
        else if (sStr == "reset" && (iNum == COMMAND_OWNER || iNum == COMMAND_WEARER))
        {
            //clear saved settings
            //llMessageLinked(LINK_SET, HTTPDB_DELETE, g_sDBToken, NULL_KEY);
            llResetScript();
        }
        else if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            if (sStr == "settings")
            {
                Notify(kID, "Texture Settings: " + llDumpList2String(g_lTextures, ","), FALSE);
            }
            else if (StartsWith(sStr, "settexture"))
            {
                if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
                {
                    Notify(kID,"You are not allowed to change the textures.", FALSE);
                }
                else if (g_iAppLock)
                {
                    Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
                }
                else
                {
                    list lParams = llParseString2List(sStr, [" "], []);
                    string sElement = llList2String(lParams, 1);
                    key kTex = (key)llList2String(lParams, 2);
                    SetElementTexture(sElement, kTex);
                }
            }
        }
        else if (iNum == HTTPDB_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == g_sDBToken)
            {
                g_lTextures = llParseString2List(sValue, ["~"], []);
                //llInstantMessage(llGetOwner(), "Loaded texture settings.");
                LoadTextureSettings();
            }
            else if (sToken == g_sAppLockToken)
            {
                g_iAppLock = (integer)sValue;
            }
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
        }
        else if (iNum == SUBMENU && sStr == g_sSubMenu)
        {
            if (sStr == g_sSubMenu)
            {
                //we don't know the authority of the menu requester, so send a message through the auth system
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "textures", kID);
            }
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (llListFindList([g_kElementID, g_ktextureID], [kID]) != -1)
            {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);

                if (kID == g_kElementID)
                {//they just chose an element, now choose a texture
                    if (sMessage == UPMENU)
                    {
                        //main menu
                        llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kAv);
                    }
                    else
                    {
                        //we just got the element name
                        s_CurrentElement = sMessage;
                        TextureMenu(kAv, iPage);
                    }
                }
                else if (kID == g_ktextureID)
                {
                    if (sMessage == UPMENU)
                    {
                        s_CurrentElement = "";
                        ElementMenu(kAv);
                    }
                    else
                    {
                        //got a texture name
                        string sTex;
                        if (llListFindList(g_textures,[sMessage]) != -1)
                        {
                            sTex = llList2String(g_textures,llListFindList(g_textures,[sMessage]) + 1);
                        }
                        else
                        {
                            sTex = (string)llGetInventoryKey(sMessage);
                        }
                        //loop through links, setting texture if element type matches what we're changing
                        //root prim is 1, so start at 2
                        SetElementTexture(s_CurrentElement, (key)sTex);
                        TextureMenu(kAv, iPage);
                    }
                }
            }
        }
    }
    
    dataserver(key query_id, string data)
    {
        if (query_id == g_ktexcardID)
        {
            if (data == EOF)
                loadNoteCards("EOF");
            else
            {
                list temp = llParseString2List(data,[",",":","|","="],[]);
                g_textures += [llList2String(temp,0),llList2Key(temp,1)];
                // bump line number for reporting purposes and in preparation for reading next line
                ++g_noteLine;
                g_ktexcardID = llGetNotecardLine(g_noteName, g_noteLine);
            }
        }
    }
    
    changed(integer change)
    {
        if(change & CHANGED_INVENTORY)
        {
            loadNoteCards("");
        }
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }
}