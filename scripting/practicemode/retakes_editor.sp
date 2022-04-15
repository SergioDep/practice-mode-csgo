KeyValues g_RetakesKv = null;

bool g_UpdatedRetakeKv = false;
char g_SelectedRetakeId[RETAKE_ID_LENGTH];
bool g_WaitForRetakeSave[MAXPLAYERS + 1] = {false, ...};

public void Retakes_MapStart() {
  PrecacheSound("ui/achievement_earned.wav");
  PrecacheSound("ui/armsrace_demoted.wav");
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
      PrintToServer("[Retakes]Failed to create directory %s", dir);
  }

  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  char path[PLATFORM_MAX_PATH];
  Format(path, sizeof(path), "%s/%s.cfg", dir, mapName);

  DeleteFile(path);
  if (!g_RetakesKv.ExportToFile(path)) {
    PrintToServer("[Retakes]Failed to write spawn names to %s", path);
  }
  RemoveHoloRetakeEntities();
}

public void UpdateHoloRetakeEntities() {
  RemoveHoloRetakeEntities();
  CreateHoloRetakeEntities();
}

public void RemoveHoloRetakeEntities() {
  int ent;
  for (int i = g_HoloRetakeEntities.Length - 1; i >= 0; i--) {
    ent = g_HoloRetakeEntities.Get(i);
    if (IsValidEntity(ent)) {
      AcceptEntityInput(ent, "Kill");
    }
  }
  g_HoloRetakeEntities.Clear();
}

public void CreateHoloRetakeEntities() {
  if (!StrEqual(g_SelectedRetakeId, "-1")) {
    // Show Only Selected
    if (g_RetakesKv.JumpToKey(g_SelectedRetakeId)) {
      if (g_RetakesKv.GotoFirstSubKey()) {
          do {
            char spawnType[RETAKE_ID_LENGTH];
            g_RetakesKv.GetSectionName(spawnType, sizeof(spawnType));
            CreateHoloRetakeEntity(spawnType, {0, 255, 0, 150});
          } while (g_RetakesKv.GotoNextKey());
          g_RetakesKv.GoBack();
        }
      g_RetakesKv.GoBack();
    }
  } else {
    // Show All Retakes
    if (g_RetakesKv.GotoFirstSubKey()) {
      do {
        char retakeid[RETAKE_ID_LENGTH];
        g_RetakesKv.GetSectionName(retakeid, sizeof(retakeid));
        // g_RetakesKv.GetString("name", retakename, sizeof(retakename));
        int retakeColor[4];
        GetRandomColor(retakeColor, 150);
        if (g_RetakesKv.GotoFirstSubKey()) {
          do {
            char spawnType[RETAKE_ID_LENGTH];
            g_RetakesKv.GetSectionName(spawnType, sizeof(spawnType));
            CreateHoloRetakeEntity(spawnType, retakeColor);
          } while (g_RetakesKv.GotoNextKey());
          g_RetakesKv.GoBack();
        }
      } while (g_RetakesKv.GotoNextKey());
      g_RetakesKv.GoBack();
    }
  }
}

public void CreateHoloRetakeEntity(const char[] spawnType, int retakeColor[4]) {
  if (g_RetakesKv.GotoFirstSubKey()) {
    do {
      char spawnid[RETAKE_ID_LENGTH];
      g_RetakesKv.GetSectionName(spawnid, sizeof(spawnid));
      int ent;
      float origin[3], angles[3];
      if (StrEqual(spawnType, KV_NADESPAWN)) {
        if (g_RetakesKv.JumpToKey("trigger_entity")) {
          float vecmins[3], vecmaxs[3];
          g_RetakesKv.GetVector("origin", origin);
          g_RetakesKv.GetVector("angles", angles);
          g_RetakesKv.GetVector("vecmins", vecmins);
          g_RetakesKv.GetVector("vecmaxs", vecmaxs);
          ent = CreateRetakeBoxEntity(spawnid, origin, angles, vecmins, vecmaxs);
          if (ent > 0) {
            g_HoloRetakeEntities.Push(ent);
          }
          g_RetakesKv.GoBack();
        }
      } else {
        g_RetakesKv.GetVector("origin", origin);
        g_RetakesKv.GetVector("angles", angles);
        ent = CreateRetakePlayerEntity(spawnType, spawnid, origin, angles, retakeColor);
        if (ent > 0) {
          g_HoloRetakeEntities.Push(ent);
        }
      }
    } while (g_RetakesKv.GotoNextKey());
    g_RetakesKv.GoBack();
  }
}

public int CreateRetakePlayerEntity(const char[] spawnType, const char[] spawnid, float origin[3], float angles[3], int color[4]) {
  //models/player/custom_player/legacy/tm_separatist_variantD.mdl <- tt
  //models/player/custom_player/legacy/ctm_sas.mdl <- ct
  int iEnt = CreateEntityByName("prop_dynamic_override");
  if (iEnt > 0) {
    DispatchKeyValue(iEnt, "classname", "prop_dynamic_override");
    if (StrEqual(spawnType, KV_BOTSPAWN)) {
      DispatchKeyValue(iEnt, "model", "models/player/custom_player/legacy/tm_separatist_variantD.mdl");
      SetEntityRenderColor(iEnt, color[0], color[1], color[2], color[3]);
    } else if (StrEqual(spawnType, KV_PLAYERSPAWN)) {
      DispatchKeyValue(iEnt, "model", "models/player/custom_player/legacy/ctm_sas.mdl");
      SetEntityRenderColor(iEnt, color[0], color[1], 255, color[3]);
    } else if (StrEqual(spawnType, KV_BOMBSPAWN)) {
      SetEntPropFloat(iEnt, Prop_Send, "m_flModelScale", 3.0);
      DispatchKeyValue(iEnt, "model", "models/weapons/w_ied_dropped.mdl");
      SetEntityRenderColor(iEnt, 255, color[1], color[2], color[3]);
    }
    DispatchKeyValue(iEnt, "spawnflags", "1"); 
    DispatchKeyValue(iEnt, "rendermode", "1");
    SetEntProp(iEnt, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(iEnt, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(iEnt, Prop_Send, "m_flGlowMaxDist", 1500.0);
    SetVariantColor(color);
    AcceptEntityInput(iEnt, "SetGlowColor");
    DispatchKeyValue(iEnt, "targetname", spawnid);
    if (DispatchSpawn(iEnt)) {
      angles[0] = 0.0; // look paralel to ground
      TeleportEntity(iEnt, origin, angles, NULL_VECTOR);
    }
  }
  return iEnt;
}

public int CreateRetakeBoxEntity(const char[] spawnid, float origin[3], float angles[3], float vecmins[3], float vecmaxs[3]) {
  int iEnt;
  iEnt = CreateEntityByName("trigger_multiple");
  if (iEnt > 0) {
    DispatchKeyValue(iEnt, "spawnflags", "64"); // 1 ?
    DispatchKeyValue(iEnt, "wait", "0");
    DispatchKeyValue(iEnt, "targetname", spawnid);
    if (DispatchSpawn(iEnt)) {
      ActivateEntity(iEnt);
      SetEntPropVector(iEnt, Prop_Send, "m_vecMins", vecmins);
      SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", vecmaxs);
      SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_BBOX);
      Entity_SetCollisionGroup(iEnt, COLLISION_GROUP_DEBRIS);
      TeleportEntity(iEnt, origin, angles, NULL_VECTOR);
    }
  }
  return iEnt;
}
