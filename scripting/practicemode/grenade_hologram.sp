#define ASSET_SMOKEMODEL "models/weapons/w_eq_smokegrenade_dropped.mdl"
#define ASSET_MOLOTOVMODEL "models/weapons/w_eq_molotov_dropped.mdl"
#define ASSET_INCENDIARYMODEL "models/weapons/w_eq_incendiarygrenade_dropped.mdl"
#define ASSET_HEMODEL "models/weapons/w_eq_fraggrenade_dropped.mdl"
#define ASSET_FLASHMODEL "models/weapons/w_eq_flashbang_dropped.mdl"
//*height is 64, crouch is 46: https://developer.valvesoftware.com/wiki/Dimensions#Eyelevel
#define GRENADEMODEL_HEIGHT 32.0
#define GRENADEMODEL_SCALE 4.0
//max distance where 2 saved nades could group "inside" a single ent in a list menu
#define MAX_NADE_GROUP_DISTANCE 150.0
// TOO LONG
#define MAX_NADE_INTERACT_DISTANCE 80.0
#define BUTTON_PLAYER_NOCLIP_DIST 84.0
#define GRENADE_COLOR_SMOKE "55 235 19"
#define GRENADE_COLOR_FLASH "87 234 247"
#define GRENADE_COLOR_MOLOTOV "255 161 46"
#define GRENADE_COLOR_HE "250 7 7"
#define GRENADE_COLOR_DEFAULT "180 180 180"

#define MAX_GRENADES_IN_GROUP 15 //its actually 14, 0 is the ent, 1 is grenadeId of ent; 2,3,4,...14 are the grenades inside this

ArrayList g_HoloNadeEntities;
// ArrayList g_HoloGrenadeIds;

//reset settings and hook
public void HoloNade_PluginStart() {
  g_HoloNadeEntities = new ArrayList(MAX_GRENADES_IN_GROUP);
}

public void HoloNade_MapStart() {

  PrecacheModel(ASSET_SMOKEMODEL, true);
  PrecacheModel(ASSET_MOLOTOVMODEL, true);
  PrecacheModel(ASSET_HEMODEL, true);
  PrecacheModel(ASSET_FLASHMODEL, true);
}

public void HoloNade_MapEnd() {
  RemoveHoloNadeEntities();
}

// check
// it updates everytime a player (or bot)? joins the server
public void HoloNade_ClientPutInServer(int client) {
  InitHoloNadeEntities();
}

public void HoloNade_LaunchPracticeMode() {
  // This gate is a workaround to prevent unexpected destruction of our entities during server initialization.
  // (The workaround is to wait until after initialization to make our entities.)
  if (!IsServerEmpty()) {
    InitHoloNadeEntities();
  }
}

public void HoloNade_ExitPracticeMode() {
  RemoveHoloNadeEntities();
}

// check
// why not use the same function
public void HoloNade_GrenadeKvMutate() {
  UpdateHoloNadeEntities();
}

public void HoloNade_EntityDestroyed(int entity) {
  if (entity == -1) {
    // Not sure what the cause is for this, but it does happen sometimes, and it's not valid for us.
    // No evident reason to log it though.
    return;
  }
  char classname[128];
  GetEntityClassname(entity, classname, sizeof(classname));
  if (!strcmp(classname, "prop_dynamic_override") || !strcmp(classname, "func_rot_button")) {
    for(int i = 0; i < g_HoloNadeEntities.Length; i++) {
      int NadeGroup[MAX_GRENADES_IN_GROUP] = {-1, ...};
      g_HoloNadeEntities.GetArray(i, NadeGroup, sizeof(NadeGroup));
      if (NadeGroup[0] == entity) {
        PrintToServer("CSGO is destroying hologram entity %i but we are retaining it. Expecting to fix at next round_start.", entity);
        g_HoloNadeEntities.Erase(i);
        return;
      }
    }
  }
}

public Action NadeDemoBot_PlayerRunCmd(int client, int &buttons, float vel[3], float angles[3], int &weapon) {
  if (!IsPlayerAlive(client)) {
    return Plugin_Continue;
  }
  if (BotMimic_IsPlayerMimicing(client)) {
    // So when stops mimicing doesnt look away
    GetClientEyeAngles(client, g_BotSpawnAngles[client]);
    return Plugin_Continue;
  }
  TeleportEntity(client, NULL_VECTOR, g_BotSpawnAngles[client], NULL_VECTOR);
  return Plugin_Continue;
}

