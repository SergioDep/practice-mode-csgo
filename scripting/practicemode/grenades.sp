
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Events */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

public void NadePrediction_PluginStart() {
  if (g_PredictionDb == null) {
    Database.Connect(SQLConnectPredictionsCallback, "prediction-test");
  }

  for (int i = 0; i <= MaxClients; i++) {
    g_PredictionResults[i] = new ArrayList(sizeof(S_Predict_PredictedPosition));
  }
}

public void NadePrediction_ClientDisconnect(int client) {
  g_Predict_Debuging[client] = false;
  g_Predict_LastMode[client] = GRENADEPREDICT_NONE;
  g_Predict_LastGrenadeEquiped[client] = GrenadeType_None;
  g_Predict_LastCrouch[client] = false;
  g_Predict_Allowed[client] = false;
  g_Predict_HoldingUse[client] = false;
  g_Predict_HoldingReload[client] = false;
  g_Predict_ViewEndpoint[client] = false;
  g_Predict_ObservingGrenade[client] = -2;
  g_Predict_FinalDestinationEnt[client] = -1;
  g_Predict_GenerateViewPointDelay[client] = GenerateViewPointDelay;
  g_Predict_LastClientViewPos[client] = ZERO_VECTOR;
  g_Predict_LastClientAng[client] = ZERO_VECTOR;
  g_Predict_LastClientViewAng[client] = ZERO_VECTOR;
  g_Prediction_CurrentLineup[client] = -1;
  g_PredictionResults[client].Clear();
  g_PredictionClientPos[client] = ZERO_VECTOR;
}

