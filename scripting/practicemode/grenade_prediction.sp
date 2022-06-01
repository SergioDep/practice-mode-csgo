
#define interval_per_tick 0.05
#define GenerateViewPointDelay 1

GrenadePredict_Mode g_PredictMode[MAXPLAYERS + 1] = {GRENADEPREDICT_NONE, ...};
bool g_Predict_HoldingUse[MAXPLAYERS + 1] = {false, ...};
bool g_Predict_HoldingReload[MAXPLAYERS + 1] = {false, ...};
bool g_Predict_ViewEndpoint[MAXPLAYERS + 1] = {false, ...};
int g_Predict_ObservingGrenade[MAXPLAYERS + 1] = {-2, ...};
int g_Predict_FinalDestinationEnt[MAXPLAYERS + 1] = {-1, ...};
int g_Predict_GenerateViewPointDelay[MAXPLAYERS + 1] = {GenerateViewPointDelay, ...};
float g_Predict_LastClientPos[MAXPLAYERS + 1][3]; // g_LastGrenadePinPulledOrigin
float g_Predict_LastClientAng[MAXPLAYERS + 1][3];

// database
Database g_PredictionDb = null;
ArrayList g_PredictionResults[MAXPLAYERS + 1] = {null, ...};
int g_PredictionCurrentLineup[MAXPLAYERS + 1];
float g_PredictionClientPos[MAXPLAYERS + 1][3];

enum struct S_PredictedPositions {
  char startingPosId[32];
  float origin[3];
  float angles[3];
  char grenadeThrowType[128];
  float airTime;
  float endPos[3];
}

enum GrenadePredict_Mode {
  GRENADEPREDICT_NONE = 0,
  GRENADEPREDICT_NORMAL,
  GRENADEPREDICT_JUMPTHROW
}

public void NadePrediction_PluginStart() {
  if (g_PredictionDb == null) {
    Database.Connect(SQLConnectPredictionsCallback, "prediction-test");
  }

  for (int i = 0; i <= MaxClients; i++) {
    g_PredictionResults[i] = new ArrayList(sizeof(S_PredictedPositions));
  }
}

public void SQLConnectPredictionsCallback(Database database, const char[] error, any data) {
  if (database == null) {
    LogError("Database failure: %s", error);
  } else {
    g_PredictionDb = database;
    char dbIdentifier[10];
    g_PredictionDb.Driver.GetIdentifier(dbIdentifier, sizeof(dbIdentifier));
    
    char createQuery[2560];
    Format(createQuery, sizeof(createQuery),
      "CREATE TABLE IF NOT EXISTS predict_startpos("...
      "  x float,"...
      "  y float,"...
      "  z float,"...
      "  pitch float,"...
      "  yaw float,"...
      "  i int,"...
      "  id varchar(25),"...
      "  map varchar(25),"...
      "  type varchar(25),"...
      "  UNIQUE(id, map, type))"...
      ");"...

      "CREATE TABLE IF NOT EXISTS predict_endpos("...
      "  parentId varchar(25),"...
      "  endx float,"...
      "  endy float,"...
      "  endz float,"...
      "  ang_x float,"...
      "  ang_y float,"...
      "  n_bounces int,"...
      "  airtime float,"...
      "  id varchar(25),"...
      "  map varchar(25),"...
      "  throwtype varchar(25),"...
      "  type varchar(25),"...
      "  UNIQUE(parentId, id, map, type))"
    );
    g_PredictionDb.Query(Predict_CreateTables_ErrorCheckCallback, createQuery, _, DBPrio_High);
  }
}

public void Predict_CreateTables_ErrorCheckCallback(Database database, DBResultSet results, const char[] error, any data) {
  if (results == null) {
    LogError("SQLite Creating the main prediction tables has failed! %s", error);
  } else {
    PrintToServer("=================Connected to DB!=================");
  }
}

