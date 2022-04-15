#define RETAKE_ID_LENGTH 16
#define RETAKE_NAME_LENGTH 128

int bombTicking;

int g_RKBot_Time[MAXPLAYERS + 1] = {0, ...};
int g_RetakeBotDirection[MAXPLAYERS + 1];
int g_RetakeBotDuck[MAXPLAYERS + 1];
// int g_RetakeBotWalk[MAXPLAYERS + 1];

int g_RetakeDeathPlayersCount = 0;

ArrayList g_RetakePlayers;
int g_RetakePlayers_Points[MAXPLAYERS + 1] = {0, ...};

ArrayList g_RetakeBots;
ArrayList g_RetakeRetakes;
char g_RetakePlayId[RETAKE_ID_LENGTH];

// editor
#define KV_BOTSPAWN "bot"
#define KV_PLAYERSPAWN "player"
#define KV_BOMBSPAWN "bomb"
#define KV_NADESPAWN "grenade"
ArrayList g_HoloRetakeEntities;
RetakeDifficulty g_RetakeDifficulty = RetakeDiff_Medium;

ConVar g_MaxRetakeBotsCvar;
ConVar g_MaxRetakePlayersCvar;

// NOTE: RKBOT_REACTTIME > RKBOT_MOVEDISTANCE && RKBOT_MOVEDISTANCE > 0
ConVar g_RKBot_ReactTimeCvar; // how long until he shoots
// NOTE: FULL TIME = REACTTIME + ATTACKTIME
ConVar g_RKBot_AttackTimeCvar; // usefull for sprays
ConVar g_RKBot_MoveDistanceCvar; // usefull for distance
ConVar g_RKBot_SpotMultCvar;

enum RetakeDifficulty {
  RetakeDiff_Easy = 0,
  RetakeDiff_Medium,
  RetakeDiff_Hard,
  RetakeDiff_VeryHard
}

public void Retakes_PluginStart() {
  g_HoloRetakeEntities = new ArrayList();
  g_RetakeRetakes = new ArrayList();
  g_RetakePlayers = new ArrayList();
  g_RetakeBots = new ArrayList();

  bombTicking = FindSendPropInfo("CPlantedC4", "m_bBombTicking");

  g_MaxRetakeBotsCvar = CreateConVar("sm_retake_max_bots", "6",
                              "How many retake bots spawn at max.", 0, true, 1.0, true, 10.0);
  g_MaxRetakePlayersCvar = CreateConVar("sm_retake_max_players", "2",
                              "How many retake players spawn at max.", 0, true, 1.0, true, 3.0);
  g_RKBot_SpotMultCvar = CreateConVar("sm_retake_spot_mult", "1.1",
                              "How many retake players spawn at max.", 0, true, 1.0, true, 2.0);
  g_RKBot_ReactTimeCvar = CreateConVar("sm_retake_react_time", "80",
                              "How many retake players spawn at max.", 0, true, 1.0, true, 2.0);
  g_RKBot_AttackTimeCvar = CreateConVar("sm_retake_attack_time", "30",
                              "How many retake players spawn at max.", 0, true, 1.0, true, 2.0);
  g_RKBot_MoveDistanceCvar = CreateConVar("sm_retake_move_distance", "60",
                              "How many retake players spawn at max.", 0, true, 1.0, true, 2.0);

  HookEvent("bomb_planted", Event_BombPlant);
  HookEvent("bomb_exploded", Event_BombExplode);
  HookEvent("bomb_defused", Event_BombDefuse);
}

stock void InitRetakes(int client) {
  if (g_InRetakeMode) {
    PM_Message(client, "{ORANGE}Retakes Ya Activo.");
    return;
  }
  // Get Retakes
  g_RetakeRetakes.Clear();
  int retakeCount = GetRetakesNextId();
  if (retakeCount > 0) {
    char iStr[RETAKE_ID_LENGTH];
    for (int i = 0; i < retakeCount; i++) {
      IntToString(i, iStr, RETAKE_ID_LENGTH);
      g_RetakeRetakes.PushString(iStr);
    }
    // Random Retakes
    SortADTArray(g_RetakeRetakes, Sort_Random, Sort_String);
  } else {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Zonas.");
    return;
  }
  // Setup Retake
  StartSingleRetake(client);
}