public void HoloNade_PluginStart() {
  g_HoloNadeEntities = new ArrayList(MAX_GRENADES_IN_GROUP);
  g_EnabledHoloNadeAuth = new ArrayList(AUTH_LENGTH);
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

public void HoloNade_EntityDestroyed(int entity) {
  if (entity == -1) {
    // Not sure what the cause is for this, but it does happen sometimes, and it's not valid for us.
    // No evident reason to log it though.
    return;
  }
  char classname[128];
  GetEntityClassname(entity, classname, sizeof(classname));
  if (StrContains(classname, "prop_dynamic_override") > -1 || StrContains(classname, "func_rot_button") > -1) {
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

public Action NadePrediction_PlayerRunCmd(int client, int &buttons, bool isGrenade, GrenadeType grenadeType) {
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
      if (VecEqual(g_Predict_LastClientViewPos[client], ZERO_VECTOR) && VecEqual(g_Predict_LastClientViewAng[client], ZERO_VECTOR)) {
        TeleportEntity(client, g_LastGrenadePinPulledOrigin[client], g_LastGrenadePinPulledAngles[client] , ZERO_VECTOR);
      } else {
        TeleportEntity(client, g_Predict_LastClientViewPos[client], g_Predict_LastClientViewAng[client] , ZERO_VECTOR);
      }
    } else if (g_Predict_ViewEndpoint[client]) {
      SetClientViewEntity(client, client);
      Client_SetFOV(client, 90);
      g_Predict_ViewEndpoint[client] = false;
      if (!(VecEqual(g_Predict_LastClientViewPos[client], ZERO_VECTOR) && VecEqual(g_Predict_LastClientViewAng[client], ZERO_VECTOR))) {
        TeleportEntity(client, g_Predict_LastClientViewPos[client], g_Predict_LastClientViewAng[client] , ZERO_VECTOR);
      } else {
        TeleportEntity(client, g_LastGrenadePinPulledOrigin[client], g_LastGrenadePinPulledAngles[client] , ZERO_VECTOR);
      }
    }
    g_Predict_HoldingReload[client] = false;
  }

  if (isGrenade) {
    if (g_Predict_LastGrenadeEquiped[client] != grenadeType) {
      g_Predict_LastGrenadeEquiped[client] = grenadeType;
    }
    if((buttons & IN_USE) && !g_Predict_HoldingUse[client]) {
      if (g_Predict_LastMode[client] == GRENADEPREDICT_NONE) {
        g_Predict_LastMode[client] = GRENADEPREDICT_NORMAL;
        PrintHintText(client, "Modo de Trayectoria: Normal");

      } else if (g_Predict_LastMode[client] == GRENADEPREDICT_NORMAL) {
        g_Predict_LastMode[client] = GRENADEPREDICT_JUMPTHROW;
        PrintHintText(client, "Modo de Trayectoria: Jumpthrow");

      } else if (g_Predict_LastMode[client] == GRENADEPREDICT_JUMPTHROW) {
        g_Predict_LastMode[client] = GRENADEPREDICT_NONE;
        PrintHintText(client, "Modo de Trayectoria: Desactivado");

      }
      g_Predict_HoldingUse[client] = true;
    } else if (!(buttons & IN_USE) && g_Predict_HoldingUse[client]) {
      g_Predict_HoldingUse[client] = false;
    }

    if (buttons & IN_ATTACK) {
      if (g_Predict_HoldingReload[client]) {
        GetClientAbsOrigin(client, g_Predict_LastClientViewPos[client]);
        GetClientEyeAngles(client, g_Predict_LastClientViewAng[client]);
        float endPoint[3];
        if (g_Predict_LastMode[client] == GRENADEPREDICT_NONE) {
          // CreateTrajectory(client, g_Predict_LastGrenadeEquiped[client], g_Predict_LastMode[client], g_Predict_LastCrouch[client],
          //  endPoint, g_Predict_LastClientViewPos[client], g_Predict_LastClientViewAng[client]);
          // TeleportEntity(g_Predict_FinalDestinationEnt[client], endPoint, NULL_VECTOR, NULL_VECTOR);
        } else {
          // while mouse1+r
          CreateTrajectory(client, g_Predict_LastGrenadeEquiped[client], g_Predict_LastMode[client], g_Predict_LastCrouch[client],
            endPoint, g_Predict_LastClientViewPos[client]);
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
        if (g_Predict_LastMode[client] > GRENADEPREDICT_NONE) {
          //while mouse1
          g_Predict_LastCrouch[client] = !!(buttons & IN_DUCK);
          CreateTrajectory(client, g_Predict_LastGrenadeEquiped[client], g_Predict_LastMode[client], g_Predict_LastCrouch[client]);
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
      if (g_Predict_LastMode[client] > GRENADEPREDICT_NONE) {
        //while r
        CreateTrajectory(client, g_Predict_LastGrenadeEquiped[client], g_Predict_LastMode[client], g_Predict_LastCrouch[client],
          _, g_Predict_LastClientViewPos[client], g_Predict_LastClientViewAng[client]);
      }
      if (GetEntityMoveType(client) == MOVETYPE_NONE && g_Predict_ObservingGrenade[client] > 1) {
        SetClientObserveEntity(client, g_Predict_ObservingGrenade[client]);
      }
    }
  } else if (g_Predict_ObservingGrenade[client] > 0) {
    // while ObservingGrenade[client]
    CreateTrajectory(client, g_Predict_LastGrenadeEquiped[client], g_Predict_LastMode[client], g_Predict_LastCrouch[client],
      _, g_Predict_LastClientViewPos[client], g_Predict_LastClientViewAng[client]);
    SetEntityRenderMode(client, RENDER_NONE); //?
  }
  return Plugin_Handled;
}

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Main */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/



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
  GrenadeType grenadeType,
  GrenadePredict_Mode predict_mode = GRENADEPREDICT_NORMAL,
  int crouching = false,
  float endPos[3] = {},
  const float customOrigin[3] = {0.0, 0.0, 0.0},
  const float customAngles[3] = {0.0, 0.0, 0.0},
  const float customVelocity[3] = {0.0, 0.0, 0.0},
  bool shouldDraw = true
) {
  bool jumpthrow = (predict_mode == GRENADEPREDICT_JUMPTHROW);
  float dtime = GetGrenadeDetonationTime(grenadeType);
  float GrenadeVelocity[3], PlayerVelocity[3], vforward[3];
  float gStart[3], gEnd[3], angThrowClean[3], angThrow[3], gStart_Last[3];

  if (customVelocity[0] || customVelocity[1] || customVelocity[2]) {
    PlayerVelocity = customVelocity;
  } else {
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", PlayerVelocity);
  }
  if (customOrigin[0] || customOrigin[1] || customOrigin[2]) {
    gStart = customOrigin;
    gStart[2] += (!crouching) ? 64.0 : 46.0; // eye level
    ScaleVector(PlayerVelocity, 0.0);
  } else {
    GetClientEyePosition(client, gStart);
  }
  if (customAngles[0] || customAngles[1] || customAngles[2]) {
    angThrow = customAngles;
  } else {
    GetClientEyeAngles(client, angThrow);
  }
  angThrowClean = angThrow;

  if (angThrow[0] < -90.0) angThrow[0] += 360.0;
  else if (angThrow[0] > 90.0) angThrow[0] -= 360.0;

  angThrow[0] -= (90.0 - FloatAbs(angThrow[0]))*10.0/90.0;

  GetAngleVectors(angThrow, vforward, NULL_VECTOR, NULL_VECTOR);
  // NormalizeVector(vforward, vforward);

  gStart[2] += (jumpthrow) ? ((!crouching) ? 27.9035568237 : 28.245349884) : 0.0;
  for (int i = 0; i < 3; i++)
    gStart[i] += vforward[i] * 16.0;

  PlayerVelocity[2] = (jumpthrow) ? ((!crouching) ? 211.3683776855468 : 214.4933776855468000) : PlayerVelocity[2];
  ScaleVector(PlayerVelocity, 1.25);

  for (int i = 0; i < 3; i++)
    GrenadeVelocity[i] =  PlayerVelocity[i] + vforward[i] * 675.0;

  gStart_Last = gStart;
  int total_bounces = 0;

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
    // bounce
    if (trFraction != 1.0) {
      int ent = TR_GetEntityIndex(gRayTrace);
      if (ent > 0) {
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
      }
      TR_GetEndPosition(gEnd, gRayTrace);

      // smoke elasticity = 0.45
      // surface elasticity = 1.0 (non-player)
      float flTotalElasticity = 0.45 * 1.0;

      // NOTE: A backoff of 2.0f is a reflection
      float normal[3];
      TR_GetPlaneNormal(gRayTrace, normal);
      float backoff = GetVectorDotProduct(GrenadeVelocity, normal) * 2.0;
      for (int i = 0; i < 3; i++) {
        GrenadeVelocity[i] -= normal[i] * backoff;
        if (GrenadeVelocity[i] > -0.1 && GrenadeVelocity[i] < 0.1) {
          GrenadeVelocity[i] = 0.0;
        }
      }
      ScaleVector(GrenadeVelocity, flTotalElasticity);

      float flSpeedSqr = GetVectorDotProduct(GrenadeVelocity, GrenadeVelocity);
      const float kSleepVelocitySquared = 400.0; //20*20
      if (normal[2] > 0.7 || (normal[2] > 0.1 && flSpeedSqr < kSleepVelocitySquared)) {
        if (flSpeedSqr > 96000.0) {
          // clip it again to emulate old behavior and keep it from bouncing up like crazy when you throw it at the ground on the first toss
          float GrenadeVelocityNormalized[3];
          NormalizeVector(GrenadeVelocity, GrenadeVelocityNormalized);
          float alongDist = GetVectorDotProduct(GrenadeVelocityNormalized, normal);
          if (alongDist > 0.5) {
            float flBouncePadding = 1.0 - alongDist + 0.5;
            ScaleVector(GrenadeVelocity, flBouncePadding);
          }
        }
        if (flSpeedSqr < kSleepVelocitySquared) {
          break;
        } else {
          // float vecBaseDir[3];
          // if (GetVectorLength(vecBaseDir) > 0.0) {
          //   VectorNormalize( vecBaseDir );
          //   Vector vecDelta = GetBaseVelocity() - vecAbsVelocity;	
          //   float flScale = vecDelta.Dot( vecBaseDir );
          //   vecAbsVelocity += GetBaseVelocity() * flScale;
          // }
          for(int i=0; i<3; i++) {
            GrenadeVelocity[i] += (1.0 - trFraction)*1/128;
          }
        }
        if (grenadeType == GrenadeType_Incendiary || grenadeType == GrenadeType_Molotov)
          dtime = 0.0;
      } else {
        for(int i=0; i<3; i++) {
          GrenadeVelocity[i] += (1.0 - trFraction)*1/128;
        }
      }
      if (total_bounces > GRENADE_FAILSAFE_MAX_BOUNCES) {
        //failsafe detonate after 20 bounces
        break;
      } else {
        total_bounces++;
      }
    }

    CloseHandle(gRayTrace);
    if (shouldDraw) {
      if (view_as<int>(t/interval_per_tick)%20==0) {
        TE_SetupBeamPoints(gStart_Last, gStart, g_PredictTrail, 0, 0, 0, g_Predict_Debuging[client] ? 10.0 : 0.1, 2.0, 2.0, 0, 0.0, { 0, 255, 255, 255 }, 0);
        TE_SendToAll();
        gStart_Last = gStart;
      }
    }
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
  if (!VecEqual(g_Predict_LastClientAng[client], angThrowClean)) {
    if (!VecEqual(g_Predict_LastClientAng[client], ZERO_VECTOR)) {
      float distanceFromTarget = GetVectorDistance(explodePos, g_PredictionClientPos[client]);
      if (distanceFromTarget <= 5.0) {
        PM_Message(client, "{ORANGE} Copy -> setang %.4f %.4f <- in console!", angThrowClean[0], angThrowClean[1]);
      }
    }
    g_Predict_LastClientAng[client] = angThrowClean;
  }
  if (shouldDraw) {
    TE_SetupBeamCube(explodePos, 2.0, g_BeamSprite, 0, 0, 0, 0.1, 2.0, 2.0, 0, 0.0, colors, 0);
  }
}

public void HoloNade_GrenadeKvMutate() {
  UpdateHoloNadeEntities();
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
  int color[4];
  GetHoloNadeColorFromType(type, color);

  char grenadeModel[50];
  GetGrenadeModelFromType(type, grenadeModel);

  int ent = CreateEntityByName("prop_dynamic_override");
  if (ent != -1) {
    DispatchKeyValue(ent, "classname", "prop_dynamic_override");
    DispatchKeyValue(ent, "spawnflags", "1"); 
    DispatchKeyValue(ent, "renderamt", "255");
    DispatchKeyValue(ent, "rendermode", "1");
    SetEntityRenderColor(ent, color[0], color[1], color[2], color[3]);
    // DispatchKeyValue(ent, "rendercolor", color);
    char targetName[OPTION_NAME_LENGTH];
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
    SetVariantColor(color);
    AcceptEntityInput(ent, "SetGlowColor");
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
      char targetName[OPTION_NAME_LENGTH];
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

  char auth[AUTH_LENGTH], nadeIdStr[OPTION_ID_LENGTH];
  IntToString(nadeId, nadeIdStr, sizeof(nadeIdStr));
  FindId(nadeIdStr, auth, sizeof(auth));
  char filepath[PLATFORM_MAX_PATH + 1];
  GetGrenadeData(auth, nadeIdStr, "record", filepath, sizeof(filepath));

  DemoNadeData demoNadeData;
  GetGrenadeVector(auth, nadeIdStr, "origin", demoNadeData.origin);
  GetGrenadeVector(auth, nadeIdStr, "angles", demoNadeData.angles);
  GetGrenadeVector(auth, nadeIdStr, "grenadeOrigin", demoNadeData.grenadeOrigin);
  GetGrenadeVector(auth, nadeIdStr, "grenadeVelocity", demoNadeData.grenadeVelocity);
  char grenadeTypeStr[OPTION_NAME_LENGTH];
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

public void UpdateHoloNadeEntities_Iterator() {
  char ownerAuth[AUTH_LENGTH];
  char grenadeId[OPTION_ID_LENGTH];
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

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Menus */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/



public Action Command_PredictResultsMenu(int client, int args) {
  Menu menu = new Menu(PredictionResultsMenuHandler);
  menu.SetTitle("Prediction Results:");

  int currentStartPos, startPosCount;
  char exploringPositionId[32] = "";
  S_Predict_PredictedPosition currentPredictedInfo;
  for (int i=0; i < g_PredictionResults[client].Length; i++) {
    g_PredictionResults[client].GetArray(i, currentPredictedInfo, sizeof(currentPredictedInfo));
    if (i == g_Prediction_CurrentLineup[client]) {
      currentStartPos = startPosCount;
    }
    if (!StrEqual(currentPredictedInfo.startingPosId, exploringPositionId)) {
      startPosCount++;
      strcopy(exploringPositionId, sizeof(exploringPositionId), currentPredictedInfo.startingPosId);
    }
  }

  char displayStr[128];
  Format(displayStr, sizeof(displayStr), "Lineup Actual [%d/%d]", g_Prediction_CurrentLineup[client]+1, g_PredictionResults[client].Length);
  menu.AddItem("", displayStr, ITEMDRAW_DISABLED);
  Format(displayStr, sizeof(displayStr), "Posicion Actual [%d/%d]\n ", currentStartPos, startPosCount);
  menu.AddItem("", displayStr, ITEMDRAW_DISABLED);

  menu.AddItem("prev_startpos", "Ir a anterior Lineup");
  menu.AddItem("next_startpos", "Ir a Siguiente Lineup");
  
  if (g_Prediction_CurrentLineup[client] > -1) {
    g_PredictionResults[client].GetArray(g_Prediction_CurrentLineup[client], currentPredictedInfo, sizeof(currentPredictedInfo));
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
    S_Predict_PredictedPosition predictedPos;
    if (StrEqual(buffer, "next_startpos")) {
      g_Prediction_CurrentLineup[client]++;
      if (g_Prediction_CurrentLineup[client] >= g_PredictionResults[client].Length) {
        g_Prediction_CurrentLineup[client] = 0;
      }
      g_PredictionResults[client].GetArray(g_Prediction_CurrentLineup[client], predictedPos, sizeof(predictedPos));
    } else if (StrEqual(buffer, "prev_startpos")) {
      g_Prediction_CurrentLineup[client]--;
      if (g_Prediction_CurrentLineup[client] < 0) {
        g_Prediction_CurrentLineup[client] = g_PredictionResults[client].Length-1;
      }
      g_PredictionResults[client].GetArray(g_Prediction_CurrentLineup[client], predictedPos, sizeof(predictedPos));
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


public void GiveNadeMenuInContext(int client) {
  if (g_ClientLastMenuType[client] == GrenadeMenuType_TypeFilter) {
    if (g_CurrentNadeControl[client] > -1) {
      GiveSingleNadeMenu(client, g_CurrentNadeControl[client]);
    } else {
      GiveNadeFilterMenu(client, g_ClientLastMenuGrenadeTypeFilter[client]);
    }
  } else if (g_ClientLastMenuType[client] == GrenadeMenuType_NadeGroup && g_CurrentNadeGroupControl[client] > -1) {
    if (g_CurrentNadeControl[client] > -1) {
      GiveSingleNadeMenu(client, g_CurrentNadeControl[client]);
    } else {
      GiveNadeGroupMenu(client, g_CurrentNadeGroupControl[client]);
    }
  } else {
    // All Nades Menu.
    GiveNadesMainMenu(client);
  }
}

stock void GiveNadesMainMenu(int client) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return;
  }
  g_ClientLastMenuType[client] = GrenadeMenuType_NadeGroup;
  g_CurrentNadeGroupControl[client] = -1;
  g_CurrentNadeControl[client] = -1;
  Menu menu = new Menu(NadesMainMenuHandler);
  menu.SetTitle("Menu de Granadas");
  menu.AddItem("savenade", "Guardar granada\n ");
  char auth[AUTH_LENGTH], buffer[128], grenadeString[32];

  GrenadeTypeString(g_ClientLastMenuGrenadeTypeFilter[client], grenadeString, sizeof(grenadeString));
  StrEqual(grenadeString, "")
  ? strcopy(grenadeString, sizeof(grenadeString), "todas")
  : 1;
  grenadeString[0] = CharToUpper(grenadeString[0]);
  Format(buffer, sizeof(buffer), "Filtro de Granadas: (%s)", grenadeString);
  menu.AddItem("filternades", buffer);
  
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  int filterNadesCount = CountGrenadesForPlayer(auth, g_ClientLastMenuGrenadeTypeFilter[client]);
  Format(buffer, sizeof(buffer), "Mis granadas(%s) [%i/%i]\n "
  , grenadeString , filterNadesCount
  , MAX_GRENADE_SAVES_PLAYER)
  menu.AddItem("mynades", buffer, filterNadesCount ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

  menu.AddItem("loadmynades", "Mostrar mis granadas");
  menu.AddItem("disablemynades", "Ocultar mis granadas");
  
  Format(buffer, sizeof(buffer), "Granadas por Defecto: %s"
  , g_HoloNadeLoadDefault ? "Activadas": "Desactivadas");
  menu.AddItem("defaultnades", buffer);

  menu.ExitBackButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
}

public int NadesMainMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    
    if (StrEqual(buffer, "savenade")) {
      g_WaitForSaveNade[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre de la granada a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
    } else if (StrEqual(buffer, "filternades")) {
      g_ClientLastMenuGrenadeTypeFilter[client] += GrenadeType_Smoke;
      if (g_ClientLastMenuGrenadeTypeFilter[client] == GrenadeType_Decoy)
        g_ClientLastMenuGrenadeTypeFilter[client] = GrenadeType_Incendiary;
      else if (g_ClientLastMenuGrenadeTypeFilter[client] > GrenadeType_Incendiary)
        g_ClientLastMenuGrenadeTypeFilter[client] = GrenadeType_None;
    } else if (StrEqual(buffer, "mynades")) {
      g_ClientLastMenuType[client] = GrenadeMenuType_TypeFilter;
    } else if (StrEqual(buffer, "defaultnades")) {
      g_HoloNadeLoadDefault = !g_HoloNadeLoadDefault;
      if (g_HoloNadeLoadDefault) {
        int index = g_EnabledHoloNadeAuth.FindString("default");
        if(index == -1) {
          g_EnabledHoloNadeAuth.PushString("default");
          UpdateHoloNadeEntities();
        }
      } else {
        int index = g_EnabledHoloNadeAuth.FindString("default");
        if(index > -1) {
          g_EnabledHoloNadeAuth.Erase(index);
          UpdateHoloNadeEntities();
        }
      }
    } else {
      char auth[AUTH_LENGTH];
      if (StrEqual(buffer, "loadmynades")) {
        GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
        int index = g_EnabledHoloNadeAuth.FindString(auth);
        if(index == -1) {
          g_EnabledHoloNadeAuth.PushString(auth);
          UpdateHoloNadeEntities();
        }
        PM_MessageToAll("{ORANGE} Granadas Actualizadas para {NORMAL}%N.", client);
      } else if (StrEqual(buffer, "disablemynades")) {
        GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
        int index = g_EnabledHoloNadeAuth.FindString(auth);
        if(index > -1) {
          g_EnabledHoloNadeAuth.Erase(index);
          UpdateHoloNadeEntities();
        }
        PM_Message(client, "{ORANGE} Granadas Ocultadas.");
      }
    }
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GivePracticeMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void GiveNadeFilterMenu(int client, GrenadeType grenadeType = GrenadeType_None) {
  g_CurrentNadeControl[client] = -1;
  g_ClientLastMenuType[client] = GrenadeMenuType_TypeFilter;
  int nadesCount = 0;
  Menu menu = new Menu(NadeFilterMenuHandler);
  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    char userName[MAX_NAME_LENGTH];
    g_GrenadeLocationsKv.GetString("name", userName, sizeof(userName));
    menu.SetTitle("Lista de Granadas de %s", userName);
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
      do {
        char id[OPTION_ID_LENGTH], name[OPTION_NAME_LENGTH];
        g_GrenadeLocationsKv.GetSectionName(id, sizeof(id));
        g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
        char type[32]
        g_GrenadeLocationsKv.GetString("grenadeType", type, sizeof(type));
        if (grenadeType == GrenadeTypeFromString(type) || grenadeType == GrenadeType_None) {
          UpperString(type);
          Format(name, sizeof(name), "%s [%s]", name, type);
          menu.AddItem(id, name);
          nadesCount++;
        }
      } while (g_GrenadeLocationsKv.GotoNextKey());

      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }

  if (nadesCount == 0) {
    g_ClientLastMenuType[client] = GrenadeMenuType_NadeGroup;
    delete menu;
    GiveNadeMenuInContext(client);
    return;
  }
  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int NadeFilterMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char nadeIdStr[OPTION_NAME_LENGTH];
    menu.GetItem(param2, nadeIdStr, sizeof(nadeIdStr));
    g_CurrentNadeControl[client] = StringToInt(nadeIdStr);
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GiveNadesMainMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public Action GiveSingleNadeMenu(int client, int NadeId) {
    g_CurrentNadeControl[client] = NadeId;
    char name[64];
    GetClientGrenadeData(NadeId, "name", name, sizeof(name));
    Menu menu = new Menu(SingleNadeMenuHandler);
    Format(name, sizeof(name), "Granada: %s", name);
    menu.SetTitle(name);

    menu.AddItem("goto", "Ir a Lineup");
    menu.AddItem("preview", "Ver Demo de Esta granada(con bot)");
    menu.AddItem("throw", "Lanzar esta granada");
    menu.AddItem("exportcode", "Compartir el Codigo de esta Granada\n ");

    char display[64];
    GetClientGrenadeData(NadeId, "grenadeType", display, sizeof(display));
    display[0] &= ~(1<<5);
    char executionType[64];
    GetClientGrenadeData(NadeId, "execution", executionType, sizeof(executionType));
    executionType[0] &= ~(1<<5);
    Format(display, sizeof(display), "Eliminar\n \nTipo: %s\nEjecución: %s", display, executionType);

    menu.AddItem("delete", display,
    (CanEditGrenade(client, NadeId))
    ? ITEMDRAW_DEFAULT
    : ITEMDRAW_DISABLED);

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int SingleNadeMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    char NadeIdStr[64];
    menu.GetItem(param2, buffer, sizeof(buffer));
    int NadeId = g_CurrentNadeControl[client];
    IntToString(NadeId, NadeIdStr, sizeof(NadeIdStr));
    if (StrEqual(buffer, "goto")) {
      TeleportToSavedGrenadePosition(client, NadeIdStr);
    } else if (StrEqual(buffer, "delete")) {
      GiveNadeDeleteConfirmationMenu(client);
      return 0;
    } else if (StrEqual(buffer, "exportcode")) {
      ExportClientNade(client, NadeIdStr);
    } else if (StrEqual(buffer, "preview")) {
      InitHoloNadeDemo(client, NadeId);
    } else if (StrEqual(buffer, "throw")) {
      ThrowGrenade(client, NadeIdStr);
    }
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    g_CurrentNadeControl[client] = -1;
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
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

public int NadeGroupMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    g_CurrentNadeControl[client] = StringToInt(buffer);
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GiveNadesMainMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public Action GiveNadeDeleteConfirmationMenu(int client) {
  Menu menu = new Menu(NadeDeletionMenuHandler);
  char name[64];
  GetClientGrenadeData(g_CurrentNadeControl[client], "name", name, sizeof(name));
  menu.SetTitle("Confirmar la eliminación de la granada: %s", name);
  menu.ExitButton = false;
  menu.ExitBackButton = false;
  menu.Pagination = MENU_NO_PAGINATION;

  // Add rows of padding to move selection out of "danger zone"
  for (int i = 0; i < 7; i++) {
    menu.AddItem("", "", ITEMDRAW_NOTEXT);
  }

  // Add actual choices
  menu.AddItem("no", "No, cancelar");
  menu.AddItem("yes", "Si, eliminar");
  menu.Display(client, MENU_TIME_FOREVER);

  return Plugin_Handled;
}

public int NadeDeletionMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "yes")) {
      char NadeIdStr[64];
      IntToString(g_CurrentNadeControl[client], NadeIdStr, sizeof(NadeIdStr));
      g_CurrentNadeControl[client] = -1;
      DeleteGrenadeFromKv(NadeIdStr);
      OnGrenadeKvMutate();
    }
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public Action GiveCopyPlayerNadeMenu(int client) {
    char iStr[16], name[MAX_NAME_LENGTH];
    Menu menu = new Menu(CopyPlayerMenuHandler);
    menu.SetTitle("Copiar la ultima granda de: ");
    for(int i = 1; i <= MaxClients; i++) {
      if(IsPlayer(i)) {
             GetClientName(i, name, sizeof(name));
             IntToString(i, iStr, sizeof(iStr));
             menu.AddItem(iStr, name);
      }
    }
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int CopyPlayerMenuHandler(Menu menu, MenuAction action, int client, int param2) {
    if (action == MenuAction_Select) {
      char buffer[OPTION_NAME_LENGTH];
      menu.GetItem(param2, buffer, sizeof(buffer));
      int CopyClient = StringToInt(buffer);
      int index = g_GrenadeHistoryPositions[CopyClient].Length - 1;
      if (index >= 0) {
        float origin[3];
        float angles[3];
        float velocity[3];
        g_GrenadeHistoryPositions[CopyClient].GetArray(index, origin, sizeof(origin));
        g_GrenadeHistoryAngles[CopyClient].GetArray(index, angles, sizeof(angles));
        TeleportEntity(client, origin, angles, velocity);
        SetEntityMoveType(client, MOVETYPE_WALK);
        PM_Message(client, "Ultima granada de %N copiada.", CopyClient);
      }
    } else if (action == MenuAction_End) {
      delete menu;
    }
    return 0;
}

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Commands */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/



public Action Command_PredictData(int client, int args) {
  float timer_start = GetEngineTime();

  ArrayList endpositions = new ArrayList(3);
  float clientOrigin[3], customAngles[3], endpos[3];
  GetClientAbsOrigin(client, clientOrigin);
  for (float x=0.0; x<=0.5; x+=0.01) {
    customAngles[0] = x;
    for (float y=0.0; y<=0.5; y+=0.01) {
      customAngles[1] = y;
      CreateTrajectory(client, GrenadeType_Smoke, GRENADEPREDICT_NORMAL, false, endpos, _, customAngles, _, false);
      endpositions.PushArray(endpos, sizeof(endpos));
    }
  }
  timer_start = GetEngineTime() - timer_start;
  PM_Message(client, "total time: %f", timer_start);
  // for (int i=0; i < endpositions.Length; i++) {
  //   endpositions.GetArray(i, endpos, sizeof(endpos));
  //   PrintToChatAll("position found: [%.2f, %.2f, %.2f]", endpos[0], endpos[1], endpos[2]);
  // }
  endpositions.Clear();
  delete endpositions;

  return Plugin_Handled;
  // bool jumpthrow = false;
  // char arg[128];
  // if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
  //   if (StrEqual(arg, "jumpthrow")) {
  //     jumpthrow = true;
  //   }
  // }
  // bool crouching = !!(GetEntityFlags(client) & FL_DUCKING);
  // float clienteyepos[3], clienteyeang[3];
  // GetClientEyePosition(client, clienteyepos);
  // GetClientEyeAngles(client, clienteyeang);
  // float customAngles[3];
  
  // for (float x=0.0; x<=0.1; x+=0.01) {
  //   customAngles[0] = x;
  //   for (float y=0.0; y<=0.1; y+=0.01) {
  //     customAngles[1] = y;
  //     CreateTrajectory(client, GrenadeType_Smoke, jumpthrow ? GRENADEPREDICT_JUMPTHROW : GRENADEPREDICT_NORMAL, crouching, _, _, customAngles);
  //     // Dev_SpawnGrenade(client, jumpthrow, crouching, clienteyepos, customAngles);
  //   }
  // }
  // timer_start = GetEngineTime() - timer_start;
  // PM_Message(client, "total time: %f", timer_start);
  // return Plugin_Handled;
}

public Action Command_AllowPredict(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  g_Predict_Allowed[client] = !g_Predict_Allowed[client];
  PM_Message(client, "{ORANGE}Nade Prediction %s", g_Predict_Allowed[client] ? "Enabled" : "Disabled");
  return Plugin_Handled;
}

public Action Command_PredictDev(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  char arg[64];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    if (StrEqual(arg, "start")) {
      g_Predict_Debuging[client] = true;
      char weapon[128];
      GetClientWeapon(client, weapon, sizeof(weapon));
      CreateTrajectory(client, GrenadeType_Smoke, g_Predict_LastMode[client], GetEntityFlags(client) & FL_DUCKING);
      PM_Message(client, "{ORANGE}Prediction Dev Mode Enabled");
      return Plugin_Handled;
    } else if (StrEqual(arg, "stop")) {
      g_Predict_Debuging[client] = false;
      PM_Message(client, "{ORANGE}Prediction Dev Mode Disabled");
      return Plugin_Handled;
    }
  }
  PM_Message(client, "{LIGHT_RED}Use \"start\" or \"stop\" as argument");
  return Plugin_Handled;
}

public Action Command_PredictNades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  float eyePos[3], eyeVec[3];
  GetClientEyePosition(client, eyePos);
  GetClientEyeAngles(client, eyeVec);

  Handle trace = TR_TraceRayFilterEx(eyePos, eyeVec, MASK_SOLID | CONTENTS_CURRENT_90, RayType_Infinite, Trace_BaseFilter, client);
  float normal[3];
  TR_GetPlaneNormal(trace, normal);
  if (normal[2] > 0.7) {
    TR_GetEndPosition(g_PredictionClientPos[client], trace);
    TE_SetupBeamCube(g_PredictionClientPos[client], 1.0, g_BeamSprite, 0, 0, 0, 1.0, 0.5, 0.5, 0, 0.0, {255, 128, 0, 255}, 0);
  } else {
    PM_Message(client, "{LIGHT_RED} Select Ground Position");
    return Plugin_Handled;
  }

  PM_Message(client, "{ORANGE} Predicting a smoke position [{GREEN}%.2f, %.2f, %.2f{ORANGE}]...",
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

public Action Command_SaveNade(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }
  char name[OPTION_NAME_LENGTH];
  GetCmdArgString(name, sizeof(name));
  TrimString(name);
  
  SaveClientNade(client, name);
  return Plugin_Handled;
}

public Action Command_ImportNade(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }
  char code[GRENADE_CODE_LENGTH];
  GetCmdArgString(code, sizeof(code));
  TrimString(code);
  int nadeId = FindGrenadeWithCode(code);
  if (nadeId > -1 && g_CSUtilsLoaded) {
    char nadeIdStr[OPTION_ID_LENGTH];
    IntToString(nadeId, nadeIdStr, sizeof(nadeIdStr));
    if (CopyGrenade(client, nadeIdStr) > 0) {
      PM_Message(client, "{ORANGE}Granada {ORANGE}guardada.");
      OnGrenadeKvMutate();
    }
  }
  return Plugin_Handled;
}

public Action Command_CopyPlayerLastGrenade(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }
  
  GiveCopyPlayerNadeMenu(client);

  return Plugin_Handled;
}

public Action Command_LastGrenade(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }
  int index = g_GrenadeHistoryPositions[client].Length - 1;
  if (index >= 0) {
    TeleportToGrenadeHistoryPosition(client, index);
  }

  return Plugin_Handled;
}

public Action Command_GrenadeBack(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }

  char argString[64];
  if (args >= 1 && GetCmdArg(1, argString, sizeof(argString))) {
    int index = StringToInt(argString) - 1;
    if (index >= 0 && index < g_GrenadeHistoryPositions[client].Length) {
      g_GrenadeHistoryIndex[client] = index;
      TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
    }
    return Plugin_Handled;
  }

  if (g_GrenadeHistoryPositions[client].Length > 0) {
    g_GrenadeHistoryIndex[client]--;
    if (g_GrenadeHistoryIndex[client] < 0)
      g_GrenadeHistoryIndex[client] = 0;

    TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
  }

  return Plugin_Handled;
}

public Action Command_GrenadeForward(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }
  if (g_GrenadeHistoryPositions[client].Length > 0) {
    int max = g_GrenadeHistoryPositions[client].Length;
    g_GrenadeHistoryIndex[client]++;
    if (g_GrenadeHistoryIndex[client] >= max)
      g_GrenadeHistoryIndex[client] = max - 1;
    TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
  }

  return Plugin_Handled;
}

public Action Command_Throw(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PrintToServer("[Command_Throw]%N failed .throw, g_CSUtilsLoaded = false", client);
    return Plugin_Handled;
  }

  char argString[256];
  GetCmdArgString(argString, sizeof(argString));
  if (args >= 1) {
    ArrayList ids = new ArrayList(OPTION_NAME_LENGTH);
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    FindMatchingGrenadesByName(argString, auth, ids);

    // Actually do the throwing.
    for (int i = 0; i < ids.Length; i++) {
      char id[OPTION_ID_LENGTH];
      ids.GetString(i, id, sizeof(id));
      if (!ThrowGrenade(client, id, 0.0)) {
        PrintToServer("[ClientThrowGrenade]No parameters for grenade id: %s", id);
      }
    }
    if (ids.Length == 0) {
      PM_Message(client, "{ORANGE}No se encontraron coincidencias para {PURPLE}%s", argString);
    }
    delete ids;

  } else {
    // No arg, throw last nade.
    if (IsGrenade(g_LastGrenadeType[client])) {
      //PM_Message(client, "Lanzando tu ultima granada.");
      CSU_ThrowGrenade(client, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                       g_LastGrenadeVelocity[client]);
    }
  }

  return Plugin_Handled;
}

public Action Command_TestFlash(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }
  
  if (!g_TestingFlash[client]) {
    g_TestingFlash[client] = true;
    PM_Message(client, "{ORANGE}Usa {GREEN}.flash {ORANGE} de nuevo para terminar.");
    GetClientAbsOrigin(client, g_TestingFlashOrigins[client]);
    GetClientEyeAngles(client, g_TestingFlashAngles[client]);
  } else {
    g_TestingFlash[client] = false;
    PM_Message(client, "{ORANGE}Cancelado");
  }
  return Plugin_Handled;
}

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Misc */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

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
      "  UNIQUE(id, map, type));"...

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
      "  UNIQUE(parentId, id, map, type));"
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

public bool Prediction_TraceFilter(int entity, int contentsMask, any data) {
  if (entity == data) return false;
  char ClassName[30];
  GetEdictClassname(entity, ClassName, sizeof(ClassName));
  if (StrContains(ClassName, "_projectile") != -1) {
    return false;
  }
  return true;
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
      S_Predict_PredictedPosition predictedPosition;
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
    g_Prediction_CurrentLineup[client] = -1;
    // bubble sort
    S_Predict_PredictedPosition predictionj;
    S_Predict_PredictedPosition predictionj_1;
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

stock void TeleportToGrenadeHistoryPosition(int client, int index,
                                            MoveType moveType = MOVETYPE_WALK) {
  float origin[3];
  float angles[3];
  float velocity[3];

  g_GrenadeHistoryPositions[client].GetArray(index, origin, sizeof(origin));
  g_GrenadeHistoryAngles[client].GetArray(index, angles, sizeof(angles));
  TeleportEntity(client, origin, angles, velocity);
  SetEntityMoveType(client, moveType);
}

public bool TeleportToSavedGrenadePosition(int client, const char[] id) {
  float origin[3];
  float angles[3];
  float velocity[3];
  char execution[64];
  bool success = false;
  float delay = 0.0;
  char typeString[32];
  GrenadeType type = GrenadeType_None;

  // Update the client's current grenade id.
  g_CurrentSavedGrenadeId[client] = StringToInt(id);

  char targetAuth[AUTH_LENGTH];
  char targetName[MAX_NAME_LENGTH];
  if (TryJumpToOwnerId(id, targetAuth, sizeof(targetAuth), targetName, sizeof(targetName))) {
    char grenadeName[OPTION_NAME_LENGTH];
    success = true;
    g_GrenadeLocationsKv.GetVector("origin", origin);
    g_GrenadeLocationsKv.GetVector("angles", angles);
    g_GrenadeLocationsKv.GetString("name", grenadeName, sizeof(grenadeName));
    g_GrenadeLocationsKv.GetString("execution", execution, sizeof(execution));
    g_GrenadeLocationsKv.GetString("grenadeType", typeString, sizeof(typeString));
    type = GrenadeTypeFromString(typeString);
    delay = g_GrenadeLocationsKv.GetFloat("delay");
    TeleportEntity(client, origin, angles, velocity);
    SetEntityMoveType(client, MOVETYPE_WALK);
    
    if (!StrEqual(execution, "")) {
      //PM_Message(client, "Ejecución: %s", execution);
      SetHudTextParams(-1.0, 0.67, 3.5, 64, 255, 64, 0, 1, 1.0, 1.0, 1.0);
      ShowSyncHudText(client, HudSync, execution);
    }

    if (delay > 0.0) {
      // PM_Message(client, "Delay de granada: %.1f seconds", delay);
    }

    if (type != GrenadeType_None) {
      char weaponName[64];
      GetGrenadeWeapon(type, weaponName, sizeof(weaponName));
      FakeClientCommand(client, "use %s", weaponName);

      // This is a dirty hack since saved nade data doesn't differentiate between a inc and molotov
      // grenade. See the problem in GrenadeFromProjectileName in csutils.inc. If that is fixed this
      // can be removed.
      if (type == GrenadeType_Molotov) {
        FakeClientCommand(client, "use weapon_incgrenade");
      } else if (type == GrenadeType_Incendiary) {
        FakeClientCommand(client, "use weapon_molotov");
      }
    }

    g_GrenadeLocationsKv.Rewind();
  }

  return success;
}

stock bool ThrowGrenade(int client, const char[] id, float delay = 0.0) {
  if (!g_CSUtilsLoaded) {
    return false;
  }

  char typeString[32];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  bool success = false;

  char auth[AUTH_LENGTH];
  if (!FindId(id, auth, sizeof(auth))) {
    return false;
  }

  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.GetVector("grenadeOrigin", grenadeOrigin);
      g_GrenadeLocationsKv.GetVector("grenadeVelocity", grenadeVelocity);
      g_GrenadeLocationsKv.GetString("grenadeType", typeString, sizeof(typeString));
      GrenadeType type = GrenadeTypeFromString(typeString);
      if (IsGrenade(type)) {
        success = true;
        if (delay > 0.1) {
          CSU_DelayThrowGrenade(delay, 0, type, grenadeOrigin, grenadeVelocity);
        } else {
          CSU_ThrowGrenade(client, type, grenadeOrigin, grenadeVelocity);
        }
      }
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }

  return success;
}

public void AddGrenadeToHistory(int client) {
  int max_grenades = g_MaxHistorySizeCvar.IntValue;
  if (max_grenades > 0 && GetArraySize(g_GrenadeHistoryPositions[client]) >= max_grenades) {
    RemoveFromArray(g_GrenadeHistoryPositions[client], 0);
    RemoveFromArray(g_GrenadeHistoryAngles[client], 0);
  }
  
  PushArrayArray(g_GrenadeHistoryPositions[client], g_LastGrenadePinPulledOrigin[client], sizeof(g_LastGrenadePinPulledOrigin[]));
  PushArrayArray(g_GrenadeHistoryAngles[client], g_LastGrenadePinPulledAngles[client], sizeof(g_LastGrenadePinPulledAngles[]));
  //when grenade released, but instead if when grenade pin pulled so it allows runthrows
  g_GrenadeHistoryIndex[client] = g_GrenadeHistoryPositions[client].Length;
}

public void SaveClientNade(int client, const char[] name) {
  if (StrEqual(name, "")) {
    PM_Message(client, "Uso: .save <nombre>");
    return;
  }

  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  char grenadeId[OPTION_ID_LENGTH];
  if (FindGrenadeByName(auth, name, grenadeId)) {
    PM_Message(client, "Ya has usado ese nombre.");
    return;
  }

  int max_saved_grenades = MAX_GRENADE_SAVES_PLAYER;
  if (max_saved_grenades > 0 && CountGrenadesForPlayer(auth) >= max_saved_grenades) {
    PM_Message(client, "Alcanzaste el maximo numero de granadas que puedes guardar (%d).",
               max_saved_grenades);
    return;
  }

  float origin[3], angles[3];
  origin = g_LastGrenadePinPulledOrigin[client];
  angles = g_LastGrenadePinPulledAngles[client];

  GrenadeType grenadeType = g_LastGrenadeType[client];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  float grenadeDetonationOrigin[3];
  grenadeOrigin = g_LastGrenadeOrigin[client];
  grenadeVelocity = g_LastGrenadeVelocity[client];
  grenadeDetonationOrigin = g_LastGrenadeDetonationOrigin[client];

  char execution[64];
  GetGrenadeExecutionType(g_ClientPulledPinButtons[client], execution, sizeof(execution));

  Action ret = Plugin_Continue;
  Call_StartForward(g_OnGrenadeSaved);
  Call_PushCell(client);
  Call_PushArray(origin, sizeof(origin));
  Call_PushArray(angles, sizeof(angles));
  Call_PushString(name);
  Call_Finish(ret);

  if (ret < Plugin_Handled) {
    if (g_CSUtilsLoaded) {
      if (!IsGrenade(g_LastGrenadeType[client])) {
        PM_Message(client, "{DARK_RED}Error. Guarda una granada válida");
        return;
      } else {
        int nadeId = SaveGrenadeToKv(client, origin, angles,
          grenadeOrigin, grenadeVelocity, grenadeType, grenadeDetonationOrigin,
          name, execution
        );
        g_CurrentSavedGrenadeId[client] = nadeId;
        int authIndex = g_EnabledHoloNadeAuth.FindString(auth);
        if(authIndex == -1) {
          g_EnabledHoloNadeAuth.PushString(auth);
        }
        PM_Message(client, "{ORANGE}Granada {PURPLE}%s {ORANGE}guardada.", name);
        g_UpdatedGrenadeKv = true;
        MaybeWriteNewGrenadeData();
        OnGrenadeKvMutate();
        if (!g_InBotDemoMode && g_recordingNadeDemoStatus[client] > 0) { //1 or 2
          g_recordingNadeDemoStatus[client] = 0;
          g_savedNewNadeDemo[client] = true;
          if (BotMimic_IsPlayerRecording(client)) {
            BotMimic_StopRecording(client, true);
          }
        }
    }
    }
  }
  g_LastGrenadeType[client] = GrenadeType_None;
}

public int CopyGrenade(int client, const char[] nadeId) {
  float origin[3];
  float angles[3];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  float grenadeDetonationOrigin[3];
  char grenadeTypeString[32];
  char grenadeName[OPTION_NAME_LENGTH];
  char execution[64];

  if (TryJumpToId(nadeId)) {
    g_GrenadeLocationsKv.GetString("name", grenadeName, sizeof(grenadeName));
    g_GrenadeLocationsKv.GetVector("origin", origin);
    g_GrenadeLocationsKv.GetVector("angles", angles);
    g_GrenadeLocationsKv.GetString("grenadeType", grenadeTypeString, sizeof(grenadeTypeString));
    g_GrenadeLocationsKv.GetVector("grenadeOrigin", grenadeOrigin);
    g_GrenadeLocationsKv.GetVector("grenadeVelocity", grenadeVelocity);
    g_GrenadeLocationsKv.GetVector("grenadeDetonationOrigin", grenadeDetonationOrigin);
    g_GrenadeLocationsKv.GetString("execution", execution, sizeof(execution));
    g_GrenadeLocationsKv.Rewind();
    return SaveGrenadeToKv(client, origin, angles, grenadeOrigin, grenadeVelocity,
                           GrenadeTypeFromString(grenadeTypeString),
                           grenadeDetonationOrigin, grenadeName, execution);
  }
  return -1;
}

public void ExportClientNade(int client, const char[] idstr) {
  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  char code[GRENADE_CODE_LENGTH];
  GetGrenadeData(auth, idstr, "code", code, sizeof(code));
  PM_Message(client, "{ORANGE}Codigo Exportado! (usar .import para guardarlo)");
  PM_Message(client, "{GREEN}%s", code);
  PrintToConsole(client, "======================================================");
  PrintToConsole(client, "Codigo de Granada Exportado : %s", code);
  PrintToConsole(client, "======================================================");
}

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Helpers */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

stock void IterateGrenades(GrenadeIteratorFunction f, any data = 0) {
  char ownerName[MAX_NAME_LENGTH];
  char ownerAuth[AUTH_LENGTH];
  char name[OPTION_NAME_LENGTH];
  char execution[128];
  char grenadeId[OPTION_ID_LENGTH];
  char grenadeTypeString[32];
  float origin[3];
  float angles[3];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  float grenadeDetonationOrigin[3];

  // Outer iteration by users.
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    do {
      g_GrenadeLocationsKv.GetSectionName(ownerAuth, sizeof(ownerAuth));
      g_GrenadeLocationsKv.GetString("name", ownerName, sizeof(ownerName));

      // Inner iteration by grenades for a user.
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          g_GrenadeLocationsKv.GetSectionName(grenadeId, sizeof(grenadeId));
          g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
          g_GrenadeLocationsKv.GetString("execution", execution, sizeof(execution));
          g_GrenadeLocationsKv.GetVector("origin", origin);
          g_GrenadeLocationsKv.GetVector("angles", angles);
          g_GrenadeLocationsKv.GetString("grenadeType", grenadeTypeString, sizeof(grenadeTypeString));
          g_GrenadeLocationsKv.GetVector("grenadeOrigin", grenadeOrigin);
          g_GrenadeLocationsKv.GetVector("grenadeVelocity", grenadeVelocity);
          g_GrenadeLocationsKv.GetVector("grenadeDetonationOrigin", grenadeDetonationOrigin);

          Action ret = Plugin_Continue;
          Call_StartFunction(INVALID_HANDLE, f);
          Call_PushString(ownerName);
          Call_PushString(ownerAuth);
          Call_PushString(name);
          Call_PushString(execution);
          Call_PushString(grenadeId);
          Call_PushArrayEx(origin, sizeof(origin), SM_PARAM_COPYBACK);
          Call_PushArrayEx(angles, sizeof(angles), SM_PARAM_COPYBACK);
          Call_PushString(grenadeTypeString);
          Call_PushArrayEx(grenadeOrigin, sizeof(grenadeOrigin), SM_PARAM_COPYBACK);
          Call_PushArrayEx(grenadeVelocity, sizeof(grenadeVelocity), SM_PARAM_COPYBACK);
          Call_PushArrayEx(grenadeDetonationOrigin, sizeof(grenadeDetonationOrigin), SM_PARAM_COPYBACK);
          Call_PushCell(data);
          Call_Finish(ret);

          g_GrenadeLocationsKv.SetVector("origin", origin);
          g_GrenadeLocationsKv.SetVector("angles", angles);
          g_GrenadeLocationsKv.SetVector("grenadeOrigin", grenadeOrigin);
          g_GrenadeLocationsKv.SetVector("grenadeVelocity", grenadeVelocity);
          g_GrenadeLocationsKv.SetVector("grenadeDetonationOrigin", grenadeDetonationOrigin);

          if (ret >= Plugin_Handled) {
            g_GrenadeLocationsKv.GoBack();
            g_GrenadeLocationsKv.GoBack();
            return;
          }

        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }

    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
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

public Action Timer_ClientSpectate(Handle Timer, DataPack pack) {
  pack.Reset();
  int client = pack.ReadCell();
  int client2 = pack.ReadCell();
  if (IsValidClient(client) && IsValidClient(client2)) {
    SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", client2);
    ChangeClientTeam(client, TEAM_SPECTATOR);
  }
  return Plugin_Handled;
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

public void GetHoloNadeColorFromType(const GrenadeType type, int color[4]) {
  switch (type) {
    case GrenadeType_Molotov:
      color = GRENADE_COLOR_MOLOTOV;
    case GrenadeType_Incendiary:
      color = GRENADE_COLOR_MOLOTOV;
    case GrenadeType_Smoke:
      color = GRENADE_COLOR_SMOKE;
    case GrenadeType_Flash:
      color =  GRENADE_COLOR_FLASH;
    case GrenadeType_HE:
      color = GRENADE_COLOR_HE;
    default:
      color = GRENADE_COLOR_DEFAULT;
  }
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

public bool FindGrenadeByName(const char[] auth, const char[] lookupName,
                       char grenadeId[OPTION_ID_LENGTH]) {
  char name[OPTION_NAME_LENGTH];
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
      do {
        g_GrenadeLocationsKv.GetSectionName(grenadeId, sizeof(grenadeId));
        g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
        if (StrEqual(name, lookupName)) {
          g_GrenadeLocationsKv.GoBack();
          g_GrenadeLocationsKv.GoBack();
          return true;
        }
      } while (g_GrenadeLocationsKv.GotoNextKey());

      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return false;
}

public bool FindMatchingGrenadesByName(const char[] lookupName, const char[] auth, ArrayList ids) {
  char currentId[OPTION_ID_LENGTH];
  char name[OPTION_NAME_LENGTH];
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          g_GrenadeLocationsKv.GetSectionName(currentId, sizeof(currentId));
          g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
          if (StrContains(name, lookupName, false) >= 0) {
            ids.PushString(currentId);
          }
        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return ids.Length > 0;
}

stock int FindGrenadeWithCode(const char[] code) {
  char auth[AUTH_LENGTH];
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    do {
      g_GrenadeLocationsKv.GetSectionName(auth, AUTH_LENGTH);
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          char currentCode[GRENADE_CODE_LENGTH];
          g_GrenadeLocationsKv.GetString("code", currentCode, sizeof(currentCode));
          if (StrEqual(currentCode, code)) {
            char currentId[OPTION_ID_LENGTH];
            g_GrenadeLocationsKv.GetSectionName(currentId, sizeof(currentId));
            g_GrenadeLocationsKv.Rewind();
            return StringToInt(currentId);
          }
        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }

    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
  }
  return -1;
}

public bool IsGrenadeProjectile(const char[] className) {
  static char projectileTypes[][] = {
      "hegrenade_projectile", "smokegrenade_projectile", "decoy_projectile",
      "flashbang_projectile", "molotov_projectile",
  };

  return FindStringInArray2(projectileTypes, sizeof(projectileTypes), className) >= 0;
}

public bool IsGrenadeWeapon(const char[] weapon) {
  static char grenades[][] = {
      "weapon_incgrenade", "weapon_molotov",   "weapon_hegrenade",
      "weapon_decoy",      "weapon_flashbang", "weapon_smokegrenade",
  };

  return FindStringInArray2(grenades, sizeof(grenades), weapon) >= 0;
}

public bool FindId(const char[] idStr, char[] auth, int authLen) {
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) { 
    do {
      g_GrenadeLocationsKv.GetSectionName(auth, authLen);
      // Inner iteration by grenades for a user.
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          char currentId[OPTION_ID_LENGTH];
          g_GrenadeLocationsKv.GetSectionName(currentId, sizeof(currentId));
          if (StrEqual(idStr, currentId)) {
            g_GrenadeLocationsKv.Rewind();
            return true;
          }
        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }

    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
  } 

  return false;
}

public bool TryJumpToId(const char[] idStr) {
  char auth[AUTH_LENGTH];
  if (FindId(idStr, auth, sizeof(auth))) {
    g_GrenadeLocationsKv.JumpToKey(auth, true);
    g_GrenadeLocationsKv.JumpToKey(idStr, true);
    return true;
  }

  return false;
}

public bool TryJumpToOwnerId(const char[] idStr, char[] ownerAuth, int authLength, char[] ownerName,
                      int nameLength) {
  if (FindId(idStr, ownerAuth, authLength)) {
    g_GrenadeLocationsKv.JumpToKey(ownerAuth, true);
    g_GrenadeLocationsKv.GetString("name", ownerName, nameLength);
    g_GrenadeLocationsKv.JumpToKey(idStr, true);
    return true;
  }

  return false;
}

stock int SaveGrenadeToKv(int client, const float origin[3], const float angles[3],
                          const float grenadeOrigin[3], const float grenadeVelocity[3],
                          GrenadeType type, const float grenadeDetonationOrigin[3], 
                          const char[] name, const char[] execution = "") {
  g_UpdatedGrenadeKv = true;
  char idStr[OPTION_ID_LENGTH];
  IntToString(g_NextID, idStr, sizeof(idStr));

  char auth[AUTH_LENGTH];
  char clientName[MAX_NAME_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  GetClientName(client, clientName, sizeof(clientName));
  g_GrenadeLocationsKv.JumpToKey(auth, true);
  g_GrenadeLocationsKv.SetString("name", clientName);

  g_GrenadeLocationsKv.JumpToKey(idStr, true);

  g_GrenadeLocationsKv.SetString("name", name);
  g_GrenadeLocationsKv.SetVector("origin", origin);
  g_GrenadeLocationsKv.SetVector("angles", angles);
  if (g_CSUtilsLoaded && IsGrenade(type)) {
    char grenadeTypeString[32];
    GrenadeTypeString(type, grenadeTypeString, sizeof(grenadeTypeString));
    g_GrenadeLocationsKv.SetString("grenadeType", grenadeTypeString);
    g_GrenadeLocationsKv.SetVector("grenadeOrigin", grenadeOrigin);
    g_GrenadeLocationsKv.SetVector("grenadeVelocity", grenadeVelocity);
    if (grenadeDetonationOrigin[0] || grenadeDetonationOrigin[1] || grenadeDetonationOrigin[2]) {
      g_GrenadeLocationsKv.SetVector("grenadeDetonationOrigin", grenadeDetonationOrigin);
    } else {
      // Try Predict Ending Pos
      float predictedEndPos[3];
      char weaponName[128];
      GetGrenadeWeapon(type, weaponName, sizeof(weaponName));
      bool predictJumpThrow = view_as<bool>(StrContains(execution, "Jump", false) + 1);
      CreateTrajectory(client, GrenadeTypeFromWeapon(client, weaponName), view_as<GrenadePredict_Mode>(predictJumpThrow),
        GetEntityFlags(client) & FL_DUCKING, predictedEndPos, origin, angles);
      g_GrenadeLocationsKv.SetVector("grenadeDetonationOrigin", predictedEndPos);
    }
    g_GrenadeLocationsKv.SetString("execution", execution);
    char toEncrypt[512];
    Format(toEncrypt, sizeof(toEncrypt), "O%f%f%fGV%f%f%f",
      origin[0], origin[1], origin[2],
      grenadeVelocity[0], grenadeVelocity[1], grenadeVelocity[2]);
    char code[GRENADE_CODE_LENGTH];
    Crypt_MD5(toEncrypt, code, sizeof(code));
    g_GrenadeLocationsKv.SetString("code", code);
  }

  g_GrenadeLocationsKv.GoBack();
  g_GrenadeLocationsKv.GoBack();
  g_NextID++;

  return g_NextID - 1;
}

public bool DeleteGrenadeFromKv(const char[] nadeIdStr) {
  g_UpdatedGrenadeKv = true;
  char auth[AUTH_LENGTH];
  FindId(nadeIdStr, auth, sizeof(auth));
  bool deleted = false;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    char name[OPTION_NAME_LENGTH];
    if (g_GrenadeLocationsKv.JumpToKey(nadeIdStr)) {
      g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
      g_GrenadeLocationsKv.GoBack();
    }

    deleted = g_GrenadeLocationsKv.DeleteKey(nadeIdStr);
    g_GrenadeLocationsKv.GoBack();
  }

  // If the grenade deleted has the highest grenadeId, reset nextid to it so that
  // we don't waste spots in the greandeId-space.
  if (deleted) {
    if (StringToInt(nadeIdStr) + 1 == g_NextID) {
      g_NextID--;
    }
  }
  
  return deleted;
}

public void SetGrenadeData(const char[] auth, const char[] id, const char[] key, const char[] value) {
  g_UpdatedGrenadeKv = true;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.SetString(key, value);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void SetGrenadeFloat(const char[] auth, const char[] id, const char[] key, float value) {
  g_UpdatedGrenadeKv = true;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.SetFloat(key, value);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void GetGrenadeData(const char[] auth, const char[] id, const char[] key, char[] value,
                    int valueLength) {
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.GetString(key, value, valueLength);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public float GetGrenadeFloat(const char[] auth, const char[] id, const char[] key) {
  float value = 0.0;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      value = g_GrenadeLocationsKv.GetFloat(key);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return value;
}

public void GetGrenadeVector(const char[] auth, const char[] id, const char[] key, float vector[3]) {
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.GetVector(key, vector);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void SetGrenadeVector(const char[] auth, const char[] id, const char[] key, const float vector[3]) {
  g_UpdatedGrenadeKv = true;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.JumpToKey(id)) {
      g_GrenadeLocationsKv.SetVector(key, vector);
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
}

public void SetClientGrenadeData(int id, const char[] key, const char[] value) {
  char auth[AUTH_LENGTH];
  char nadeId[OPTION_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  SetGrenadeData(auth, nadeId, key, value);
}

public void GetClientGrenadeData(int id, const char[] key, char[] value, int valueLength) {
  char auth[AUTH_LENGTH];
  char nadeId[OPTION_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  GetGrenadeData(auth, nadeId, key, value, valueLength);
}

public void SetClientGrenadeFloat(int id, const char[] key, float value) {
  char auth[AUTH_LENGTH];
  char nadeId[OPTION_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  SetGrenadeFloat(auth, nadeId, key, value);
}

public float GetClientGrenadeFloat(int id, const char[] key) {
  char auth[AUTH_LENGTH];
  char nadeId[OPTION_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  return GetGrenadeFloat(auth, nadeId, key);
}

public void GetClientGrenadeVector(int id, const char[] key, float vector[3]) {
  char auth[AUTH_LENGTH];
  char nadeId[OPTION_ID_LENGTH];
  IntToString(id, nadeId, sizeof(nadeId));
  FindId(nadeId, auth, sizeof(auth));
  GetGrenadeVector(auth, nadeId, key, vector);
}

stock int CountGrenadesForPlayer(const char[] auth, GrenadeType grenadeType = GrenadeType_None) {
  int count = 0;
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
      do {
        if (grenadeType == GrenadeType_None) {
          count++;
        } else {
          char grenadeTypeString[32];
          g_GrenadeLocationsKv.GetString("grenadeType", grenadeTypeString, sizeof(grenadeTypeString));
          if (grenadeType == GrenadeTypeFromString(grenadeTypeString)) {
            count++;
          }
        }
      } while (g_GrenadeLocationsKv.GotoNextKey());

      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return count;
}

// public int FindNextGrenadeId(int client, int currentId) {
//   char auth[AUTH_LENGTH];
//   GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

//   int ret = -1;
//   if (g_GrenadeLocationsKv.JumpToKey(auth)) {
//     if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
//       do {
//         char idBuffer[OPTION_ID_LENGTH];
//         g_GrenadeLocationsKv.GetSectionName(idBuffer, sizeof(idBuffer));
//         int id = StringToInt(idBuffer);
//         if (id > currentId) {
//           ret = id;
//           break;
//         }
//       } while (g_GrenadeLocationsKv.GotoNextKey());
//       g_GrenadeLocationsKv.GoBack();
//     }
//     g_GrenadeLocationsKv.GoBack();
//   }

//   return ret;
// }

static KeyValues g_NewKv;

static ArrayList g_AllIds;
static bool g_RepeatIdSeen;

public void MaybeCorrectGrenadeIds() {
  // Determine if we need to do this first. Iterate over all grenades and store the ids as an int.
  // If we see a repeat, then we need to do the correction.
  g_AllIds = new ArrayList();
  g_RepeatIdSeen = false;
  IterateGrenades(IsCorrectionNeededHelper);

  // But first... let's make sure the nextid field is always right.
  SortADTArray(g_AllIds, Sort_Ascending, Sort_Integer);
  int biggestID = 0;
  if (g_AllIds.Length > 0) {
    biggestID = g_AllIds.Get(g_AllIds.Length - 1);
  }
  g_NextID = biggestID + 1;

  delete g_AllIds;

  if (g_RepeatIdSeen) {
    CorrectGrenadeIds();
  }
}

public Action IsCorrectionNeededHelper(
  const char[] ownerName, 
  const char[] ownerAuth, 
  const char[] name,
  const char[] execution, 
  const char[] grenadeId, 
  const float origin[3], 
  const float angles[3],
  const char[] grenadeType, 
  const float grenadeOrigin[3], 
  const float grenadeVelocity[3], 
  const float grenadeDetonationOrigin[3], 
  any data
) {
  int id = StringToInt(grenadeId);
  if (g_AllIds.FindValue(id) >= 0) {
    g_RepeatIdSeen = true;
  }
  g_AllIds.Push(id);
  return Plugin_Continue;
}

public void CorrectGrenadeIds() {
  // We'll do the correction; use a temp kv structure to copy data over using new ids and
  // swap it into the existing g_GrenadeLocationsKv structure.
  PrintToServer("Updating grenadeIds since duplicates were found...");
  g_NewKv = new KeyValues("Grenades");
  g_NextID = 1;
  IterateGrenades(CorrectGrenadeIdsHelper);

  // Move the temp g_NewKv to replace data in g_GrenadeLocationsKv.
  delete g_GrenadeLocationsKv;
  g_GrenadeLocationsKv = g_NewKv;
  g_NewKv = null;
  g_UpdatedGrenadeKv = true;
}

public Action CorrectGrenadeIdsHelper(
  const char[] ownerName, 
  const char[] ownerAuth, 
  const char[] name, 
  const char[] execution, 
  const char[] grenadeId, 
  const float origin[3], 
  const float angles[3], 
  const char[] grenadeType, 
  const float grenadeOrigin[3], 
  const float grenadeVelocity[3], 
  const float grenadeDetonationOrigin[3], 
  any data
) {
  char newId[64];
  IntToString(g_NextID, newId, sizeof(newId));
  g_NextID++;

  if (g_NewKv.JumpToKey(ownerAuth, true)) {
    g_NewKv.SetString("name", ownerName);
    if (g_NewKv.JumpToKey(newId, true)) {
      g_NewKv.SetString("name", name);
      g_NewKv.SetVector("origin", origin);
      g_NewKv.SetVector("angles", angles);
      g_NewKv.SetString("execution", execution);
      g_NewKv.GoBack();
    }
  }
  g_NewKv.Rewind();
  return Plugin_Continue;
}

public bool CanEditGrenade(int client, int id) {
  bool ret = false;
  char clientAuth[AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));
  if (g_GrenadeLocationsKv.JumpToKey(clientAuth)) {
    char strId[32];
    IntToString(id, strId, sizeof(strId));
    if (g_GrenadeLocationsKv.JumpToKey(strId)) {
      ret = true;
      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return ret;
}

public void GetGrenadeExecutionType(int btns, char[] buffer, int size) {
  bool printSeparator = false;
  char execution[64-1];
  if (btns & IN_SPEED) {
    strcopy(execution, sizeof(execution), "Shift");
    printSeparator = true;
  }
  if (btns & IN_DUCK) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "CTRL");
    printSeparator = true;
  }
  if (btns & IN_FORWARD) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "W");
    printSeparator = true;
  }
  if (btns & IN_MOVELEFT) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "A");
    printSeparator = true;
  }
  if (btns & IN_MOVERIGHT) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "D");
    printSeparator = true;
  }
  if (btns & IN_BACK) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "S");
    printSeparator = true;
  }
  if (btns & IN_ATTACK) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "Mouse1");
    printSeparator = true;
  }
  if (btns & IN_ATTACK2) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "Mouse2");
    printSeparator = true;
  }
  if (btns & IN_JUMP) {
    if (printSeparator) StrCat(execution, sizeof(execution), " + ");
    StrCat(execution, sizeof(execution), "JumpThrow");
  }

  strcopy(buffer, size, execution);
}
