#define RETAKE_ID_LENGTH 16
#define RETAKE_NAME_LENGTH 128

#define MAX_RETAKE_PLAYERS 2
#define MAX_RETAKE_BOTS 5
bool g_InRetakeMode;
ArrayList g_RetakePlayers;
ArrayList g_RetakeBots;
char g_RetakePlayId[RETAKE_ID_LENGTH];

// editor
#define KV_BOTSPAWN "bot"
#define KV_NADESPAWN "grenade"
#define KV_PLAYERSPAWN "player"
KeyValues g_RetakesKv = null;
ArrayList g_HoloRetakeEntities;
RetakeDifficulty g_RetakeDifficulty = RetakeDiff_Medium;

enum RetakeDifficulty {
  RetakeDiff_Easy = 0,
  RetakeDiff_Medium,
  RetakeDiff_Hard,
  RetakeDiff_VeryHard
}

public void Retakes_PluginStart() {
  g_HoloRetakeEntities = new ArrayList();
  g_RetakePlayers = new ArrayList();
  g_RetakeBots = new ArrayList();
}

public void Retakes_MapStart() {
  delete g_RetakesKv;
  g_RetakesKv = new KeyValues("Retakes");
  // g_RetakesKv.SetEscapeSequences(true); // Avoid fatals from special chars in user data

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  char retakesFile[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, retakesFile, sizeof(retakesFile),
            "data/practicemode/retakes/%s.cfg", map);
  g_RetakesKv.ImportFromFile(retakesFile);
}

public void Retakes_MapEnd() {
  char dir[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, dir, sizeof(dir), "data/practicemode/retakes");
  if (!DirExists(dir)) {
    if (!CreateDirectory(dir, 511))
      LogError("Failed to create directory %s", dir);
  }

  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  char path[PLATFORM_MAX_PATH];
  Format(path, sizeof(path), "%s/%s.cfg", dir, mapName);

  DeleteFile(path);
  if (!g_RetakesKv.ExportToFile(path)) {
    LogError("Failed to write spawn names to %s", path);
  }
  RemoveHoloRetakeEntities();
}

// Use Timer instead
public Action RetakeBot_PlayerRunCmd(int client, int &buttons, float vel[3], float angles[3], int &weapon) {
  if (!g_InRetakeMode) {
    return Plugin_Continue;
  }
  int targetPlayer;
  targetPlayer = GetClosestPlayer(client, true);
  if (targetPlayer > 0) {
    float clientEyepos[3], viewTarget[3];
    GetClientEyePosition(client, clientEyepos);
    GetClientEyePosition(targetPlayer, viewTarget);
    SubtractVectors(viewTarget, clientEyepos, viewTarget);
    GetVectorAngles(viewTarget, viewTarget);
    TeleportEntity(client, NULL_VECTOR, viewTarget, NULL_VECTOR);
  }
  return Plugin_Continue;
}

public Action Command_RetakesSetupMenu(int client, int args) {
  if (!IsPlayer(client)) {
    return Plugin_Handled;
  }
  RetakesSetupMenu(client);
  return Plugin_Handled;
}

