#define CROSSFIRE_ID_LENGTH 16
#define CROSSFIRE_NAME_LENGTH 128

#define KV_BOTSPAWN "bot"
#define KV_PLAYERSPAWN "player"
#define KV_NADESPAWN "grenade"

int g_CFMisc_Countdown = -1;
Handle g_CFMisc_CountdownHandle = INVALID_HANDLE;

ArrayList g_HoloCFireEnts;

float g_CFBotSpawnOrigin[MAXPLAYERS + 1][3];
float g_CFBotMaxOrigin[MAXPLAYERS + 1][3];

bool g_CrossfirePlayers_Ready = false;
int g_CFireDeathPlayersCount = 0;
ArrayList g_CrossfirePlayers;
int g_CrossfirePlayers_Points[MAXPLAYERS + 1] = {0, ...};
int g_CrossfirePlayers_Room[MAXPLAYERS + 1] = {-1, ...};

ArrayList g_CrossfireBots;

ArrayList g_CFireArenas;
char g_CFireActiveId[CROSSFIRE_ID_LENGTH];

ConVar g_MaxCrossfireBotsCvar;
ConVar g_MaxCrossfirePlayersCvar;

// Options

bool g_CFOption_EndlessMode = false;

#define CFOption_BotsDifficultyMIN 0
int g_CFOption_BotsDifficulty = 3;
#define CFOption_BotsDifficultyMAX 5

#define CFOption_MaxSimBotsMIN 1
int g_CFOption_MaxSimBots = 2;
#define CFOption_MaxSimBotsMAX 5

#define CFOption_BotReactTimeMIN 60
int g_CFOption_BotReactTime = 180;
#define CFOption_BotReactTimeMAX 300

#define CFOption_BotStartDelayMIN 50
int g_CFOption_BotStartDelay = 100;
#define CFOption_BotStartDelayMAX 400

#define CFOption_BotStrafeChanceMIN 0
int g_CFOption_BotStrafeChance = 2;
#define CFOption_BotStrafeChanceMAX 3

#define CFOption_BotWeaponsMIN 0
int g_CFOption_BotWeapons = 4;
#define CFOption_BotWeaponsMAX 5

bool g_CFOption_BotsAttack = true;
bool g_CFOption_BotsFlash = false;

char g_CFMisc_PlayerWeapon[MAXPLAYERS + 1][128];

// Bot Logic
int g_CFBot_StartTime[MAXPLAYERS + 1];
int g_CFBot_Time[MAXPLAYERS + 1];

bool g_CFBotAllowedAttack[MAXPLAYERS + 1];
bool g_CFireBotDucking[MAXPLAYERS + 1];
bool g_CFBotStrafe[MAXPLAYERS + 1];
int g_CFBotStrafeHoldTime[MAXPLAYERS + 1];
bool g_CFBot_Seen[MAXPLAYERS + 1];
int g_CFBot_SeenTime[MAXPLAYERS + 1];
int g_CFBot_SeenTotalTime[MAXPLAYERS + 1];
bool g_CFBot_Moving[MAXPLAYERS + 1];

// NOTE: FULL TIME = REACTTIME + ATTACKTIME
ConVar g_CFBot_AttackTimeCvar; // usefull for sprays

public void Crossfire_PluginStart() {
  g_HoloCFireEnts = new ArrayList();
  g_CrossfirePlayers = new ArrayList();
  g_CrossfireBots = new ArrayList();
  g_CFireArenas = new ArrayList();

  g_MaxCrossfireBotsCvar = CreateConVar("sm_crossfire_max_bots", "8",
                              "How many crossfire bots spawn at max.", 0, true, 1.0, true, 10.0);
  g_MaxCrossfirePlayersCvar = CreateConVar("sm_crossfire_max_players", "2",
                              "How many crossfire players spawn at max.", 0, true, 1.0, true, 3.0);
  g_CFBot_AttackTimeCvar = CreateConVar("sm_crossfire_attack_time", "30",
                              "How much ticks until bot stops shooting.", 0, true, 0.0, true, 100.0);
}

public Action CS_OnBuyCommand(int client, const char[] weapon) {
  Format(g_CFMisc_PlayerWeapon[client], sizeof(g_CFMisc_PlayerWeapon[]), "weapon_%s", weapon);
  return Plugin_Continue;
}

