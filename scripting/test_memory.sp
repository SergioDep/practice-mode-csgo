
#include <sourcemod>
#include <cstrike>
#include <vector>
#include <sdktools>


public void OnPluginStart() {
  RegConsoleCmd("sm_cacastart", FUNCION_CACACACA);
  RegConsoleCmd("sm_cacaclear", FUNCION_CACACLEAR);
}

Action FUNCION_CACACLEAR(int client, int args) {
  int clearEntity = -1;
  while ((clearEntity = FindEntityByClassname(clearEntity, "smokegrenade_projectile")) != -1) {
    RemoveEntity(clearEntity);
  }
  return Plugin_Handled;
}

bool Trace_BaseFilter(int entity, int contentsMask, any data) {
  if (entity == data) return false;
  return true;
}

void Dev_SpawnGrenade(
  int client,
  bool jumpthrow = false,
  bool crouching = false,
  float clientEyePos[3],
  float clientEyeAngles[3]) {
  float jumpthrowHeightDiff = (!crouching) ? 27.9035568237 : 28.245349884;
  // for normal, No Idea why too many random values
  //27.903553009
  //27.9035491943
  //27.9036560059
  //27.9035568237
  //27.9036560059
  //27.90365600585937
  // for crouching:
  // forgot to copy all found values here, but on average 28.245349884
  float jumpthrowZVelDiff = (!crouching) ? 211.3683776855468 : 214.4933776855468000;
  // for normal
  //  211.36837768554680
  // for crouching: either one of those, maybe not, no idea why too many values
  //  208.2433776855468000
  //  214.4933776855468000

  // Predict Position
  float clientfwd[3], clientvelocity[3], predictednadepos[3];
  clientEyePos[2] += (jumpthrow) ? jumpthrowHeightDiff : 0.0;
  // PM_MessageToAll("{PURPLE}predicted player height: [%.32f, %.32f, %.32f]", clientEyePos[0], clientEyePos[1], clientEyePos[2]);
  GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", clientvelocity);
  clientvelocity[2] = (jumpthrow) ? jumpthrowZVelDiff : clientvelocity[2];

  if (clientEyeAngles[0] < -90.0) clientEyeAngles[0] += 360.0;
  else if (clientEyeAngles[0] > 90.0) clientEyeAngles[0] -= 360.0;

  clientEyeAngles[0] -= (90.0 - FloatAbs(clientEyeAngles[0]))*10.0/90.0;
  
  GetAngleVectors(clientEyeAngles, clientfwd, NULL_VECTOR, NULL_VECTOR);
  float secondparameter[3];
  float fwd22[3], fwd6[3];
  fwd22 = clientfwd;
  fwd6 = clientfwd;
  ScaleVector(fwd22, 22.0);
  ScaleVector(fwd6, 6.0);
  AddVectors(clientEyePos, fwd22, secondparameter);

  float fmins[3] = {-2.0, -2.0, -2.0};
  float fmaxs[3] = {2.0, 2.0, 2.0};
  Handle trace = TR_TraceHullFilterEx(clientEyePos, secondparameter, fmins, fmaxs, MASK_SOLID|CONTENTS_CURRENT_90, Trace_BaseFilter, client);
  TR_GetEndPosition(predictednadepos, trace);

  SubtractVectors(predictednadepos, fwd6, predictednadepos);
  // PM_MessageToAll("{PURPLE}predicted nadeorigin: [%.32f, %.32f, %.32f]", predictednadepos[0], predictednadepos[1], predictednadepos[2]);

  // Predict Position

  // Predict Velocity
  float predictednadevel[3];
  ScaleVector(clientvelocity, 1.25);

  for (int i=0; i < 3; i++) {
    predictednadevel[i] = clientfwd[i]*675.0 + clientvelocity[i];
  }
  // PM_MessageToAll("{PURPLE}predicted nadevelocity: [%.32f, %.32f, %.32f]", predictednadevel[0], predictednadevel[1], predictednadevel[2]);

  // Predict Velocity

  // Spawn Grenade
  int grenadeTest = CreateEntityByName("smokegrenade_projectile");
  if (grenadeTest > 0) {
    if (DispatchSpawn(grenadeTest)) {
      DispatchKeyValue(grenadeTest, "globalname", "custom");
      AcceptEntityInput(grenadeTest, "InitializeSpawnFromWorld");
      AcceptEntityInput(grenadeTest, "FireUser1", client);
      SetEntProp(grenadeTest, Prop_Send, "m_iTeamNum", GetClientTeam(client));
      SetEntPropEnt(grenadeTest, Prop_Send, "m_hOwnerEntity", client);
      SetEntPropVector(grenadeTest, Prop_Data, "m_vecVelocity", predictednadevel);
      SetEntPropVector(grenadeTest, Prop_Send, "m_vInitialVelocity", predictednadevel);
      SetEntPropFloat(grenadeTest, Prop_Data, "m_flGravity", 0.4);
      SetEntPropFloat(grenadeTest, Prop_Data, "m_flFriction", 0.2);
      SetEntPropFloat(grenadeTest, Prop_Data, "m_flDamage", 100.0);
      SetEntPropFloat(grenadeTest, Prop_Data, "m_flElasticity", 0.45);
      SetEntPropEnt(grenadeTest, Prop_Send, "m_hThrower", client);
      float angVelocity[3];
      angVelocity[0] = 600.0;
      angVelocity[1] = GetRandomFloat(-1200.0, 1200.0);
      angVelocity[2] = 0.0;
      SetEntPropVector(grenadeTest, Prop_Data, "m_vecAngVelocity", angVelocity);
      SetEntProp(grenadeTest, Prop_Send, "m_nSmokeEffectTickBegin", 0);
      SetEntProp(grenadeTest, Prop_Data, "m_CollisionGroup", 14); //COLLISION_GROUP_PROJECTILE
      TeleportEntity(grenadeTest, predictednadepos, NULL_VECTOR, predictednadevel);
    }
  }
}

