#define CROSSFIRE_ID_LENGTH 16
#define CROSSFIRE_NAME_LENGTH 128

#define KV_BOTSPAWN "bot"
#define KV_PLAYERSPAWN "player"
#define KV_NADESPAWN "grenade"

ArrayList g_HoloCFireEnts;

int g_CFBot_Time[MAXPLAYERS + 1] = {0, ...};

// bool g_CFireBotAllowedAttack[MAXPLAYERS + 1];
bool g_CFireBotMovingRight[MAXPLAYERS + 1];
bool g_CFireBotDucking[MAXPLAYERS + 1];

int g_CFireDeathPlayersCount = 0;
ArrayList g_CrossfirePlayers;
int g_CrossfirePlayers_Points[MAXPLAYERS + 1] = {0, ...};
int g_CrossfirePlayers_Room[MAXPLAYERS + 1] = {-1, ...};

ArrayList g_CrossfireBots;

ArrayList g_CFireArenas;
char g_CFireActiveId[CROSSFIRE_ID_LENGTH];

ConVar g_MaxCrossfireBotsCvar;
ConVar g_MaxCrossfirePlayersCvar;

int g_CrossfireDifficulty = 0;

// NOTE: CFBOT_REACTTIME > CFBOT_MOVEDISTANCE && CFBOT_MOVEDISTANCE > 0
ConVar g_CFBot_ReactTimeCvar; // how long until he shoots
// NOTE: FULL TIME = REACTTIME + ATTACKTIME
ConVar g_CFBot_AttackTimeCvar; // usefull for sprays
ConVar g_CFBot_MoveDistanceCvar; // usefull for distance

public void Crossfire_PluginStart() {
  g_HoloCFireEnts = new ArrayList();
  g_CrossfirePlayers = new ArrayList();
  g_CrossfireBots = new ArrayList();
  g_CFireArenas = new ArrayList();

  g_MaxCrossfireBotsCvar = CreateConVar("sm_crossfire_max_bots", "7",
                              "How many crossfire bots spawn at max.", 0, true, 1.0, true, 8.0);
  g_MaxCrossfirePlayersCvar = CreateConVar("sm_crossfire_max_players", "2",
                              "How many crossfire players spawn at max.", 0, true, 1.0, true, 3.0);
  g_CFBot_ReactTimeCvar = CreateConVar("sm_crossfire_react_time", "80",
                              "How many crossfire players spawn at max.", 0, true, 1.0, true, 2.0);
  g_CFBot_AttackTimeCvar = CreateConVar("sm_crossfire_attack_time", "30",
                              "How many crossfire players spawn at max.", 0, true, 1.0, true, 2.0);
  g_CFBot_MoveDistanceCvar = CreateConVar("sm_crossfire_move_distance", "60",
                              "How many crossfire players spawn at max.", 0, true, 1.0, true, 2.0);
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
  StartSingleCrossfire(client, 0);
}

stock void StartSingleCrossfire(int client, int crossfirePos = 0) {
  g_CFireDeathPlayersCount = 0;
  g_CFireArenas.GetString(crossfirePos, g_CFireActiveId, CROSSFIRE_ID_LENGTH);
  char crossfireName[CROSSFIRE_NAME_LENGTH];
  GetCrossfireName(g_CFireActiveId, crossfireName, CROSSFIRE_NAME_LENGTH);
  PM_Message(client, "{ORANGE}Empezando Arena: {GREEN}%s", crossfireName);
  PrintToServer("[RETAKES-LOG]Empezando Arena: %s", crossfireName);

  // Spawn Zone Setup vecmins[3], vecmaxs[3]
  // CreateDataTimer(1.0, Timer_ShowCrossfireBoxEntity, pack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
  CreateTimer(0.2, Timer_StartCrossfire, GetClientSerial(client));
}

public Action Timer_StartCrossfire(Handle timer, int serial) {
  for (int i = 0; i < g_CrossfirePlayers.Length; i++) {
    int player = g_CrossfirePlayers.Get(i);
    if (IsPlayer(player) && !IsPlayerAlive(player)) {
      CS_RespawnPlayer(player);
    }
  }
  g_CrossfireBots.Clear();
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
    SetEntityMoveType(player, MOVETYPE_WALK);
    TeleportEntity(player, origin, angles, ZERO_VECTOR);
  }

  delete enabledPlayers;

  // Success
  SetCvarIntSafe("mp_forcecamera", 0);
  SetCvarIntSafe("mp_radar_showall", 0);
  SetCvarIntSafe("sm_glow_pmbots", 0);
  // SetCvarIntSafe("mp_ignore_round_win_conditions", 0);
  SetCvarIntSafe("sv_grenade_trajectory", 0);
  SetCvarIntSafe("sv_infinite_ammo", 2);
  SetCvarIntSafe("sm_allow_noclip", 0);
  SetCvarIntSafe("mp_respawn_on_death_ct", 0);
  SetCvarIntSafe("mp_respawn_on_death_t", 0);
  SetCvarIntSafe("sv_showimpacts", 0);
  SetCvarIntSafe("sm_holo_spawns", 0);
  SetCvarIntSafe("sm_bot_collision", 1);
  g_InCrossfireMode = true;
  return Plugin_Handled;
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
  switch(g_CrossfireDifficulty) {
    case 0: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), false);
      Client_SetArmor(bot, 100);
    }
    case 1: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case 2: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
  }

  float botOrigin[3], botAngles[3];
  GetCrossfireSpawnVectorKV(g_CFireActiveId, KV_BOTSPAWN, spawnId, "origin", botOrigin);
  GetCrossfireSpawnVectorKV(g_CFireActiveId, KV_BOTSPAWN, spawnId, "angles", botAngles);
  TeleportEntity(bot, botOrigin, botAngles, ZERO_VECTOR);
  // SetEntPropFloat(bot, Prop_Data, "m_flLaggedMovementValue", 0.0);

  return Plugin_Handled;
}

