#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#define DEBUG
#define SpectateModel "models/chicken/festive_egg.mdl"

#define Mouse1and2_Strength 0.5
#define Mouse1_Strength 1.0
#define Jumpthrow_Strength 3.5
#define Mouse2_Strength 0.0

#define sv_gravity 800
#define trail_tickness 0.5
#define interval_per_tick 0.05

enum ThrowType{
  Mouse1 = 0,
  Mouse2,
  Mouse1and2,
  Jumpthrow
}

int g_trail;
Handle sm_test_mode;
char nadelist[128] = "weapon_hegrenade weapon_smokegrenade weapon_flashbang weapon_incgrenade weapon_tagrenade weapon_molotov weapon_decoy";
bool g_InNadrMode = false;

float ClientThrowStrength[MAXPLAYERS + 1] = {Mouse1_Strength, ...};
float ClientThrowVel[MAXPLAYERS + 1] = {675.0, ...};
float ClientVectorConst[MAXPLAYERS + 1][3];

CSWeaponID ClientSavedWeapons[MAXPLAYERS + 1][10]; //each player, 10 max weapons
char ClientLastGrenadeName[MAXPLAYERS + 1][64];

int ClientEntity_TrailEnd[MAXPLAYERS+1] = {-1, ...};
int ClientEntity_StaticCamera[MAXPLAYERS+1] = {-1, ...};
int ClientEntity_ThrownGrenade[MAXPLAYERS+1] = {-1, ...};

bool ClientViewing_StaticCamera[MAXPLAYERS + 1] = {false, ...};
bool ClientViewing_RotatingCamera[MAXPLAYERS + 1] = {false, ...};

float ClientLastAbsPosition[MAXPLAYERS + 1][3];
float ClientLastEyePosition[MAXPLAYERS + 1][3];
float ClientLastEyeAngles[MAXPLAYERS + 1][3];

bool ClientHoldingE[MAXPLAYERS+1] = {false, ...};
bool ClientHoldingR[MAXPLAYERS+1] = {false, ...};
bool ClientHoldingF[MAXPLAYERS+1] = {false, ...};
bool FirstTriggerF[MAXPLAYERS+1] = {true, ...};

public Plugin myinfo =  {
  name = "Grenade Trajectory Prediction",
  author = "",
  description = "",
  version = "1.0",
  url = ""
};


public OnPluginStart() {
  g_InNadrMode = true;
  sm_test_mode = CreateConVar("sm_test_mode", "0.0", "Testing mode: 0 for disabled, 1 for enabled.", FCVAR_NOTIFY | FCVAR_DONTRECORD, true, 0.0, true, 1.0);
  RegAdminCmd("sm_nadr", Command_ToggleLaunchNadr, ADMFLAG_CHANGEMAP, "Launches/Exits grenade trajectory mode");
  RegConsoleCmd("sm_fastforward", FFastForward);
  AddCommandListener(OnClientHoldFKey, "+lookatweapon");
  AddCommandListener(OnClientReleaseFKey, "-lookatweapon");
}


public Action Command_ToggleLaunchNadr(int client, int args) {
  g_InNadrMode = !g_InNadrMode;
  PrintToChat(client, "[\x05PracticeMode\x01] Grenade Trajectory Preview %s", !g_InNadrMode ? "Disabled" : "Enabled");
  return Plugin_Handled;
}


public void OnEntityCreated(int entity, const char[] className) {
  if (!g_InNadrMode || !IsValidEntity(entity) || !IsValidEdict(entity)) {
    return;
  }
  SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}


public void OnEntitySpawned(int entity) {
  char className[128];
  GetEdictClassname(entity, className, sizeof(className));
  if (IsGrenadeProjectile(className)) {
    int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
    if (IsValidClient(client)) {
      ClientEntity_ThrownGrenade[client] = entity;
    }
  }
}

