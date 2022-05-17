#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#include <clientprefs>
#include <chat-processor>
#include <multicolors>

Handle g_hNameCookie;

char g_sNameTags[STORE_MAX_ITEMS][MAXLENGTH_NAME];
char g_sNameColors[STORE_MAX_ITEMS][32];
char g_sMessageColors[STORE_MAX_ITEMS][32];

//Custom Tags
char g_sNameTagsCustom[MAXPLAYERS+1][MAXLENGTH_NAME];
bool g_bInSettingCustomNameTags[MAXPLAYERS+1];
int g_iIsCustomNameTag[STORE_MAX_ITEMS];

int g_iNameTags = 0;
int g_iNameColors = 0;
int g_iMessageColors = 0;

public Plugin myinfo =
{
	name = "Store - Chat Processor item module with Scoreboard Tag",
	author = "nuclear silo, Mesharsky, AiDN™, HotoCocoa",
	description = "Chat Processor item module by nuclear silo, the Scoreboard Tag for Zephyrus's by Mesharksy, for nuclear silo's edited store by AiDN™",
	version = "1.1.1",
	url = "github.com/shanapu/MyStore"
};

public void OnPluginStart()
{

	Store_RegisterHandler("nametag", "tag", _, CPSupport_Reset, NameTags_Config, CPSupport_Equip, CPSupport_Remove, true);
	Store_RegisterHandler("namecolor", "color", _, CPSupport_Reset, NameColors_Config, CPSupport_Equip, CPSupport_Remove, true);
	Store_RegisterHandler("msgcolor", "color", _, CPSupport_Reset, MsgColors_Config, CPSupport_Equip, CPSupport_Remove, true);

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	RegConsoleCmd("sm_setnametag", Command_SetCustomNameTag, "设置自定义聊天前缀");
	RegConsoleCmd("sm_testmytag", Command_Testmytag, "Know my tag.");

	g_hNameCookie = RegClientCookie("customnametag_mycookie", "The cookie to store custom nametag.", CookieAccess_Public);
}

public void OnClientPutInServer(int client)
{
	g_bInSettingCustomNameTags[client] = false;
}

public void OnClientCookiesCached(int client)
{
	char sValue[MAXLENGTH_NAME];
	GetClientCookie(client, g_hNameCookie, sValue, sizeof(sValue));

	if (sValue[0])
	{
		FormatEx(g_sNameTagsCustom[client], sizeof(g_sNameTagsCustom[]), "%s{teamcolor} ", sValue);
	}
	else if (!sValue[0])
	{
		FormatEx(g_sNameTagsCustom[client], sizeof(g_sNameTagsCustom[]), "{chocolate}VIP");
	}
}

public Action Command_Testmytag(int client, int args)
{
	ReplyToCommand(client, "%s", g_sNameTagsCustom[client]);
	PrintToChat(client, "%s", g_sNameTagsCustom[client]);
}

public Action Command_SetCustomNameTag(int client, int args)
{
	g_bInSettingCustomNameTags[client] = true;
	ReplyToCommand(client, "请在聊天输入你的头衔，例如{orange}橘子超人 或{#000080}蓝色怪物，输入 default 则表示使用默认。");
}

public Action Command_Say(int client, const char[] command,int argc)
{
	if (!g_bInSettingCustomNameTags[client])
		return Plugin_Continue;

	char sMessage[MAXLENGTH_NAME];
	GetCmdArgString(sMessage, sizeof(sMessage));
	StripQuotes(sMessage);

	if (strcmp(sMessage, "default", true) == 0)	//输入了default
	{
		SetClientCookie(client, g_hNameCookie, "{chocolate}VIP");
		FormatEx(g_sNameTagsCustom[client], sizeof(g_sNameTagsCustom[]), "{chocolate}VIP");
		CPrintToChat(client, "{unique}[自定义]{default}自定义头衔已设置为默认。");
		g_bInSettingCustomNameTags[client] = false;
		return Plugin_Handled;
	}

	SetClientCookie(client, g_hNameCookie, sMessage);
	FormatEx(g_sNameTagsCustom[client], sizeof(g_sNameTagsCustom[]), "%s", sMessage);
	g_bInSettingCustomNameTags[client] = false;
	CPrintToChat(client, "{unique}[自定义]{default}自定义头衔已设置。在聊天区尝试吧！");
	return Plugin_Handled;
}

public void CPSupport_Reset()
{
	g_iNameTags = 0;
	g_iNameColors = 0;
	g_iMessageColors = 0;
}

public bool NameTags_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iNameTags);
	kv.GetString("tag", g_sNameTags[g_iNameTags], sizeof(g_sNameTags[]));
	g_iIsCustomNameTag[g_iNameTags] = kv.GetNum("custom", 0);
	g_iNameTags++;

	return true;
}

public bool NameColors_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iNameColors);
	kv.GetString("color", g_sNameColors[g_iNameColors], sizeof(g_sNameColors[]));
	g_iNameColors++;
	return true;
}

public bool MsgColors_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iMessageColors);
	kv.GetString("color", g_sMessageColors[g_iMessageColors], sizeof(g_sMessageColors[]));
	g_iMessageColors++;

	return true;
}


public int CPSupport_Equip(int client, int itemid)
{
	return -1;
}

public int CPSupport_Remove(int client, int itemid)
{
	return 0;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	int iEquippedNameTag = Store_GetEquippedItem(author, "nametag");
	int iEquippedNameColor = Store_GetEquippedItem(author, "namecolor");
	int iEquippedMsgColor = Store_GetEquippedItem(author, "msgcolor");

	if (iEquippedNameTag < 0 && iEquippedNameColor < 0 && iEquippedMsgColor < 0)
		return Plugin_Continue;

	char sName[MAXLENGTH_NAME*2];
	char sNameTag[MAXLENGTH_NAME];
	char sNameColor[32];

	if (iEquippedNameTag >= 0)
	{
		int iNameTag = Store_GetDataIndex(iEquippedNameTag);
		strcopy(sNameTag, sizeof(sNameTag), g_sNameTags[iNameTag]);
		if (g_iIsCustomNameTag[iNameTag] > 0)
		{
			FormatEx(sNameTag, sizeof(sNameTag), "%s{teamcolor} ", g_sNameTagsCustom[author]);
		}
	}

	if (iEquippedNameColor >= 0)
	{
		int iNameColor = Store_GetDataIndex(iEquippedNameColor);
		strcopy(sNameColor, sizeof(sNameColor), g_sNameColors[iNameColor]);
	}

	Format(sName, sizeof(sName), "%s%s%s", sNameTag, sNameColor, name);

	//CFormat(sName, sizeof(sName));
	ReplaceColors(sName, sizeof(sName));

	strcopy(name, MAXLENGTH_NAME, sName);

	if (iEquippedMsgColor >= 0)
	{
		char sMessage[MAXLENGTH_BUFFER];
		strcopy(sMessage, sizeof(sMessage), message);
		Format(message, MAXLENGTH_BUFFER, "%s%s", g_sMessageColors[Store_GetDataIndex(iEquippedMsgColor)], sMessage);
		ReplaceColors(message, MAXLENGTH_BUFFER);
		//CFormat(message, MAXLENGTH_BUFFER);
	}

	return Plugin_Changed;
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	if (IsClientReplay(client))return false;
	if (IsFakeClient(client))return false;
	if (IsClientSourceTV(client))return false;
	return IsClientInGame(client);
}