stock void InitCrossfire(int client) {
  if (g_InCrossfireMode) {
    PM_Message(client, "{ORANGE}Crossfires Ya Activo.");
    return;
  }
  // Get Crossfires
  g_CFireArenas.Clear();
  int crossfireCount = GetCrossfiresNextId();
  if (crossfireCount > 0) {
    char iStr[CROSSFIRE_ID_LENGTH];
    for (int i = 0; i < crossfireCount; i++) {
      IntToString(i, iStr, CROSSFIRE_ID_LENGTH);
      g_CFireArenas.PushString(iStr);
    }
    // Random Crossfires
    SortADTArray(g_CFireArenas, Sort_Random, Sort_String);
  } else {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Zonas.");
    return;
  }
  // Setup First Crossfire
  g_CrossfirePlayers.Clear();
  g_CrossfirePlayers.Push(client);
  // Choose N random clients
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
      if (i == client) continue; // Already In ArrayList
      if (g_CrossfirePlayers.Length < g_MaxCrossfirePlayersCvar.IntValue) {
        g_CrossfirePlayers.Push(i);
      } else {
        ChangeClientTeam(i, CS_TEAM_SPECTATOR);
      }
    }
  }
  PrintToServer("[RETAKES-LOG]%d jugadores conectados.", g_CrossfirePlayers.Length);
  
  CS_TerminateRound(0.0, CSRoundEnd_Draw);
  StartSingleCrossfire(client, 0);
}

stock void StartSingleCrossfire(int client, int crossfirePos = 0) {
  ServerCommand("bot_kick");
  g_CrossfireBots.Clear();
  g_CFireDeathPlayersCount = 0;
  g_CFireArenas.GetString(crossfirePos, g_CFireActiveId, CROSSFIRE_ID_LENGTH);
  char crossfireName[CROSSFIRE_NAME_LENGTH];
  GetCrossfireName(g_CFireActiveId, crossfireName, CROSSFIRE_NAME_LENGTH);
  PM_Message(client, "{ORANGE}Empezando Arena: {GREEN}%s", crossfireName);
  PrintToServer("[RETAKES-LOG]Empezando Arena: %s", crossfireName);

  // Spawn Zone Setup vecmins[3], vecmaxs[3]
  // CreateDataTimer(1.0, Timer_ShowCrossfireBoxEntity, pack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
  g_CrossfirePlayers_Ready = false;
  CreateTimer(0.2, Timer_StartCrossfire, GetClientSerial(client));
}