public void OnEntityDestroyed(entity) {
  if (!IsValidEdict(entity) || !IsValidEntity(entity) || !g_InNadrMode) {
    return;
  }
  char className[128];
  GetEdictClassname(entity, className, sizeof(className));
  int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
  if (!IsValidClient(client) || !IsGrenadeProjectile(className)) {
    return;
  }
  if (entity == ClientEntity_ThrownGrenade[client]) {
    //it was destroyed
    ClientEntity_ThrownGrenade[client] = -1;
  }
}


public void OnClientDisconnect(int client) {
  if (!IsValidClient(client)) {
    return;
  }
  //destroy this clients entities if they exist
  if (IsValidEntity(ClientEntity_TrailEnd[client]) && ClientEntity_TrailEnd[client] > 0) {
    // >-1 ?
    AcceptEntityInput(ClientEntity_TrailEnd[client], "Kill");
    ClientEntity_TrailEnd[client] = -1;
  }
  if (IsValidEntity(ClientEntity_StaticCamera[client]) && ClientEntity_StaticCamera[client] > 0) {
    AcceptEntityInput(ClientEntity_StaticCamera[client], "Kill");
    ClientEntity_StaticCamera[client] = -1;
  }
}


public void OnClientPostAdminCheck(int client) {
  if (!IsValidClient(client)) {
    return;
  }
  //create this clients entities if they dont exist already
  float origin[3];
  GetClientAbsOrigin(client, origin);
  if (!IsValidEntity(ClientEntity_TrailEnd[client]) || ClientEntity_TrailEnd[client] < 0) {
    //== -1?
    ClientEntity_TrailEnd[client] = CreateEntityByName("prop_dynamic_override");
    DispatchKeyValue(ClientEntity_TrailEnd[client], "model", SpectateModel);
    SetEntityRenderMode(ClientEntity_TrailEnd[client], RENDER_NONE);
    TeleportEntity(ClientEntity_TrailEnd[client], origin, NULL_VECTOR, NULL_VECTOR);
    DispatchSpawn(ClientEntity_TrailEnd[client]);
  }
  origin[2] += 20.0;
  if (!IsValidEntity(ClientEntity_StaticCamera[client]) || ClientEntity_StaticCamera[client] < 0) {
    ClientEntity_StaticCamera[client] = CreateEntityByName("prop_dynamic_override");
    DispatchKeyValue(ClientEntity_StaticCamera[client], "model", SpectateModel);
    SetEntityRenderMode(ClientEntity_StaticCamera[client], RENDER_NONE);
    TeleportEntity(ClientEntity_StaticCamera[client], origin, NULL_VECTOR, NULL_VECTOR);
    DispatchSpawn(ClientEntity_StaticCamera[client]);
  }
  PrintToServer("Entities Spawned for player %N", client);
}


public OnMapStart() {
  g_trail = PrecacheModel("sprites/laserbeam.spr");
  // g_trail = PrecacheModel("materials/sprites/white.vmt");
  PrecacheModel(SpectateModel);
}

