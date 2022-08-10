#define ZERO_VECTOR {0.0, 0.0, 0.0}

enum struct CEffectData {
  float m_vOrigin[3];
  float m_vStart[3];
  float m_vNormal[3];
  float m_vAngles[3];
  int m_fFlags;
  int m_nEntIndex;
  float m_flScale;
  float m_flMagnitude;
  float m_flRadius;
  int m_nAttachmentIndex;
  int m_nSurfaceProp;
  int m_nMaterial;
  int m_nDamageType;
  int m_nHitBox;
  int m_nOtherEntIndex;
  int m_nColor;
  bool m_bPositionsAreRelativeToEntity;
  int m_iEffectName;
}

static char _colorNames[][] = {"{NORMAL}", "{DARK_RED}",    "{PINK}",      "{GREEN}",
                               "{YELLOW}", "{LIGHT_GREEN}", "{LIGHT_RED}", "{GRAY}",
                               "{ORANGE}", "{LIGHT_BLUE}",  "{DARK_BLUE}", "{PURPLE}"};
static char _colorCodes[][] = {"\x01", "\x02", "\x03", "\x04",
                                "\x05", "\x06", "\x07", "\x08",
                                "\x09", "\x0B", "\x0C", "\x0E"};

stock void SwitchPlayerTeam(int client, int team) {
  if (GetClientTeam(client) == team)
    return;

  if (team > CS_TEAM_SPECTATOR) {
    ForcePlayerSuicide(client);
    CS_SwitchTeam(client, team);
    CS_UpdateClientModel(client);
    CS_RespawnPlayer(client);
  } else {
    ChangeClientTeam(client, team);
  }
}