public void EndSingleCrossfire(bool win) {
  ServerCommand("bot_kick");
  g_CrossfireBots.Clear();
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
      PM_Message(player, "{GREEN}===============================");
      PM_Message(player, "{ORANGE}Crossfire {PURPLE}%s {ORANGE} %s", crossfireName, (win) ? "Ganado" : "Perdido.");
      PM_Message(player, "{GREEN}===============================");
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
  // error
  StopCrossfiresMode();
  // ServerCommand("mp_restartgame 1");
}

public void StopCrossfiresMode() {
  ServerCommand("bot_kick");
  g_CrossfirePlayers.Clear();
  g_CrossfireBots.Clear();
  g_CFireArenas.Clear();
  g_InCrossfireMode = false;
  
  SetConVarFloatSafe("mp_roundtime_defuse", 60.0);
  SetCvarIntSafe("mp_forcecamera", 2);
  SetCvarIntSafe("mp_radar_showall", 1);
  SetCvarIntSafe("sm_glow_pmbots", 1);
  // SetCvarIntSafe("mp_ignore_round_win_conditions", 1);
  SetCvarIntSafe("sv_grenade_trajectory", 1);
  SetCvarIntSafe("sv_infinite_ammo", 1);
  SetCvarIntSafe("sm_allow_noclip", 1);
  SetCvarIntSafe("mp_respawn_on_death_ct", 1);
  SetCvarIntSafe("mp_respawn_on_death_t", 1);
  SetCvarIntSafe("sv_showimpacts", 1);
  SetCvarIntSafe("sm_holo_spawns", 1);
  SetCvarIntSafe("sm_bot_collision", 0);
}

// TODO: Use Timer for calculating the closest player, store it in global -> g_crossfireBotTarget[bot] = me
public Action CrossfireBot_PlayerRunCmd(int client, int &buttons, float vel[3], float angles[3], int &weapon) {
  if (!g_InCrossfireMode) {
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
      if (!IsAbleToSee(client, target)) {
        if (distance < 1000.0) {
          nearestNonVisibleTarget = target;
        }
        continue;
      }
      nearestDistance = distance;
      nearestTarget = target;
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
    // Strafe movement perpendicular to player->bot vector
    // bot will stop and attack every g_CFBot_ReactTimeCvar.IntValue frames
    if (g_CFBot_Time[client] >= g_CFBot_ReactTimeCvar.IntValue &&
        g_CFBot_Time[client] <= (g_CFBot_ReactTimeCvar.IntValue+g_CFBot_AttackTimeCvar.IntValue)) { // bot will attack for (2 + 1) frames
      vel[1] = 0.0;
      buttons |= IN_ATTACK;
      // buttons &= ~IN_SPEED;
      if (g_CFBot_Time[client] == (g_CFBot_ReactTimeCvar.IntValue+g_CFBot_AttackTimeCvar.IntValue)) {
        g_CFireBotDucking[client] = !GetRandomInt(0, 1);
        g_CFBot_Time[client] = 0;
      }
      else g_CFBot_Time[client]++;
    } else {
      buttons &= ~IN_ATTACK;
      buttons &= ~IN_DUCK;
      // buttons &= ~IN_SPEED;
      if (g_CFBot_Time[client] == g_CFBot_ReactTimeCvar.IntValue - g_CFBot_MoveDistanceCvar.IntValue) { // the bot will be moving CFBot_MOVEDISTANCE frames
        g_CFireBotMovingRight[client] = !GetRandomInt(0, 1);
        g_CFireBotDucking[client] = !GetRandomInt(0, 1);
        // g_CrossfireBotWalk[client] = GetRandomInt(0, 1);
      } else {
        if (g_CFBot_Time[client] > g_CFBot_ReactTimeCvar.IntValue - g_CFBot_MoveDistanceCvar.IntValue) { // while the bot is moving
          if (g_CFireBotMovingRight[client]) vel[1] = 250.0;
          else vel[1] = -250.0;
          if (g_CFireBotDucking[client]) buttons |= IN_DUCK;

          // if (g_CrossfireBotWalk[client]) buttons |= IN_SPEED;
          if (g_CFBot_Time[client] == g_CFBot_ReactTimeCvar.IntValue - g_CFBot_MoveDistanceCvar.IntValue + 5) { // just after the bot started moving to check if IS STUCK
            float fAbsVel[3];
            Entity_GetAbsVelocity(client, fAbsVel);
            if (GetVectorLength(fAbsVel) < 5.0) {
              // PrintToChatAll("block detected");
              // Jump to Attack Time ?
              // g_CFBot_Time[client] = g_CFBot_ReactTimeCvar.IntValue;
              // PrintToChatAll("direction changed from %s", g_CFireBotMovingRight[client] ? "right to left" : "left to right");
              g_CFireBotMovingRight[client] = !g_CFireBotMovingRight[client];
            }
          }
        } else {
          // unknown status (bot is standing?)
        }
      }
      g_CFBot_Time[client]++;
    }
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
  if (g_CrossfireBots.Length == 0) {
    EndSingleCrossfire(true);
  }
  return Plugin_Continue;
}

////////////////////////
////////COMMANDS////////
////////////////////////

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