public Action OnPlayerRunCmd(int client, int& buttons) {
  if (!g_InNadrMode || !IsValidClient(client)) {
    return Plugin_Continue;
  }
  if (!IsValidEntity(ClientEntity_StaticCamera[client]) || !IsValidEntity(ClientEntity_TrailEnd[client])) {
    float EntsOrigin[3];
    GetClientAbsOrigin(client, EntsOrigin);
    if (!IsValidEntity(ClientEntity_TrailEnd[client]) || ClientEntity_TrailEnd[client] < 0) {
      //== -1?
      ClientEntity_TrailEnd[client] = CreateEntityByName("prop_dynamic_override");
      DispatchKeyValue(ClientEntity_TrailEnd[client], "model", SpectateModel);
      SetEntityRenderMode(ClientEntity_TrailEnd[client], RENDER_NONE);
      TeleportEntity(ClientEntity_TrailEnd[client], EntsOrigin, NULL_VECTOR, NULL_VECTOR);
      DispatchSpawn(ClientEntity_TrailEnd[client]);
    }
    EntsOrigin[2] += 20.0;
    if (!IsValidEntity(ClientEntity_StaticCamera[client]) || ClientEntity_StaticCamera[client] < 0) {
      ClientEntity_StaticCamera[client] = CreateEntityByName("prop_dynamic_override");
      DispatchKeyValue(ClientEntity_StaticCamera[client], "model", SpectateModel);
      SetEntityRenderMode(ClientEntity_StaticCamera[client], RENDER_NONE);
      TeleportEntity(ClientEntity_StaticCamera[client], EntsOrigin, NULL_VECTOR, NULL_VECTOR);
      DispatchSpawn(ClientEntity_StaticCamera[client]);
    }
    PrintToServer("Entities Spawned for player %N", client);
    return Plugin_Continue;
  }
  //if there is a flying grenade, dont execute anything else
  if ((buttons & IN_RELOAD) && ClientHoldingR[client] && ClientEntity_ThrownGrenade[client] > 0 && IsValidEntity(ClientEntity_ThrownGrenade[client])
  && !(buttons & IN_USE) && !ClientHoldingF[client]) {
    if (!ClientViewing_RotatingCamera[client]) {
      //started watching
      //trigger only once
      PreActivateRotatingCamera(client);
    } else {
      //if its already watching
      //same method as before?
      ActivateRotatingCamera(client, ClientEntity_ThrownGrenade[client]);
      ShowTrajectory(client, ClientLastGrenadeName[client], true, ClientLastEyePosition[client], ClientLastEyeAngles[client]);
    }
    return Plugin_Continue;
  } /*else if ((buttons & IN_RELOAD) && ClientHoldingR[client] && ClientEntity_ThrownGrenade[client] == -1 && !(buttons & IN_USE) && !ClientHoldingF[client]) {
  }*/

  char weaponName[64];
  GetClientWeapon(client, weaponName, sizeof(weaponName));

  if (StrContains(nadelist, weaponName, false) == -1) {
    //its not a grenade
    /*if ((buttons & IN_RELOAD) && !ClientHoldingR[client]) {
      //client started to press R
      //only trigger once
      ClientHoldingR[client] = true;
    } else if (!(buttons & IN_RELOAD) && ClientHoldingR[client]) {
      //Client Released R key
      //only trigger once
      ClientHoldingR[client] = false;
      SetClientViewEntity(client, client); //quick fix
      if (ClientViewing_RotatingCamera[client]) {
        ClientViewing_RotatingCamera[client] = false;
        //deactivate rotating camera
        RestoreAllInventory(client);
      }
      if (GetVectorLength(ClientLastAbsPosition[client]) != 0) {
        //if not equal to 0,0,0
        TeleportEntity(client, ClientLastAbsPosition[client], ClientLastEyeAngles[client], NULL_VECTOR);
      }
    }*/
    return Plugin_Continue;
  }
  //??????????????????????TODO FIX BUG WHEN E+R WHEN THROWED GRENADE
  //MAYBE DISABLE WEAPONS ALSO IN E+R?
  if (weaponName[0]) {
    //its not empty AND ITS A GRENADE
    ClientLastGrenadeName[client] = weaponName;
  }
  //CHECK E KEY
  if ((buttons & IN_USE) && !ClientHoldingE[client]) {
    //client started to press E
    if (ClientViewing_RotatingCamera[client]) {
      //ClientViewing_RotatingCamera[client] = false;
      //deactivate rotating camera
      //RestoreAllInventory(client);
      TeleportEntity(client, ClientLastAbsPosition[client], ClientLastEyeAngles[client], NULL_VECTOR);
    }
    //only trigger once
    ClientHoldingE[client] = true;
    return Plugin_Continue;
  } else if (!(buttons & IN_USE) && ClientHoldingE[client]) {
    //Client Released E key
    if (ClientViewing_StaticCamera[client]) {
      SetClientViewEntity(client, client); //quick fix
      ClientViewing_StaticCamera[client] = false;
    }
    //SetClientViewEntity(client, client); //quick fix
    if (ClientHoldingR[client]) {
      //activate rotating camera
      PreActivateRotatingCamera(client);
    }
    //only trigger once
    ClientHoldingE[client] = false;
    return Plugin_Continue;
  }
  //CHECK R KEY
  if ((buttons & IN_RELOAD) && !ClientHoldingR[client]) {
    //client started to press R
    //only trigger once
    ClientHoldingR[client] = true;
    return Plugin_Continue;
  } else if (!(buttons & IN_RELOAD) && ClientHoldingR[client]) {
    //Client Released R key
    //only trigger once
    ClientHoldingR[client] = false;
    SetClientViewEntity(client, client); //quick fix
    if (ClientViewing_RotatingCamera[client]) {
      ClientViewing_RotatingCamera[client] = false;
      //deactivate rotating camera
      RestoreAllInventory(client);
      TeleportEntity(client, ClientLastAbsPosition[client], ClientLastEyeAngles[client]
      ,view_as<float>({0.0,0.0,0.0}));
    }
    if (ClientViewing_StaticCamera[client]) {
      SetClientViewEntity(client, client); //quick fix
      ClientViewing_StaticCamera[client] = false;
    }
    if (GetVectorLength(ClientLastAbsPosition[client]) != 0) {
      //if not equal to 0,0,0
      TeleportEntity(client, ClientLastAbsPosition[client], ClientLastEyeAngles[client], NULL_VECTOR);
    }
    return Plugin_Continue;
  }

  //check F Key
  if (ClientHoldingF[client]) {
    //holding F key
    On_Client_Configs(client, Jumpthrow);
    if (ClientHoldingR[client]) {
      //R key and F key
      if (!ClientViewing_StaticCamera[client]) {
        ClientViewing_StaticCamera[client] = true;
        ClientEntity_ThrownGrenade[client] = -1;
        SetClientViewEntity(client, ClientEntity_StaticCamera[client]);
      } else {
        //already in camera
        GetClientAbsOrigin(client, ClientLastAbsPosition[client]);
        GetClientEyePosition(client, ClientLastEyePosition[client]);
        GetClientEyeAngles(client, ClientLastEyeAngles[client]);
      }
    } else {
      SetClientViewEntity(client, client); //quick fix
    }
    ShowTrajectory(client, ClientLastGrenadeName[client]);
  } else if ((buttons & IN_USE) && ClientHoldingE[client]) {
    //holding E key
    if ((buttons & IN_ATTACK) && (buttons & IN_ATTACK2)) {
      On_Client_Configs(client, Mouse1and2);
    } else if (buttons & IN_ATTACK2) {
      On_Client_Configs(client, Mouse2);
    } else {
      On_Client_Configs(client, Mouse1);
    }
    if (ClientHoldingR[client]) {
      //R key and E key
      if (!ClientViewing_StaticCamera[client]) {
        ClientViewing_StaticCamera[client] = true;
        ClientEntity_ThrownGrenade[client] = -1;
        SetClientViewEntity(client, ClientEntity_StaticCamera[client]);
      } else {
        //already in camera
        GetClientAbsOrigin(client, ClientLastAbsPosition[client]);
        GetClientEyePosition(client, ClientLastEyePosition[client]);
        GetClientEyeAngles(client, ClientLastEyeAngles[client]);
      }
    } else {
      SetClientViewEntity(client, client); //quick fix
    }
    ShowTrajectory(client, ClientLastGrenadeName[client]);
  } else if ((buttons & IN_RELOAD) && ClientHoldingR[client]) {
    //only holding R key
    if (GetVectorLength(ClientLastAbsPosition[client]) != 0) {
      if (!ClientViewing_RotatingCamera[client]) {
        //activate rotating camera
        PreActivateRotatingCamera(client);
      } else {
        //rotating camera is activated (LOOP)
        ActivateRotatingCamera(client, ClientEntity_TrailEnd[client]);
      }
      ShowTrajectory(client, ClientLastGrenadeName[client], true, ClientLastEyePosition[client], ClientLastEyeAngles[client]);
    } else{
      PrintToServer("Error! %N", client);
    }
  }

  return Plugin_Continue;
}

