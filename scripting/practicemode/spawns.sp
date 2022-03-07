public void Spawns_MapStart() {
  g_Spawns.Clear();
  AddMapSpawnsForTeam("info_player_counterterrorist");
  AddMapSpawnsForTeam("info_player_terrorist");
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
    int SpawnEnts[5];
    g_Spawns.GetArray(i, SpawnEnts, sizeof(SpawnEnts));
    for (int j=1; j<5; j++) {
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
  float nearestEntAngles[3]
  ) {
  int nearestIndex = -1;
  float distance = -1.0;
  float nearestDistance = -1.0;
  //Find all the entities and compare the distances
  int SpawnEnts[5];
  for (int index = 0; index < g_Spawns.Length; index++) {
    //for each of all current active entities
    g_Spawns.GetArray(index, SpawnEnts, sizeof(SpawnEnts));
    float entOrigin[3], entAngles[3];
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

public Action Timer_SpawnsRedGlow(Handle timer, int ent) {
  SetEntityRenderColor(ent, 255, 0, 0);
  return Plugin_Handled;
}

public void CreateHoloSpawnEntities() {
  for (int i = 0; i < g_Spawns.Length; i++) {
    int SpawnEnts[5];
    g_Spawns.GetArray(i, SpawnEnts, sizeof(SpawnEnts));
    int player_info_ent = SpawnEnts[0];
    if (IsValidEntity(player_info_ent)) {
      float vOrigin[3];
      Entity_GetAbsOrigin(player_info_ent, vOrigin);
      float size = 20.0
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
      SpawnEnts[1] = CreateBeam(vMins, vPos1);
      SpawnEnts[2] = CreateBeam(vPos1, vMaxs);
      SpawnEnts[3] = CreateBeam(vMaxs, vPos2);
      SpawnEnts[4] = CreateBeam(vPos2, vMins);
      g_Spawns.SetArray(i, SpawnEnts, sizeof(SpawnEnts));
    }
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

public void OnBeamInteraction(const char[] output, int caller, int activator, float delay) {
  // PrintToChatAll("%d interacted", activator);
  // DispatchKeyValue(caller, "OnTouchedByEntity", "!self,TurnOn,,0.002,-1");
  // AcceptEntityInput(caller,"TurnOn");
}

public void AddMapSpawnsForTeam(const char[] spawnClassName) {
  int SpawnGroup[5] = {-1, ...};
  int minPriority = -1;
  // First pass over spawns to find minPriority.
  int ent = -1;
  while ((ent = FindEntityByClassname(ent, spawnClassName)) != -1) {
    int priority = GetEntProp(ent, Prop_Data, "m_iPriority");
    if (priority < minPriority || minPriority == -1) {
      minPriority = priority;
    }
  }
  // Second pass only adds spawns with the lowest priority to the list.
  ent = -1;
  while ((ent = FindEntityByClassname(ent, spawnClassName)) != -1) {
    int priority = GetEntProp(ent, Prop_Data, "m_iPriority");
    int enabled = GetEntProp(ent, Prop_Data, "m_bEnabled");
    if (enabled && priority == minPriority) {
      SpawnGroup[0] = ent;
      g_Spawns.PushArray(SpawnGroup, sizeof(SpawnGroup));
    }
  }
}