public int CreateInvisibleEnt() {
  int ent = -1;
  ent = CreateEntityByName("prop_dynamic_override");
  if (ent > 0) {
    DispatchKeyValue(ent, "classname", "prop_dynamic_override");
    DispatchKeyValue(ent, "model", "models/chicken/festive_egg.mdl");
    SetEntityRenderMode(ent, RENDER_NONE);
    DispatchSpawn(ent);
  }
  return ent;
}

public Action NadePrediction_PlayerRunCmd(int client, int &buttons, char[] weaponName) {
  // Player Has Required Entities?
  if (g_Predict_FinalDestinationEnt[client] < 0 || !IsValidEntity(g_Predict_FinalDestinationEnt[client])) {
    g_Predict_FinalDestinationEnt[client] = CreateInvisibleEnt();
    return Plugin_Handled;
  } 

  // Get Client Buttons
  if ((buttons & IN_RELOAD) && !g_Predict_HoldingReload[client]) {
    g_Predict_HoldingReload[client] = true;
  } else if (!(buttons & IN_RELOAD) && g_Predict_HoldingReload[client]) {
    if (g_Predict_ObservingGrenade[client] > 0) {
      ClientStopObserveEntities(client);
      g_Predict_ObservingGrenade[client] = -1;
      if (Math_VectorsEqual(g_Predict_LastClientPos[client], ZERO_VECTOR) && Math_VectorsEqual(g_Predict_LastClientAng[client], ZERO_VECTOR)) {
        TeleportEntity(client, g_LastGrenadePinPulledOrigin[client], g_LastGrenadePinPulledAngles[client] , ZERO_VECTOR);
      } else {
        TeleportEntity(client, g_Predict_LastClientPos[client], g_Predict_LastClientAng[client] , ZERO_VECTOR);
      }
    } else if (g_Predict_ViewEndpoint[client]) {
      SetClientViewEntity(client, client);
      Client_SetFOV(client, 90);
      g_Predict_ViewEndpoint[client] = false;
      if (!(Math_VectorsEqual(g_Predict_LastClientPos[client], ZERO_VECTOR) && Math_VectorsEqual(g_Predict_LastClientAng[client], ZERO_VECTOR))) {
        TeleportEntity(client, g_Predict_LastClientPos[client], g_Predict_LastClientAng[client] , ZERO_VECTOR);
      } else {
        TeleportEntity(client, g_LastGrenadePinPulledOrigin[client], g_LastGrenadePinPulledAngles[client] , ZERO_VECTOR);
      }
    }
    g_Predict_HoldingReload[client] = false;
  }

  if (StrContains(nadelist, weaponName, false) != -1) {
    if((buttons & IN_USE) && !g_Predict_HoldingUse[client]) {
      if (g_PredictMode[client] == GRENADEPREDICT_NONE) {
        g_PredictMode[client] = GRENADEPREDICT_NORMAL;
        PrintHintText(client, "Modo de Trayectoria: Normal");

      } else if (g_PredictMode[client] == GRENADEPREDICT_NORMAL) {
        g_PredictMode[client] = GRENADEPREDICT_JUMPTHROW;
        PrintHintText(client, "Modo de Trayectoria: Jumpthrow");

      } else if (g_PredictMode[client] == GRENADEPREDICT_JUMPTHROW) {
        g_PredictMode[client] = GRENADEPREDICT_NONE;
        PrintHintText(client, "Modo de Trayectoria: Desactivado");

      }
      g_Predict_HoldingUse[client] = true;
    } else if (!(buttons & IN_USE) && g_Predict_HoldingUse[client]) {
      g_Predict_HoldingUse[client] = false;
    }

    if (buttons & IN_ATTACK) {
      if (g_Predict_HoldingReload[client]) {
        GetClientAbsOrigin(client, g_Predict_LastClientPos[client]);
        GetClientEyeAngles(client, g_Predict_LastClientAng[client]);
        float endPoint[3];
        if (g_PredictMode[client] == GRENADEPREDICT_NONE) {
          // CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW, buttons & IN_DUCK,
          //  endPoint, g_Predict_LastClientPos[client], g_Predict_LastClientAng[client]);
          // TeleportEntity(g_Predict_FinalDestinationEnt[client], endPoint, NULL_VECTOR, NULL_VECTOR);
        } else {
          CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW, buttons & IN_DUCK,
            endPoint, g_Predict_LastClientPos[client]);
          if (!g_Predict_ViewEndpoint[client]) {
            SetClientViewEntity(client, g_Predict_FinalDestinationEnt[client]);
            Client_SetFOV(client, 120);
            g_Predict_ViewEndpoint[client] = true;
            g_Predict_GenerateViewPointDelay[client] = GenerateViewPointDelay;
          } else {
            if (g_Predict_GenerateViewPointDelay[client] == GenerateViewPointDelay) {
              TeleportToObserverPos(client, endPoint);
              g_Predict_GenerateViewPointDelay[client] = 0;
            }
            g_Predict_GenerateViewPointDelay[client]++;
          }
        }
      } else {
        if (g_PredictMode[client] > GRENADEPREDICT_NONE) {
          CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW, buttons & IN_DUCK);
        }
      }
    } else if (IsValidEntity(g_LastGrenadeEntity[client]) && g_LastGrenadeEntity[client] > 0 &&
      g_Predict_HoldingReload[client] && g_Predict_ObservingGrenade[client] < 0) {
        if (g_Predict_ViewEndpoint[client]) {
          SetClientViewEntity(client, client);
          Client_SetFOV(client, 90);
          g_Predict_ViewEndpoint[client] = false;
          g_Predict_ObservingGrenade[client] = 1;
          CreateTimer(0.35, Timer_WaitForNewGrenade, GetClientSerial(client));
        } else {
          g_Predict_ObservingGrenade[client] = WatchFlyingGrenade(client, true);
        }
    } else if (g_Predict_HoldingReload[client]) {
      if (g_PredictMode[client] > GRENADEPREDICT_NONE) {
        CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW, buttons & IN_DUCK,
          _, g_Predict_LastClientPos[client], g_Predict_LastClientAng[client]);
      }
      if (GetEntityMoveType(client) == MOVETYPE_NONE && g_Predict_ObservingGrenade[client] > 1) {
        SetClientObserveEntity(client, g_Predict_ObservingGrenade[client]);
      }
    }
  } else if (g_Predict_ObservingGrenade[client] > 0) {
    CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW, buttons & IN_DUCK,
      _, g_Predict_LastClientPos[client], g_Predict_LastClientAng[client]);
    SetEntityRenderMode(client, RENDER_NONE); //?
  }
  return Plugin_Handled;
}