void RemoveWeapons(int client) {
  int wepamount=0;
  for (int i = 0; i < 5; i++) {
    int weapon;
    int WeaponItemDefIndex;
    while ((weapon = GetPlayerWeaponSlot(client, i)) != -1) {
      //all weapons we are deleting
      WeaponItemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
      ClientSavedWeapons[client][wepamount] = CS_ItemDefIndexToID(WeaponItemDefIndex);
      RemovePlayerItem(client, weapon);
      AcceptEntityInput(weapon, "Kill");
      wepamount++;
    }
  }
}

stock void PreActivateRotatingCamera(int client) {
  SetClientViewEntity(client, client);
  ClientViewing_RotatingCamera[client] = true;
  RemoveFullInventory(client);
}

stock void RemoveFullInventory(int client) {
  SetEntityMoveType(client, MOVETYPE_NONE);
  SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD")|( 1<<3 )|( 1<<0 ));
  SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
  RemoveWeapons(client);
}

stock void ActivateRotatingCamera(int client, int entity) {
  //teleporting the client to the entity with certain angles to fit your description
  float origin[3], angles[3], angles1[3], result[3];
  GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
  GetClientEyeAngles(client, angles);
  angles1 = angles;
  GetAngleVectors(angles, angles1, NULL_VECTOR, NULL_VECTOR);
  NormalizeVector(angles1, angles1);
  angles1[0] *= 100.0;
  angles1[1] *= 100.0;
  angles1[2] *= 100.0;
  SubtractVectors(origin, angles1, result);
  result[2] -= 64;
  //im teleporting to eyes not to absolute position
  TeleportEntity(client, result, NULL_VECTOR, NULL_VECTOR);
}

