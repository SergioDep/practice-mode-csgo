
#define interval_per_tick 0.05
#define GenerateViewPointDelay 1

GrenadePredict_Mode g_PredictMode[MAXPLAYERS + 1] = {GRENADEPREDICT_NORMAL, ...};
bool g_Predict_HoldingUse[MAXPLAYERS + 1] = {false, ...};
bool g_Predict_HoldingReload[MAXPLAYERS + 1] = {false, ...};
bool g_Predict_ViewEndpoint[MAXPLAYERS + 1] = {false, ...};
int g_Predict_ObservingGrenade[MAXPLAYERS + 1] = {-2, ...};
int g_Predict_FinalDestinationEnt[MAXPLAYERS + 1] = {-1, ...};
int g_Predict_GenerateViewPointDelay[MAXPLAYERS + 1] = {GenerateViewPointDelay, ...};
float g_Predict_LastClientPos[MAXPLAYERS + 1][3]; // g_LastGrenadePinPulledOrigin
float g_Predict_LastClientAng[MAXPLAYERS + 1][3];

enum GrenadePredict_Mode {
  GRENADEPREDICT_NONE = 0,
  GRENADEPREDICT_NORMAL,
  GRENADEPREDICT_JUMPTHROW
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
      if (!(g_Predict_LastClientPos[client][0] == g_Predict_LastClientPos[client][1] &&
          g_Predict_LastClientPos[client][1] == g_Predict_LastClientPos[client][2] &&
          g_Predict_LastClientAng[client][0] == g_Predict_LastClientAng[client][1] &&
          g_Predict_LastClientAng[client][1] == g_Predict_LastClientAng[client][2])) {
        TeleportEntity(client, g_Predict_LastClientPos[client], g_Predict_LastClientAng[client]
        , view_as<float>({0.0,0.0,0.0}));
      }
      else
        TeleportEntity(client, g_LastGrenadePinPulledOrigin[client], g_LastGrenadePinPulledAngles[client]
        , view_as<float>({0.0,0.0,0.0}));
    } else if (g_Predict_ViewEndpoint[client]) {
      SetClientViewEntity(client, client);
      Client_SetFOV(client, 90);
      g_Predict_ViewEndpoint[client] = false;
      if (!(g_Predict_LastClientPos[client][0] == g_Predict_LastClientPos[client][1] &&
          g_Predict_LastClientPos[client][1] == g_Predict_LastClientPos[client][2] &&
          g_Predict_LastClientAng[client][0] == g_Predict_LastClientAng[client][1] &&
          g_Predict_LastClientAng[client][1] == g_Predict_LastClientAng[client][2])) {
        TeleportEntity(client, g_Predict_LastClientPos[client], g_Predict_LastClientAng[client]
        , view_as<float>({0.0,0.0,0.0}));
      }
      else
        TeleportEntity(client, g_LastGrenadePinPulledOrigin[client], g_LastGrenadePinPulledAngles[client]
        , view_as<float>({0.0,0.0,0.0}));
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
          CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW, endPoint, true, true); //jt
          TeleportEntity(g_Predict_FinalDestinationEnt[client], endPoint, NULL_VECTOR, NULL_VECTOR);
        } else {
          CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW, endPoint, true, false); //jt
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
            // TeleportEntity(g_Predict_FinalDestinationEnt[client], endPoint, NULL_VECTOR, NULL_VECTOR);
          }
        }
      } else {
        //WATCH_NONE
        if (g_PredictMode[client] > GRENADEPREDICT_NONE) {
          CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW);
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
      CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW, _, true, true);
      // random bug
      if (GetEntityMoveType(client) == MOVETYPE_NONE && g_Predict_ObservingGrenade[client] > 1) {
        SetClientObserveEntity(client, g_Predict_ObservingGrenade[client]);
        SetEntityMoveType(client, MOVETYPE_OBSERVER);
      }
      //WATCH_FINAL_ENDPOINT (LAST_ENDPOINT)  # VIEW AND TELEPORT PLAYER WHEN RELEASE?
    }
  } else if (g_Predict_ObservingGrenade[client] > 0) { // && GetEntityMoveType(client) == MOVETYPE_OBSERVER
    CreateTrajectory(client, weaponName, g_PredictMode[client]==GRENADEPREDICT_JUMPTHROW, _, true, true); //jt
    SetEntityRenderMode(client, RENDER_NONE); //0
  }
  return Plugin_Handled;
}