stock bool IsValidClient(int client) {
  return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

stock bool IsPlayer(int client) {
  return IsValidClient(client) && !IsFakeClient(client) && !IsClientSourceTV(client);
}

public bool IsPointVisible(const float start[3], const float end[3]) {
  TR_TraceRayFilter(start, end, MASK_SHOT_HULL, RayType_EndPoint, Trace_NoPlayersFilter);
  return TR_GetFraction() == 1.0;
}

public bool Trace_NoPlayersFilter(int entity, int contentsMask)
{
    return (entity > MaxClients && !(0 < GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") <= MaxClients));
}

public bool Trace_BaseFilter(int entity, int contentsMask, any data) {
  if (entity == data) return false;
  return true;
}

stock void SendVectorToGround(float origin[3]) {
  if(TR_PointOutsideWorld(origin)){
    return;
  }
  float ground[3];
  Handle hTrace = TR_TraceRayEx(origin, {90.0,0.0,0.0}, CONTENTS_SOLID, RayType_Infinite);
  if (TR_DidHit(hTrace)) {
    TR_GetEndPosition(ground, hTrace);
    CloseHandle(hTrace);
    origin[2] = ground[2];
  }
}

stock bool IsServerEmpty() {
  for (int client = 1; client <= MaxClients; client++) {
    if (IsPlayer(client)) {
      return false;
    }
  }
  return true;
}

stock void Colorize(char[] msg, int size, bool stripColor = false) {
  for (int i = 0; i < sizeof(_colorNames); i++) {
    if (stripColor)
      ReplaceString(msg, size, _colorNames[i], "\x01");  // replace with white
    else
      ReplaceString(msg, size, _colorNames[i], _colorCodes[i]);
  }
}

public void SetCvarIntSafe(const char[] name, int value) {
  Handle cvar = FindConVar(name);
  if (cvar == INVALID_HANDLE) {
    PrintToServer("1-Failed to find cvar: \"%s\"", name);
  } else {
    SetConVarInt(cvar, value);
  }
}

public void SetConVarFloatSafe(const char[] name, float value) {
  Handle cvar = FindConVar(name);
  if (cvar == INVALID_HANDLE) {
    PrintToServer("2-Failed to find cvar: \"%s\"", name);
  } else {
    SetConVarFloat(cvar, value);
  }
}

stock void SetConVarStringSafe(const char[] name, const char[] value) {
  Handle cvar = FindConVar(name);
  if (cvar == INVALID_HANDLE) {
    PrintToServer("3-Failed to find cvar: \"%s\"", name);
  } else {
    SetConVarString(cvar, value);
  }
}

stock int FindAndErase(ArrayList array, int value) {
  int count = 0;
  for (int i = 0; i < array.Length; i++) {
    if (array.Get(i) == value) {
      array.Erase(i);
      i--;
      count++;
    }
  }
  return count;
}

stock int GetCvarIntSafe(const char[] cvarName, int defaultValue = 0) {
  Handle cvar = FindConVar(cvarName);
  if (cvar == INVALID_HANDLE) {
    PrintToServer("4-Failed to find cvar \"%s\"", cvar);
    return defaultValue;
  } else {
    return GetConVarInt(cvar);
  }
}

stock float GetCvarFloatSafe(const char[] cvarName, float defaultValue = 0.0) {
  Handle cvar = FindConVar(cvarName);
  if (cvar == INVALID_HANDLE) {
    PrintToServer("5-Failed to find cvar \"%s\"", cvar);
    return defaultValue;
  } else {
    return GetConVarFloat(cvar);
  }
}

stock void GetCvarStringSafe(const char[] cvarName, char[] buffer, int size, char[] defaultValue = "") {
  Handle cvar = FindConVar(cvarName);
  if (cvar == INVALID_HANDLE) {
    PrintToServer("6-Failed to find cvar \"%s\"", cvar);
    strcopy(buffer, size, defaultValue);
  } else {
    GetConVarString(cvar, buffer, size);
  }
}

stock int FindStringInArray2(const char[][] array, int len, const char[] string,
                             bool caseSensitive = true) {
  for (int i = 0; i < len; i++) {
    if (StrEqual(string, array[i], caseSensitive)) {
      return i;
    }
  }

  return -1;
}

stock void GetCleanMapName(char[] buffer, int size) {
  char mapName[PLATFORM_MAX_PATH];
  GetCurrentMap(mapName, sizeof(mapName));
  CleanMapName(mapName, buffer, size);
}

stock void CleanMapName(const char[] input, char[] buffer, int size) {
  int last_slash = 0;
  int len = strlen(input);
  for (int i = 0; i < len; i++) {
    if (input[i] == '/' || input[i] == '\\')
      last_slash = i + 1;
  }
  strcopy(buffer, size, input[last_slash]);
}

stock void RemoveCvarFlag(Handle cvar, int flag) {
  SetConVarFlags(cvar, GetConVarFlags(cvar) & ~flag);
}

stock ConVar GetCvar(const char[] name) {
  ConVar cvar = FindConVar(name);
  if (cvar == null) {
    SetFailState("Failed to find cvar: \"%s\"", name);
  }
  return cvar;
}

stock void UpperString(char[] string) {
  int len = strlen(string);
  for (int i = 0; i < len; i++) {
    string[i] = CharToUpper(string[i]);
  }
}

public bool EnforceDirectoryExists(const char[] smPath) {
  char dir[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, dir, sizeof(dir), smPath);
  if (!DirExists(dir)) {
    if (!CreateDirectory(dir, 511)) {
      PrintToServer("Failed to create directory %s", dir);
      return false;
    }
  }
  return true;
}

stock void ChangeMap(const char[] map, float delay = 3.0) {
  DataPack pack = CreateDataPack();
  pack.WriteString(map);
  CreateTimer(delay, Timer_DelayedChangeMap, pack);
}

stock Action Timer_DelayedChangeMap(Handle timer, Handle data) {
  char map[PLATFORM_MAX_PATH];
  DataPack pack = view_as<DataPack>(data);
  pack.Reset();
  pack.ReadString(map, sizeof(map));
  delete pack;

  if (IsMapValid(map)) {
    ServerCommand("changelevel %s", map);
  } else if (StrContains(map, "workshop") == 0) {
    ServerCommand("host_workshop_map %d", GetMapIdFromString(map));
  }

  return Plugin_Handled;
}

stock int GetMapIdFromString(const char[] map) {
  char buffers[4][PLATFORM_MAX_PATH];
  ExplodeString(map, "/", buffers, sizeof(buffers), PLATFORM_MAX_PATH);
  return StringToInt(buffers[1]);
}

stock void AddMenuInt(Menu menu, int value, const char[] display, any:...) {
  char formattedDisplay[128];
  VFormat(formattedDisplay, sizeof(formattedDisplay), display, 4);
  char buffer[32];
  IntToString(value, buffer, sizeof(buffer));
  menu.AddItem(buffer, formattedDisplay);
}

stock void AddMenuIntStyle(Menu menu, int value, int style, const char[] display, any:...) {
  char formattedDisplay[128];
  VFormat(formattedDisplay, sizeof(formattedDisplay), display, 5);
  char buffer[32];
  IntToString(value, buffer, sizeof(buffer));
  menu.AddItem(buffer, formattedDisplay, style);
}

stock int GetMenuInt(Menu menu, int param2) {
  char buffer[32];
  menu.GetItem(param2, buffer, sizeof(buffer));
  return StringToInt(buffer);
}

stock void GetPlayerBoundingBox(int client, float min[3], float max[3]) {
  float clientMin[3];
  float clientMax[3];
  float clientOrigin[3];
  GetClientMins(client, clientMin);
  GetClientMaxs(client, clientMax);
  GetClientAbsOrigin(client, clientOrigin);
  for (int i = 0; i < 3; i++) {
    min[i] = clientOrigin[i] + clientMin[i];
    max[i] = clientOrigin[i] + clientMax[i];
  }
}

stock bool DoPlayersCollide(int client1, int client2) {
  float client1Min[3];
  float client1Max[3];
  float client2Min[3];
  float client2Max[3];
  GetPlayerBoundingBox(client1, client1Min, client1Max);
  GetPlayerBoundingBox(client2, client2Min, client2Max);
  return (client1Min[0] <= client2Max[0] && client1Max[0] >= client2Min[0]) &&
         (client1Min[1] <= client2Max[1] && client1Max[1] >= client2Min[1]) &&
         (client1Min[2] <= client2Max[2] && client1Max[2] >= client2Min[2]);
}

stock float GetFlashDuration(int client) {
  return GetEntDataFloat(client, FindSendPropInfo("CCSPlayer", "m_flFlashDuration"));
}

stock int GetRoundTimeSeconds() {
  ConVar cvar = FindConVar("mp_roundtime");
  float cvar_value = 1.92;
  if (cvar != null) {
    cvar_value = cvar.FloatValue;
  }
  return RoundFloat(cvar_value * 60);
}

public void DispatchEffect(int client, const char[] effectName, CEffectData data) {
    data.m_iEffectName = GetEffectIndex(effectName);

    TE_SetupEffectDispatch(data);
    if (client == 0) TE_SendToAll();
    else TE_SendToClient(client);
}

int GetEffectIndex(const char[] effectName) {
    static int table = INVALID_STRING_TABLE;
    
    if (table == INVALID_STRING_TABLE)
        table = FindStringTable("EffectDispatch");
    
    int index = FindStringIndex(table, effectName);
    
    if (index != INVALID_STRING_INDEX)
        return index;

    return 0;
}

void TE_SetupEffectDispatch(CEffectData data) {
    TE_Start("EffectDispatch");
    TE_WriteFloatArray("m_vOrigin.x", data.m_vOrigin, 3);
    TE_WriteFloatArray("m_vStart.x", data.m_vStart, 3);
    TE_WriteAngles("m_vAngles", data.m_vAngles);
    TE_WriteVector("m_vNormal", data.m_vNormal);
    TE_WriteNum("m_fFlags", data.m_fFlags);
    TE_WriteFloat("m_flMagnitude", data.m_flMagnitude);
    TE_WriteFloat("m_flScale", data.m_flScale);
    TE_WriteNum("m_nAttachmentIndex", data.m_nAttachmentIndex);
    TE_WriteNum("m_nSurfaceProp", data.m_nSurfaceProp);
    TE_WriteNum("m_iEffectName", data.m_iEffectName);
    TE_WriteNum("m_nMaterial", data.m_nMaterial);
    TE_WriteNum("m_nDamageType", data.m_nDamageType);
    TE_WriteNum("m_nHitBox", data.m_nHitBox);
    TE_WriteNum("entindex", data.m_nEntIndex);
    TE_WriteNum("m_nOtherEntIndex", data.m_nOtherEntIndex);
    TE_WriteNum("m_nColor", data.m_nColor);
    TE_WriteFloat("m_flRadius", data.m_flRadius);
    TE_WriteNum("m_bPositionsAreRelativeToEntity", data.m_bPositionsAreRelativeToEntity);
}

public int GetParticleSystemIndex(const char[] effectName) {
    static int table = INVALID_STRING_TABLE;
    
    if (table == INVALID_STRING_TABLE)
        table = FindStringTable("ParticleEffectNames");
    
    int index = FindStringIndex(table, effectName);
    
    if (index != INVALID_STRING_INDEX)
        return index;

    return 0;
}

public void GetRandomColor(int colors[4], int alpha) {
  colors[0] = GetRandomInt(0, 255);
  colors[1] = GetRandomInt(0, 255);
  colors[2] = GetRandomInt(0, 255);
  colors[3] = alpha;
}

public bool VecEqual(const float vec1[3], const float vec2[3]) {
  return vec1[0]==vec2[0] && vec1[1]==vec2[1] && vec1[2]==vec2[2];
}