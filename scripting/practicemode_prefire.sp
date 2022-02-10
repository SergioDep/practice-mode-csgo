#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <cstrike>


#define PLUGIN_VERSION "1.0"
#define MAX_MAP_SPAWNPOINTS 160
#define MAX_SPAWN_NAME 40
#define MAX__BOTS_PER_ZONE 12
#define MAX_POINT_NAME 128
#define MAX_PREFIRE_PLAYERS 2
#define STARTING_BOT_HP 100

#define NUM_EQUIPO "UNO"

#pragma semicolon 1
#pragma newdecls required

////////////////keyvalues
KeyValues g_SpawnPointsKv;
char KvFileName[PLATFORM_MAX_PATH];
bool g_UpdatedSpawnsKv = false;
char ClientIdstr[MAXPLAYERS + 1][MAX_POINT_NAME];
char g_SpawnName[MAX_MAP_SPAWNPOINTS][MAX_SPAWN_NAME];

////////////////prefire
bool g_PFBotInit = false;
bool g_InBotPrefireMode = false;
bool IsClientSelected[MAXPLAYERS+1] = false;

int g_PlayerStartingHealth = 200;
int g_PFBotClientFrom[MAX__BOTS_PER_ZONE + 1];
int g_SelectedClientsNumber = 0;
int g_DeathPlayers = 0;

int g_ClientFromSpawn1 = -1;
int g_ClientFromSpawn2 = -1;

char g_CurrentPFZoneName[MAX_SPAWN_NAME];

float g_PlayerSpawnOrigin[MAXPLAYERS + 1][3];
float g_PlayerSpawnAngles[MAXPLAYERS + 1][3];

float g_PFBotOrigin[MAX__BOTS_PER_ZONE][3];
float g_PFBotAngles[MAX__BOTS_PER_ZONE][3];

////////////////timer
bool g_RunningTimeCommand = false;
bool g_RunningTimeZoneCommand = false;
Handle HTMTimer;
float g_LastTimeCommand;
float g_LastZoneTimeCommand;

////////////////edit
int g_TotalSpawns = 0;
int g_CurrentPrefireZone = 1;
int g_BotDifficultyInt = 0;
int g_currentPointID[MAXPLAYERS + 1];

char g_CurrentZoneName[MAXPLAYERS + 1][MAX_POINT_NAME];

bool g_WaitingForNameZone[MAXPLAYERS + 1] = false;
bool g_PointIsSelected[MAXPLAYERS + 1] = false;

ArrayList g_PointZoneData[MAXPLAYERS + 1];

public Plugin myinfo = {
    name        = "Prefire Mode",
    author      = "Sergio",
    description = "",
    version     = "PLUGIN_VERSION",
    url         = "1.1.0"
};
//todo

//botmimic speed, x3 x5 x10, backwards(possible?)

//solucion al problema de attack fakeclient, memory hack, workaround:
//% probabilidades de que una bala spawnee y le de a la cabeza de un jugador(generar fake info de kill?, attach bala a bot para dar output de kill)
// o milagrosamente hacerlos atacar con runcmd

public void OnPluginStart()
{
    RegConsoleCmd("sm_pointmenu", CMD_PointMenu);
    RegConsoleCmd("sm_prefire", CMD_LaunchPrefireMode);
    RegConsoleCmd("sm_exitprefire", CMD_ExitPrefireMode);
    
    AddCommandListener(ChatListener, "say");
    AddCommandListener(ChatListener, "say2");
    AddCommandListener(ChatListener, "say_team");
    AddCommandListener(ChangeTeam, "jointeam");
    
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
    HookUserMessage(GetUserMessageId("SayText2"), Hook_SayText2, true);
    HTMTimer = CreateHudSynchronizer();
}

public void OnMapStart() {
    EnforceDirectoryExists("data/prefiremode");
    EnforceDirectoryExists("data/prefiremode/spawnpoints");
    
    
    char mapName[PLATFORM_MAX_PATH];
    GetCleanMapName(mapName, sizeof(mapName));
    
    BuildPath(Path_SM, KvFileName, sizeof(KvFileName), "data/prefiremode/spawnpoints/%s.cfg", mapName);
    delete g_SpawnPointsKv;
    g_SpawnPointsKv = new KeyValues("Points");
    g_SpawnPointsKv.ImportFromFile(KvFileName);
    DeleteFile(KvFileName);
    
    for (int i = 0; i <= MaxClients; i++) {
        delete g_PointZoneData[i];
        g_PointZoneData[i] = new ArrayList(7);
        if(i != 0) IsClientSelected[i]=false;
    }
    g_UpdatedSpawnsKv=true;
    MaybeWriteNewData();
    
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed) {
    if (!g_InBotPrefireMode) {
        return Plugin_Continue;
    }
    
    if(!IsPlayerAlive(client)){
        return Plugin_Continue;
    }
    
    if(IsPrefireBot(client)) {
        if(buttons & IN_JUMP) {
            buttons &= ~IN_JUMP;
            return Plugin_Changed;
        }
        if(buttons & IN_DUCK) {
            buttons &= ~IN_DUCK;
            return Plugin_Changed;
        }
        
        int ActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
        if (!IsValidEdict(ActiveWeapon) || ActiveWeapon == -1) {
            return Plugin_Continue;
        }
        
        int target = GetClosestClient(client);
        int ClipAmmo = GetEntProp(ActiveWeapon, Prop_Send, "m_iClip1");
        
        if (ClipAmmo > 0 && target > 0) {
            LookAtClient(client, target);
        }
        
        seed = 0;
        return Plugin_Changed;
    }
    return Plugin_Continue;
} 