public void TeleportToObserverPos(int client, const float CenterPoint[3]) {
  Handle NearestCeil = TR_TraceRayFilterEx(
    CenterPoint,
    view_as<float>({-90.0,0.0,0.0}),
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
  if (!g_Predict_HoldingReload[client]) {
    ClientStopObserveEntities(client);
    return Plugin_Handled;
  }
  g_Predict_ObservingGrenade[client] = WatchFlyingGrenade(client);
  return Plugin_Handled;
}

stock void CreateTrajectory(
  int client,
  const char[] cWeapon,
  bool jumpthrow = false,
  float endPos[3] = {},
  bool useLastPosition = false,
  bool useLastAngles = false
) {
  float dtime = GetDetonationTime(client, cWeapon);
  float GrenadeVelocity[3], PlayerVelocity[3], vforward[3];
  float gStart[3], gEnd[3], angThrow[3];

  GetClientEyePosition(client, gStart);
  GetClientEyeAngles(client, angThrow);
  GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", PlayerVelocity);
  if (useLastPosition) {
    gStart = g_Predict_LastClientPos[client];
    gStart[2] += 64.0; // eye level
    ScaleVector(PlayerVelocity, 0.0);
  }
  if (useLastAngles) {
    angThrow = g_Predict_LastClientAng[client];
  }

  if (angThrow[0] < -90.0) angThrow[0] += 360.0;
  else if (angThrow[0] > 90.0) angThrow[0] -= 360.0;

  angThrow[0] -= (90.0 - FloatAbs(angThrow[0]))*10.0/90.0;

  GetAngleVectors(angThrow, vforward, NULL_VECTOR, NULL_VECTOR);
  NormalizeVector(vforward, vforward);

  gStart[2] += (jumpthrow) ? 27.90365600585937 : 0.0;

  // PrintToChatAll("BEFORE PREDICT: %.20f %.20f %.20f", gStart[0], gStart[1], gStart[2]);
  // PrintToChatAll("FORWARD PREDICT: %.20f %.20f %.20f", vforward[0], vforward[1], vforward[2]);
  for (int i = 0; i < 3; i++)
    gStart[i] += vforward[i] * 16.0000142601273616094204044;
  
  // PrintToChatAll("AFTER PREDICT: %.20f %.20f %.20f", gStart[0], gStart[1], gStart[2]);

  if (jumpthrow) PlayerVelocity[2] = 211.3683776855468;
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
      view_as<float>({-2.0, -2.0, -2.0}),
      view_as<float>({2.0, 2.0, 2.0}),
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
        if (StrEqual(cWeapon, "weapon_incgrenade", false) || StrEqual(cWeapon, "weapon_molotov", false))
          dtime = 0.0;
      } else {
        // fixVelFraction(GrenadeVelocity, trFraction);
      }
    }

    CloseHandle(gRayTrace);
    TE_SetupBeamPoints(gStart, gEnd, g_PredictTrail, 0, 0, 0, 0.1, 0.5, 0.5, 0, 0.0, { 0, 255, 255, 255 }, 0);
    TE_SendToAll(0.0);
    gStart = gEnd;
  }
  endPos = gEnd;
}

stock void fixVelFraction(float GrenadeVelocity[3], float frac, bool sum = true) {
  // PrintToChatAll("fraction %f", frac);
  // if (frac != 0) {
  //   for (int i = 0; i<3; i++) {
  //     // GrenadeVelocity[i] -= GrenadeVelocity[i]*(1.0-frac)*0.05;
  //     // GrenadeVelocity[i] = GrenadeVelocity[i]*(1.0-frac*0.05);
  //     // GrenadeVelocity[i] += GrenadeVelocity[i]*(1.0-frac)*0.05;
  //     // GrenadeVelocity[i] += GrenadeVelocity[i]*(1.0-frac)*0.04545454545;
  //     // GrenadeVelocity[i] += GrenadeVelocity[i]*(1.0-frac)*0.0258;
  //     // GrenadeVelocity[i] -= GrenadeVelocity[i]*(1.0-frac)*0.0015;
  //   }
  // }
}

public bool Prediction_TraceFilter(int entity, any data) {
  if (entity == data) return false;
  char ClassName[30];
  GetEdictClassname(entity, ClassName, sizeof(ClassName));
  if (StrContains(ClassName, "_projectile") != -1) {
    return false;
  }
  return false;
}

stock float GetDetonationTime(int client, const char[] weapon) {
  if (StrEqual(weapon, "weapon_smokegrenade", false))
    return 10.0;
  else if (StrEqual(weapon, "weapon_incgrenade", false) || StrEqual(weapon, "weapon_molotov", false))
    return 1.979;
  else if (StrEqual(weapon, "weapon_hegrenade", false) || StrEqual(weapon, "weapon_flashbang", false))
    return 1.602
  else {
    if (g_LastGrenadeType[client] == GrenadeType_Flash || g_LastGrenadeType[client] == GrenadeType_HE)
      return 1.602
    else if (g_LastGrenadeType[client] == GrenadeType_Incendiary || g_LastGrenadeType[client] == GrenadeType_Molotov)
      return 1.979;
  }
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
    SetEntProp(ent, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(ent, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(ent, Prop_Send, "m_flGlowMaxDist", 250000.0);
    SetVariantString("!activator");
    AcceptEntityInput(ent, "SetParent", g_LastGrenadeEntity[client], ent, 0);
  }
  SetClientObserveEntity(client, ent);
  return ent;
}

public void SetClientObserveEntity(int client, int entity) {
  SetEntityRenderMode(client, RENDER_NONE); //0
  SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", entity); //parent an entity to here?
  SetEntProp(client, Prop_Send, "m_iObserverMode", 5); //3
  SetEntityMoveType(client, MOVETYPE_OBSERVER); //1
  PrintHintText(client, "Suelta R para regresar");
}

public void ClientStopObserveEntities(int client) {
  SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
  SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
  SetEntityRenderMode(client, RENDER_NORMAL);
  SetEntityMoveType(client, MOVETYPE_WALK);
}