stock void StartSingleRetake(int client, int retakePos = 0) {
  g_RetakeDeathPlayersCount = 0;
  g_RetakeRetakes.GetString(retakePos, g_RetakePlayId, RETAKE_ID_LENGTH);
  char retakeName[RETAKE_NAME_LENGTH];
  GetRetakeName(g_RetakePlayId, retakeName, RETAKE_NAME_LENGTH);
  PM_Message(client, "{ORANGE}Empezando Retake: {PURPLE}%s", retakeName);

  // Get Bombs
  char nextSpawn[RETAKE_ID_LENGTH];
  GetRetakeSpawnsNextId(g_RetakePlayId, KV_BOMBSPAWN, nextSpawn, RETAKE_ID_LENGTH);
  int bombCount = StringToInt(nextSpawn);
  if (bombCount < 0) {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Spawns de Bombas.");
    return;
  }
  // Bomb Setup
  char randomSpawnId[RETAKE_ID_LENGTH];
  IntToString(GetRandomInt(0, bombCount-1), randomSpawnId, RETAKE_ID_LENGTH);
  float bombPosition[3];
  GetRetakeSpawnVectorKV(g_RetakePlayId, KV_BOMBSPAWN, randomSpawnId, "origin", bombPosition);
  PlantBomb(client, bombPosition);

  CreateTimer(0.2, Timer_StartRetake, GetClientSerial(client));
}

