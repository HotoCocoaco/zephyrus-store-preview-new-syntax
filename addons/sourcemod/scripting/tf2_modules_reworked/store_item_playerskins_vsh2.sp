#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <tf2_stocks>
#include <vsh2>

#include <store>
#include <zephstocks>
//#pragma newdecls required

enum struct PlayerSkin
{
	char szModel[PLATFORM_MAX_PATH];
	char szArms[PLATFORM_MAX_PATH];
	char szGunslinger[PLATFORM_MAX_PATH];
	int iSkin;
	int iBody;
	//bool:bTemporary,
	int iTeam;
	int nModelIndex;
	int iClass;
	int nArmModelIndex;
	int nGunslingerModelIndex;
}

PlayerSkin g_ePlayerSkins[STORE_MAX_ITEMS];

int g_iPlayerSkins = 0;

int g_cvarSkinDelay = -1;


Handle g_hTimerPreview[MAXPLAYERS + 1];

char m_szGameDir[32];

int g_bSkinEnable;

int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

char g_sChatPrefix[128];

bool g_bSdkStarted = false;
Handle g_hSdkEquipWearable;
int g_iPlayerBGroups[MAXPLAYERS+1];

#define BODYGROUP_SCOUT_HAT				(1 << 0)
#define BODYGROUP_SCOUT_HEADPHONES		(1 << 1)
#define BODYGROUP_SCOUT_SHOESSOCKS		(1 << 2)
#define BODYGROUP_SCOUT_DOGTAGS			(1 << 3)

#define BODYGROUP_SOLDIER_ROCKET		(1 << 0)
#define BODYGROUP_SOLDIER_HELMET		(1 << 1)
#define BODYGROUP_SOLDIER_MEDAL			(1 << 2)
#define BODYGROUP_SOLDIER_GRENADES		(1 << 3)

#define BODYGROUP_PYRO_HEAD				(1 << 0)
#define BODYGROUP_PYRO_GRENADES			(1 << 1)

#define BODYGROUP_DEMO_SMILE			(1 << 0)
#define BODYGROUP_DEMO_SHOES			(1 << 1)

#define BODYGROUP_HEAVY_HANDS			(1 << 0)

#define BODYGROUP_ENGINEER_HELMET		(1 << 0)
#define BODYGROUP_ENGINEER_ARM			(1 << 1)

#define BODYGROUP_MEDIC_BACKPACK		(1 << 0)

#define BODYGROUP_SNIPER_ARROWS			(1 << 0)
#define BODYGROUP_SNIPER_HAT			(1 << 1)
#define BODYGROUP_SNIPER_BULLETS		(1 << 2)

#define BODYGROUP_SPY_MASK				(1 << 0)

#define EF_BONEMERGE            (1 << 0)
#define EF_NOSHADOW             (1 << 4)
#define EF_BONEMERGE_FASTCULL   (1 << 7)
#define EF_PARENT_ANIMATES      (1 << 9)
#define BLUE_sign "models/player/items/all_class/blue_sign.mdl"
#define RED_sign "models/player/items/all_class/red_sign.mdl"