stock void RestoreAllInventory(int client) {
  SetEntityMoveType(client, MOVETYPE_WALK);
  SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
  SetEntProp(client, Prop_Send, "m_iHideHUD", 0);
  for(int i=0; i<10; i++) {
    if (!CS_IsValidWeaponID(ClientSavedWeapons[client][i])) {
      continue;
    }
    char weaponName[64];
    CS_WeaponIDToAlias(ClientSavedWeapons[client][i], weaponName, sizeof(weaponName));
    Format(weaponName, sizeof(weaponName), "weapon_%s", weaponName);
    GivePlayerItem(client, weaponName);
  }
  FakeClientCommand(client, "use %s", ClientLastGrenadeName[client]);
}

public Action OnClientHoldFKey(int client, const char[] command, int argc) {
  if (!IsValidClient(client) || !g_InNadrMode) {
    return Plugin_Continue;
  }
  //client started to press F key, only trigger once?
  if (FirstTriggerF[client]) {
    if (ClientViewing_RotatingCamera[client]) {
      //ClientViewing_RotatingCamera[client] = false;
      //deactivate rotating camera
      //RestoreAllInventory(client);
      TeleportEntity(client, ClientLastAbsPosition[client], ClientLastEyeAngles[client], NULL_VECTOR);
    }
    //FirstTriggerF[client] = false;
  }
  ClientHoldingF[client] = true;
  return Plugin_Continue;
}

public Action OnClientReleaseFKey(int client, const char[] command, int argc) {
  if (!IsValidClient(client) || !g_InNadrMode) {
    return Plugin_Continue;
  }
  if (ClientViewing_StaticCamera[client]) {
    SetClientViewEntity(client, client); //quick fix
    ClientViewing_StaticCamera[client] = false;
  }
  ClientHoldingF[client] = false;
  FirstTriggerF[client] = true;
  //SetClientViewEntity(client, client); //quick fix
  return Plugin_Continue;
}