public Action Timer_StartCrossfire(Handle timer, int serial) {
  for (int i = 0; i < g_CrossfirePlayers.Length; i++) {
    int player = g_CrossfirePlayers.Get(i);
    if (IsPlayer(player) && !IsPlayerAlive(player)) {
      CS_RespawnPlayer(player);
    }
  }
  // Get Bots
  char nextSpawn[CROSSFIRE_ID_LENGTH];
  GetCrossfireSpawnsNextId(g_CFireActiveId, KV_BOTSPAWN, nextSpawn, CROSSFIRE_ID_LENGTH);
  PrintToServer("[RETAKES-LOG]Cantidad de Bots: %s", nextSpawn);
  int botCount = StringToInt(nextSpawn);
  ArrayList enabledBots = new ArrayList(CROSSFIRE_ID_LENGTH);
  if (botCount > 0) {
    char iStr[CROSSFIRE_ID_LENGTH];
    for (int i = 0; i < botCount; i++) {
      IntToString(i, iStr, CROSSFIRE_ID_LENGTH);
      enabledBots.PushString(iStr);
    }
    // Random Spawns
    SortADTArray(enabledBots, Sort_Random, Sort_String);
    // Clamp if above max bots
    if (botCount > g_MaxCrossfireBotsCvar.IntValue) {
      // Take first max bots
      for (int i = enabledBots.Length - 1; i >= g_MaxCrossfireBotsCvar.IntValue; i--) {
        enabledBots.Erase(i);
      }
      botCount = g_MaxCrossfireBotsCvar.IntValue;
    }
  } else {
    PrintToServer("[RETAKES-LOG]Error: No Existen Suficientes Spawns de Bots.");
    return Plugin_Handled;
  }

  // Bots Setup
  for (int i = 0; i < botCount; i++) {
    char randomSpawnId[CROSSFIRE_ID_LENGTH];
    enabledBots.GetString(i, randomSpawnId, CROSSFIRE_ID_LENGTH);
    ServerCommand("bot_quota_mode normal");
    ServerCommand("bot_add");
    DataPack pack;
    CreateDataTimer(0.2, Timer_GetCrossfireBots, pack);
    pack.WriteString(randomSpawnId);
  }

  delete enabledBots;

  // Get Players
  GetCrossfireSpawnsNextId(g_CFireActiveId, KV_PLAYERSPAWN, nextSpawn, CROSSFIRE_ID_LENGTH);
  int playerCount = StringToInt(nextSpawn);
  ArrayList enabledPlayers = new ArrayList(CROSSFIRE_ID_LENGTH);
  if (playerCount > 0) {
    char iStr[CROSSFIRE_ID_LENGTH];
    for (int i = 0; i < playerCount; i++) {
      IntToString(i, iStr, CROSSFIRE_ID_LENGTH);
      enabledPlayers.PushString(iStr);
    }
    // Random Spawns
    SortADTArray(enabledPlayers, Sort_Random, Sort_String);
    // Clamp if above max players
    if (playerCount >= g_MaxCrossfirePlayersCvar.IntValue) {
      // Take first max players
      for (int i = enabledPlayers.Length - 1; i >= g_MaxCrossfirePlayersCvar.IntValue; i--) {
        enabledPlayers.Erase(i);
      }
      playerCount = g_MaxCrossfirePlayersCvar.IntValue;
    }
  } else {
    PrintToServer("[RETAKES-LOG]Error: No Existen Suficientes Spawns de Jugadores.");
    return Plugin_Handled;
  }

  // More Players Than Available Spawns (I dont need the if but it reads better)
  if (g_CrossfirePlayers.Length > enabledPlayers.Length) {
    for (int i = g_CrossfirePlayers.Length; i > enabledPlayers.Length; i--) {
      int player = g_CrossfirePlayers.Get(i);
      ChangeClientTeam(player, CS_TEAM_SPECTATOR);
      g_CrossfirePlayers.Erase(i);
    }
  }
  // Players Setup
  for (int i = 0; i < g_CrossfirePlayers.Length; i++) {
    char randomSpawnId[CROSSFIRE_ID_LENGTH];
    enabledPlayers.GetString(i, randomSpawnId, CROSSFIRE_ID_LENGTH);
    float origin[3], angles[3], vecmin[3], vecmax[3];
    GetCrossfireSpawnVectorKV(g_CFireActiveId, KV_PLAYERSPAWN, randomSpawnId, "origin", origin);
    GetCrossfireSpawnVectorKV(g_CFireActiveId, KV_PLAYERSPAWN, randomSpawnId, "angles", angles);
    GetCrossfireSpawnVectorKV(g_CFireActiveId, KV_PLAYERSPAWN, randomSpawnId, "vecmin", vecmin);
    GetCrossfireSpawnVectorKV(g_CFireActiveId, KV_PLAYERSPAWN, randomSpawnId, "vecmax", vecmax);
    PrintToServer("[RETAKES-LOG] Teleporting Client to [%f, %f, %f] with angles: [%f, %f]",
      origin[0], origin[1], origin[2], angles[0], angles[1]);
    int player = g_CrossfirePlayers.Get(i);
    g_CrossfirePlayers_Room[player] = CreateCrossFireRoomEntity(player, vecmin, vecmax);
    ChangeClientTeam(player, CS_TEAM_CT);
    TeleportEntity(player, origin, angles, ZERO_VECTOR);
    int weaponIndex = Client_GiveWeapon(player, g_CFMisc_PlayerWeapon[player]);
    if (IsValidEntity(weaponIndex)) {
      SetEntPropFloat(weaponIndex, Prop_Send, "m_flNextPrimaryAttack", 9999.0);
    }
    SetEntityMoveType(player, MOVETYPE_NONE);
  }

  delete enabledPlayers;

  // Success
  SetCvarIntSafe("mp_forcecamera", 0);
  SetCvarIntSafe("mp_radar_showall", 0);
  SetCvarIntSafe("sm_glow_pmbots", 0);
  SetCvarIntSafe("sv_infinite_ammo", 1);
  SetCvarIntSafe("sv_grenade_trajectory", 0);
  SetCvarIntSafe("sm_allow_noclip", 0);
  SetCvarIntSafe("mp_respawn_on_death_ct", 0);
  SetCvarIntSafe("mp_respawn_on_death_t", 0);
  SetCvarIntSafe("sv_showimpacts", 0);
  SetCvarIntSafe("sm_holo_spawns", 0);
  SetCvarIntSafe("sm_bot_collision", 1);

  // wait for setting in true
  g_CFMisc_Countdown = 3;
  g_CFMisc_CountdownHandle = CreateTimer(1.0, Crossfire_CountDown, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
  g_InCrossfireMode = true;
  return Plugin_Handled;
}

public Action Crossfire_CountDown(Handle timer, any data) {
  g_CFMisc_Countdown--;
  if(g_CFMisc_Countdown <= 0) {
    for (int i = 0; i < g_CrossfirePlayers.Length; i++) {
      int player = g_CrossfirePlayers.Get(i);
      if (IsPlayer(player)) {
        ClearSyncHud(player, HudSync);
        SetEntityMoveType(player, MOVETYPE_WALK);
        
        // char weaponName[128];
        // if (StrEqual(g_CFMisc_PlayerWeapon[player], "weapon_usp_silencer")) {
        //   strcopy(weaponName, sizeof(weaponName), "weapon_hkp2000");
        // } else {
        //   strcopy(weaponName, sizeof(weaponName), g_CFMisc_PlayerWeapon[player]);
        // }
        int weaponIndex = Client_GetActiveWeapon(player); // Client_GetWeapon(player, weaponName);
        if (IsValidEntity(weaponIndex)) {
          SetEntPropFloat(weaponIndex, Prop_Send, "m_flNextPrimaryAttack", -0.01);
        }
      }
    }
    g_CrossfirePlayers_Ready = true;
    if(g_CFMisc_CountdownHandle != INVALID_HANDLE) {
      KillTimer(g_CFMisc_CountdownHandle);
      g_CFMisc_CountdownHandle = INVALID_HANDLE;
    }
    return Plugin_Stop;
  }
  for (int i = 0; i < g_CrossfirePlayers.Length; i++) {
    int player = g_CrossfirePlayers.Get(i);
    if (IsPlayer(player)) {
      SetHudTextParams(-1.0, 0.45, 3.5, 64, 255, 64, 0, 1, 1.0, 0.1, 0.1);
      ShowSyncHudText(player, HudSync, "%d", g_CFMisc_Countdown);
    }
  }
  return Plugin_Continue;
}

public int CreateCrossFireRoomEntity(int client, float vecmin[3], float vecmax[3]) {
  int iEnt = CreateEntityByName("trigger_multiple");
  if (iEnt > 0) {
    DispatchKeyValue(iEnt, "spawnflags", "64");
    DispatchKeyValue(iEnt, "wait", "0");
    DispatchSpawn(iEnt);
    ActivateEntity(iEnt);
    float vecmiddle[3];
    SubtractVectors(vecmax, vecmin, vecmiddle);
    ScaleVector(vecmiddle, 0.5);
    AddVectors(vecmin, vecmiddle, vecmiddle);

    TeleportEntity(iEnt, vecmiddle, NULL_VECTOR, NULL_VECTOR);
    SetEntityModel(iEnt, "models/error.mdl");
    // Have the mins always be negative
    vecmin[0] = vecmin[0] - vecmiddle[0];
    if (vecmin[0] > 0.0)
      vecmin[0] *= -1.0;
    vecmin[1] = vecmin[1] - vecmiddle[1];
    if (vecmin[1] > 0.0)
      vecmin[1] *= -1.0;
    vecmin[2] = vecmin[2] - vecmiddle[2];
    if (vecmin[2] > 0.0)
      vecmin[2] *= -1.0;

    // And the maxs always be positive
    vecmax[0] = vecmax[0] - vecmiddle[0];
    if (vecmax[0] < 0.0)
      vecmax[0] *= -1.0;
    vecmax[1] = vecmax[1] - vecmiddle[1];
    if (vecmax[1] < 0.0)
      vecmax[1] *= -1.0;
    vecmax[2] = vecmax[2] - vecmiddle[2];
    if (vecmax[2] < 0.0)
      vecmax[2] *= -1.0;

    // Make it Higher
    vecmax[2] *= 10.0;
    SetEntPropVector(iEnt, Prop_Send, "m_vecMins", vecmin);
    SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", vecmax);
    SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_BBOX);
    Entity_SetCollisionGroup(iEnt, COLLISION_GROUP_DEBRIS);
    // SDKHook(iEnt, SDKHook_StartTouch, CrossfireRoom_OnStartTouch);
    SDKHook(iEnt, SDKHook_EndTouch, CrossfireRoom_OnEndTouch);
    DataPack boxPack;
    CreateDataTimer(0.3, Timer_ShowBoxEntity, boxPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT)
    boxPack.WriteCell(iEnt);
    boxPack.WriteFloatArray(vecmin, 3);
    boxPack.WriteFloatArray(vecmax, 3);
    return iEnt;
  }
  return -1;
}