public Action Timer_StartRetake(Handle timer, int serial) {
  g_RetakePlayers.Clear();
  g_RetakeBots.Clear();

  int client = GetClientFromSerial(serial);
  g_RetakePlayers.Push(client);
  // Choose N random clients
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
      if (i == client) continue; // Already In ArrayList
      if (g_RetakePlayers.Length < g_MaxRetakePlayersCvar.IntValue) {
        g_RetakePlayers.Push(i);
      } else {
        ChangeClientTeam(i, CS_TEAM_SPECTATOR);
      }
    }
  }
  // PM_Message(client, "{ORANGE}%d jugadores conectados.", g_RetakePlayers.Length);

  // Get Bots
  char nextSpawn[RETAKE_ID_LENGTH];
  GetRetakeSpawnsNextId(g_RetakePlayId, KV_BOTSPAWN, nextSpawn, RETAKE_ID_LENGTH);
  // PM_Message(client, "{ORANGE}Cantidad de Bots: %s", nextSpawn);
  int botCount = StringToInt(nextSpawn);
  ArrayList enabledBots = new ArrayList(RETAKE_ID_LENGTH);
  if (botCount > 0) {
    char iStr[RETAKE_ID_LENGTH];
    for (int i = 0; i < botCount; i++) {
      IntToString(i, iStr, RETAKE_ID_LENGTH);
      enabledBots.PushString(iStr);
    }
    // Random Spawns
    SortADTArray(enabledBots, Sort_Random, Sort_String);
    // Clamp if above max bots
    if (botCount > g_MaxRetakeBotsCvar.IntValue) {
      // Take first max bots
      for (int i = enabledBots.Length - 1; i >= g_MaxRetakeBotsCvar.IntValue; i--) {
        enabledBots.Erase(i);
      }
      botCount = g_MaxRetakeBotsCvar.IntValue;
    }
  } else {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Spawns de Bots.");
    return Plugin_Handled;
  }

  // Bots Setup
  for (int i = 0; i < botCount; i++) {
    char randomSpawnId[RETAKE_ID_LENGTH];
    enabledBots.GetString(i, randomSpawnId, RETAKE_ID_LENGTH);
    ServerCommand("bot_quota_mode normal");
    ServerCommand("bot_add");
    DataPack pack;
    CreateDataTimer(0.2, Timer_GetRetakeBots, pack);
    pack.WriteString(randomSpawnId);
  }

  delete enabledBots;

  // Get Players
  GetRetakeSpawnsNextId(g_RetakePlayId, KV_PLAYERSPAWN, nextSpawn, RETAKE_ID_LENGTH);
  int playerCount = StringToInt(nextSpawn);
  ArrayList enabledPlayers = new ArrayList(RETAKE_ID_LENGTH);
  if (playerCount > 0) {
    char iStr[RETAKE_ID_LENGTH];
    for (int i = 0; i < playerCount; i++) {
      IntToString(i, iStr, RETAKE_ID_LENGTH);
      enabledPlayers.PushString(iStr);
    }
    // Random Spawns
    SortADTArray(enabledPlayers, Sort_Random, Sort_String);
    // Clamp if above max players
    if (playerCount >= g_MaxRetakePlayersCvar.IntValue) {
      // Take first max players
      for (int i = enabledPlayers.Length - 1; i >= g_MaxRetakePlayersCvar.IntValue; i--) {
        PM_Message(client, "{ORANGE}borrando: %d", i);
        enabledPlayers.Erase(i);
      }
      playerCount = g_MaxRetakePlayersCvar.IntValue;
    }
  } else {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Spawns de Jugadores.");
    return Plugin_Handled;
  }

  // Players Setup
  for (int i = 0; i < g_RetakePlayers.Length; i++) {
    char randomSpawnId[RETAKE_ID_LENGTH];
    enabledPlayers.GetString(i, randomSpawnId, RETAKE_ID_LENGTH);
    float origin[3], angles[3];
    GetRetakeSpawnVectorKV(g_RetakePlayId, KV_PLAYERSPAWN, randomSpawnId, "origin", origin);
    GetRetakeSpawnVectorKV(g_RetakePlayId, KV_PLAYERSPAWN, randomSpawnId, "angles", angles);
    int player = g_RetakePlayers.Get(i);
    ChangeClientTeam(player, CS_TEAM_CT);
    SetEntityMoveType(player, MOVETYPE_WALK);
    TeleportEntity(player, origin, angles, ZERO_VECTOR);
  }

  delete enabledPlayers;

  // Success
  SetCvarIntSafe("mp_forcecamera", 0);
  SetCvarIntSafe("mp_radar_showall", 0);
  SetCvarIntSafe("sm_glow_pmbots", 0);
  SetCvarIntSafe("mp_ignore_round_win_conditions", 0);
  SetCvarIntSafe("sv_grenade_trajectory", 0);
  SetCvarIntSafe("sv_infinite_ammo", 2);
  SetCvarIntSafe("sm_allow_noclip", 0);
  SetCvarIntSafe("mp_respawn_on_death_ct", 0);
  SetCvarIntSafe("mp_respawn_on_death_t", 0);
  SetCvarIntSafe("sv_showimpacts", 0);
  SetCvarIntSafe("sm_holo_spawns", 0);
  SetCvarIntSafe("sm_bot_collision", 1);
  g_InRetakeMode = true;
  return Plugin_Handled;
}

public Action Timer_GetRetakeBots(Handle timer, DataPack pack) {
  pack.Reset();
  char spawnId[RETAKE_ID_LENGTH];
  pack.ReadString(spawnId, RETAKE_ID_LENGTH);
  
  int bot = GetLiveBot(CS_TEAM_T);
  if (bot < 0) {
    return Plugin_Handled;
  }

  char name[MAX_NAME_LENGTH];
  GetClientName(bot, name, MAX_NAME_LENGTH);
  Format(name, MAX_NAME_LENGTH, "[RETAKE]%s", name);
  SetClientName(bot, name);
  g_IsRetakeBot[bot] = true;
  g_RetakeBots.Push(bot);

  // Weapons
  Client_RemoveAllWeapons(bot);
  switch(g_RetakeDifficulty) {
    case RetakeDiff_Easy: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), false);
      Client_SetArmor(bot, 100);
    }
    case RetakeDiff_Medium: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case RetakeDiff_Hard: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
  }

  float botOrigin[3], botAngles[3];
  GetRetakeSpawnVectorKV(g_RetakePlayId, KV_BOTSPAWN, spawnId, "origin", botOrigin);
  GetRetakeSpawnVectorKV(g_RetakePlayId, KV_BOTSPAWN, spawnId, "angles", botAngles);
  TeleportEntity(bot, botOrigin, botAngles, ZERO_VECTOR);
  // SetEntPropFloat(bot, Prop_Data, "m_flLaggedMovementValue", 0.0);

  return Plugin_Handled;
}