stock void On_Client_Configs(int client, ThrowType type = Mouse1) {
  ClientThrowVel[client] = 750 * 0.9;
  ClientVectorConst[client] = NULL_VECTOR;
  if (type == Jumpthrow) {
    ClientThrowStrength[client] = Jumpthrow_Strength;
    ClientThrowVel[client] /= ((0.7 * ClientThrowStrength[client]) + 0.3);
    ClientVectorConst[client][2] = 261.5;
  } else if (type == Mouse1and2) {
    ClientThrowStrength[client] = Mouse1and2_Strength;
  } else if (type == Mouse2) {
    ClientThrowStrength[client] = Mouse2_Strength;
  } else if (type == Mouse1) {
    ClientThrowStrength[client] = Mouse1_Strength;
    ClientVectorConst[client][2] = -2.9;
  }
}

stock void ShowTrajectory(
  int client,
  const char[] cWeapon,
  bool OverrideStart = false,
  float O_StartPoint[3] = {},
  float O_Angles[3] = {}
)   {
  float dtime = GetDetonationTime(cWeapon);
  float GrenadeVelocity[3], PlayerVelocity[3], vforward[3], v68;
  float gStart[3], gEnd[3], angThrow[3], fwd[3], right[3], up[3];

  if (OverrideStart) {
    gStart = O_StartPoint;
    angThrow = O_Angles;
  } else {
    GetClientEyePosition(client, gStart);
    GetClientEyeAngles(client, angThrow);
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", PlayerVelocity);
  }

  if (angThrow[0] < -90.0) angThrow[0] += 360.0;
  else if (angThrow[0] > 90.0) angThrow[0] -= 360.0;

  angThrow[0] -= (90.0 - FloatAbs(angThrow[0]))*10.0/90.0;

  GetAngleVectors(angThrow, fwd, right, up);
  NormalizeVector(fwd, vforward);

  for (int i = 0; i < 3; i++)
    gStart[i] += vforward[i] * 22;

  float throwHeight = (ClientThrowStrength[client] * 12.0) - 12.0;

  gStart[2] += throwHeight;
  v68 = ClientThrowVel[client] * ((0.7 * ClientThrowStrength[client]) + 0.3);
  ScaleVector(PlayerVelocity, 1.25);

  for (int i = 0; i < 3; i++)
    GrenadeVelocity[i] = ClientVectorConst[client][i] + PlayerVelocity[i] + vforward[i] * v68;

  for (float t = 0.0; t <= dtime; t += interval_per_tick) {
    gEnd[0] = gStart[0] + GrenadeVelocity[0] * interval_per_tick;
    gEnd[1] = gStart[1] + GrenadeVelocity[1] * interval_per_tick;

    float ent_Gravity = 0.4;
    float GetActualGravity = ent_Gravity*sv_gravity;
    float newZVelocity = GrenadeVelocity[2] - GetActualGravity * interval_per_tick;

    gEnd[2] = gStart[2] + (GrenadeVelocity[2] + newZVelocity) / 2.0 * interval_per_tick;
    GrenadeVelocity[2] = newZVelocity;

    float mins[3] = {-2.0, -2.0, -2.0}, maxs[3] = {2.0, 2.0, 2.0};
    Handle gRayTrace = TR_TraceHullEx(gStart, gEnd, mins, maxs, MASK_SOLID | CONTENTS_CURRENT_90);
    if (TR_GetFraction(gRayTrace) != 1.0) {
      if (TR_GetEntityIndex(gRayTrace) == client) {
        CloseHandle(gRayTrace);
        gStart = gEnd;
        continue;
      }

      int entidad = TR_GetEntityIndex(gRayTrace);
      char ClassName[30];
      GetEdictClassname(entidad, ClassName, sizeof(ClassName));
      if (!StrEqual(ClassName,"worldspawn",false) && GetConVarBool(sm_test_mode)) {
        PrintToChat(client, "ClassName: %s",ClassName);
      }
      if (StrContains(ClassName, "_projectile") != -1) {
        CloseHandle(gRayTrace);
        gStart = gEnd;
        continue;
      }
      if (StrEqual(ClassName, "info_target", false)) {
        CloseHandle(gRayTrace);
        gStart = gEnd;
        continue;
      }
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
        if (FloatAbs(GrenadeVelocity[i]) > -0.1 && FloatAbs(GrenadeVelocity[i]) < 0.1)
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
            for (int i = 0; i < 3; i++) {
              GrenadeVelocity[i] *= 1.0 - l + 0.5;
            }
          } else {
            for (int i = 0; i < 3; i++) {
              GrenadeVelocity[i] = GrenadeVelocity[i]; //?
            }
          }
        }
        if (flSpeedSqr < 20.0 * 20.0) {
          ScaleVector(GrenadeVelocity, 0.0);
        } else {
          for (int i = 0; i < 3; i++) {
            GrenadeVelocity[i] = GrenadeVelocity[i];
          }
        }
        if (StrEqual(cWeapon, "weapon_incgrenade", false) || StrEqual(cWeapon, "weapon_molotov", false))
          dtime = 0.0;
      }
    }

    CloseHandle(gRayTrace);
    float width = trail_tickness;
    TE_SetupBeamPoints(gStart, gEnd, g_trail, 0, 0, 0, 0.1, width, width, 0, 0.0, { 0, 255, 255, 255 }, 0);
    TE_SendToAll(0.0);
    gStart = gEnd;
  }
  TeleportEntity(ClientEntity_TrailEnd[client], gEnd, NULL_VECTOR, NULL_VECTOR);
  TeleportCamera(client, gEnd);
}