public void CrossfireRoom_OnStartTouch(int entity, int client) {
  if (!IsValidClient(client))
    return;

}

public void CrossfireRoom_OnEndTouch(int entity, int client) {
  if (!IsValidClient(client))
    return;
  float fVel[3];
  Entity_GetAbsVelocity(client, fVel);
  fVel[0] = fVel[0] * -2.0;
  fVel[1] = fVel[1] * -2.0;
  TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
}

public Action Timer_GetCrossfireBots(Handle timer, DataPack pack) {
  pack.Reset();
  char spawnId[CROSSFIRE_ID_LENGTH];
  pack.ReadString(spawnId, CROSSFIRE_ID_LENGTH);
  
  int bot = GetLiveBot(CS_TEAM_T);
  if (bot < 0) {
    return Plugin_Handled;
  }

  char name[MAX_NAME_LENGTH];
  GetClientName(bot, name, MAX_NAME_LENGTH);
  char crossfireName[CROSSFIRE_NAME_LENGTH];
  GetCrossfireName(g_CFireActiveId, crossfireName, CROSSFIRE_NAME_LENGTH);
  Format(name, MAX_NAME_LENGTH, "[%s] %s", name, crossfireName);
  SetClientName(bot, name);
  g_IsCrossfireBot[bot] = true;
  g_CrossfireBots.Push(bot);

  // Weapons
  Client_RemoveAllWeapons(bot);
  switch(g_CFOption_BotWeapons) {
    case 0: {
      GivePlayerItem(bot, "weapon_knife");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), false);
      Client_SetArmor(bot, 100);
    }
    case 1: {
      GivePlayerItem(bot, "weapon_glock");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case 2: {
      GivePlayerItem(bot, "weapon_mp9");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case 3: {
      GivePlayerItem(bot, "weapon_deagle");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case 4: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case 5: {
      GivePlayerItem(bot, "weapon_awp");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
  }

  // Setup Single Bot
  g_CFBot_StartTime[bot] = g_CFOption_BotStartDelay;
  g_CFBot_Time[bot] = 0;
  g_CFireBotDucking[bot] = false;
  g_CFBotStrafeHoldTime[bot] = 0;
  g_CFBotStrafe[bot] = false;
  g_CFBot_Seen[bot] = false;
  g_CFBot_SeenTime[bot] = 0;
  g_CFBot_SeenTotalTime[bot] = 0;
  g_CFBot_Moving[bot] = false;
  g_CFBotAllowedAttack[bot] = false;
  if (g_CrossfireBots.Length <= 2) { // TODO FIX PEDO CACA
    // 1st and 2nd will be able to move
    // PrintToChatAll("[%N]: Moving!", bot);
    g_CFBot_Moving[bot] = true;
  }


  float botAngles[3];
  GetCrossfireSpawnVectorKV(g_CFireActiveId, KV_BOTSPAWN, spawnId, "origin", g_CFBotSpawnOrigin[bot]);
  GetCrossfireSpawnVectorKV(g_CFireActiveId, KV_BOTSPAWN, spawnId, "angles", botAngles); // not needed
  GetCrossfireSpawnVectorKV(g_CFireActiveId, KV_BOTSPAWN, spawnId, "maxorigin", g_CFBotMaxOrigin[bot]);
  TeleportEntity(bot, g_CFBotSpawnOrigin[bot], botAngles, ZERO_VECTOR);
  // SetEntPropFloat(bot, Prop_Data, "m_flLaggedMovementValue", 0.0);

  return Plugin_Handled;
}

public void EndSingleCrossfire(bool win) {
  char crossfireName[CROSSFIRE_NAME_LENGTH];
  GetCrossfireName(g_CFireActiveId, crossfireName, CROSSFIRE_NAME_LENGTH);
  for (int i = 0; i < g_CrossfirePlayers.Length; i++) {
    int player = g_CrossfirePlayers.Get(i);
    if (IsPlayer(player)) {
      if (IsValidEntity(g_CrossfirePlayers_Room[player])) {
        AcceptEntityInput(g_CrossfirePlayers_Room[player], "Kill");
        g_CrossfirePlayers_Room[player] = -1;
      }
      EmitSoundToClient(player, (win) ? "ui/achievement_earned.wav" : "ui/armsrace_demoted.wav", _, _, SNDLEVEL_ROCKET);
      // PM_Message(player, "{ORANGE}Crossfire {PURPLE}%s {ORANGE} %s", crossfireName, (win) ? "Ganado" : "Perdido.");
    }
  }
  int client = g_CrossfirePlayers.Get(0);
  if (IsPlayer(client)) {
    int currentCrossfireIndex = g_CFireArenas.FindString(g_CFireActiveId);
    if (win) {
      if (currentCrossfireIndex < g_CFireArenas.Length - 1) {
        // go to next crossfire
        currentCrossfireIndex++;
        StartSingleCrossfire(client, currentCrossfireIndex);
        return;
      }
    } else {
      StartSingleCrossfire(client, currentCrossfireIndex);
      return;
    }
  }
  // Finished last arena
  if (g_CFOption_EndlessMode) {
    // Endless
    StartSingleCrossfire(client);
  } else {
    // Stop on Last Arena
    StopCrossfiresMode();
  }
  // ServerCommand("mp_restartgame 1");
}

public void StopCrossfiresMode() {
  ServerCommand("bot_kick");
  for (int i = 0; i < g_CrossfirePlayers.Length; i++) {
    int player = g_CrossfirePlayers.Get(i);
    if (IsPlayer(player)) {
      if (IsValidEntity(g_CrossfirePlayers_Room[player])) {
        AcceptEntityInput(g_CrossfirePlayers_Room[player], "Kill");
        g_CrossfirePlayers_Room[player] = -1;
      }
      PM_Message(player, "{GREEN}===============================");
      PM_Message(player, "{ORANGE}end");
      PM_Message(player, "{GREEN}===============================");
    }
  }
  g_CrossfirePlayers.Clear();
  g_CrossfireBots.Clear();
  g_CFireArenas.Clear();
  g_InCrossfireMode = false;
  
  SetConVarFloatSafe("mp_roundtime_defuse", 60.0);
  SetCvarIntSafe("mp_forcecamera", 2);
  SetCvarIntSafe("mp_radar_showall", 1);
  SetCvarIntSafe("sm_glow_pmbots", 1);
  SetCvarIntSafe("sv_grenade_trajectory", 1);
  SetCvarIntSafe("sm_allow_noclip", 1);
  SetCvarIntSafe("mp_respawn_on_death_ct", 1);
  SetCvarIntSafe("mp_respawn_on_death_t", 1);
  SetCvarIntSafe("sv_showimpacts", 1);
  SetCvarIntSafe("sm_holo_spawns", 1);
  SetCvarIntSafe("sm_bot_collision", 0);
  CS_TerminateRound(0.0, CSRoundEnd_Draw);
}

// TODO: Use Timer for calculating the closest player, store it in global -> g_crossfireBotTarget[bot] = me
public Action CrossfireBot_PlayerRunCmd(int client, int &buttons, float vel[3], float angles[3], int &weapon) {
  if (!g_InCrossfireMode || !g_CrossfirePlayers_Ready) {
    return Plugin_Continue;
  }

  if (!IsPlayerAlive(client)) {
    return Plugin_Continue;
  }

  float m_bData = GetEntPropFloat(client, Prop_Data, "m_flDuckSpeed");
  if (m_bData < 7.0) {
    SetEntPropFloat(client, Prop_Send, "m_flDuckSpeed", 7.0, 0);
  }

  // always look at closest player (otherwise bot overrides its angles(maybe create global variable and update that through timer function?))
  int nearestTarget = -1;
  int nearestNonVisibleTarget = -1;

  float nearestDistance = -1.0;
  float distance;
  for (int i = 0; i < g_CrossfirePlayers.Length; i++) {
    int target = g_CrossfirePlayers.Get(i);
    if (IsPlayer(target)) {
      if (!IsPlayerAlive(target)) {
        continue;
      }
      distance = Entity_GetDistance(client, target);
      if (distance > nearestDistance && nearestDistance > -1.0) {
        continue;
      }
      if (!IsAbleToSee(client, target, 0.9)) {
        // if (distance < 1000.0) {
        nearestNonVisibleTarget = target;
        // }
        continue;
      }
      nearestDistance = distance;
      nearestTarget = target;
    }
  }

  // Movement And Attack Logic

  // ONLY 2 BOTS EXECUTE THIS LOGIC AT MAX <- set to cvar ? Make this Logic inside player_death event with global true var
  // 1) Bot Wait Random Time
  // 2) Bot moves towards g_CFBotMaxOrigin[client]
  // 3) Player can see the bot, g_CFBotStrafe[client] = 1(randomInt)
  // 4) Bot moves back to SpawnOrigin, g_CFBotStrafeHoldTime[client] = 14(randomInt)
  // 5) Player can't see the bot, 14 ticks has passed
  // 6) Bot moves towards g_CFBotMaxOrigin[client]
  // 7) Player can see the bot, g_CFBotStrafe[client] = 0(randomInt)
  // 8) Bot gets to g_CFBotMaxOrigin[client], g_CFireBotDucking[client] = 1(randomInt)
  // 9) Bot crouches and starts shooting

  if (g_CFBot_Moving[client]) {
    if (g_CFBot_StartTime[client] > 0) {
      if (g_CFBot_Time[client] == g_CFBot_StartTime[client]) {
        g_CFBot_Time[client] = 0;
        g_CFBot_StartTime[client] = -1;
      } else {
        // Still havent Waited Random Time (STEP 1)
        g_CFBot_Time[client]++;
      }
    } else {
      // Officially started, g_CFBot_Time[client] should be 0
      if (g_CFBot_Time[client] == 0) {
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR); // dont move him
      } else if (g_CFBot_Time[client] > 0) {
        float clientOrigin[3];
        GetClientAbsOrigin(client, clientOrigin);
        if (nearestTarget > 0) {
          if (!g_CFBot_Seen[client]) {
            // Player started to see the bot (STEP 3)
            g_CFBot_SeenTotalTime[client]++;
            if (g_CFBot_SeenTotalTime[client] < 10) {
              // PrintToChatAll("[%N]: player started seeing me, ignore!", client);
            } else {
              g_CFBot_SeenTotalTime[client] = 0;
              g_CFBot_Seen[client] = true;
              g_CFBot_SeenTime[client] = g_CFBot_Time[client];
              g_CFBotStrafe[client] = (GetRandomInt(1, 3*(CFOption_BotStrafeChanceMAX+1) + 3) <= (3*g_CFOption_BotStrafeChance));
              // if (g_CFBotStrafe[client]) PrintToChatAll("[%N]: player finished seeing me, coming back to spawn!", client);
              // else PrintToChatAll("[%N]: player finished seeing me, peeking him!", client);
              g_CFBotStrafeHoldTime[client] = GetRandomInt(0, 50);
            }
          } else {
            // Player seeing The Bot
            // Move back to SpawnOrigin (STEP 4)
            if (g_CFBotStrafe[client]) {
              if (GetVectorDistance(clientOrigin, g_CFBotSpawnOrigin[client]) > 5.0) {
                // PrintToChatAll("[%N]: moving back to spawn!", client);
                // Go to Spawn Origin
                SubtractVectors(g_CFBotSpawnOrigin[client], clientOrigin, clientOrigin);
                NormalizeVector(clientOrigin, clientOrigin);
                ScaleVector(clientOrigin, 250.0);
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientOrigin);
              } else {
                // PrintToChatAll("[%N]: errorspawn!", client);
                // Bot Reached spawnOrigin while player can see him <- this shouldnt happen?
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
              }
            } else {
              // Player can see bot, but he wont strafe (STEP 7)
              if (GetVectorDistance(clientOrigin, g_CFBotMaxOrigin[client]) > 5.0) {
                // PrintToChatAll("[%N]: moving to maxorigin!", client);
                // Go to maxOrigin
                SubtractVectors(g_CFBotMaxOrigin[client], clientOrigin, clientOrigin);
                NormalizeVector(clientOrigin, clientOrigin);
                ScaleVector(clientOrigin, 250.0);
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientOrigin);
              } else {
                // Bot gets to maxorigin (STEP 8)
                float playerPos[3];
                GetClientEyePosition(nearestTarget, playerPos);
                float crouchPos[3];
                crouchPos = g_CFBotMaxOrigin[client];
                crouchPos[2] += 48.0;
                g_CFireBotDucking[client] = !GetRandomInt(0, 1) && IsPointVisible(playerPos, crouchPos);
                // Get To The Next Sequence
                g_CFBot_Moving[client] = false;
                g_CFBotAllowedAttack[client] = true;
                g_CFBot_Time[client] = 0;
              }
            }
          }
        } else {
          // Player Saw Bot but now doesnt, He Is Hiding|Holding, dont do anything, let time pass
          if (g_CFBot_Seen[client] && (g_CFBot_Time[client] - g_CFBot_SeenTime[client]) <= g_CFBotStrafeHoldTime[client]) {
            // PrintToChatAll("[%N]: Im hiding until time pass!", client);
          } else {
            // If Time passed (STEP 5)
            if (g_CFBot_Seen[client]) {
              // PrintToChatAll("[%N]: Time passed, I can try peek now!", client);
              g_CFBot_Seen[client] = false;
            } else {
              // Move towards to maxOrigin (STEP 2 & STEP 6)
              if (GetVectorDistance(clientOrigin, g_CFBotMaxOrigin[client]) > 5.0) {
                SubtractVectors(g_CFBotMaxOrigin[client], clientOrigin, clientOrigin);
                NormalizeVector(clientOrigin, clientOrigin);
                ScaleVector(clientOrigin, 250.0);
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientOrigin);
              } else {
                // PrintToChatAll("[%N]: errormaxorigin", client);
                // Bot Reached maxOrigin while player Cant see him <- this shouldnt happen?
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
              }
            }
          }
        }
      }
      g_CFBot_Time[client]++;
    }
  } else if (g_CFBotAllowedAttack[client]) {
    // Should Attack
    if (g_CFireBotDucking[client]) buttons |= IN_DUCK;
    if (nearestTarget > 0) {
      if (g_CFBot_Time[client] >= g_CFOption_BotReactTime &&
      g_CFBot_Time[client] <= (g_CFOption_BotReactTime+g_CFBot_AttackTimeCvar.IntValue)) {
        // Has a Target
        if (g_CFBot_Time[client] == g_CFOption_BotReactTime) {
          if (g_CFOption_BotWeapons == 5 && !GetEntProp(client, Prop_Send, "m_bIsScoped")) {
            // zoom
            buttons |= IN_ATTACK2;
          }
        }
        if (g_CFOption_BotsAttack) buttons |= IN_ATTACK;
        if (g_CFBot_Time[client] == (g_CFOption_BotReactTime+g_CFBot_AttackTimeCvar.IntValue)) {
          // Reset Shooting time
          buttons &= ~IN_ATTACK;
          // g_CFireBotDucking[client] = GetRandomInt(0, 1); CROUCH | STAND WHILE SHOOTING
          g_CFBot_Time[client] = 0;
        } else {
          g_CFBot_Time[client]++;
        }
      }
      g_CFBot_Time[client]++;
    } else {
      g_CFBot_Time[client] = 0;
    }
  }

  if (nearestTarget > 0) {
    float clientEyepos[3], viewTarget[3];
    GetClientEyePosition(client, clientEyepos);
    GetClientEyePosition(nearestTarget, viewTarget);
    viewTarget[2] -= 0.0; // headshot or bodyshot(30.0) ?
    SubtractVectors(viewTarget, clientEyepos, viewTarget);
    GetVectorAngles(viewTarget, viewTarget);
    TeleportEntity(client, NULL_VECTOR, viewTarget, NULL_VECTOR);
  } else if (nearestNonVisibleTarget > 0) {
    float clientEyepos[3], viewTarget[3];
    GetClientEyePosition(client, clientEyepos);
    GetClientEyePosition(nearestNonVisibleTarget, viewTarget);
    SubtractVectors(viewTarget, clientEyepos, viewTarget);
    GetVectorAngles(viewTarget, viewTarget);
    viewTarget[2] -= 3.0; //headshot
    TeleportEntity(client, NULL_VECTOR, viewTarget, NULL_VECTOR);
  }

  return Plugin_Continue;
}

