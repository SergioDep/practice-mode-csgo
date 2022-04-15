ArrayList RespawnEnts_propdoorrotating;
ArrayList RespawnEnts_funcbreakable;
ArrayList RespawnEnts_propdynamic;

enum struct B_PropDoorRotating {
  float origin[3];
  float angles[3];
  // int disableshadows;
  // int distance;
  bool forceclosed;
  char model[128];
  int rendercolor[4];
  float returndelay;
  char slavename[128];
  char soundcloseoverride[128];
  char soundmoveoverride[128];
  char soundopenoverride[128];
  char soundunlockedoverride[128];
  int spawnflags;
  float speed;
  char targetname[MAX_TARGET_LENGTH];
}

enum struct B_FuncBreakable {
  float origin[3];
  float angles[3];
  char model[128];
  char targetname[MAX_TARGET_LENGTH];
  RenderMode rendermode;
  // int material;
}

enum struct B_PropDynamic {
  float origin[3];
  float angles[3];
  char model[128];
  int rendercolor[4];
  SolidType_t solidtype;
  SolidFlags_t solidflags;
  int spawnflags;
  char targetname[MAX_TARGET_LENGTH];
}

public void Breakables_MapStart() {
  RespawnEnts_propdoorrotating.Clear();
  RespawnEnts_funcbreakable.Clear();
  RespawnEnts_propdynamic.Clear();
  SaveBreakbaleEnts();
}

public void Breakables_PluginStart() {
  RespawnEnts_propdoorrotating = new ArrayList(sizeof(B_PropDoorRotating));
  RespawnEnts_funcbreakable = new ArrayList(sizeof(B_FuncBreakable));
  RespawnEnts_propdynamic = new ArrayList(sizeof(B_PropDynamic));
}

public void BreakBreakableEnts() {
  int ent = -1;
  while ((ent = FindEntityByClassname(ent, "func_breakable")) != -1) {
    AcceptEntityInput(ent, "Kill");
  }
  while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1) {
    char model[128];
    Entity_GetModel(ent, model, sizeof(model));
    if (StrContains(model, "vent", false) == -1 &&
    StrContains(model, "wall_hole", false) == -1 &&
    StrContains(model, "breakable", false) == -1) {
      continue;
    }
    AcceptEntityInput(ent, "Kill");
  }
  while ((ent = FindEntityByClassname(ent, "prop_door_rotating")) != -1) {
    AcceptEntityInput(ent, "Kill");
  }
}

public void RespawnBreakableEnts() {
  // windows ...
  for (int i = 0; i < RespawnEnts_funcbreakable.Length; i++) {
    B_FuncBreakable breakable;
    RespawnEnts_funcbreakable.GetArray(i, breakable, sizeof(breakable));
    int ent = CreateEntityByName("func_breakable");
    if (ent > 0) {
      DispatchKeyValue(ent, "classname", "func_breakable");
      DispatchKeyValue(ent, "model", breakable.model);
      DispatchKeyValue(ent, "health", "1");
      DispatchKeyValue(ent, "targetname", breakable.targetname);
      SetEntityRenderMode(ent, breakable.rendermode);
      // SetEntProp(ent, Prop_Send, "m_nMaterial", breakable.material); // DispatchKeyValue(ent, "material", breakable.material);
      if (DispatchSpawn(ent)) {
        TeleportEntity(ent, breakable.origin, breakable.angles, NULL_VECTOR);
      }
    }
  }
  // doors ...
  for (int i = 0; i < RespawnEnts_propdoorrotating.Length; i++) {
    B_PropDoorRotating door;
    RespawnEnts_propdoorrotating.GetArray(i, door, sizeof(door));
    int ent = CreateEntityByName("prop_door_rotating");
    if (ent > 0) {
      DispatchKeyValue(ent, "classname", "prop_door_rotating");
      DispatchKeyValue(ent, "model", door.model);
      Entity_SetAbsAngles(ent, door.angles);
      // DispatchKeyValue(ent, "disableshadows", "1");
      // DispatchKeyValue(ent, "distance", "89");
      Entity_SetForceClose(ent, door.forceclosed);
      Entity_SetRenderColor(ent, door.rendercolor[0], door.rendercolor[1], door.rendercolor[2]);
      SetEntPropFloat(ent, Prop_Data, "m_flAutoReturnDelay", door.returndelay);
      // DispatchKeyValue(ent, "returndelay", door.returndelay);
      DispatchKeyValue(ent, "slavename", door.slavename);
      DispatchKeyValue(ent, "soundcloseoverride", door.soundcloseoverride);
      DispatchKeyValue(ent, "soundmoveoverride", door.soundmoveoverride);
      DispatchKeyValue(ent, "soundopenoverride", door.soundopenoverride);
      DispatchKeyValue(ent, "soundunlockedoverride", door.soundunlockedoverride);
      Entity_SetSpawnFlags(ent, door.spawnflags);
      Entity_SetSpeed(ent, door.speed);
      DispatchKeyValue(ent, "targetname", door.targetname);
      Entity_SetAbsOrigin(ent, door.origin);
      if (DispatchSpawn(ent)) {
        ActivateEntity(ent);
      }
    }
  }
  // vents ...
  for (int i = 0; i < RespawnEnts_propdynamic.Length; i++) {
    B_PropDynamic prop;
    RespawnEnts_propdynamic.GetArray(i, prop, sizeof(prop));
    int ent = CreateEntityByName("prop_dynamic");
    if (ent > 0) {
      DispatchKeyValue(ent, "classname", "prop_dynamic");
      DispatchKeyValue(ent, "model", prop.model);
      Entity_SetRenderColor(ent, prop.rendercolor[0], prop.rendercolor[1], prop.rendercolor[2]);
      Entity_SetSpawnFlags(ent, prop.spawnflags);
      Entity_SetSolidType(ent, prop.solidtype);
      Entity_SetSolidFlags(ent, prop.solidflags);
      DispatchKeyValue(ent, "targetname", prop.targetname);
      // Entity_SetFlags(ent, 524288);
      // get entityoutput
      // SetEntityFlags(ent, 262144);
      if (DispatchSpawn(ent)) {
        TeleportEntity(ent, prop.origin, prop.angles, NULL_VECTOR);
      }
    }
  }
}

