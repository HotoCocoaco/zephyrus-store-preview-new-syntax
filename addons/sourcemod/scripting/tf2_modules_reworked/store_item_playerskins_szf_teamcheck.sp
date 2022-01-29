#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <tf2>
#include <tf2_stocks>
#include <saxtonhale>

#include <store>
#include <zephstocks>
//#pragma newdecls required

enum struct PlayerSkin
{
	char szModel[PLATFORM_MAX_PATH];
	//char szArms[PLATFORM_MAX_PATH];
	int iSkin;
	int iBody;
	//bool:bTemporary,
	int iTeam;
	int nModelIndex;
	int iClass;
}

PlayerSkin g_ePlayerSkins[STORE_MAX_ITEMS];

int g_iPlayerSkins = 0;

int g_cvarSkinDelay = -1;


Handle g_hTimerPreview[MAXPLAYERS + 1];

char m_szGameDir[32];

int g_bSkinEnable;

int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

char g_sChatPrefix[128];

public Plugin myinfo =
{
	name = "Store - Player Skin Module (No ZR version)",
	author = "nuclear silo, HotoCocoa", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.0.1", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
}

public void OnPluginStart()
{
	LoadTranslations("store.phrases");

	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));

	if(!StrEqual(m_szGameDir, "tf"))
	{
		SetFailState("[SM]This module is for TF2 only.");
		return;
	}

	Store_RegisterHandler("playerskin", "model", PlayerSkins_OnMapStart, PlayerSkins_Reset, PlayerSkins_Config, PlayerSkins_Equip, PlayerSkins_Remove, true);

	g_cvarSkinDelay = RegisterConVar("sm_store_playerskin_delay", "2", "Delay after spawn before applying the skin. -1 means no delay", TYPE_FLOAT);
	g_bSkinEnable = RegisterConVar("sm_store_playerskin_enable", "1", "Enable the player skin module", TYPE_INT);


	HookEvent("player_spawn", PlayerSkins_PlayerSpawn);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void PlayerSkins_OnMapStart()
{
	for(int i=0;i<g_iPlayerSkins;++i)
	{
		g_ePlayerSkins[i].nModelIndex = PrecacheModel2(g_ePlayerSkins[i].szModel, true);
		Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i].szModel);
	}
}

public int PlayerSkins_Reset()
{
	g_iPlayerSkins = 0;
}

public bool PlayerSkins_Config(Handle &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iPlayerSkins);

	KvGetString(kv, "model", g_ePlayerSkins[g_iPlayerSkins].szModel, PLATFORM_MAX_PATH);

	g_ePlayerSkins[g_iPlayerSkins].iSkin = KvGetNum(kv, "skin");
	g_ePlayerSkins[g_iPlayerSkins].iTeam = KvGetNum(kv, "team");
	g_ePlayerSkins[g_iPlayerSkins].iClass = KvGetNum(kv, "class");


	if(FileExists(g_ePlayerSkins[g_iPlayerSkins].szModel, true))
	{
		++g_iPlayerSkins;
		return true;
	}

	return false;
}

public int PlayerSkins_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	//int iIndex =  Store_GetDataIndex(id);
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
		if(IsPlayerAlive(client) && IsValidClient(client, true) && GetClientTeam(client)==g_ePlayerSkins[m_iData].iTeam && TF2_GetPlayerClassAsNumber(client)==g_ePlayerSkins[m_iData].iClass)
		{
			Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel);
		}

		else if(Store_IsClientLoaded(client))
			CPrintToChat(client, " %s%t", g_sChatPrefix , "PlayerSkins Settings Changed");
	}
	else CPrintToChat(client, "%sStore Player Skin module is currently temporary disabled", g_sChatPrefix);

	return (g_ePlayerSkins[Store_GetDataIndex(id)].iClass)-1;
}