public Action Event_CrossfireBot_Death(int victim, Event event, const char[] name, bool dontBroadcast) {
  // TODO: Respawn in next pos?
  int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
  if (!IsValidClient(killer) || killer == victim) {
    return Plugin_Continue;
  }
  int index = -1;
  if((index = g_CrossfireBots.FindValue(victim)) != -1) {
    int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
    CreateTimer(0.5, Timer_RemoveRagdoll, EntIndexToEntRef(ragdoll), TIMER_FLAG_NO_MAPCHANGE);
    g_CFBot_Time[index] = 0;
    if (g_CrossfirePlayers.FindValue(killer) != -1) {
      g_CrossfirePlayers_Points[killer] += 5; // 5 points per kill
    }
    g_CrossfireBots.Erase(index);
  }
  if (g_CFBot_Moving[victim] || g_CFBotAllowedAttack[victim]) {
    // he was an active bot, send the next one
    g_CFBot_Moving[victim] = false;
    g_CFBotAllowedAttack[victim] = false;
    for (int i = 0; i < g_CrossfireBots.Length; i++) {
      int bot = g_CrossfireBots.Get(i);
      if (!g_CFBot_Moving[bot] && !g_CFBotAllowedAttack[bot]) {
        g_CFBot_Moving[bot] = true;
        break;
      }
    }
  }
  if (g_CrossfireBots.Length == 0) {
    EndSingleCrossfire(true);
  }
  return Plugin_Continue;
}

