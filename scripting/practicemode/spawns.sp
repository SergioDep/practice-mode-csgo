int ctSpawnsLength;

public void Spawns_MapStart() {
  g_Spawns.Clear();
  ctSpawnsLength = 0;
  AddMapSpawnsForTeam("info_player_counterterrorist");
  ctSpawnsLength = g_Spawns.Length;
  AddMapSpawnsForTeam("info_player_terrorist");
}

public void AddMapSpawnsForTeam(const char[] spawnClassName) {
  int SpawnGroup[6] = {-1, ...};
  // int minPriority = -1;
  // First pass over spawns to find minPriority.
  int ent = -1;
  // while ((ent = FindEntityByClassname(ent, spawnClassName)) != -1) {
  //   int priority = GetEntProp(ent, Prop_Data, "m_iPriority");
  //   if (priority < minPriority || minPriority == -1) {
  //     minPriority = priority;
  //   }
  // }
  // Second pass only adds spawns with the lowest priority to the list.
  ent = -1;
  while ((ent = FindEntityByClassname(ent, spawnClassName)) != -1) {
    // int priority = GetEntProp(ent, Prop_Data, "m_iPriority");
    int enabled = GetEntProp(ent, Prop_Data, "m_bEnabled");
    if (enabled) { //&& priority == minPriority
      SpawnGroup[0] = ent;
      g_Spawns.PushArray(SpawnGroup, sizeof(SpawnGroup));
    }
  }
}

stock Action TeleportToSpawn(int client, int args, int team) {
  float spawnOrigin[3], spawnAngles[3];
  int index;
  if (args >= 1) {
    char arg[16];
    GetCmdArg(args, arg, sizeof(arg));
    index = StringToInt(arg) - 1; // Actual index
    int spawnEnt = -1;
    if (team == CS_TEAM_CT) {
      if (0 <= index < ctSpawnsLength) {
        spawnEnt = g_Spawns.Get(index, 0);
        PM_Message(client, "{ORANGE}Teletransportado a Spawn CT {GREEN}%d", index + 1);
      } else {
        PM_Message(client, "{ORANGE}Numero de Spawn no Válido {GREEN}[%d-%d]", 1, ctSpawnsLength);
        return Plugin_Handled;
      }
    } else {
      index += ctSpawnsLength;
      if (ctSpawnsLength <= index < g_Spawns.Length) {
        spawnEnt = g_Spawns.Get(index, 0);
        PM_Message(client, "{ORANGE}Teletransportado a Spawn T {GREEN}%d", index + 1 - ctSpawnsLength);
      } else {
        PM_Message(client, "{ORANGE}Numero de Spawn no Válido {GREEN}[%d-%d]", 1, g_Spawns.Length - ctSpawnsLength);
        return Plugin_Handled;
      }
    }
    if (!IsValidEntity(spawnEnt)) {
      return Plugin_Handled;
    } else {
      Entity_GetAbsOrigin(spawnEnt, spawnOrigin);
      Entity_GetAbsAngles(spawnEnt, spawnAngles);
    }
  } else {
    float fOrigin[3];
    GetClientAbsOrigin(client, fOrigin);
    index = GetNearestSpawnEntsIndex(fOrigin, spawnOrigin, spawnAngles, team);
  }
  TeleportEntity(client, spawnOrigin, spawnAngles, {0.0, 0.0, 0.0});
  return Plugin_Handled;
}

public Action Command_GotoSpawn(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  return TeleportToSpawn(client, args, GetClientTeam(client));
}

public Action Command_GotoCTSpawn(int client, int args) {
  return TeleportToSpawn(client, args, CS_TEAM_CT);
}

public Action Command_GotoTSpawn(int client, int args) {
  return TeleportToSpawn(client, args, CS_TEAM_T);
}

public void Spawns_MapEnd() {
  RemoveHoloSpawnEntities();
}

public void Spawns_ExitPracticeMode() {
  RemoveHoloSpawnEntities();
}

public void UpdateHoloSpawnEntities() {
  RemoveHoloSpawnEntities();
  CreateHoloSpawnEntities();
}

public void RemoveHoloSpawnEntities() {
  for (int i = g_Spawns.Length - 1; i >= 0; i--) {
    int SpawnEnts[6];
    g_Spawns.GetArray(i, SpawnEnts, sizeof(SpawnEnts));
    for (int j=1; j<6; j++) {
      int ent = SpawnEnts[j]; // 0 is the info_player_ ent
      SpawnEnts[j] = -1;
      if (IsValidEntity(ent)) {
        AcceptEntityInput(ent, "Kill");
      }
    }
    g_Spawns.SetArray(i, SpawnEnts, sizeof(SpawnEnts));
  }
}

stock int GetNearestSpawnEntsIndex(
  const float origin[3],
  float nearestEntOrigin[3],
  float nearestEntAngles[3],
  int team = -1
  ) {
  int nearestIndex = -1;
  float distance = -1.0;
  float nearestDistance = -1.0;
  //Find all the entities and compare the distances
  int SpawnEnts[6];
  for (int index = 0; index < g_Spawns.Length; index++) {
    //for each of all current active entities
    g_Spawns.GetArray(index, SpawnEnts, sizeof(SpawnEnts));
    float entOrigin[3], entAngles[3];
    char entClassname[CLASS_LENGTH];
    Entity_GetClassName(SpawnEnts[0], entClassname, sizeof(entClassname));
    if (team != 1) {
      if (StrEqual(entClassname, "info_player_counterterrorist") && team == CS_TEAM_T) {
        continue;
      }
      if (StrEqual(entClassname, "info_player_terrorist") && team == CS_TEAM_CT) {
        continue;
      }
    }
    Entity_GetAbsOrigin(SpawnEnts[0], entOrigin);
    Entity_GetAbsAngles(SpawnEnts[0], entAngles);
    distance = GetVectorDistance(entOrigin, origin);
    if (distance < nearestDistance || nearestDistance == -1.0) {
      nearestIndex = index;
      nearestDistance = distance;
      nearestEntOrigin = entOrigin;
      nearestEntAngles = entAngles;
    }
  }
  return nearestIndex;
}