//https://stackoverflow.com/questions/47932955/how-to-check-if-a-3d-point-is-inside-a-cylinder
public bool PointInsideViewRange(float q[3], float p1[3], float p2[3]) {
  float auxDistVector[3], dirVector[3];
  SubtractVectors(p2, p1, dirVector);
  SubtractVectors(q, p2, auxDistVector);
  if (GetVectorDotProduct(auxDistVector, dirVector) > 0.0) {
    return false;
  }
  SubtractVectors(q, p1, auxDistVector);
  if (GetVectorDotProduct(auxDistVector, dirVector) < 0.0) {
    return false;
  }
  GetVectorCrossProduct(auxDistVector, dirVector, auxDistVector);
  float radius = 15.0;
  if ((GetVectorLength(auxDistVector)/GetVectorLength(dirVector)) > radius)
    return false;
  return true;
}

public void InitHoloNadeEntities() {
  if (g_InPracticeMode && !g_InRetakeMode && !g_HoloNadeEntities.Length) {
    UpdateHoloNadeEntities();
  }
}

public void UpdateHoloNadeEntities() {
  RemoveHoloNadeEntities();
  UpdateHoloNadeEntities_Iterator();
}

// public bool IsHoloNadeLoaded(const char[] grenadeIdStr) {
//   int grenadeId = StringToInt(grenadeIdStr);
//   for (int i = 0; i < g_HoloNadeEntities.Length; i++) {
//     for (int j = 1; j < MAX_GRENADES_IN_GROUP; j++) {
//       int value = g_HoloNadeEntities.Get(i, j)
//       if (value == grenadeId) {
//         // Exists already
//         return true;
//       }
//       if (value == -1) {
//         // Go To Next Group
//         break;
//       }
//     }
//   }
//   return false;
// }

public void UpdateHoloNadeEntities_Iterator() {
  char ownerAuth[AUTH_LENGTH];
  char grenadeId[GRENADE_ID_LENGTH];
  char grenadeTypeString[32];
  float grenadeDetonationOrigin[3];
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    do {
      g_GrenadeLocationsKv.GetSectionName(ownerAuth, sizeof(ownerAuth));
      if (g_EnabledHoloNadeAuth.FindString(ownerAuth) == -1) {
        continue;
      }
      // Inner iteration by grenades for a user.
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          g_GrenadeLocationsKv.GetSectionName(grenadeId, sizeof(grenadeId));
          g_GrenadeLocationsKv.GetString("grenadeType", grenadeTypeString, sizeof(grenadeTypeString));
          g_GrenadeLocationsKv.GetVector("grenadeDetonationOrigin", grenadeDetonationOrigin);
          GrenadeType type = GrenadeTypeFromString(grenadeTypeString);

          float projectedOrigin[3];
          AddVectors(grenadeDetonationOrigin, view_as<float>({0.0, 0.0, GRENADEMODEL_HEIGHT}), projectedOrigin);
          
          if (type == GrenadeType_Molotov || type == GrenadeType_Incendiary) {
            SendVectorToGround(projectedOrigin);
            projectedOrigin[2] += GRENADEMODEL_HEIGHT;
          } else if (type == GrenadeType_Flash)
            projectedOrigin[2] -= GRENADEMODEL_SCALE*5.5; //set to middle

          CreateHoloNadeGroup(projectedOrigin, type, grenadeId);
        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }
    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
  }
}

public int CreateHoloNadeGroup(const float origin[3], const GrenadeType type, const char[] grenadeID) {
  int GroupEnts[MAX_GRENADES_IN_GROUP] = {-1, ...};
  float distance;
  int NearestGroupIndex = GetAvailableNadeGroupIndex(origin, type, distance);
  if (NearestGroupIndex > -1 && (distance <= MAX_NADE_GROUP_DISTANCE)) {
    // Exists and is near
    // dont spawn, group in that location
    g_HoloNadeEntities.GetArray(NearestGroupIndex, GroupEnts, sizeof(GroupEnts));
    //i = 1,2,3... only saves the grenadeIds, i=0 saves the spawned entity index, i=1 is grenadeId of the entity
    for (int i = 2; i < MAX_GRENADES_IN_GROUP; i++) {
      if(GroupEnts[i] == -1) {
        //saves the grenadeId in the next aviable spot ( = -1 )
        GroupEnts[i] = StringToInt(grenadeID);
        g_HoloNadeEntities.SetArray(NearestGroupIndex, GroupEnts, sizeof(GroupEnts));
        return NearestGroupIndex;
      }
    }
    //cant represent more grenades with a single entity (MAX_GRENADES_IN_GROUP)
  }

  // Only spawn this nade
  int ent = CreateHoloNadeEnt(origin, type, grenadeID);
  GroupEnts[0] = ent;
  GroupEnts[1] = StringToInt(grenadeID);
  return g_HoloNadeEntities.PushArray(GroupEnts, sizeof(GroupEnts));
}

