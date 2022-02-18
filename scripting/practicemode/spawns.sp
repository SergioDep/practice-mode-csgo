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
    int SpawnEnts[3];
    g_Spawns.GetArray(i, SpawnEnts, sizeof(SpawnEnts));
    int ent = SpawnEnts[1]; // 0 is the info_player_ ent
    SpawnEnts[1] = -1;
    g_Spawns.SetArray(i, SpawnEnts, sizeof(SpawnEnts));
    // in case if it got destroyed before somehow ?
    if (IsValidEntity(ent)) {
      AcceptEntityInput(ent, "Kill");
    }
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
  int SpawnEnts[3];
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
  SetGlowColor(ent, "255 0 0");
  return Plugin_Handled;
}

public void CreateHoloSpawnEntities() {
  for (int i = 0; i < g_Spawns.Length; i++) {
    int SpawnEnts[3];
    g_Spawns.GetArray(i, SpawnEnts, sizeof(SpawnEnts));
    int player_info_ent = SpawnEnts[0];
    if (IsValidEntity(player_info_ent)) {
      int ent = CreateEntityByName("prop_dynamic_override"); // holo ent
      if (ent != -1) {
        SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 0.3);
        float vOrigin[3];
        Entity_GetAbsOrigin(player_info_ent, vOrigin);
        DispatchKeyValue(ent, "classname", "prop_dynamic_override");
        DispatchKeyValue(ent, "spawnflags", "1");
        DispatchKeyValue(ent, "renderamt", "0");
        DispatchKeyValue(ent, "rendermode", "1");
        DispatchKeyValue(ent, "targetname", "holo_spawn");
        DispatchKeyValue(ent, "model", "models/tools/green_plane/green_plane.mdl");
        if (!DispatchSpawn(ent)) {
          continue;
        }
        TeleportEntity(ent, vOrigin, NULL_VECTOR, NULL_VECTOR);
        SetEntProp(ent, Prop_Send, "m_bShouldGlow", true, true);
        SetEntProp(ent, Prop_Send, "m_nGlowStyle", 0);
        SetEntPropFloat(ent, Prop_Send, "m_flGlowMaxDist", 900.0);
        SetGlowColor(ent, "255 0 0");
      }
      SpawnEnts[1] = ent;
      g_Spawns.SetArray(i, SpawnEnts, sizeof(SpawnEnts));
    }
  }
}

public void AddMapSpawnsForTeam(const char[] spawnClassName) {
  int SpawnGroup[3] = {-1, ...};
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

// //does what it says
// public void TeleportToSpawnEnt(int client, int ent) {
//   float origin[3];
//   float angles[3];
//   float velocity[3];
//   GetEntPropVector(ent, Prop_Data, "m_vecOrigin", origin);
//   GetEntPropVector(ent, Prop_Data, "m_angRotation", angles);
//   TeleportEntity(client, origin, angles, velocity);
// }