public void CreateHoloSpawnEntities() {
  char iStr[MAX_TARGET_LENGTH];
  for (int i = 0; i < g_Spawns.Length; i++) {
    int SpawnEnts[6];
    g_Spawns.GetArray(i, SpawnEnts, sizeof(SpawnEnts));
    int player_info_ent = SpawnEnts[0];
    if (IsValidEntity(player_info_ent)) {
      float vOrigin[3];
      Entity_GetAbsOrigin(player_info_ent, vOrigin);
      int triggerEnt = CreateEntityByName("trigger_multiple");
      IntToString(i, iStr, sizeof(iStr));
      DispatchKeyValue(triggerEnt, "spawnflags", "64"); // 1 ?
      DispatchKeyValue(triggerEnt, "wait", "0");
      DispatchKeyValue(triggerEnt, "targetname", iStr);
      DispatchSpawn(triggerEnt);
      ActivateEntity(triggerEnt);
      TeleportEntity(triggerEnt, vOrigin, NULL_VECTOR, NULL_VECTOR);
      SetEntPropVector(triggerEnt, Prop_Send, "m_vecMins", {-16.0, -16.0, 0.0});
      SetEntPropVector(triggerEnt, Prop_Send, "m_vecMaxs", {16.0, 16.0, 0.0});
      SetEntProp(triggerEnt, Prop_Send, "m_nSolidType", SOLID_BBOX);
      Entity_SetCollisionGroup(triggerEnt, COLLISION_GROUP_DEBRIS);
      SDKHook(triggerEnt, SDKHook_StartTouch, HologramSpawn_OnStartTouch);
      SDKHook(triggerEnt, SDKHook_EndTouch, HologramSpawn_OnEndTouch);
      SpawnEnts[1] = triggerEnt;
      float size = 16.0
      float vMins[3], vMaxs[3];
      vMins[0] = -size; vMaxs[0] = size;
      vMins[1] = -size; vMaxs[1] = size;
      AddVectors(vOrigin, vMaxs, vMaxs);
      AddVectors(vOrigin, vMins, vMins);
      float vPos1[3], vPos2[3];
      vPos1 = vMaxs;
      vPos1[0] = vMins[0];
      vPos2 = vMaxs;
      vPos2[1] = vMins[1];
      SpawnEnts[2] = CreateBeam(vMins, vPos1);
      SpawnEnts[3] = CreateBeam(vPos1, vMaxs);
      SpawnEnts[4] = CreateBeam(vMaxs, vPos2);
      SpawnEnts[5] = CreateBeam(vPos2, vMins);
      g_Spawns.SetArray(i, SpawnEnts, sizeof(SpawnEnts));
    }
  }
}

public void HologramSpawn_OnEndTouch(int entity, int other) {
  if (!IsValidClient(other))
    return;
  char targetName[MAX_TARGET_LENGTH];
  GetEntPropString(entity, Prop_Data, "m_iName", targetName, sizeof(targetName));
  int index = StringToInt(targetName);
  if (index==0 && !StrEqual(targetName, "0")) {
    return;
  }
  int spawnEnts[6];
  g_Spawns.GetArray(index, spawnEnts, sizeof(spawnEnts));
  for (int i = 2; i < 6; i++) {
    SetEntityRenderColor(spawnEnts[i], 255, 0, 0, 255);
  }
}

public void HologramSpawn_OnStartTouch(int entity, int other) {
  if (!IsValidClient(other))
    return;
  char targetName[MAX_TARGET_LENGTH];
  GetEntPropString(entity, Prop_Data, "m_iName", targetName, sizeof(targetName));
  int index = StringToInt(targetName);
  if (index==0 && !StrEqual(targetName, "0")) {
    return;
  }
  int spawnEnts[6];
  g_Spawns.GetArray(index, spawnEnts, sizeof(spawnEnts));
  for (int i = 2; i < 6; i++) {
    SetEntityRenderColor(spawnEnts[i], 0, 255, 0, 255);
  }
}

public int CreateBeam(float origin[3], float end[3]) {
  int beament = CreateEntityByName("env_beam");
  SetEntityModel(beament, "sprites/laserbeam.spr");
  SetEntityRenderColor(beament, 255, 0, 0, 255);
  TeleportEntity(beament, origin, NULL_VECTOR, NULL_VECTOR); // Teleport the beam
  SetEntPropVector(beament, Prop_Data, "m_vecEndPos", end);
  DispatchKeyValue(beament, "texture", "sprites/laserbeam.spr");
  SetEntPropFloat(beament, Prop_Data, "m_fWidth", 1.0);
  SetEntPropFloat(beament, Prop_Data, "m_fEndWidth", 1.0);
  AcceptEntityInput(beament,"TurnOn");
  return beament;
}