public int CreateHoloNadeEnt(const float origin[3], const GrenadeType type, const char[] grenadeID) {
  char color[16];
  GetHoloNadeColorFromType(type, color);

  char grenadeModel[50];
  GetGrenadeModelFromType(type, grenadeModel);

  int ent = CreateEntityByName("prop_dynamic_override");
  if (ent != -1) {
    DispatchKeyValue(ent, "classname", "prop_dynamic_override");
    DispatchKeyValue(ent, "spawnflags", "1"); 
    DispatchKeyValue(ent, "renderamt", "255");
    DispatchKeyValue(ent, "rendermode", "1"); 
    DispatchKeyValue(ent, "rendercolor", color);
    char targetName[GRENADE_NAME_LENGTH];
    GrenadeTypeString(type, targetName, sizeof(targetName));
    DispatchKeyValue(ent, "targetname", targetName);
    DispatchKeyValue(ent, "model", grenadeModel);
    if (!DispatchSpawn(ent)) {
      return -1;
    }
    SetEntPropFloat(ent, Prop_Send, "m_flModelScale", GRENADEMODEL_SCALE);
    if (type == GrenadeType_Molotov)
      SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 3.1);
    TeleportEntity(ent, origin, NULL_VECTOR, NULL_VECTOR);
    // Hack: reuse this prop for storing grenade ID.
    SetEntProp(ent, Prop_Send, "m_iTeamNum", StringToInt(grenadeID, 10));
    SetEntProp(ent, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(ent, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(ent, Prop_Send, "m_flGlowMaxDist", 2500.0);
    SetGlowColor(ent, color);
    return ent;
  }
  return -1;
}

public int GetAvailableNadeGroupIndex(const float origin[3], GrenadeType grenadeType, float &distance) {
  int nearestIndex = -1;
  float nearestDistance = -1.0;
  // Compare the distances
  for (int i = 0; i < g_HoloNadeEntities.Length; i++) {
    // For each of all current active entities
    int lastNadeId = g_HoloNadeEntities.Get(i, MAX_GRENADES_IN_GROUP-1);
    if (lastNadeId > -1) {
      // Its full
      continue;
    }
    // Group has space, check if its same grenadeType
    int iEnt = g_HoloNadeEntities.Get(i, 0);
    if (iEnt > 0) {
      char targetName[GRENADE_NAME_LENGTH];
      GetEntPropString(iEnt, Prop_Data, "m_iName", targetName, sizeof(targetName));
      GrenadeType holoEntType = GrenadeTypeFromString(targetName);
      if (holoEntType == grenadeType) {
        float entOrigin[3];
        Entity_GetAbsOrigin(iEnt, entOrigin);
        distance = GetVectorDistance(origin, entOrigin);
        if (distance < nearestDistance || nearestDistance == -1.0) {
          nearestIndex = i;
          nearestDistance = distance;
        }
      }
    }
  }
  distance = nearestDistance;
  return nearestIndex;
}

public void RemoveHoloNadeEntities() {
  for (int i = g_HoloNadeEntities.Length - 1; i >= 0; i--) {
    int GroupNades[MAX_GRENADES_IN_GROUP];
    g_HoloNadeEntities.GetArray(i, GroupNades, sizeof(GroupNades));
    g_HoloNadeEntities.Erase(i);
    int ent = GroupNades[0];
    if (IsValidEntity(ent)) {
      AcceptEntityInput(ent, "Kill");
    }
  }
}

public void GiveNadeGroupMenu(int client, int HoloNadeIndex) {
  g_CurrentNadeControl[client] = -1;
  g_CurrentNadeGroupControl[client] = HoloNadeIndex;
  g_ClientLastMenuType[client] = GrenadeMenuType_NadeGroup;
  if (HoloNadeIndex >= g_HoloNadeEntities.Length) {
    g_CurrentNadeGroupControl[client] = -1;
    return;
  }
  char name[64], auth[AUTH_LENGTH], NadeIdStr[16];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  Menu menu = new Menu(NadeGroupMenuHandler);
  char title[64];
  GetEntPropString(client, Prop_Send, "m_szLastPlaceName", title, sizeof(title));
  Format(title, sizeof(title), "Lugar: [%s]", strlen(title) ? title : "-");
  menu.SetTitle(title);
  int NadeIds[MAX_GRENADES_IN_GROUP];
  g_HoloNadeEntities.GetArray(HoloNadeIndex, NadeIds, sizeof(NadeIds));
  for (int i = 1; i < MAX_GRENADES_IN_GROUP; i++) {
    if (NadeIds[i] >= 0) {
      GetClientGrenadeData(NadeIds[i], "name", name, sizeof(name));
      IntToString(NadeIds[i], NadeIdStr, sizeof(NadeIdStr));
      menu.AddItem(NadeIdStr, name);
    }
  }
  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

stock int GetNearestNadeGroupIndex(
  const float origin[3],
  float nearestEntOrigin[3] = ZERO_VECTOR
  ) {
  int nearestIndex = -1;
  float distance;
  float nearestDistance = -1.0;
  //Find all the entities and compare the distances
  int NadeGroup[MAX_GRENADES_IN_GROUP];
  for (int index = 0; index < g_HoloNadeEntities.Length; index++) {
    //for each of all current active entities
    g_HoloNadeEntities.GetArray(index, NadeGroup, sizeof(NadeGroup));
    if (NadeGroup[0] > 0) {
      float entOrigin[3];
      Entity_GetAbsOrigin(NadeGroup[0], entOrigin);
      distance = GetVectorDistance(entOrigin, origin);
      if (distance < nearestDistance || nearestDistance == -1.0) {
          nearestIndex = index;
          nearestDistance = distance;
          nearestEntOrigin = entOrigin;
      }
    }
  }
  return nearestIndex;
}

public void InitHoloNadeDemo(int client, int nadeId) {
  PM_Message(client, "{ORANGE}Starting Demo...");
  ServerCommand("bot_quota_mode normal");
  ServerCommand("bot_add");
  DataPack pack = new DataPack();
  CreateDataTimer(0.2, Timer_GetHoloNadeBot, pack, TIMER_FLAG_NO_MAPCHANGE);
  pack.WriteCell(client);
  pack.WriteCell(nadeId);
}

public Action Timer_GetHoloNadeBot(Handle timer, DataPack pack) {
  pack.Reset();
  int client = pack.ReadCell();
  if (!IsValidClient(client)) {
    return Plugin_Handled;
  }
  int nadeId = pack.ReadCell();
  int bot = GetLiveBot(CS_TEAM_T);
  if (bot < 0) {
    return Plugin_Handled;
  }

  GetClientName(bot, g_BotOriginalName[bot], MAX_NAME_LENGTH);
  SetClientName(bot, "DEMO");

  g_IsNadeDemoBot[bot] = true;
  g_DemoNadeData[bot].Clear();

  Client_RemoveAllWeapons(bot);
  
  Entity_SetCollisionGroup(bot, COLLISION_GROUP_DEBRIS);

  char auth[AUTH_LENGTH], nadeIdStr[GRENADE_ID_LENGTH];
  IntToString(nadeId, nadeIdStr, sizeof(nadeIdStr));
  FindId(nadeIdStr, auth, sizeof(auth));
  char filepath[PLATFORM_MAX_PATH + 1];
  GetGrenadeData(auth, nadeIdStr, "record", filepath, sizeof(filepath));

  DemoNadeData demoNadeData;
  GetGrenadeVector(auth, nadeIdStr, "origin", demoNadeData.origin);
  GetGrenadeVector(auth, nadeIdStr, "angles", demoNadeData.angles);
  GetGrenadeVector(auth, nadeIdStr, "grenadeOrigin", demoNadeData.grenadeOrigin);
  GetGrenadeVector(auth, nadeIdStr, "grenadeVelocity", demoNadeData.grenadeVelocity);
  char grenadeTypeStr[GRENADE_NAME_LENGTH];
  GetGrenadeData(auth, nadeIdStr, "grenadeType", grenadeTypeStr, sizeof(grenadeTypeStr));
  demoNadeData.grenadeType = GrenadeTypeFromString(grenadeTypeStr);
  demoNadeData.delay = GetGrenadeFloat(auth, nadeIdStr, "delay");

  g_DemoNadeData[bot].PushArray(demoNadeData, sizeof(demoNadeData));

  if (!IsPlayerAlive(bot)) {
    CS_RespawnPlayer(bot);
  }

  BMFileHeader header;
  BMError error = BotMimic_GetFileHeaders(filepath, header, sizeof(header));
  if (error != BM_NoError) {
    char errorString[128];
    BotMimic_GetErrorString(error, errorString, sizeof(errorString));
    PrintToServer("[Timer_GetHoloNadeBot]Failed to get %s headers: %s", filepath, errorString);
    return Plugin_Handled;
  }
  g_BotSpawnAngles[bot] = header.BMFH_initialAngles;
  char sAlias[64];
  GetGrenadeWeapon(demoNadeData.grenadeType, sAlias, sizeof(sAlias));
  GivePlayerItem(bot, sAlias);
  TeleportEntity(bot, header.BMFH_initialPosition, g_BotSpawnAngles[bot], {0.0, 0.0, 0.0});
  // wait some time so client can see lineup
  DataPack demoPack = new DataPack();
  RequestFrame(StartBotMimicDemo, demoPack);
  demoPack.WriteCell(bot);
  demoPack.WriteString(filepath);
  demoPack.WriteFloat(1.5);
  g_DemoBotStopped[bot] = false;
  g_CurrentDemoNadeIndex[bot] = 0;
  g_ClientSpecBot[bot] = client;
  g_LastSpecPlayerTeam[client] = (GetClientTeam(client) == CS_TEAM_T) ? CS_TEAM_T : CS_TEAM_CT;
  GetClientAbsOrigin(client, g_LastSpecPlayerPos[client]);
  GetClientEyeAngles(client, g_LastSpecPlayerAng[client]);

  DataPack playerPack = new DataPack();
  CreateDataTimer(0.1, Timer_ClientSpectate, playerPack);
  playerPack.WriteCell(client);
  playerPack.WriteCell(bot);

  return Plugin_Handled;
}

public Action Timer_ClientSpectate(Handle Timer, DataPack pack) {
  pack.Reset();
  int client = pack.ReadCell();
  int bot = pack.ReadCell();
  if (IsValidClient(client) && IsValidClient(bot)) {
    SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", bot);
    ChangeClientTeam(client, TEAM_SPECTATOR);
  }
  return Plugin_Handled;
}

public int GetHoloNadeColorFromType(const GrenadeType type, char[] buffer) {
  switch (type) {
    case GrenadeType_Molotov:
      return strcopy(buffer, 16, GRENADE_COLOR_MOLOTOV);
    case GrenadeType_Incendiary:
      return strcopy(buffer, 16, GRENADE_COLOR_MOLOTOV);
    case GrenadeType_Smoke:
      return strcopy(buffer, 16, GRENADE_COLOR_SMOKE);
    case GrenadeType_Flash:
      return strcopy(buffer, 16,  GRENADE_COLOR_FLASH);
    case GrenadeType_HE:
      return strcopy(buffer, 16, GRENADE_COLOR_HE);
  }
  return strcopy(buffer, 16, GRENADE_COLOR_DEFAULT);
}

public int GetGrenadeModelFromType(const GrenadeType type, char[] bufferz) {
  switch (type) {
    case GrenadeType_Molotov:
      return strcopy(bufferz, 50, ASSET_MOLOTOVMODEL);
    case GrenadeType_Incendiary:
      return strcopy(bufferz, 50, ASSET_INCENDIARYMODEL);
    case GrenadeType_Smoke:
      return strcopy(bufferz, 50, ASSET_SMOKEMODEL);
    case GrenadeType_Flash:
      return strcopy(bufferz, 50,  ASSET_FLASHMODEL);
    case GrenadeType_HE:
      return strcopy(bufferz, 50, ASSET_HEMODEL);
  }
  return strcopy(bufferz, 50, ASSET_SMOKEMODEL);
}

stock void SetGlowColor(int entity, const char[] kolor) {
	char colorbuffers[3][4];
	ExplodeString(kolor, " ", colorbuffers, sizeof(colorbuffers), sizeof(colorbuffers[]));
	int colors[4];
	for (int i = 0; i < 3; i++)
		colors[i] = StringToInt(colorbuffers[i]);
	colors[3] = 255; // Set alpha
	SetVariantColor(colors);
	AcceptEntityInput(entity, "SetGlowColor");
}