public void SaveBreakbaleEnts() {
  int ent = -1;
  // windows ...
  while ((ent = FindEntityByClassname(ent, "func_breakable")) != -1) {
    B_FuncBreakable breakable;
    Entity_GetModel(ent, breakable.model, sizeof(breakable.model));
    Entity_GetName(ent, breakable.targetname, sizeof(breakable.targetname));
    breakable.rendermode = GetEntityRenderMode(ent);
    //m_nMaterial
    // breakable.material = GetEntProp(ent, Prop_Send, "m_nMaterial");
    int charIndex = StrContains(breakable.targetname, ".brush");
    if (charIndex > -1) {
      continue;
    }
    Entity_GetAbsOrigin(ent, breakable.origin);
    Entity_GetAbsAngles(ent, breakable.angles);
    RespawnEnts_funcbreakable.PushArray(breakable, sizeof(breakable));
  }
  // doors ...
  while ((ent = FindEntityByClassname(ent, "prop_door_rotating")) != -1) {
    B_PropDoorRotating door;
    Entity_GetAbsOrigin(ent, door.origin);
    Entity_GetAbsAngles(ent, door.angles);
    // door.disableshadows = GetEntProp(door, Prop_Data, "m_bDisableShadows");
    // door.distance = GetEntProp(door, Prop_Data, "m_Radius"); //m_flDistance m_flShadowMaxDist m_flSunDistance
    Entity_GetModel(ent, door.model, sizeof(door.model));
    Entity_GetRenderColor(ent, door.rendercolor);
    door.forceclosed = Entity_GetForceClose(ent);
    door.returndelay = GetEntPropFloat(ent, Prop_Data, "m_flAutoReturnDelay");
    GetEntPropString(ent, Prop_Data, "m_SlaveName", door.slavename, sizeof(door.slavename));
    GetEntPropString(ent, Prop_Data, "m_SoundClose", door.soundcloseoverride, sizeof(door.soundcloseoverride));
    GetEntPropString(ent, Prop_Data, "m_SoundMoving", door.soundmoveoverride, sizeof(door.soundmoveoverride));
    GetEntPropString(ent, Prop_Data, "m_SoundOpen", door.soundopenoverride, sizeof(door.soundopenoverride));
    GetEntPropString(ent, Prop_Data, "m_ls.sUnlockedSound", door.soundunlockedoverride, sizeof(door.soundunlockedoverride));
    door.spawnflags = Entity_GetSpawnFlags(ent);
    door.speed = Entity_GetSpeed(ent);
    Entity_GetName(ent, door.targetname, sizeof(door.targetname));
    RespawnEnts_propdoorrotating.PushArray(door, sizeof(door));
  }
  // vents ...
  while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1) {
    B_PropDynamic prop;
    Entity_GetAbsOrigin(ent, prop.origin);
    Entity_GetAbsAngles(ent, prop.angles);
    Entity_GetModel(ent, prop.model, sizeof(prop.model));
    if (StrContains(prop.model, "vent", false) == -1 &&
    StrContains(prop.model, "wall_hole", false) == -1 &&
    StrContains(prop.model, "breakable", false) == -1) {
      continue;
    }
    Entity_GetName(ent, prop.targetname, sizeof(prop.targetname));
    Entity_GetRenderColor(ent, prop.rendercolor);
    prop.solidtype = Entity_GetSolidType(ent);
    prop.solidflags = Entity_GetSolidFlags(ent);
    prop.spawnflags = Entity_GetSpawnFlags(ent);
    RespawnEnts_propdynamic.PushArray(prop, sizeof(prop));
  }
  PrintToServer("Saved %d funcbreakable entities.", RespawnEnts_funcbreakable.Length);
  PrintToServer("Saved %d propdoorrotating entities.", RespawnEnts_propdoorrotating.Length);
  PrintToServer("Saved %d propdynamic entities.", RespawnEnts_propdynamic.Length);
}