Action FUNCION_CACACACA(int client, int args) {
  // ArrayList endpositions = new ArrayList(3);
  // float clientOrigin[3], customAngles[3], endpos[3];
  // GetClientAbsOrigin(client, clientOrigin);
  // for (float x=0.0; x<=0.5; x+=0.01) {
  //   customAngles[0] = x;
  //   for (float y=0.0; y<=0.5; y+=0.01) {
  //     customAngles[1] = y;
  //     CreateTrajectory(client, "weapon_smokegrenade", Grenade_PredictMode_Normal, false, endpos, _, customAngles, _, false);
  //     endpositions.PushArray(endpos, sizeof(endpos));
  //   }
  // }
  // // for (int i=0; i < endpositions.Length; i++) {
  // //   endpositions.GetArray(i, endpos, sizeof(endpos));
  // //   PrintToChatAll("position found: [%.2f, %.2f, %.2f]", endpos[0], endpos[1], endpos[2]);
  // // }
  // endpositions.Clear();
  // delete endpositions;

  // return Plugin_Handled;
  bool jumpthrow = false;
  char arg[128];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    if (StrEqual(arg, "jumpthrow")) {
      jumpthrow = true;
    }
  }
  bool crouching = !!(GetEntityFlags(client) & FL_DUCKING);
  float clienteyepos[3], clienteyeang[3];
  GetClientEyePosition(client, clienteyepos);
  GetClientEyeAngles(client, clienteyeang);
  float timer_start = GetEngineTime();
  float customAngles[3];
  
  for (float x=0.0; x<=0.1; x+=0.01) {
    customAngles[0] = x;
    for (float y=0.0; y<=0.1; y+=0.01) {
      customAngles[1] = y;
      Dev_SpawnGrenade(client, jumpthrow, crouching, clienteyepos, customAngles);
    }
  }
  timer_start = GetEngineTime() - timer_start;
  PrintToChatAll("total time: %f", timer_start);
  return Plugin_Handled;
}