KeyValues g_CrossfiresKv = null;

bool g_UpdatedCrossfireKv = false;
char g_SelectedCrossfireId[CROSSFIRE_ID_LENGTH];
bool g_WaitForCrossfireSave[MAXPLAYERS + 1] = {false, ...};

public void Crossfires_MapStart() {
  PrecacheSound("ui/achievement_earned.wav");
  PrecacheSound("ui/armsrace_demoted.wav");
  delete g_CrossfiresKv;
  g_CrossfiresKv = new KeyValues("Crossfires");
  // g_CrossfiresKv.SetEscapeSequences(true); // Avoid fatals from special chars in user data

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  char crossfiresFile[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, crossfiresFile, sizeof(crossfiresFile),
            "data/practicemode/crossfires/%s.cfg", map);
  g_CrossfiresKv.ImportFromFile(crossfiresFile);
}

public void Crossfires_MapEnd() {
  char dir[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, dir, sizeof(dir), "data/practicemode/crossfires");
  if (!DirExists(dir)) {
    if (!CreateDirectory(dir, 511))
      PrintToServer("[Crossfires_MapEnd]Failed to create directory %s", dir);
  }

  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  char path[PLATFORM_MAX_PATH];
  Format(path, sizeof(path), "%s/%s.cfg", dir, mapName);

  DeleteFile(path);
  if (!g_CrossfiresKv.ExportToFile(path)) {
    PrintToServer("[Crossfires_MapEnd]Failed to write spawn names to %s", path);
  }
  RemoveHoloCFireEnts();
}

public void UpdateHoloCFireEnts() {
  RemoveHoloCFireEnts();
  CreateHoloCFireEnts();
}

public void RemoveHoloCFireEnts() {
  int ent;
  for (int i = g_HoloCFireEnts.Length - 1; i >= 0; i--) {
    ent = g_HoloCFireEnts.Get(i);
    if (IsValidEntity(ent)) {
      AcceptEntityInput(ent, "Kill");
    }
  }
  g_HoloCFireEnts.Clear();
}

public void CreateHoloCFireEnts() {
  if (!StrEqual(g_SelectedCrossfireId, "-1")) {
    // Show Only Selected
    if (g_CrossfiresKv.JumpToKey(g_SelectedCrossfireId)) {
      if (g_CrossfiresKv.GotoFirstSubKey()) {
          do {
            char spawnType[CROSSFIRE_ID_LENGTH];
            g_CrossfiresKv.GetSectionName(spawnType, sizeof(spawnType));
            CreateHoloCrossfireEntity(spawnType, {0, 255, 0, 150});
          } while (g_CrossfiresKv.GotoNextKey());
          g_CrossfiresKv.GoBack();
        }
      g_CrossfiresKv.GoBack();
    }
  } else {
    // Show All Crossfires
    if (g_CrossfiresKv.GotoFirstSubKey()) {
      do {
        char crossfireId[CROSSFIRE_ID_LENGTH];
        g_CrossfiresKv.GetSectionName(crossfireId, sizeof(crossfireId));
        // g_CrossfiresKv.GetString("name", crossfirename, sizeof(crossfirename));
        int crossfireColor[4];
        GetRandomColor(crossfireColor, 150);
        if (g_CrossfiresKv.GotoFirstSubKey()) {
          do {
            char spawnType[CROSSFIRE_ID_LENGTH];
            g_CrossfiresKv.GetSectionName(spawnType, sizeof(spawnType));
            CreateHoloCrossfireEntity(spawnType, crossfireColor);
          } while (g_CrossfiresKv.GotoNextKey());
          g_CrossfiresKv.GoBack();
        }
      } while (g_CrossfiresKv.GotoNextKey());
      g_CrossfiresKv.GoBack();
    }
  }
}

public void CreateHoloCrossfireEntity(const char[] spawnType, int crossfireColor[4]) {
  if (g_CrossfiresKv.GotoFirstSubKey()) {
    do {
      char spawnid[CROSSFIRE_ID_LENGTH];
      g_CrossfiresKv.GetSectionName(spawnid, sizeof(spawnid));
      float origin[3], angles[3];
      g_CrossfiresKv.GetVector("origin", origin);
      g_CrossfiresKv.GetVector("angles", angles);
      CreateCrossfirePlayerEntity(spawnType, spawnid, origin, angles, crossfireColor);
    } while (g_CrossfiresKv.GotoNextKey());
    g_CrossfiresKv.GoBack();
  }
}

public void CreateCrossfirePlayerEntity(const char[] spawnType, const char[] spawnId, float origin[3], float angles[3], int color[4]) {
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
      float fMins[3], fMaxs[3];
      g_CrossfiresKv.GetVector("vecmin", fMins);
      g_CrossfiresKv.GetVector("vecmax", fMaxs);
      DataPack boxPack;
      CreateDataTimer(0.3, Timer_ShowBoxEntity, boxPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT)
      boxPack.WriteCell(iEnt);
      boxPack.WriteFloatArray(fMins, 3);
      boxPack.WriteFloatArray(fMaxs, 3);
    }
    DispatchKeyValue(iEnt, "spawnflags", "1"); 
    DispatchKeyValue(iEnt, "rendermode", "1");
    SetEntProp(iEnt, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(iEnt, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(iEnt, Prop_Send, "m_flGlowMaxDist", 1500.0);
    SetVariantColor(color);
    AcceptEntityInput(iEnt, "SetGlowColor");
    DispatchKeyValue(iEnt, "targetname", spawnId);
    if (DispatchSpawn(iEnt)) {
      angles[0] = 0.0; // look paralel to ground
      TeleportEntity(iEnt, origin, angles, NULL_VECTOR);
    }
    g_HoloCFireEnts.Push(iEnt);
  }
}

public Action Timer_ShowBoxEntity(Handle timer, DataPack pack) {
  pack.Reset();
  int parent = pack.ReadCell();
  if (!IsValidEntity(parent)) {
    return Plugin_Stop;
  }
  float origin[3];
  Entity_GetAbsOrigin(parent, origin);
  float fMins[3], fMaxs[3];
  pack.ReadFloatArray(fMins, 3);
  pack.ReadFloatArray(fMaxs, 3);
  fMins[2] = fMaxs[2] = (origin[2] + 16.0);

  TE_SendBeamSquareToAll(fMins, fMaxs, g_PredictTrail, 0, 0, 0, 0.3, 1.5, 1.5, 0, 0.0, {0, 255, 0, 255}, 0);
  return Plugin_Continue;
}

stock TE_SendBeamSquareToAll(
  float bottomcorner[3],
  float uppercorner[3],
  int ModelIndex,
  int HaloIndex,
  int StartFrame,
  int FrameRate,
  float Life,
  float Width,
  float EndWidth,
  int FadeLength,
  float Amplitude,
  const Color[4],
  int Speed
) {
  // Create the additional corners of the square
  float tc1[3];
  tc1 = uppercorner;
  tc1[0] = bottomcorner[0];
  float tc2[3];
  tc2 = uppercorner;
  tc2[1] = bottomcorner[1];
  
  // Draw all the edges
  TE_SetupBeamPoints(uppercorner, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(tc1, bottomcorner, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(bottomcorner, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(tc2, uppercorner, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
  TE_SendToAll();
}