public void EndSingleRetake(bool win) {
  ServerCommand("bot_kick");
  g_RetakeBots.Clear();
  char retakeName[RETAKE_NAME_LENGTH];
  GetRetakeName(g_RetakePlayId, retakeName, RETAKE_NAME_LENGTH);
  for (int i = 0; i < g_RetakePlayers.Length; i++) {
    int player = g_RetakePlayers.Get(i);
    if (win) {
      EmitSoundToClient(player, "ui/achievement_earned.wav", _, _, SNDLEVEL_ROCKET);
      PM_Message(player, "{GREEN}===============================");
      PM_Message(player, "{ORANGE}Retake {PURPLE}%s {ORANGE}Ganado.", retakeName);
      PM_Message(player, "{GREEN}===============================");
      if (i == 0) {
        // go to next retake
        int currentRetakeIndex = g_RetakeRetakes.FindString(g_RetakePlayId);
        if (currentRetakeIndex < g_RetakeRetakes.Length - 1) {
          currentRetakeIndex++;
          StartSingleRetake(i, currentRetakeIndex);
        } else {
          StopRetakesMode();
        }
      }
    } else {
      EmitSoundToClient(player, "ui/armsrace_demoted.wav", _, _, SNDLEVEL_ROCKET);
      PM_Message(player, "{GREEN}===============================");
      PM_Message(player, "{ORANGE}Retake {PURPLE}%s {ORANGE}Perdido.", retakeName);
      PM_Message(player, "{GREEN}===============================");
      if (i == 0) {
        // repeat round
        int currentRetakeIndex = g_RetakeRetakes.FindString(g_RetakePlayId);
        StartSingleRetake(player, currentRetakeIndex);
      }
    }
  }
  g_RetakeDeathPlayersCount = 0;
}

public void StopRetakesMode() {
  GameRules_SetProp("m_bBombPlanted", 0);
  ServerCommand("bot_kick");
  // ServerCommand("mp_restartgame 1"); // test
  g_RetakePlayers.Clear();
  g_RetakeBots.Clear();
  g_RetakeRetakes.Clear();
  g_InRetakeMode = false;
  
  SetConVarFloatSafe("mp_roundtime_defuse", 60.0);
  SetCvarIntSafe("mp_forcecamera", 2);
  SetCvarIntSafe("mp_radar_showall", 1);
  SetCvarIntSafe("sm_glow_pmbots", 1);
  SetCvarIntSafe("mp_ignore_round_win_conditions", 1);
  SetCvarIntSafe("sv_grenade_trajectory", 1);
  SetCvarIntSafe("sv_infinite_ammo", 1);
  SetCvarIntSafe("sm_allow_noclip", 1);
  SetCvarIntSafe("mp_respawn_on_death_ct", 1);
  SetCvarIntSafe("mp_respawn_on_death_t", 1);
  SetCvarIntSafe("sv_showimpacts", 1);
  SetCvarIntSafe("sm_holo_spawns", 1);
  SetCvarIntSafe("sm_bot_collision", 0);
  g_RetakeDeathPlayersCount = 0;
}