public void StartRetakes(int client) {
  if (g_InRetakeMode) {
    PM_Message(client, "{ORANGE}Retake Ya Empezado.")
    return;
  }
  // Choose random RetakeId
  int retakeCount = GetRetakesNextId() - 1;
  if (retakeCount < 0) {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Zonas.");
    return;
  } else {
    IntToString(GetRandomInt(0, retakeCount), g_RetakePlayId, sizeof(g_RetakePlayId));
  }
  char retakeName[RETAKE_NAME_LENGTH];
  GetRetakeName(g_RetakePlayId, retakeName, RETAKE_NAME_LENGTH);
  PM_Message(client, "{ORANGE}Empezando Retake: {PURPLE}%s", retakeName);

  g_RetakePlayers.Push(client);

  // Choose N random clients
  for (int i = 0; i <= MAXPLAYERS; i++) {
    if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
      if (i == client) continue; // Already In ArrayList
      if (g_RetakePlayers.Length < MAX_RETAKE_PLAYERS) {
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
    // Random Spawns if above max bots
    if (botCount > MAX_RETAKE_BOTS) {
      SortADTArray(enabledBots, Sort_Random, Sort_String);
      // Take first max bots
      for (int i = enabledBots.Length - 1; i >= MAX_RETAKE_BOTS; i--) {
        enabledBots.Erase(i);
      }
      botCount = MAX_RETAKE_BOTS;
    }
  } else {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Bots.");
    return;
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

  // Players Setup
  for (int i = 0; i < g_RetakePlayers.Length; i++) {
    char spawnId[RETAKE_ID_LENGTH];
    IntToString(i, spawnId, RETAKE_ID_LENGTH);
    float origin[3], angles[3];
    GetRetakeSpawnVectorKV(g_RetakePlayId, KV_PLAYERSPAWN, spawnId, "origin", origin);
    GetRetakeSpawnVectorKV(g_RetakePlayId, KV_PLAYERSPAWN, spawnId, "angles", angles);
    int player = g_RetakePlayers.Get(i);
    TeleportEntity(player, origin, angles, {0.0,0.0,0.0});
    SetEntPropFloat(player, Prop_Data, "m_flLaggedMovementValue", 0.0);
  }

  // Success
  g_InRetakeMode = true;
}

public Action Timer_GetRetakeBots(Handle timer, DataPack pack) {
  pack.Reset();
  char spawnId[RETAKE_ID_LENGTH];
  pack.ReadString(spawnId, RETAKE_ID_LENGTH);
  int largestUserid = -1;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && IsFakeClient(i) && !IsClientSourceTV(i)) {
      int userid = GetClientUserId(i);
      if (userid > largestUserid && !g_IsRetakeBot[i]) {
        largestUserid = userid;
      }
    }
  }
  if (largestUserid == -1) {
    LogError("(Timer_GetRetakeBots->largestUserid) Error getting bot %s from %s", spawnId, g_RetakePlayId);
    return Plugin_Handled;
  }
  int bot = GetClientOfUserId(largestUserid);
  if (!IsValidClient(bot)) {
    LogError("(Timer_GetRetakeBots->IsValidClient) Error getting bot %s from %s", spawnId, g_RetakePlayId);
    return Plugin_Handled;
  }
  char name[MAX_NAME_LENGTH];
  GetClientName(bot, name, MAX_NAME_LENGTH);
  Format(name, MAX_NAME_LENGTH, "[RETAKE]%s", name);
  SetClientName(bot, name);
  g_IsRetakeBot[bot] = true;
  g_RetakeBots.Push(bot);
  ChangeClientTeam(bot, CS_TEAM_T);
  KillBot(bot);
  CS_RespawnPlayer(bot);

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
  TeleportEntity(bot, botOrigin, botAngles, {0.0,0.0,0.0});
  SetEntPropFloat(bot, Prop_Data, "m_flLaggedMovementValue", 0.0);

  return Plugin_Handled;
}

public void StopRetakes() {
  ServerCommand("bot_kick");
  g_RetakePlayers.Clear();
  g_RetakeBots.Clear();
  g_InRetakeMode = false;
}

public void RetakesSetupMenu(int client) {
  Menu menu = new Menu(RetakesSetupMenuHandler);

  menu.SetTitle("Opciones De Retake");
  // menu.AddItem("togglerepeat", "Repetir: %");
  // menu.AddItem("togglerandom", "RandomWeapons: %");
  // menu.AddItem("togglezone", "");
  // menu.AddItem("start", "");
  menu.AddItem("start", "Empezar Retakes");
  menu.AddItem("stop", "Salir de Retakes");
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int RetakesSetupMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if(action == MenuAction_Select) {
    char buffer[128];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "start")) {
      StartRetakes(client);
    } else if (StrEqual(buffer, "stop")) {
      StopRetakes();
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public Action Command_RetakesEditorMenu(int client, int args) {
  if (!IsRetakesEditor(client)) {
    PM_Message(client, "No tienes permisos de editor.");
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