public void TeleportToObserverPos(int client, const float CenterPoint[3]) {
  Handle NearestCeil = TR_TraceRayFilterEx(
    CenterPoint,
    {-90.0,0.0,0.0},
    CONTENTS_SOLID,
    RayType_Infinite,
    Prediction_TraceFilter,
    client
  );
  float topPos[3];
  TR_GetEndPosition(topPos, NearestCeil);
  float eyeAngles[3];
  GetClientEyeAngles(client, eyeAngles);
  eyeAngles[0] = 90.0;
  TeleportEntity(g_Predict_FinalDestinationEnt[client], topPos, eyeAngles, NULL_VECTOR);
}

public Action Timer_WaitForNewGrenade(Handle Timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (!g_Predict_HoldingReload[client] || !IsValidEntity(g_LastGrenadeEntity[client]) || g_LastGrenadeEntity[client] < 0) {
    ClientStopObserveEntities(client);
    return Plugin_Handled;
  }
  g_Predict_ObservingGrenade[client] = WatchFlyingGrenade(client);
  return Plugin_Handled;
}

stock void CreateTrajectory(
  int client,
  const char[] weapon,
  bool jumpthrow = false,
  int crouching = false,
  float endPos[3] = {},
  const float customOrigin[3] = {0.0, 0.0, 0.0},
  const float customAngles[3] = {0.0, 0.0, 0.0},
  const float customVelocity[3] = {0.0, 0.0, 0.0}
) {
  GrenadeType grenadeType = GrenadeTypeFromWeapon(client, weapon);
  float dtime = GetGrenadeDetonationTime(grenadeType);
  float GrenadeVelocity[3], PlayerVelocity[3], vforward[3];
  float gStart[3], gEnd[3], angThrow[3];

  GetClientEyePosition(client, gStart);
  GetClientEyeAngles(client, angThrow);
  GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", PlayerVelocity);
  if (customOrigin[0] || customOrigin[1] || customOrigin[2]) {
    gStart = customOrigin;
    gStart[2] += 64.0; // eye level
    ScaleVector(PlayerVelocity, 0.0);
  }
  if (customAngles[0] || customAngles[1] || customAngles[2]) {
    angThrow = customAngles;
  }
  if (customVelocity[0] || customVelocity[1] || customVelocity[2]) {
    PlayerVelocity = customVelocity;
  }

  if (angThrow[0] < -90.0) angThrow[0] += 360.0;
  else if (angThrow[0] > 90.0) angThrow[0] -= 360.0;

  angThrow[0] -= (90.0 - FloatAbs(angThrow[0]))*10.0/90.0;

  GetAngleVectors(angThrow, vforward, NULL_VECTOR, NULL_VECTOR);
  NormalizeVector(vforward, vforward);

  gStart[2] += (jumpthrow) ? ((!crouching) ? 27.9035568237 : 28.245349884) : 0.0;
  for (int i = 0; i < 3; i++)
    gStart[i] += vforward[i] * 16.0000142601273616094204044;

  PlayerVelocity[2] = (jumpthrow) ? ((!crouching) ? 211.3683776855468 : 214.4933776855468000) : PlayerVelocity[2];
  ScaleVector(PlayerVelocity, 1.25);

  for (int i = 0; i < 3; i++)
    GrenadeVelocity[i] =  PlayerVelocity[i] + vforward[i] * 675.0;

  for (float t = 0.0; t <= dtime; t += interval_per_tick) {
    gEnd[0] = gStart[0] + GrenadeVelocity[0] * interval_per_tick;
    gEnd[1] = gStart[1] + GrenadeVelocity[1] * interval_per_tick;

    float newZVelocity = GrenadeVelocity[2] - 0.4 * 800 * interval_per_tick;

    gEnd[2] = gStart[2] + (GrenadeVelocity[2] + newZVelocity) / 2.0 * interval_per_tick;
    GrenadeVelocity[2] = newZVelocity;

    Handle gRayTrace = TR_TraceHullFilterEx(
      gStart,
      gEnd,
      {-2.0, -2.0, -2.0},
      {2.0, 2.0, 2.0},
      MASK_SOLID | CONTENTS_CURRENT_90,
      Prediction_TraceFilter,
      client);
    float trFraction = TR_GetFraction(gRayTrace);
    if (trFraction != 1.0) {
      int ent = TR_GetEntityIndex(gRayTrace);
      char ClassName[30];
      GetEdictClassname(ent, ClassName, sizeof(ClassName));
      if (StrEqual(ClassName, "func_breakable", false) || StrEqual(ClassName, "prop_dynamic", false)) {
        CloseHandle(gRayTrace);
        gStart = gEnd;
        for (int i = 0; i < 3; i++) {
          GrenadeVelocity[i] *= 0.4;
        }
        continue;
      }

      TR_GetEndPosition(gEnd, gRayTrace);
      float normal[3];
      TR_GetPlaneNormal(gRayTrace, normal);
      float backoff = 2 * GetVectorDotProduct(normal, GrenadeVelocity);
      for (int i = 0; i < 3; i++) {
        GrenadeVelocity[i] -= normal[i] * backoff;
        if (GrenadeVelocity[i] > -0.1 && GrenadeVelocity[i] < 0.1)
          GrenadeVelocity[i] = 0.0;
      }
      ScaleVector(GrenadeVelocity, 0.45);
      if (normal[2] > 0.7) {
        float flSpeedSqr = GetVectorDotProduct(GrenadeVelocity, GrenadeVelocity);
        if (flSpeedSqr > 96000.0) {
          float GrenadeVelocityNormalized[3];
          NormalizeVector(GrenadeVelocity, GrenadeVelocityNormalized);
          float l = GetVectorDotProduct(GrenadeVelocityNormalized, normal);
          if (l > 0.5) {
            ScaleVector(GrenadeVelocity, 1.0 - l + 0.5);
          }
        }
        if (flSpeedSqr < 400.0) {
          ScaleVector(GrenadeVelocity, 0.0);
        } else {
          // fixVelFraction(GrenadeVelocity, trFraction, false);
        }
        if (grenadeType == GrenadeType_Incendiary || grenadeType == GrenadeType_Molotov)
          dtime = 0.0;
      } else {
        // fixVelFraction(GrenadeVelocity, trFraction);
      }
    }

    CloseHandle(gRayTrace);
    TE_SetupBeamPoints(gStart, gEnd, g_PredictTrail, 0, 0, 0, 0.1, 0.5, 0.5, 0, 0.0, { 0, 255, 255, 255 }, 0);
    TE_SendToAll();
    gStart = gEnd;
  }
  endPos = gEnd;
  int colors[4] = { 0, 255, 0, 255 };
  float explodePos[3];
  explodePos = endPos;
  if (grenadeType >= GrenadeType_Molotov && grenadeType != GrenadeType_Decoy) {
    float ground[3];
    Handle hTrace = TR_TraceRayEx(explodePos, {90.0,0.0,0.0}, MASK_SOLID | CONTENTS_CURRENT_90, RayType_Infinite);
    if (TR_DidHit(hTrace)) {
      TR_GetEndPosition(ground, hTrace);
      if ((explodePos[2] - ground[2]) < 131) {
        ground[2] += 2.0;
      } else {
        colors[0] = 255; colors[1] = 0;
      }
    }
  }
  // TE_SetupBeamCube(explodePos, 2.0, g_BeamSprite, 0, 0, 0, 0.1, 0.5, 0.5, 0, 0.0, colors, 0);
}