////////////////////////
////////COMMANDS////////
////////////////////////

public Action Command_NextCrossfire(int client, int args) {
  int currentCrossfireIndex = g_CFireArenas.FindString(g_CFireActiveId);
  if (currentCrossfireIndex < g_CFireArenas.Length - 1) {
    // go to next crossfire
    currentCrossfireIndex++;
    StartSingleCrossfire(client, currentCrossfireIndex);
  }
  return Plugin_Handled;
}

public Action Command_PrevCrossfire(int client, int args) {
  int currentCrossfireIndex = g_CFireArenas.FindString(g_CFireActiveId);
  if (currentCrossfireIndex > 0) {
    // go to prev crossfire
    currentCrossfireIndex--;
    StartSingleCrossfire(client, currentCrossfireIndex);
  }
  return Plugin_Handled;
}

public Action Command_CrossfiresSetupMenu(int client, int args) {
  if (!IsPlayer(client)) {
    return Plugin_Handled;
  }
  CrossfiresSetupMenu(client);
  return Plugin_Handled;
}

public Action Command_CrossfiresEditorMenu(int client, int args) {
  if (g_InCrossfireMode) {
    PM_Message(client, "{ORANGE}Crossfire Ya Empezado.");
    return Plugin_Continue;
  }
  PM_Message(client, "{ORANGE}Modo Edición Activado.");
  CrossfiresEditorMenu(client);
  return Plugin_Handled;
}

public bool IsCrossfireBot(int client) {
  return client > 0 && g_IsCrossfireBot[client] && IsClientInGame(client) && IsFakeClient(client);
}