stock void LookAtClient(int client, int target) {
    float TargetPos[3], TargetAngles[3], ClientPos[3], FinalPos[3];
    GetClientEyePosition(client, ClientPos);
    GetClientEyePosition(target, TargetPos);
    GetClientEyeAngles(target, TargetAngles);
    
    float VecFinal[3];
    AddInFrontOf(TargetPos, TargetAngles, 7.0, VecFinal);
    MakeVectorFromPoints(ClientPos, VecFinal, FinalPos);
    
    GetVectorAngles(FinalPos, FinalPos);

    TeleportEntity(client, NULL_VECTOR, FinalPos, NULL_VECTOR);
}

stock void AddInFrontOf(float VecOrigin[3], float VecAngle[3], float Units, float OutPut[3]) {
    float VecView[3];
    GetViewVector(VecAngle, VecView);
    
    OutPut[0] = VecView[0] * Units + VecOrigin[0];
    OutPut[1] = VecView[1] * Units + VecOrigin[1];
    OutPut[2] = VecView[2] * Units + VecOrigin[2];
}

stock void GetViewVector(float VecAngle[3], float OutPut[3]) {
    OutPut[0] = Cosine(VecAngle[1] / (180 / FLOAT_PI));
    OutPut[1] = Sine(VecAngle[1] / (180 / FLOAT_PI));
    OutPut[2] = -Sine(VecAngle[0] / (180 / FLOAT_PI));
}


stock int GetClosestClient(int client) {
    float ClientOrigin[3], TargetOrigin[3];
    
    GetClientAbsOrigin(client, ClientOrigin);
    
    int clientTeam = GetClientTeam(client);
    int ClosestTarget = -1;
    
    float ClosestDistance = -1.0;
    float TargetDistance;
    
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i)) {
            if (client == i || GetClientTeam(i) == clientTeam || !IsPlayerAlive(i)) {
                continue;
            }
            GetClientAbsOrigin(i, TargetOrigin);
            TargetDistance = GetVectorDistance(ClientOrigin, TargetOrigin);

            if (TargetDistance > ClosestDistance && ClosestDistance > -1.0) {
                continue;
            }
            if (!ClientCanSeeTarget(client, i)) {
                continue;
            }
            if (GetEntPropFloat(i, Prop_Send, "m_fImmuneToGunGameDamageTime") > 0.0) {
                continue;
            }			
            ClosestDistance = TargetDistance;
            ClosestTarget = i;
        }
    }
    return ClosestTarget;
}

stock bool ClientCanSeeTarget(int client, int target) {
    float ClientPosition[3], TargetPosition[3];
    
    GetEntPropVector(client, Prop_Send, "m_vecOrigin", ClientPosition);
    ClientPosition[2] += 50.0;
    
    GetClientEyePosition(target, TargetPosition);
    
    Handle hTrace = TR_TraceRayFilterEx(ClientPosition, TargetPosition, MASK_SOLID_BRUSHONLY, RayType_EndPoint, Base_TraceFilter);
    
    if (TR_DidHit(hTrace)) {
        delete hTrace;
        return false;
    }
    
    delete hTrace;
    return true;
}

////////////////events{

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    if (!g_InBotPrefireMode) {
        return Plugin_Continue;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));

    if(IsPrefireBot(client)) {
        FreezePF(client);
        GetBotDataFromKv(client);
        TeleportEntity(client, g_PFBotOrigin[GetPrefireBotNumber(client) + 1], g_PFBotAngles[GetPrefireBotNumber(client) + 1], NULL_VECTOR);
    }

    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    if (!g_InBotPrefireMode) {
        return Plugin_Continue;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));

    if(IsPrefireBot(client)) {
        int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
        CreateTimer(0.5, Timer_RemoveRagdoll, EntIndexToEntRef(ragdoll), TIMER_FLAG_NO_MAPCHANGE);
        
        if (GetAliveTeamCount(CS_TEAM_CT) == 0){
            g_CurrentPrefireZone++;
            if (g_CurrentPrefireZone > MaxZonesCurrentMap()) {
                ExitPrefire();
                PrintToChatAll(" \x05[Prefire] \x01Arena \x0E%s \x01Time: \x04%.1f\x01s", g_CurrentPFZoneName, StopZoneTimer());
                PrintToChatAll(" \x05[Prefire] \x0E-----------------------");
                PrintToChatAll(" \x05[Prefire] \x01Course Time: \x04%.1f\x01s", StopClientTimer());
                PrintToChatAll(" \x05[Prefire] \x0E-----------------------");
            } else {
                PrintToChatAll(" \x05[Prefire] \x01Arena \x0E%s \x01Time: \x04%.1f\x01s", g_CurrentPFZoneName, StopZoneTimer());
                ServerCommand("bot_kick");
                InitPrefireFunctions();
            }
        }
    }
    if(IsClientSelected[client]) {
        if(g_ClientFromSpawn2 == -1){
            CreateTimer(1.0, Timer_RespawnBot, GetClientSerial(client));
            ServerCommand("bot_kick");
            InitPrefireFunctions();
        }
        else {
            g_DeathPlayers++;
            if(g_DeathPlayers == MAX_PREFIRE_PLAYERS) {
                ServerCommand("bot_kick");
                CreateTimer(1.0, Timer_RespawnBot, GetClientSerial(g_ClientFromSpawn1));
                CreateTimer(1.0, Timer_RespawnBot, GetClientSerial(g_ClientFromSpawn2));
                InitPrefireFunctions();
            }
        }
    }

    return Plugin_Continue;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    SetEventBroadcast(event, true);
    return Plugin_Continue;
}