public Plugin myinfo =
{
	name = "Store - Player Skin Module (No ZR version)",
	author = "nuclear silo, HotoCocoa", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.0.2", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
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
	TF2_SdkStartup();
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void PlayerSkins_OnMapStart()
{
	for(int i=0;i<g_iPlayerSkins;++i)
	{
		g_ePlayerSkins[i].nModelIndex = PrecacheModel2(g_ePlayerSkins[i].szModel);
		//Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i].szModel);

		if (g_ePlayerSkins[i].szArms[0])
		{
			g_ePlayerSkins[i].nArmModelIndex = PrecacheModel2(g_ePlayerSkins[i].szArms);
			//Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i].szArms);
		}

		if (g_ePlayerSkins[i].szGunslinger[0])
		{
			g_ePlayerSkins[i].nGunslingerModelIndex = PrecacheModel2(g_ePlayerSkins[i].szGunslinger);
		}
	}

	PrecacheModel(BLUE_sign, true);
	PrecacheModel(RED_sign, true);
	AddFileToDownloadsTable(BLUE_sign);
	AddFileToDownloadsTable("models/player/items/all_class/blue_sign.dx80.vtx");
	AddFileToDownloadsTable("models/player/items/all_class/blue_sign.dx90.vtx");
	AddFileToDownloadsTable("models/player/items/all_class/blue_sign.sw.vtx");
	AddFileToDownloadsTable("models/player/items/all_class/blue_sign.vvd");
	AddFileToDownloadsTable(RED_sign);
	AddFileToDownloadsTable("models/player/items/all_class/red_sign.dx80.vtx");
	AddFileToDownloadsTable("models/player/items/all_class/red_sign.dx90.vtx");
	AddFileToDownloadsTable("models/player/items/all_class/red_sign.sw.vtx");
	AddFileToDownloadsTable("models/player/items/all_class/red_sign.vvd");
	AddFileToDownloadsTable("materials/models/player/items/all_class/BLACK.vmt");
	AddFileToDownloadsTable("materials/models/player/items/all_class/BLUE.vmt");
	AddFileToDownloadsTable("materials/models/player/items/all_class/RED.vmt");
}

public int PlayerSkins_Reset()
{
	g_iPlayerSkins = 0;
	return 0;
}

public bool PlayerSkins_Config(Handle &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iPlayerSkins);

	KvGetString(kv, "model", g_ePlayerSkins[g_iPlayerSkins].szModel, PLATFORM_MAX_PATH);

	g_ePlayerSkins[g_iPlayerSkins].iSkin = KvGetNum(kv, "skin");
	g_ePlayerSkins[g_iPlayerSkins].iTeam = KvGetNum(kv, "team");
	g_ePlayerSkins[g_iPlayerSkins].iClass = KvGetNum(kv, "class");

	KvGetString(kv, "arm", g_ePlayerSkins[g_iPlayerSkins].szArms, PLATFORM_MAX_PATH);
	KvGetString(kv, "gunslinger", g_ePlayerSkins[g_iPlayerSkins].szGunslinger, PLATFORM_MAX_PATH);


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

			if (g_ePlayerSkins[m_iData].szArms[0])
			{
				Store_SetClientArmModel(client, g_ePlayerSkins[m_iData]);
			}
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
		if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3) || client <= 0)
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

	if (VSH2Player(client).GetPropAny("bIsBoss"))	//检查是否为VSH2的Boss。
		return Plugin_Stop;

	if (VSH2Player(client).GetPropAny("bIsMinion"))	//检查是否为VSH2的Boss。
		return Plugin_Stop;

	if (VSH2Player(client).GetPropAny("bIsZombie"))	//检查是否为VSH2的Boss。
		return Plugin_Stop;

	//PrintToServer("Ready to set model!");

	int class = TF2_GetPlayerClassAsNumber(client)-1;
	int m_iEquipped = Store_GetEquippedItem(client, "playerskin", class);
	/*if(m_iEquipped < 0)
		m_iEquipped = Store_GetEquippedItem(client, "playerskin", GetClientTeam(client)-2);*/
	if(m_iEquipped >= 0)
	{
		int m_iData = Store_GetDataIndex(m_iEquipped);
		Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel);

		if (g_ePlayerSkins[m_iData].szArms[0])
		{
			Store_SetClientArmModel(client, g_ePlayerSkins[m_iData]);
		}
	}
	return Plugin_Stop;
}

void Store_SetClientModel(int client, const char[] model)
{
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModelWithClassAnimations");
	SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 0);
	SetEntProp(client, Prop_Send, "m_nBody", CalculateBodyGroups(client));
	if (TF2_GetClientTeam(client) == TFTeam_Red)
	{
		EquipWearable(client, RED_sign);
	}
	else if (TF2_GetClientTeam(client) == TFTeam_Blue)
	{
		EquipWearable(client, BLUE_sign);
	}
}