// TODO: Use Timer for calculating the closest player, store it in global -> g_retakeBotTarget[bot] = me
public Action RetakeBot_PlayerRunCmd(int client, int &buttons, float vel[3], float angles[3], int &weapon) {
  if (!g_InRetakeMode) {
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
  for (int i = 0; i < g_RetakePlayers.Length; i++) {
    int target = g_RetakePlayers.Get(i);
    if (IsPlayer(target)) {
      if (!IsPlayerAlive(target)) {
        continue;
      }
      distance = Entity_GetDistance(client, target);
      if (distance > nearestDistance && nearestDistance > -1.0) {
        continue;
      }
      if (!IsAbleToSee(client, target)) {
        if (distance < 500.0) {
          nearestNonVisibleTarget = -1; //target
        }
        continue;
      }
      // if (!ClientCanSeeClient(client, target)) {
      //   if (distance < 500.0) {
      //     nearestNonVisibleTarget = target;
      //   }
      //   continue;
      // }
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
    // bot will stop and attack every g_RKBot_ReactTimeCvar.IntValue frames
    if (g_RKBot_Time[client] >= g_RKBot_ReactTimeCvar.IntValue &&
        g_RKBot_Time[client] <= (g_RKBot_ReactTimeCvar.IntValue+g_RKBot_AttackTimeCvar.IntValue)) { // bot will attack for (2 + 1) frames
      vel[1] = 0.0;
      if (nearestTarget == -1 && nearestNonVisibleTarget > 0) {
        // doesnt see anybody but has a close target
      }
      buttons |= IN_ATTACK;
      // buttons &= ~IN_SPEED;
      if (g_RKBot_Time[client] == (g_RKBot_ReactTimeCvar.IntValue+g_RKBot_AttackTimeCvar.IntValue)) {
        g_RetakeBotDuck[client] = GetRandomInt(0, 1);
        g_RKBot_Time[client] = 0;
      }
      else g_RKBot_Time[client]++;
    } else {
      buttons &= ~IN_ATTACK;
      buttons &= ~IN_DUCK;
      // buttons &= ~IN_SPEED;
      if (g_RKBot_Time[client] == g_RKBot_ReactTimeCvar.IntValue - g_RKBot_MoveDistanceCvar.IntValue) { // the bot will be moving RKBOT_MOVEDISTANCE frames
        g_RetakeBotDirection[client] = GetRandomInt(0, 1);
        g_RetakeBotDuck[client] = GetRandomInt(0, 1);
        // g_RetakeBotWalk[client] = GetRandomInt(0, 1);
      } else {
        if (g_RKBot_Time[client] > g_RKBot_ReactTimeCvar.IntValue - g_RKBot_MoveDistanceCvar.IntValue) { // while the bot is moving
          if (g_RetakeBotDirection[client] == 1) vel[1] = 250.0;
          else vel[1] = -250.0;
          if (g_RetakeBotDuck[client] == 1) buttons |= IN_DUCK;

          // if (g_RetakeBotWalk[client]) buttons |= IN_SPEED;
          if (g_RKBot_Time[client] == g_RKBot_ReactTimeCvar.IntValue - g_RKBot_MoveDistanceCvar.IntValue + 5) { // just after the bot started moving to check if IS STUCK
            float fAbsVel[3];
            Entity_GetAbsVelocity(client, fAbsVel);
            if (GetVectorLength(fAbsVel) < 5.0) {
              // PrintToChatAll("block detected");
              // Jump to Attack Time ?
              // g_RKBot_Time[client] = g_RKBot_ReactTimeCvar.IntValue;
              // PrintToChatAll("direction changed from %d to %d", g_RetakeBotDirection[client], 1 - g_RetakeBotDirection[client]);
              g_RetakeBotDirection[client] = 1 - g_RetakeBotDirection[client];
            }
          }
        } else {
          // unknown status (bot is standing?)
        }
      }
      g_RKBot_Time[client]++;
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

//////////////////////
////////EVENTS////////
//////////////////////

public Action Event_BombPlant(Event event, const char[] name, bool dontBroadcast) {
  // go to next retake

  return Plugin_Continue;
}

public Action Event_BombExplode(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InRetakeMode) {
    return Plugin_Continue;
  }
  EndSingleRetake(false);
  return Plugin_Continue;
}

public Action Event_BombDefuse(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InRetakeMode) {
    return Plugin_Continue;
  }
  EndSingleRetake(true);
  return Plugin_Continue;
}

public Action Event_Retakes_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  return Plugin_Continue;
}

// This Always get Executed when finished a Retake
public Action Event_Retakes_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  // EndSingleRetake();
  return Plugin_Continue;
}

public Action Event_RetakeBot_Death(int victim, Event event, const char[] name, bool dontBroadcast) {
  // TODO: Respawn in next pos?
  int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
  if (!IsValidClient(killer) || killer == victim) {
    return Plugin_Continue;
  }
  int index = -1;
  if((index = g_RetakeBots.FindValue(victim)) != -1) {
    int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
    CreateTimer(0.5, Timer_RemoveRagdoll, EntIndexToEntRef(ragdoll), TIMER_FLAG_NO_MAPCHANGE);
    g_RKBot_Time[index] = 0;
    if (g_RetakePlayers.FindValue(killer) != -1) {
      g_RetakePlayers_Points[killer] += 5; // 5 points per kill
    }
    g_RetakeBots.Erase(index);
  }
  // if (g_RetakeBots.Length == 0) {
  //   // all bots are dead
  // }
  return Plugin_Continue;
}

////////////////////////
////////COMMANDS////////
////////////////////////

public Action Command_RetakesSetupMenu(int client, int args) {
  if (!IsPlayer(client)) {
    return Plugin_Handled;
  }
  RetakesSetupMenu(client);
  return Plugin_Handled;
}

public Action Command_RetakesEditorMenu(int client, int args) {
  if (g_InRetakeMode) {
    PM_Message(client, "{ORANGE}Retake Ya Empezado.");
    return Plugin_Continue;
  }
  if (!IsRetakesEditor(client)) {
    PM_Message(client, "{ORANGE}No tienes permisos de editor.");
    return Plugin_Handled;
  }
  PM_Message(client, "{ORANGE}Modo Edición Activado.");
  RetakesEditorMenu(client);
  return Plugin_Handled;
}

public bool IsRetakesEditor(int client) {
  return true;
}

public bool IsRetakeBot(int client) {
  return client > 0 && g_IsRetakeBot[client] && IsClientInGame(client) && IsFakeClient(client);
}

/////////////////////
////////UTILS////////
/////////////////////

public void PlantBomb(int client, float bombPosition[3]) {
  int bombEntity = CreateEntityByName("planted_c4");
  // TODO: save bombEntity as global ent?
  GameRules_SetProp("m_bBombPlanted", 1);
  SetEntData(bombEntity, bombTicking, 1, 1, true);
  Event event = CreateEvent("bomb_planted");
  if (event != null) {
    event.SetInt("userid", GetClientUserId(client));
    event.SetInt("site", GetNearestBombsite(bombPosition));
    event.Fire();
  }

  if (DispatchSpawn(bombEntity)) {
    ActivateEntity(bombEntity);

    SendVectorToGround(bombPosition);
    TeleportEntity(bombEntity, bombPosition, NULL_VECTOR, NULL_VECTOR)
  }
  else {
    CS_TerminateRound(1.0, CSRoundEnd_Draw);
  }
}

stock int GetNearestBombsite(float start[3]) {
  int playerResource = GetPlayerResourceEntity();
  if (playerResource == -1) {
    return -1;
  }

  float aCenter[3], bCenter[3];
  GetEntPropVector(playerResource, Prop_Send, "m_bombsiteCenterA", aCenter);
  GetEntPropVector(playerResource, Prop_Send, "m_bombsiteCenterB", bCenter);
  float aDist = GetVectorDistance(aCenter, start, true);
  float bDist = GetVectorDistance(bCenter, start, true);
  if (aDist < bDist) {
    return 0; //A
  }
  
  return 1; //B
}

public bool IsAbleToSee(int entity, int client) {
  // Skip all traces if the player isn't within the field of view.
  // - Temporarily disabled until eye angle prediction is added.
  // if (IsInFieldOfView(g_vEyePos[client], g_vEyeAngles[client], g_vAbsCentre[entity]))
  
  float vecOrigin[3], vecEyePos[3];
  GetClientAbsOrigin(entity, vecOrigin);
  GetClientEyePosition(client, vecEyePos);
  
  // Check if centre is visible.
  if (IsPointVisible(vecEyePos, vecOrigin)) {
      return true;
  }
  
  float vecEyePos_ent[3], vecEyeAng[3];
  GetClientEyeAngles(entity, vecEyeAng);
  GetClientEyePosition(entity, vecEyePos_ent);
  
  float mins[3], maxs[3];
  GetClientMins(client, mins);
  GetClientMaxs(client, maxs);
  // Check outer 4 corners of player.
  if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, g_RKBot_SpotMultCvar.FloatValue)) {
      return true;
  }

  // Check if weapon tip is visible.
  // if (IsFwdVecVisible(vecEyePos, vecEyeAng, vecEyePos_ent)) {
  //     return true;
  // }

  // // Check outer 4 corners of player.
  // if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, 1.30)) {
  //     return true;
  // }
  // // Check inner 4 corners of player.
  // if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, 0.65)) {
  //     return true;
  // }

  return false;
}