public void TE_SetupBeamCube(float center[3], float size, int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, 
				float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed) {
  float vMins[3], vMaxs[3];
  vMins[0] = -size; vMaxs[0] = size;
  vMins[1] = -size; vMaxs[1] = size;
  vMins[2] = -size; vMaxs[2] = size;
  AddVectors(center, vMaxs, vMaxs);
  AddVectors(center, vMins, vMins);
  float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
  vPos1 = vMaxs;
  vPos1[0] = vMins[0];
  vPos2 = vMaxs;
  vPos2[1] = vMins[1];
  vPos3 = vMaxs;
  vPos3[2] = vMins[2];
  vPos4 = vMins;
  vPos4[0] = vMaxs[0];
  vPos5 = vMins;
  vPos5[1] = vMaxs[1];
  vPos6 = vMins;
  vPos6[2] = vMaxs[2];
  TE_SetupBeamPoints(vMaxs, vPos1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vMaxs, vPos2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vMaxs, vPos3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vPos6, vPos1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vPos6, vPos2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vPos6, vMins, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vPos4, vMins, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vPos5, vMins, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vPos5, vPos1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vPos5, vPos3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vPos4, vPos3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(vPos4, vPos2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength
  , Amplitude, Color, Speed);
  TE_SendToAll();
}

stock void fixVelFraction(float GrenadeVelocity[3], float frac, bool sum = true) {
  // PrintToChatAll("fraction %f", frac);
  if (frac != 0) {
    for (int i = 0; i<3; i++) {
      // GrenadeVelocity[i] -= GrenadeVelocity[i]*(1.0-frac)*0.05;
      // GrenadeVelocity[i] = GrenadeVelocity[i]*(1.0-frac*0.05);
      // GrenadeVelocity[i] += GrenadeVelocity[i]*(1.0-frac)*0.05;
      // GrenadeVelocity[i] += GrenadeVelocity[i]*(1.0-frac)*0.04545454545;
      // GrenadeVelocity[i] += GrenadeVelocity[i]*(1.0-frac)*0.0258;
      // GrenadeVelocity[i] -= GrenadeVelocity[i]*(1.0-frac)*0.0015;
    }
  }
}

public bool Prediction_TraceFilter(int entity, int contentsMask, any data) {
  if (entity == data) return false;
  char ClassName[30];
  GetEdictClassname(entity, ClassName, sizeof(ClassName));
  if (StrContains(ClassName, "_projectile") != -1) {
    return false;
  }
  return true;
}

stock GrenadeType GrenadeTypeFromWeapon(int client, const char[] name) {
  if (StrEqual(name, "weapon_smokegrenade")) return GrenadeType_Smoke;
  if (StrEqual(name, "weapon_flashbang")) return GrenadeType_Flash;
  if (StrEqual(name, "weapon_hegrenade")) return GrenadeType_HE;
  if (StrEqual(name, "weapon_molotov")) return GrenadeType_Molotov;
  if (StrEqual(name, "weapon_decoy")) return GrenadeType_Decoy;
  if (StrEqual(name, "weapon_incgrenade")) return GrenadeType_Incendiary;
  else return g_LastGrenadeType[client];
}

stock float GetGrenadeDetonationTime(GrenadeType grenadeType) {
  if (grenadeType == GrenadeType_Smoke) return 10.0;
  if (grenadeType == GrenadeType_Incendiary || grenadeType == GrenadeType_Molotov) return 2.00; // 1.979 2.031250
  if (grenadeType == GrenadeType_HE || grenadeType == GrenadeType_Flash) return 1.602;
  return 10.0;
}

stock int WatchFlyingGrenade(int client, bool teleport = false) {
  // Create Follow entity
  int ent = CreateInvisibleEnt();
  if (ent > 0) {
    float origin[3], angles[3];
    Entity_GetAbsOrigin(g_LastGrenadeEntity[client], origin);
    Entity_GetAbsAngles(g_LastGrenadeEntity[client], angles);
    TeleportEntity(ent, origin, angles, NULL_VECTOR);
    if (teleport) TeleportEntity(client, origin, angles, NULL_VECTOR);
    SetVariantString("!activator");
    AcceptEntityInput(ent, "SetParent", g_LastGrenadeEntity[client], ent, 0);
  }
  SetClientObserveEntity(client, ent);
  return ent;
}

public void SetClientObserveEntity(int client, int entity) {
  SetEntityRenderMode(client, RENDER_NONE);
  SetEntityMoveType(client, MOVETYPE_OBSERVER);
  SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
  SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", entity);
  SetEntityRenderMode(client, RENDER_NONE);
  // PrintHintText(client, "Suelta R para regresar");
}

public void ClientStopObserveEntities(int client) {
  SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
  SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
  SetEntityRenderMode(client, RENDER_NORMAL);
  SetEntityMoveType(client, MOVETYPE_WALK);
}

public Action Command_PredictNades(int client, int args) {
  GetClientAbsOrigin(client, g_PredictionClientPos[client]);
  PM_Message(client, "{ORANGE} Predicting a smoke for your current position [{GREEN}%.2f, %.2f, %.2f{ORANGE}]...",
    g_PredictionClientPos[client][0], g_PredictionClientPos[client][1], g_PredictionClientPos[client][2]);
  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));
  float precision = 10.0;
  float zprecision = 35.0;
  PM_Message(client, "{ORANGE}Radius: %.2f, Z Precision = %.2f", precision, zprecision);
  char query[512];
  SQL_FormatQuery(g_PredictionDb, query, sizeof(query),
    "  SELECT s.x, s.y, s.z, e.ang_x, e.ang_y, e.throwtype, e.airtime, e.parentId, e.endx, e.endy, e.endz"...
    "  FROM predict_endpos e, predict_startpos s"...
    "  WHERE e.map = '%s' AND e.parentId = s.id"...
    "  AND e.endx BETWEEN %f AND %f"...
    "  AND e.endy BETWEEN %f AND %f"...
    "  AND e.endz BETWEEN %f AND %f",
    map,
    g_PredictionClientPos[client][0] - precision,
    g_PredictionClientPos[client][0] + precision,
    g_PredictionClientPos[client][1] - precision,
    g_PredictionClientPos[client][1] + precision,
    g_PredictionClientPos[client][2] - zprecision,
    g_PredictionClientPos[client][2] + zprecision
  );
  g_PredictionDb.Query(T_PredictGrenadesCallback, query, client);
  
  return Plugin_Handled;
}