public Action Hook_SayText2(UserMsg msg_id, any msg, const int[] players, int playersNum, bool reliable, bool init)
{
    char[] sMessage = new char[24];
    if(GetUserMessageType() == UM_Protobuf) {
        Protobuf pbmsg = msg;
        pbmsg.ReadString("msg_name", sMessage, 24);
    } else {
        BfRead bfmsg = msg;
        bfmsg.ReadByte();
        bfmsg.ReadByte();
        bfmsg.ReadString(sMessage, 24, false);
    }
    if(StrEqual(sMessage, "#Cstrike_Name_Change")) {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

////////////////events}

////////////////CMD{

public Action CMD_PointMenu(int client, int args) {
    SaveClientAuth(client);
    GiveZonesMenu(client);
    return Plugin_Handled;
}

public Action CMD_LaunchPrefireMode(int client, int args) {
    g_CurrentPrefireZone = 1;
    GivePrefireMenu(client);
    return Plugin_Handled;
}

stock void GivePrefireMenu(int client, int pos = 0){
    Menu menu = new Menu(PrefireMenuHandler);
    menu.SetTitle("Prefire Options");
    char BotDiff[MAX_SPAWN_NAME], StartingZone[MAX_SPAWN_NAME], StartingHP[MAX_SPAWN_NAME];
    Format(BotDiff, MAX_SPAWN_NAME, "Bot Difficulty : %d", g_BotDifficultyInt + 1);
    Format(StartingZone, MAX_SPAWN_NAME, "Starting Zone : %d", g_CurrentPrefireZone);
    Format(StartingHP, MAX_SPAWN_NAME, "Initial HP : %d", g_PlayerStartingHealth);
    if(IsClientSelected[client])
        menu.AddItem("readymode", "You Are Ready");
    else 
        menu.AddItem("readymode", "You Are Unready");
    menu.AddItem("bot_diff", BotDiff);
    menu.AddItem("startingzone", StartingZone);
    menu.AddItem("sethealth", StartingHP);
    menu.AddItem("startprefire", "Start Prefire Mode");

    menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public int PrefireMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[MAX_POINT_NAME + 1];
        menu.GetItem(param2, buffer, sizeof(buffer));
        if(g_PFBotInit || g_InBotPrefireMode) {
            PrintToChat(client, "Wait For Match To End");
            return 0;
        }
        if (StrContains(buffer, "bot_diff") == 0) {
            g_BotDifficultyInt++;
            if(g_BotDifficultyInt > 3) {
                g_BotDifficultyInt = 0;
            }
            SetPrefireDifficulty(client, g_BotDifficultyInt);
            GivePrefireMenu(client);
        } else if (StrContains(buffer, "sethealth") == 0) {
            g_PlayerStartingHealth += 50;
            if(g_PlayerStartingHealth > 200) {
                g_PlayerStartingHealth = 100;
            }
            GivePrefireMenu(client);
        } else if (StrContains(buffer, "readymode") == 0) {
            TogglePrefireSelected(client);
            GivePrefireMenu(client);
        } else if (StrContains(buffer, "startingzone") == 0) {
            g_CurrentPrefireZone++;
            if (g_CurrentPrefireZone > MaxZonesCurrentMap()) {
                g_CurrentPrefireZone = 1;
            }
            MaxBotsCurrentZone();
            GivePrefireMenu(client);
            PrintToChat(client, " \x05[Prefire] \x01Selected Zone: %s", g_CurrentPFZoneName);
        } else if (StrContains(buffer, "startprefire") == 0) {
            ServerCommand("mp_respawn_on_death_ct 0");
            ServerCommand("mp_respawn_on_death_t 0");
            ServerCommand("mp_buy_anywhere 1");
            ServerCommand("mp_buytime 99999");
            ServerCommand("sv_showimpacts 0");
            ServerCommand("sm_allow_noclip 0");
            InitPrefireFunctions();
            Start_PFTimer();
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

public void SetPrefireDifficulty(int client, int difficulty) {
    if(difficulty == 0) {
        PrintToChatAll(" \x05[Prefire] \x01Difficulty set to: \x04SILVER");
        ServerCommand("bot_difficulty 0");
        ServerCommand("mp_damage_headshot_only 0");
    } else if(difficulty == 1) {
        PrintToChatAll(" \x05[Prefire] \x01Difficulty set to: \x04GOLD NOVA");
        ServerCommand("bot_difficulty 1");
        ServerCommand("mp_damage_headshot_only 0");
    } else if(difficulty == 2) {
        PrintToChatAll(" \x05[Prefire] \x01Difficulty set to: \x04LEGENDARY EAGLE");
        ServerCommand("bot_difficulty 2"); //todo usar porcentaje de disparo
    } else if(difficulty == 3) {
        PrintToChatAll(" \x05[Prefire] \x01Difficulty set to: \x04GLOBAL ELITE");
        ServerCommand("bot_difficulty 3"); //todo y tambien cada cuanto dispara
        //PONER ARMA MP9
    }
}

public Action CMD_ExitPrefireMode(int client, int args) {
    if(!g_InBotPrefireMode) {
        return Plugin_Handled;
    }
    g_RunningTimeCommand = false;
    g_RunningTimeZoneCommand = false;
    ExitPrefire();
    PrintToChatAll(" \x05[Prefire] \x01 Exited prefire mode.");
    return Plugin_Handled;
}

public void TogglePrefireSelected(int client) {
    if(g_PFBotInit || g_InBotPrefireMode) {
        PrintToChat(client, "Wait For Match To End");
        return;
    }
    if(IsClientSelected[client]) {
        PrintToChatAll(" \x05[Prefire] \x01User %N is Unready!", client);
        g_SelectedClientsNumber-=1;
        IsClientSelected[client] = false;
        return;
    }
    if(GetClientTeam(client) == 1) {
        return;
    }
    g_SelectedClientsNumber++;
    if(g_SelectedClientsNumber == 1) {
        IsClientSelected[client] = true;
        PrintToChat(client, " \x05[Prefire] \x01You Are Ready");
        PrintToChatAll(" \x05[Prefire] \x01User %N is Ready!", client);
        g_ClientFromSpawn1 = client;
        return;
    }
    else if (g_SelectedClientsNumber == 2) {
        IsClientSelected[client] = true;
        g_ClientFromSpawn2 = client;
        PrintToChat(client, " \x05[Prefire] \x01You Are Ready");
        PrintToChatAll(" \x05[Prefire] \x012 Players are Ready.");
        return;
    }
    else if(g_SelectedClientsNumber > 2) {
        PrintToChat(client, " \x05[Prefire] \x01Only 2 players are allowed.");
        return;
    }
}

public Action ChatListener(int client, const char[] command, int args) {
    char msg[MAX_POINT_NAME];
    GetCmdArgString(msg, sizeof(msg));
    StripQuotes(msg);
    TrimString(msg);
    if (StrEqual(msg, "") || StrEqual(msg, " ")) {
        return Plugin_Continue;
    }
    if (g_WaitingForNameZone[client] && IsValidClient(client) && !IsChatTrigger()) {
        CleanNameTag(msg, sizeof(msg));
        g_WaitingForNameZone[client] = false;
        if (StrContains(msg, "cancel") || StrContains(msg, ".cancel")) {
            PrintToChat(client, "Action Canceled");
            return Plugin_Handled;
        } else {
            SaveClientAuth(client);
            strcopy(g_CurrentZoneName[client], MAX_POINT_NAME, msg);
            SavePointWithName(client, "spawn1");
            PrintToChat(client, " \x05[Prefire] \x01 Player Spawn 1 from %s Added!", msg);
        }
        return Plugin_Continue;
    } else if (g_PointIsSelected[client] && IsValidClient(client) && !IsChatTrigger()) {
        CleanNameTag(msg, sizeof(msg));
        g_PointIsSelected[client] = false;
        if (StrEqual(msg, "!updatepoint")) {
            UpdatePoint(client);
            PrintToChat(client, " \x05[Prefire] \x01 Point \x04%d \x01Position Updated!", g_currentPointID[client]);
        }
        else {
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

////////////////CMD}

public void ExitPrefire() {
    for (int i = 1; i <= MaxClients; i++)
        IsClientSelected[i]=false;
    g_ClientFromSpawn1 = -1;
    g_ClientFromSpawn2 = -1;
    ServerCommand("bot_kick");
    g_PFBotInit = false;
    g_InBotPrefireMode = false;
    g_PlayerStartingHealth = 200;
    g_SelectedClientsNumber = 0;
    ServerCommand("mp_respawn_on_death_ct 1");
    ServerCommand("mp_respawn_on_death_t 1");
    ServerCommand("mp_damage_headshot_only 0");
    ServerCommand("sv_showimpacts 1");
    ServerCommand("sm_allow_noclip 1");
}

public void InitPrefireFunctions() {
    if(GetPlayersReady() == -1) {
        PrintToChatAll(" \x05[Prefire] \x01 No Clients Ready.");
        return;
    }
    for (int i = 0; i < MaxBotsCurrentZone(); i++) {
        g_PFBotClientFrom[i] = -1; //valor inicial
    }
    g_InBotPrefireMode = true;
    g_PFBotInit = true;
    GetPFBots();
    Start_TimerPerZone();
    if(g_CurrentPrefireZone > 0) {
        PrintToChatAll(" \x05[Prefire] \x01Arena \x04%s", g_CurrentPFZoneName);
    }
}

public int GetPlayersReady() {
    if (g_SelectedClientsNumber == 0){
        g_ClientFromSpawn1 = -1;
        return -1;
    }
    GetPlayerSpawnsFromKv(g_ClientFromSpawn1);    
    if(g_SelectedClientsNumber == 1) {
        TeleportPrefirePlayers();
        return 1;
    } else if(g_SelectedClientsNumber >= 2) {
        if(g_ClientFromSpawn2 == -1) return -1;
        GetPlayerSpawnsFromKv(g_ClientFromSpawn2);
        TeleportPrefirePlayers();
        if(g_SelectedClientsNumber == 2) return 1;
        for(int i = 1;i<=MaxClients;i++) {
            if(IsValidClient(i) && !IsClientSelected[i]) {
                CS_SwitchTeam(i, CS_TEAM_SPECTATOR);
            }
        }
    }
    return 1;
}

public Action TeleportPrefirePlayers() {
    CreateTimer(1.0, Timer_Teleport);
    return Plugin_Handled;
}

public Action Timer_Teleport(Handle timer) {
    TeleportEntity(g_ClientFromSpawn1, g_PlayerSpawnOrigin[g_ClientFromSpawn1], g_PlayerSpawnAngles[g_ClientFromSpawn1], NULL_VECTOR);
    FreezePF(g_ClientFromSpawn1, true);
    if (g_ClientFromSpawn2 != -1) {
        TeleportEntity(g_ClientFromSpawn2, g_PlayerSpawnOrigin[g_ClientFromSpawn2], g_PlayerSpawnAngles[g_ClientFromSpawn2], NULL_VECTOR);
        FreezePF(g_ClientFromSpawn2, true);
    }
    CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Handled;
}

stock void GetPFBots() {
    ServerCommand("bot_quota_mode normal");
    for (int i = 0; i < MaxBotsCurrentZone(); i++) {
        if (!IsPrefireBot(i)) {
            ServerCommand("bot_add");
        }
    }

    CreateTimer(0.1, Timer_GetPrefireBots);
}

public Action Timer_GetPrefireBots(Handle timer) {
    g_PFBotInit = true;

    for (int i = 0; i < MaxBotsCurrentZone(); i++) {
        char name[MAX_NAME_LENGTH];
        Format(name, sizeof(name), "[PREFIRE] %s %d", g_CurrentPFZoneName, i + 1);
        if (!IsPrefireBot(g_PFBotClientFrom[i])) {
            g_PFBotClientFrom[i] = GetLiveBot(name);
        }
    }
    return Plugin_Handled;
}

public int GetLiveBot(const char[] name) {
    int largestUserid = GetLargestBotUserId();
    if (largestUserid == -1) {
        return -1;
    }

    int bot = GetClientOfUserId(largestUserid);
    if (!PM_IsValidClient(bot)) {
        return -1;
    }
    SetClientName(bot, name);
    CS_SwitchTeam(bot, CS_TEAM_CT);
    DestroyPFBot(bot);
    return bot;
}

public void DestroyPFBot(int client) {
    //float botOrigin[3] = {-7000.0, 0.0, 0.0};
    //teleport?
    ForcePlayerSuicide(client);
    CreateTimer(2.0, Timer_RespawnBot, GetClientSerial(client));
}

public Action Timer_RespawnBot(Handle timer, int serial){
    int client = GetClientFromSerial(serial);
    CS_RespawnPlayer(client);
}

public int GetLargestBotUserId() {
  int largestUserid = -1;
  for (int i = 1; i <= MaxClients; i++) {
    if (PM_IsValidClient(i) && IsFakeClient(i) && !IsClientSourceTV(i)) {
      int userid = GetClientUserId(i);
      if (userid > largestUserid && !IsPrefireBot(i)) {
        largestUserid = userid;
      }
    }
  }
  return largestUserid;
}

public bool IsPrefireBot(int client) {
  return GetPrefireBotNumber(client) >= 0;
}

public int GetPrefireBotNumber(int client) {
  if (!IsPossiblePrefireBot(client)) {
    return -1;
  }
  for (int i = 0; i < MaxBotsCurrentZone(); i++) {
    if (g_PFBotClientFrom[i] == client) {
        return i;
    }
  }
  return -1;
}

public bool IsPossiblePrefireBot(int client) {
  if (!PM_IsValidClient(client) || !IsFakeClient(client) || IsClientSourceTV(client)) {
    return false;
  }
  return IsFakeClient(client); //&& !g_IsPMBot[client] si es bot fake no dispara practicemode retorna 0, para compatibilidad
}

public void AddZonePoint(int client, int pointID, const float[3] personOrigin, const float[3] personAngles) {
  int index = g_PointZoneData[client].Push(pointID);
  g_PointZoneData[client].Set(index, view_as<int>(personOrigin[0]), 1);
  g_PointZoneData[client].Set(index, view_as<int>(personOrigin[1]), 2);
  g_PointZoneData[client].Set(index, view_as<int>(personOrigin[2]), 3);
  g_PointZoneData[client].Set(index, view_as<int>(personAngles[0]), 4);
  g_PointZoneData[client].Set(index, view_as<int>(personAngles[1]), 5);
  g_PointZoneData[client].Set(index, view_as<int>(personAngles[2]), 6);
}

public void GetZonePoint(int client, int index, int& pointID, float personOrigin[3], float personAngles[3]) {
  pointID = g_PointZoneData[client].Get(index, 0);
  personOrigin[0] = g_PointZoneData[client].Get(index, 1);
  personOrigin[1] = g_PointZoneData[client].Get(index, 2);
  personOrigin[2] = g_PointZoneData[client].Get(index, 3);
  personAngles[0] = g_PointZoneData[client].Get(index, 4);
  personAngles[1] = g_PointZoneData[client].Get(index, 5);
  personAngles[2] = g_PointZoneData[client].Get(index, 6);
}

////////////////menus{

stock void GiveZonesMenu(int client, int pos = 0){
    Menu menu = new Menu(ZoneMenuHandler);
    menu.SetTitle("Zones list");

    char zona[MAX_POINT_NAME];
    if(g_SpawnPointsKv.JumpToKey(NUM_EQUIPO, true)) {
        if(g_SpawnPointsKv.GotoFirstSubKey(false)){
            do {
                g_SpawnPointsKv.GetSectionName(zona, sizeof(zona));
                if(!StrEqual(zona, "TotalIds") && !StrEqual(zona, NUM_EQUIPO))
                    menu.AddItem(zona, zona);
            } while(g_SpawnPointsKv.GotoNextKey());
            g_SpawnPointsKv.Rewind();
        }
    }
    menu.AddItem("add_zone", "Add new Zone");

    menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public int ZoneMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[MAX_POINT_NAME + 1];
        menu.GetItem(param2, buffer, sizeof(buffer));
        if (StrContains(buffer, "add_zone") == 0) {
            g_WaitingForNameZone[client]=true;
            PrintToChat(client, " \x05[Prefire] \x01 Please Go To First Player Spawn and Write the Zone name below");
            PrintToChat(client, " \x05[Prefire] \x01 To cancel the action just say: \x04'.cancel' \x01or \x04'cancel'");
            //delete menu;
        } else {
            strcopy(g_CurrentZoneName[client], MAX_POINT_NAME, buffer);
            GivePointsMenu(client);
        }

        //GivePointsMenu(client); por si hay mas if arriba
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

stock void GivePointsMenu(int client, int pos = 0) {

    Menu menu = new Menu(PointsMenuHandler);
    menu.SetTitle("%s points: ", g_CurrentZoneName[client]);
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    
    GetPointsInfo(g_CurrentZoneName[client], client);
    menu.AddItem("add_newplayer", "Add New Player Spawn"); //[0/2]
    menu.AddItem("add_newbot", "Add new bot"); //[0/10]
    for (int i = 0; i < g_PointZoneData[client].Length; i++) {
        float personOrigin[3];
        float personAngles[3];
        int PointID;
        GetZonePoint(client, i, PointID, personOrigin, personAngles);

        AddMenuInt(menu, i, g_SpawnName[PointID]);
    }

    menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public int PointsMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[513];
    menu.GetItem(param2, buffer, sizeof(buffer));
    if (StrContains(buffer, "add_newbot") == 0) {
      int current_bots = KvSpawns_Finder(client, true);
      if(current_bots != 10) {
        char botspawn[MAX_SPAWN_NAME];
        Format(botspawn, MAX_SPAWN_NAME, "bot%d", current_bots + 1);
        SavePointWithName(client, botspawn);
        PrintToChat(client, " \x05[Prefire] \x01 Bot Spawn added!");
      } else {
        PrintToChat(client, " \x05[Prefire] \x01 Max 10 Bots Allowed");
      }
    } else if (StrContains(buffer, "add_newplayer") == 0) {
      if(KvSpawns_Finder(client) != 1) {
        SavePointWithName(client, "spawn2");
        PrintToChat(client, " \x05[Prefire] \x01 Player Spawn 2 added!");
      } else {
        PrintToChat(client, " \x05[Prefire] \x01 Theres already 2 Player Spawns!");
      }
    } else {
        int pointIndex = GetMenuInt(menu, param2); int pointID;
        float personOrigin[3], personAngles[3];
        GetZonePoint(client, pointIndex, pointID, personOrigin, personAngles);
        PrintToChat(client, " \x05[Prefire] \x01Say in chat \x04'!updatepoint' \x01to Update the position of: \x04%s", g_SpawnName[pointID]);
        TeleportEntity(client, personOrigin, personAngles, NULL_VECTOR);
        g_currentPointID[client] = pointID;
        g_PointIsSelected[client] = true;
    }
    GivePointsMenu(client, GetMenuSelectionPosition());
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveZonesMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

////////////////menus}

////////////////keyvalues{

stock void SavePointWithName(int client, const char[] name) {
    //continuar valor ID
    if (g_SpawnPointsKv.JumpToKey(NUM_EQUIPO, true)) {
        g_TotalSpawns = g_SpawnPointsKv.GetNum("TotalIds", 0) + 1;
        g_SpawnPointsKv.Rewind();
    }
    
    if (g_SpawnPointsKv.JumpToKey(NUM_EQUIPO, true)) {
        g_SpawnPointsKv.SetNum("TotalIds", g_TotalSpawns); //ultimo
        if(g_SpawnPointsKv.JumpToKey(g_CurrentZoneName[client], true)) {
            if(g_SpawnPointsKv.JumpToKey(name, true)) {//hace 1 { 0 { origin angles } }... para cada client
                float origin[3];
                float angles[3];
                GetClientAbsOrigin(client, origin);
                GetClientEyeAngles(client, angles);
                g_SpawnPointsKv.SetNum("spawnID", g_TotalSpawns);
                g_SpawnPointsKv.SetVector("origin", origin);
                g_SpawnPointsKv.SetVector("angles", angles);
                g_TotalSpawns++;
            }
        }
    }
    g_UpdatedSpawnsKv=true;
    MaybeWriteNewData();
}

public void GetPlayerSpawnsFromKv(int client) {
    g_SpawnPointsKv.Rewind();
    if (g_SpawnPointsKv.JumpToKey(NUM_EQUIPO, true)) { //client
        if(g_SpawnPointsKv.GotoFirstSubKey()) { //zone
            for(int i=1; i<g_CurrentPrefireZone; i++) { //if zoneid 2, goes to 2nd zone
                g_SpawnPointsKv.GotoNextKey();
            }
            if (g_SpawnPointsKv.GotoFirstSubKey()) {
                do {
                    char SpawnName[MAX_SPAWN_NAME];
                    g_SpawnPointsKv.GetSectionName(SpawnName, sizeof(SpawnName));
                    if((StrContains(SpawnName, "spawn1") != -1) && (client == g_ClientFromSpawn1)){
                        g_SpawnPointsKv.GetVector("origin", g_PlayerSpawnOrigin[client]);
                        g_SpawnPointsKv.GetVector("angles", g_PlayerSpawnAngles[client]);
                    }
                    if((StrContains(SpawnName, "spawn2") != -1) && (client == g_ClientFromSpawn2)){
                        g_SpawnPointsKv.GetVector("origin", g_PlayerSpawnOrigin[client]);
                        g_SpawnPointsKv.GetVector("angles", g_PlayerSpawnAngles[client]);
                    }
                } while (g_SpawnPointsKv.GotoNextKey());
            }
        }
    }
    g_SpawnPointsKv.Rewind();
}

stock int KvSpawns_Finder(int client, bool finding_bots = false) {
    int NumberOfBots = 0;
    g_SpawnPointsKv.Rewind();
    if (g_SpawnPointsKv.JumpToKey(NUM_EQUIPO, true)) { //client
        if(g_SpawnPointsKv.JumpToKey(g_CurrentZoneName[client], true)) {
            if (g_SpawnPointsKv.GotoFirstSubKey()) {
                do {
                    char SpawnName[MAX_SPAWN_NAME];
                    g_SpawnPointsKv.GetSectionName(SpawnName, sizeof(SpawnName));
                    if((finding_bots == false) && (StrContains(SpawnName, "spawn2") != -1)) {
                        g_SpawnPointsKv.Rewind();
                        return 1;
                    }
                    if((finding_bots == true) && (StrContains(SpawnName, "bot") != -1)) {
                        NumberOfBots++;
                    }
                } while (g_SpawnPointsKv.GotoNextKey());
            }
        }
    }
    g_SpawnPointsKv.Rewind();
    return NumberOfBots;
}

static void MaybeWriteNewData() {
    if (g_UpdatedSpawnsKv) {
        g_SpawnPointsKv.Rewind();
        DeleteFile(KvFileName);
        if (!g_SpawnPointsKv.ExportToFile(KvFileName)) {
            LogError("Failed to write data to %s", KvFileName);
        }
        g_UpdatedSpawnsKv = false;
    }
}

public void GetBotDataFromKv(int client) {
    int NumberOfBot=1;
    g_SpawnPointsKv.Rewind();
    if (g_SpawnPointsKv.GotoFirstSubKey()) { //client
        if(g_SpawnPointsKv.GotoFirstSubKey()) { //zone
            for(int i=1; i<g_CurrentPrefireZone; i++) { //if zoneid 2, goes to 2nd zone
                g_SpawnPointsKv.GotoNextKey();
            }
            if (g_SpawnPointsKv.GotoFirstSubKey()) {
                do {
                    char SpawnName[MAX_SPAWN_NAME];
                    g_SpawnPointsKv.GetSectionName(SpawnName, sizeof(SpawnName));
                    if(StrContains(SpawnName, "spawn") == -1){
                        //first bot spawn found
                        g_SpawnPointsKv.GetVector("origin", g_PFBotOrigin[NumberOfBot]);
                        g_SpawnPointsKv.GetVector("angles", g_PFBotAngles[NumberOfBot]);
                        NumberOfBot++;
                    }
                } while (g_SpawnPointsKv.GotoNextKey());
            }
        }
    }
    g_SpawnPointsKv.Rewind();
}

public int MaxBotsCurrentZone() {
    int NumberOfBots = 0;
    g_SpawnPointsKv.Rewind();
    if (g_SpawnPointsKv.GotoFirstSubKey()) {
        if(g_SpawnPointsKv.GotoFirstSubKey()) { //zones
            for(int i=1; i<g_CurrentPrefireZone; i++) { //if zoneid 2, goes to 2nd zone
                g_SpawnPointsKv.GotoNextKey();
            }
            g_SpawnPointsKv.GetSectionName(g_CurrentPFZoneName, MAX_SPAWN_NAME);
            if (g_SpawnPointsKv.GotoFirstSubKey()) {
                do {
                    char SpawnName[MAX_SPAWN_NAME];
                    g_SpawnPointsKv.GetSectionName(SpawnName, sizeof(SpawnName));
                    if(StrContains(SpawnName, "bot") != -1){
                        //first bot spawn found
                        NumberOfBots++;
                    }
                } while (g_SpawnPointsKv.GotoNextKey());
            }
        }
    }
    g_SpawnPointsKv.Rewind();
    return NumberOfBots;
}

public int MaxZonesCurrentMap() {
    int NumberOfZones = 0;
    g_SpawnPointsKv.Rewind();
    if(g_SpawnPointsKv.GotoFirstSubKey()) {
        if(g_SpawnPointsKv.GotoFirstSubKey()) {
            do {
                NumberOfZones++;
            } while (g_SpawnPointsKv.GotoNextKey());
        }
    }
    g_SpawnPointsKv.Rewind();
    return NumberOfZones;
}

stock void UpdatePoint(int client) {
    if (g_SpawnPointsKv.JumpToKey(NUM_EQUIPO, false)) {
        if(g_SpawnPointsKv.JumpToKey(g_CurrentZoneName[client], false)) {
            if(g_SpawnPointsKv.JumpToKey(g_SpawnName[g_currentPointID[client]], false)) {
                float neworigin[3];
                float newangles[3];
                GetClientAbsOrigin(client, neworigin);
                GetClientEyeAngles(client, newangles);
                g_SpawnPointsKv.SetVector("origin", neworigin);
                g_SpawnPointsKv.SetVector("angles", newangles);
            }
        }
    }
    g_SpawnPointsKv.Rewind();
}

public void GetPointsInfo(const char[] Zoneid, int client) {
  g_PointZoneData[client].Clear();
  if (g_SpawnPointsKv.JumpToKey(NUM_EQUIPO, true)) {
    if ((g_SpawnPointsKv.JumpToKey(Zoneid, true))) {
      if (g_SpawnPointsKv.GotoFirstSubKey()) {
        do {
          float origin[3];
          float angles[3];
          char SpawnName[MAX_SPAWN_NAME];
          int PointId;
          g_SpawnPointsKv.GetSectionName(SpawnName, sizeof(SpawnName));
          PointId = g_SpawnPointsKv.GetNum("spawnID");
          g_SpawnPointsKv.GetVector("origin", origin);
          g_SpawnPointsKv.GetVector("angles", angles);
          g_SpawnName[PointId] = SpawnName;
          AddZonePoint(client, PointId, origin, angles);
        } while (g_SpawnPointsKv.GotoNextKey());
      }
    }
  }
  g_SpawnPointsKv.Rewind();
}

////////////////keyvalues}

////////////////else

public bool Base_TraceFilter(int entity, int ContentsMask, int data) {
	return entity == data;
}

stock int GetAliveTeamCount(int team) {
    int number = 0;
    for (int i=1; i<=MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && IsPrefireBot(i) && GetClientTeam(i) == team) {
            number++;
        }
    }
    return number;
}

stock void Start_PFTimer() {
  if (!g_InBotPrefireMode) {
    return;
  }

  if (!g_RunningTimeCommand) {
    g_RunningTimeCommand = true;
    StartClientTimer();
  } else {
    StopClientTimer();
  }
}

public void StartClientTimer() {
  g_LastTimeCommand = GetEngineTime();
}

public float StopClientTimer() {
    g_RunningTimeCommand = false;
    return GetEngineTime() - g_LastTimeCommand;
}

stock void Start_TimerPerZone() {
  if (!g_InBotPrefireMode) {
    return;
  }

  if (!g_RunningTimeZoneCommand) {
    g_RunningTimeZoneCommand = true;
    StartZoneTimer();
  } else {
    StopZoneTimer();
  }
}

public void StartZoneTimer() {
  g_LastZoneTimeCommand = GetEngineTime();
}

public float StopZoneTimer() {
    g_RunningTimeZoneCommand = false;
    return GetEngineTime() - g_LastZoneTimeCommand;
}

public Action Timer_RemoveRagdoll(Handle timer, int ref) {
    int ragdoll = EntRefToEntIndex(ref);
    if(ragdoll != INVALID_ENT_REFERENCE)
        AcceptEntityInput(ragdoll, "Kill");
}

stock void FreezePF(int client, bool IsPlayer = false) {
    if (!IsPlayer) {
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.0);
        SetEntityHealth(client, STARTING_BOT_HP);
        return;
    }
    SetEntityHealth(client, g_PlayerStartingHealth);
    if(g_BotDifficultyInt == 0)
        SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1); 
    SetEntityMoveType(client, MOVETYPE_NONE);
    CreateTimer(4.3, Timer_Unfreeze, GetClientSerial(client));
}

int seconds = 3;

public Action Timer_CountDown(Handle timer) {
    if (seconds == 0) {
        seconds = 3;
        for (int i = 1; i <= MAXPLAYERS + 1; i++)
        {
            if(IsValidClient(i))
            {
                ClearSyncHud(i, HTMTimer);
            }
        }
        return Plugin_Stop;
    } else {
        for (int i = 1; i <= MAXPLAYERS + 1; i++)
        {
            if(IsValidClient(i))
            {
                SetHudTextParams(-1.0, 0.45, 1.0, 64, 255, 64, 255, 0, 0.0, 0.0, 0.0);
                ShowSyncHudText(i, HTMTimer, "%d", seconds);
            }
        }
        seconds--;
    }
    return Plugin_Continue;
}

public Action Timer_Unfreeze(Handle timer, int serial) {
    int client = GetClientFromSerial(serial);
    SetEntityMoveType(client, MOVETYPE_WALK);
}

public Action ChangeTeam(int client, const char[] command, int args)
{
    if(!IsValidClient(client)){
        return Plugin_Continue;
    }
    if(g_InBotPrefireMode) {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
} 

////////////////reusado

stock void SaveClientAuth(int client){
    char auth[MAX_POINT_NAME];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    ClientIdstr[client]=auth;
}

stock bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
    {
        return false;
    }
    return true;
}

stock bool PM_IsValidClient(int client) {
  return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

stock void CleanNameTag(char[] nameTag, int size)
{
    ReplaceString(nameTag, size, "%", "％");
    while(StrContains(nameTag, "  ") > -1)
    {
        ReplaceString(nameTag, size, "  ", " ");
    }
    StripQuotes(nameTag);
}

stock void AddMenuInt(Menu menu, int value, const char[] display, any:...) {
    char formattedDisplay[128];
    VFormat(formattedDisplay, sizeof(formattedDisplay), display, 4);
    char buffer[32];
    IntToString(value, buffer, sizeof(buffer));
    menu.AddItem(buffer, formattedDisplay);
}

stock int GetMenuInt(Menu menu, int param2) {
  char buffer[32];
  menu.GetItem(param2, buffer, sizeof(buffer));
  return StringToInt(buffer);
}

public bool EnforceDirectoryExists(const char[] smPath) {
    char dir[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, dir, sizeof(dir), smPath);
    if (!DirExists(dir)) {
        if (!CreateDirectory(dir, 511)) {
        LogError("Failed to create directory %s", dir);
        return false;
        }
    }
    return true;
}

stock void GetCleanMapName(char[] buffer, int size) {
    char mapName[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));
    CleanMapName(mapName, buffer, size);
}

stock void CleanMapName(const char[] input, char[] buffer, int size) {
    int last_slash = 0;
    int len = strlen(input);
    for (int i = 0; i < len; i++) {
        if (input[i] == '/' || input[i] == '\\')
        last_slash = i + 1;
    }
    strcopy(buffer, size, input[last_slash]);
}