void Store_SetClientArmModel(int iClient, PlayerSkin skin)
{
	int maxweapons = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
	for(int i = 0; i < maxweapons; i++)
	{
		int weapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if (weapon != INVALID_ENT_REFERENCE)
		{
			char buffer[64], script[PLATFORM_MAX_PATH];
			GetEntityClassname(weapon, buffer, 64);
			if (!StrContains(buffer, "tf_weapon_invis") || !StrContains(buffer, "tf_weapon_pda_spy"))
			{
				continue;
			}

			if (!StrContains(buffer, "tf_weapon_robot_arm"))
			{
				if (skin.nGunslingerModelIndex)
				{
					Format(script, PLATFORM_MAX_PATH, "self.SetCustomViewModel(`%s`)", skin.szGunslinger);
					SetVariantString(script);
					AcceptEntityInput(weapon, "RunScriptCode");
					//SetEntProp(weapon, Prop_Send, "m_nCustomViewmodelModelIndex", skin.nGunslingerModelIndex);
				}
				
				continue;
			}

			Format(script, PLATFORM_MAX_PATH, "self.SetCustomViewModel(`%s`)", skin.szArms);
			SetVariantString(script);
			AcceptEntityInput(weapon, "RunScriptCode");
			//SetEntProp(weapon, Prop_Send, "m_nCustomViewmodelModelIndex", skin.nArmModelIndex);
		}
			
	}
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

stock EquipWearable(client, char[] Mdl)
{ // ^ bad name probably
	int wearable = CreateWearable(client, Mdl);
	if (wearable == -1)
		return -1;
	return wearable;
}

stock CreateWearable(client, String:model[]) // Randomizer code :3
{
	int ent = CreateEntityByName("tf_wearable");
	if (!IsValidEntity(ent)) return -1;
	SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel(model));
	SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_PARENT_ANIMATES);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
	SetEntProp(ent, Prop_Send, "m_bValidatedAttachedEntity", 1);
	DispatchSpawn(ent);
	SetVariantString("!activator");
	ActivateEntity(ent);
	TF2_EquipWearable(client, ent); // urg
	return ent;
}

// *sigh*
stock TF2_EquipWearable(int client,int Ent)
{
	if (g_bSdkStarted == false || g_hSdkEquipWearable == INVALID_HANDLE)
	{
		TF2_SdkStartup();
		LogMessage("Error: Can't call EquipWearable, SDK functions not loaded! If it continues to fail, reload plugin or restart server. Make sure your gamedata is intact!");
	}
	else
	{
		SDKCall(g_hSdkEquipWearable, client, Ent);
	}
}
stock bool TF2_SdkStartup()
{
	Handle hGameConf = LoadGameConfigFile("tf2.utils.nosoop");
	if (hGameConf == INVALID_HANDLE)
	{
		LogMessage("Couldn't load SDK functions (GiveWeapon). Make sure tf2.utils.nosoop.txt is in your gamedata folder! Restart server if you want wearable weapons.");
		return false;
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable()");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSdkEquipWearable = EndPrepSDKCall();

	CloseHandle(hGameConf);
	g_bSdkStarted = true;
	return true;
}

CalculateBodyGroups(client)
{
	int iBodyGroups = g_iPlayerBGroups[client];
//	new iItemGroups = 0;

	TFClassType class = TF2_GetPlayerClass(client);
	switch(class)
	{
		case TFClass_Scout:
		{
			iBodyGroups |= BODYGROUP_SCOUT_HAT;
			iBodyGroups |= BODYGROUP_SCOUT_HEADPHONES;
			iBodyGroups |= BODYGROUP_SCOUT_SHOESSOCKS;
			iBodyGroups |= BODYGROUP_SCOUT_DOGTAGS;
		}
		case TFClass_Soldier:
		{
			iBodyGroups |= BODYGROUP_SOLDIER_ROCKET;
			iBodyGroups |= BODYGROUP_SOLDIER_HELMET;
			iBodyGroups |= BODYGROUP_SOLDIER_GRENADES;
		}
		case TFClass_Pyro:
		{
			iBodyGroups |= BODYGROUP_PYRO_HEAD;
			iBodyGroups |= BODYGROUP_PYRO_GRENADES;
		}
		case TFClass_DemoMan:
		{
			iBodyGroups |= BODYGROUP_DEMO_SMILE;
			iBodyGroups |= BODYGROUP_DEMO_SHOES;
		}
		case TFClass_Heavy:
		{
			iBodyGroups = BODYGROUP_HEAVY_HANDS;
		}
		case TFClass_Engineer:
		{
			iBodyGroups |= BODYGROUP_ENGINEER_HELMET;
			iBodyGroups |= BODYGROUP_ENGINEER_ARM;
		}
		case TFClass_Medic:
		{
			iBodyGroups |= BODYGROUP_MEDIC_BACKPACK;
		}
		case TFClass_Sniper:
		{
			iBodyGroups |= BODYGROUP_SNIPER_ARROWS;
			iBodyGroups |= BODYGROUP_SNIPER_HAT;
			iBodyGroups |= BODYGROUP_SNIPER_BULLETS;
		}
		case TFClass_Spy:
		{
			iBodyGroups |= BODYGROUP_SPY_MASK;
		}
	}

	return iBodyGroups;
}