public void T_PredictGrenadesCallback(Database database, DBResultSet results, const char[] error, int client) {
  if (!IsPlayer(client)) {
    PrintToServer("error T_PredictGrenadesCallback, invalid player (disconnected)");
    return;
  }
  if (results == null) {
    PrintToServer("Query T_PredictGrenadesCallback failed! %s", error);
  } else if (results.RowCount == 0) {
    PM_Message(client, "{LIGHT_RED}No se encontraron coincidencias");
  } else {
    g_PredictionResults[client].Clear();
    while (SQL_FetchRow(results)) {
      S_PredictedPositions predictedPosition;
      predictedPosition.origin[0] = results.FetchFloat(0);
      predictedPosition.origin[1] = results.FetchFloat(1);
      predictedPosition.origin[2] = results.FetchFloat(2);

      predictedPosition.angles[0] = results.FetchFloat(3);
      predictedPosition.angles[1] = results.FetchFloat(4);

      results.FetchString(5, predictedPosition.grenadeThrowType, sizeof(predictedPosition.grenadeThrowType));

      predictedPosition.airTime = results.FetchFloat(6);

      results.FetchString(7, predictedPosition.startingPosId, sizeof(predictedPosition.startingPosId));

      predictedPosition.endPos[0] = results.FetchFloat(8);
      predictedPosition.endPos[1] = results.FetchFloat(9);
      predictedPosition.endPos[2] = results.FetchFloat(10);
      g_PredictionResults[client].PushArray(predictedPosition, sizeof(predictedPosition));
    }
    g_PredictionCurrentLineup[client] = -1;
    // bubble sort
    S_PredictedPositions predictionj;
    S_PredictedPositions predictionj_1;
    for (int i = 1; i < g_PredictionResults[client].Length; i++) {
      for (int j = i; j > 0 ; j--) {
        g_PredictionResults[client].GetArray(j, predictionj, sizeof(predictionj));
        g_PredictionResults[client].GetArray(j-1, predictionj_1, sizeof(predictionj_1));
        if (strcmp(predictionj.startingPosId, predictionj_1.startingPosId) == -1) {
          g_PredictionResults[client].SwapAt(j, j-1);
        }
        else break;
      }
    }
    PM_Message(client, "{ORANGE}%d resultados encontrados!", results.RowCount);
    Command_PredictResultsMenu(client, 0);
  }
}