public int PlayerSkins_Remove(int client,int id)
{
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{

		if (Store_IsClientLoaded(client) && IsValidClient(client, true) && IsClientInGame(client))
		{

		}
		else CPrintToChat(client, " %s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
	}
	else CPrintToChat(client, "%sStore Player Skin module is currently temporary disabled", g_sChatPrefix);

	return view_as<int>(g_ePlayerSkins[Store_GetDataIndex(id)].iClass)-1;
}

public Action PlayerSkins_PlayerSpawn(Event event,const char[] name,bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
		if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
			return Plugin_Continue;

		float Delay = view_as<float>(g_eCvars[g_cvarSkinDelay].aCache);

		CreateTimer(Delay, PlayerSkins_PlayerSpawnPost, GetClientUserId(client));
	}
	else CPrintToChat(client, "%sStore Player Skin module is currently temporary disabled", g_sChatPrefix);

	return Plugin_Continue;
}

public Action PlayerSkins_PlayerSpawnPost(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	//int iIndex =  Store_GetDataIndex(id);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (IsValidClient(client, true) && !IsPlayerAlive(client))
		return Plugin_Stop;

	if (TF2_GetClientTeam(client) != TFTeam_Red)	//检查是否为红队
		return Plugin_Stop;

	int class = TF2_GetPlayerClassAsNumber(client)-1;
	int m_iEquipped = Store_GetEquippedItem(client, "playerskin", class);
	/*if(m_iEquipped < 0)
		m_iEquipped = Store_GetEquippedItem(client, "playerskin", GetClientTeam(client)-2);*/
	if(m_iEquipped >= 0)
	{
		int m_iData = Store_GetDataIndex(m_iEquipped);
		Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel);
	}
	return Plugin_Stop;
}

void Store_SetClientModel(int client, const char[] model)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 0);
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	//SetEntProp(client, Prop_Send, "m_nBody", CalculateBodyGroups(client));
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (!StrEqual(type, "playerskin"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_physics_multiplayer

	if (g_hTimerPreview[client] != null)
	{
        delete g_hTimerPreview[client];
        g_hTimerPreview[client] = null;
	}

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_ePlayerSkins[index].szModel);

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	if (g_ePlayerSkins[index].iBody > 0)
	{
		SetEntProp(iPreview, Prop_Send, "m_nBody", g_ePlayerSkins[index].iBody);
	}


	float fOrigin[3], fAngles[3], fRad[2], fPosition[3];

	GetClientAbsOrigin(client, fOrigin);
	GetClientAbsAngles(client, fAngles);

	fRad[0] = DegToRad(fAngles[0]);
	fRad[1] = DegToRad(fAngles[1]);

	fPosition[0] = fOrigin[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPosition[1] = fOrigin[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPosition[2] = fOrigin[2] + 4 * Sine(fRad[0]);

	fAngles[0] *= -1.0;
	fAngles[1] *= -1.0;

	fPosition[2] += 5;

	TeleportEntity(iPreview, fPosition, fAngles, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPosition);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(45.0, Timer_KillPreview, client);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview", client);
}

public Action Hook_SetTransmit_Preview(int ent, int client)
{
	if (g_iPreviewEntity[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iPreviewEntity[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_KillPreview(Handle timer, int client)
{
	g_hTimerPreview[client] = null;

	if (g_iPreviewEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntity[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}

stock bool IsValidClient(int client, bool nobots = true)
{
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
    {
        return false;
    }
    return IsClientInGame(client);
}

stock int TF2_GetPlayerClassAsNumber(int client)
{
	int Num;
	TFClassType class = TF2_GetPlayerClass(client);
	switch(class)
	{
		case TFClass_Scout:
		{
			Num=1;
		}
		case TFClass_Soldier:
		{
			Num=2;
		}
		case TFClass_Pyro:
		{
			Num=3;
		}
		case TFClass_DemoMan:
		{
			Num=4;
		}
		case TFClass_Heavy:
		{
			Num=5;
		}
		case TFClass_Engineer:
		{
			Num=6;
		}
		case TFClass_Medic:
		{
			Num=7;
		}
		case TFClass_Sniper:
		{
			Num=8;
		}
		case TFClass_Spy:
		{
			Num=9;
		}
	}
	return Num;
}