public void TeleportCamera(int client, const float end[3]) {
  float angles[3], origin[3];
  origin = end;
  origin[0] -= 120.0;
  origin[2] += 100.0;
  angles = view_as<float>({40.0, 0.0, 0.0});
  if (TR_PointOutsideWorld(origin)) {
    origin[0] += 120.0;
    origin[2] -= 10.0;
    angles[0] += 50.0;
  }
  TeleportEntity(ClientEntity_StaticCamera[client], origin, angles, NULL_VECTOR);
}

stock float GetDetonationTime(const char[] weapon) {
  if (StrContains("weapon_hegrenade weapon_flashbang", weapon,  false) != -1)
    return 1.604;
  else if (StrEqual("weapon_tagrenade", weapon, false))
    return 5.0;
  else if (StrEqual(weapon, "weapon_incgrenade", false) || StrEqual(weapon, "weapon_molotov", false))
    return 1.979;
  else
    return 11.0;
}

stock bool IsGrenadeProjectile(const char[] className) {
  static char projectileTypes[][] = {
    "hegrenade_projectile", "smokegrenade_projectile", "decoy_projectile",
    "flashbang_projectile", "molotov_projectile",
  };
  return FindStringInArray2(projectileTypes, sizeof(projectileTypes), className) >= 0;
}

stock int FindStringInArray2(const char[][] array, int len, const char[] string, bool caseSensitive = true) {
  for (int i = 0; i < len; i++) {
    if (StrEqual(string, array[i], caseSensitive)) {
      return i;
    }
  }
  return -1;
}

public Action FFastForward(int client, int args) {
  g_InNadrMode = false;
  CreateTimer(3.5, EnableNadr);
  return Plugin_Handled;
}

public Action EnableNadr(Handle timer) {
  g_InNadrMode = true;
  return Plugin_Handled;
}

stock bool IsValidClient(int client) {
  return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client);
}