public Action Command_PredictResultsMenu(int client, int args) {
  Menu menu = new Menu(PredictionResultsMenuHandler);
  menu.SetTitle("Prediction Results:");

  int currentStartPos, startPosCount;
  char exploringPositionId[32] = "";
  S_PredictedPositions currentPredictedInfo;
  for (int i=0; i < g_PredictionResults[client].Length; i++) {
    g_PredictionResults[client].GetArray(i, currentPredictedInfo, sizeof(currentPredictedInfo));
    if (i == g_PredictionCurrentLineup[client]) {
      currentStartPos = startPosCount;
    }
    if (!StrEqual(currentPredictedInfo.startingPosId, exploringPositionId)) {
      startPosCount++;
      strcopy(exploringPositionId, sizeof(exploringPositionId), currentPredictedInfo.startingPosId);
    }
  }

  char displayStr[128];
  Format(displayStr, sizeof(displayStr), "Lineup Actual [%d/%d]", g_PredictionCurrentLineup[client]+1, g_PredictionResults[client].Length);
  menu.AddItem("", displayStr, ITEMDRAW_DISABLED);
  Format(displayStr, sizeof(displayStr), "Posicion Actual [%d/%d]\n ", currentStartPos, startPosCount);
  menu.AddItem("", displayStr, ITEMDRAW_DISABLED);

  menu.AddItem("prev_startpos", "Ir a anterior Lineup");
  menu.AddItem("next_startpos", "Ir a Siguiente Lineup");
  
  if (g_PredictionCurrentLineup[client] > -1) {
    g_PredictionResults[client].GetArray(g_PredictionCurrentLineup[client], currentPredictedInfo, sizeof(currentPredictedInfo));
    Format(displayStr, sizeof(displayStr), "Distancia hacia el Objetivo: %.2f", GetVectorDistance(g_PredictionClientPos[client], currentPredictedInfo.endPos));
    menu.AddItem("", displayStr, ITEMDRAW_DISABLED);
    Format(displayStr, sizeof(displayStr), "Ejecucion: %s", currentPredictedInfo.grenadeThrowType);
    menu.AddItem("", displayStr, ITEMDRAW_DISABLED);
    Format(displayStr, sizeof(displayStr), "Tiempo en Aire: %.2f", currentPredictedInfo.airTime);
    menu.AddItem("", displayStr, ITEMDRAW_DISABLED);
  } else {
    menu.AddItem("", "", ITEMDRAW_NOTEXT);
    menu.AddItem("", "", ITEMDRAW_NOTEXT);
    menu.AddItem("", "", ITEMDRAW_NOTEXT);
  }

  menu.Pagination = MENU_NO_PAGINATION;
  menu.ExitButton = true;
  menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
  return Plugin_Handled;
}

public int PredictionResultsMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[128];
    menu.GetItem(item, buffer, sizeof(buffer));
    S_PredictedPositions predictedPos;
    if (StrEqual(buffer, "next_startpos")) {
      g_PredictionCurrentLineup[client]++;
      if (g_PredictionCurrentLineup[client] >= g_PredictionResults[client].Length) {
        g_PredictionCurrentLineup[client] = 0;
      }
      g_PredictionResults[client].GetArray(g_PredictionCurrentLineup[client], predictedPos, sizeof(predictedPos));
    } else if (StrEqual(buffer, "prev_startpos")) {
      g_PredictionCurrentLineup[client]--;
      if (g_PredictionCurrentLineup[client] < 0) {
        g_PredictionCurrentLineup[client] = g_PredictionResults[client].Length-1;
      }
      g_PredictionResults[client].GetArray(g_PredictionCurrentLineup[client], predictedPos, sizeof(predictedPos));
    }

    predictedPos.origin[2] -= 64.0;
    SetEntityMoveType(client, MOVETYPE_WALK);
    TeleportEntity(client, predictedPos.origin, predictedPos.angles, ZERO_VECTOR);

    Command_PredictResultsMenu(client, 0);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}