/*stock bool IsFwdVecVisible(const float start[3], const float angles[3], const float end[3]) {
  float fwd[3];
  GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
  ScaleVector(fwd, 50.0);
  AddVectors(end, fwd, fwd);

  return IsPointVisible(start, fwd);
}*/

stock bool IsRectangleVisible(const float start[3], const float end[3], const float mins[3], const float maxs[3], float scale=1.0) {
  float ZpozOffset = maxs[2];
  float ZnegOffset = mins[2];
  float WideOffset = ((maxs[0] - mins[0]) + (maxs[1] - mins[1])) / 4.0;

  // This rectangle is just a point!
  if (ZpozOffset == 0.0 && ZnegOffset == 0.0 && WideOffset == 0.0) {
      return IsPointVisible(start, end);
  }

  // Adjust to scale.
  // ZpozOffset *= scale;
  // ZnegOffset *= scale;
  WideOffset *= scale;
  
  // Prepare rotation matrix.
  float angles[3], fwd[3], right[3];

  SubtractVectors(start, end, fwd);
  NormalizeVector(fwd, fwd);

  GetVectorAngles(fwd, angles);
  GetAngleVectors(angles, fwd, right, NULL_VECTOR);

  float vRectangle[4][3], vTemp[3];

  // If the player is on the same level as us, we can optimize by only rotating on the z-axis.
  if (FloatAbs(fwd[2]) <= 0.7071) {
    ScaleVector(right, WideOffset);
    // Corner 1, 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vRectangle[0]);
    SubtractVectors(vTemp, right, vRectangle[1]);
    // Corner 3, 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vRectangle[2]);
    SubtractVectors(vTemp, right, vRectangle[3]);
  } else if (fwd[2] > 0.0) { // Player is below us.
    fwd[2] = 0.0;
    NormalizeVector(fwd, fwd);
    
    ScaleVector(fwd, scale);
    ScaleVector(fwd, WideOffset);
    ScaleVector(right, WideOffset);
    
    // Corner 1
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[0]);
    
    // Corner 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    SubtractVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[1]);
    
    // Corner 3
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[2]);
    
    // Corner 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    SubtractVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[3]);
  } else { // Player is above us.
    fwd[2] = 0.0;
    NormalizeVector(fwd, fwd);
    
    ScaleVector(fwd, scale);
    ScaleVector(fwd, WideOffset);
    ScaleVector(right, WideOffset);

    // Corner 1
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[0]);
    
    // Corner 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    SubtractVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[1]);
    
    // Corner 3
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[2]);
    
    // Corner 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    SubtractVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[3]);
  }

  // Run traces on all corners.
  for (new i = 0; i < 4; i++) {
    if (IsPointVisible(start, vRectangle[i])) {
        return true;
    }
  }

  return false;
}
