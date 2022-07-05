#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <smlib>
#include <botmimic>
#include <dhooks>
#include "practicemode/util.sp"
#include <practicemode>

#include "botmimic/globals.sp"
#include "botmimic/utils.sp"
#include "botmimic/forwards.sp"
#include "botmimic/natives.sp"

#undef REQUIRE_EXTENSIONS
#pragma newdecls required

public Plugin myinfo = {
  name = "Bot Mimic",
  author = "Jannik \"Peace-Maker\" Hartung",
  description = "Bots mimic your movements!",
  version = PLUGIN_VERSION,
  url = "http://www.wcfan.de/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  RegPluginLibrary("botmimic");

  CreateNative("BotMimic_StartRecording", Native_StartRecording);
  CreateNative("BotMimic_StopRecording", Native_StopRecording);
  CreateNative("BotMimic_IsPlayerRecording", Native_IsPlayerRecording);
  CreateNative("BotMimic_ResumeRecording", Native_ResumeRecording);
  CreateNative("BotMimic_PauseRecording", Native_PauseRecording);
  CreateNative("BotMimic_IsRecordingPaused", Native_IsRecordingPaused);
  CreateNative("BotMimic_DeleteRecord", Native_DeleteRecord);
  CreateNative("BotMimic_PlayRecordFromFile", Native_PlayRecordFromFile);
  CreateNative("BotMimic_PlayRecordByName", Native_PlayRecordByName); // useless
  CreateNative("BotMimic_IsBotMimicing", Native_IsBotMimicing);
  CreateNative("BotMimic_ResetMimic", Native_ResetMimic);
  CreateNative("BotMimic_StopBotMimicing", Native_StopBotMimicing);
  CreateNative("BotMimic_GetMimicFileFromBot", Native_GetMimicFileFromBot);
  CreateNative("BotMimic_GetFileHeaders", Native_GetFileHeaders);
  CreateNative("BotMimic_ChangeBotNameFromFile", Native_ChangeBotNameFromFile);
  CreateNative("BotMimic_GetGameMode", Native_GetGameMode);
  CreateNative("BotMimic_GetVersusModeReactionTime", Native_GetVersusModeReactionTime);
  CreateNative("BotMimic_GetVersusModeMoveDistance", Native_GetVersusModeMoveDistance);
  CreateNative("BotMimic_GetLoadedRecordList", Native_GetLoadedRecordList);
  CreateNative("BotMimic_GetLoadedRecordCategoryList", Native_GetLoadedRecordCategoryList);
  CreateNative("BotMimic_GetFileCategory", Native_GetFileCategory);

  g_OnPlayerStarsRecordingForward = CreateGlobalForward("BotMimic_OnPlayerStartsRecording", ET_Hook, Param_Cell, Param_String, Param_String, Param_String, Param_String);
  g_OnPlayerStopsRecordingForward = CreateGlobalForward("BotMimic_OnPlayerStopsRecording", ET_Hook, Param_Cell, Param_String, Param_String, Param_String, Param_String, Param_CellByRef);
  g_hfwdOnRecordingPauseStateChanged = CreateGlobalForward("BotMimic_OnRecordingPauseStateChanged", ET_Ignore, Param_Cell, Param_Cell);
  g_OnRecordSavedForward = CreateGlobalForward("BotMimic_OnRecordSaved", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String, Param_String);
  g_OnRecordDeletedForward = CreateGlobalForward("BotMimic_OnRecordDeleted", ET_Ignore, Param_String, Param_String, Param_String);
  g_OnBotStartsMimicForward = CreateGlobalForward("BotMimic_OnBotStartsMimic", ET_Hook, Param_Cell, Param_String, Param_String, Param_String);
  g_OnBotMimicLoopsForward = CreateGlobalForward("BotMimic_OnBotMimicLoops", ET_Hook, Param_Cell);
  g_OnBotStopsMimicForward = CreateGlobalForward("BotMimic_OnBotStopsMimic", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String);

  return APLRes_Success;
}

public void OnPluginStart() {
  Handle hGameConfig = LoadGameConfigFile("practicemode.games");
  if (hGameConfig == INVALID_HANDLE)
    SetFailState("Failed to find practicemode.games game config.");

  if(!(g_pVersusModeTheBots = GameConfGetAddress(hGameConfig, "TheBots")))
		SetFailState("Failed to get TheBots address.");

  // CCSBot::MoveTo
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::MoveTo");
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer); // Move Position As Vector, Pointer
  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // Move Type As Integer
  if ((g_hVersusModeMoveTo = EndPrepSDKCall()) == INVALID_HANDLE)
    SetFailState("Failed to create SDKCall for CCSBot::MoveTo signature!");

  // CBotManager::IsLineBlockedBySmoke
  StartPrepSDKCall(SDKCall_Raw);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBotManager::IsLineBlockedBySmoke");
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
  PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
  if ((g_hVersusModeIsLineBlockedBySmoke = EndPrepSDKCall()) == INVALID_HANDLE)
    SetFailState("Failed to create SDKCall for CBotManager::IsLineBlockedBySmoke offset!");

  CreateConVar("sm_botmimic_version", PLUGIN_VERSION, "Bot Mimic version", FCVAR_NOTIFY|FCVAR_DONTRECORD);

  // Save the position of clients every 10000 ticks
  // This is to avoid bots getting stuck in walls due to slightly lower jumps, if they don't touch the ground.
  g_iServerTickRate = RoundFloat(1/GetTickInterval());
  AutoExecConfig();

  // Maps path to .rec -> record enum
  g_hLoadedRecords = new StringMap();

  // Maps path to .rec -> record category
  g_hLoadedRecordsCategory = new StringMap();

  // Save all paths to .rec files in the trie sorted by time
  g_hSortedRecordList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
  g_hSortedCategoryList = new ArrayList(ByteCountToCells(64));

  g_VersusMode_AttackTimeCvar = CreateConVar("sm_botmimic_attack_time", "30",
                              "How much ticks until bot stops shooting.", 0, true, 0.0, true, 100.0);
  // g_VersusMode_SpotMultCvar = CreateConVar("sm_botmimic_spot_mult", "1.1",
  //                             "Only for testing purposes.", 0, true, 1.0, true, 2.0);

  HookEvent("player_spawn", Event_OnPlayerSpawn);
  HookEvent("player_death", Event_OnPlayerDeath);

  if (g_hTeleport == null) {
    // Optionally setup a hook on CBaseEntity::Teleport to keep track of sudden place changes
    Handle hGameData = LoadGameConfigFile("sdktools.games");
    if (hGameData == null)
      return;
    int iOffset = GameConfGetOffset(hGameData, "Teleport");
    delete hGameData;
    if (iOffset == -1)
      return;
    
    g_hTeleport = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHooks_OnTeleport);
    if (g_hTeleport == null)
      return;
    DHookAddParam(g_hTeleport, HookParamType_VectorPtr);
    DHookAddParam(g_hTeleport, HookParamType_ObjectPtr);
    DHookAddParam(g_hTeleport, HookParamType_VectorPtr);
    if (GetEngineVersion() == Engine_CSGO)
      DHookAddParam(g_hTeleport, HookParamType_Bool);
    
    for(int i=1;i<=MaxClients;i++) {
      if (IsClientInGame(i))
        OnClientPutInServer(i);
    }
  }
}

public void Record_RunCmd(int client, int buttons, const float angles[3], int weapon) {
  // Client is recording and recording is not paused.
  if (g_hRecording[client] == null || g_bRecordingPaused[client]) {
    return;
  }

  // Save frame info
  S_FrameInfo iFrame;
  iFrame.PlayerButtons = buttons;
  GetClientAbsOrigin(client, iFrame.PlayerOrigin);
  iFrame.PlayerAngles = angles;
  Entity_GetAbsVelocity(client, iFrame.PlayerVelocity);
  // iFrame.ExtraData = 0; // by default its 0

  // EXTRA_PLAYERDATA_HEALTH
  int health = GetClientHealth(client);
  if (g_iRecordPreviousExtraFrame[client].Health != health || g_iRecordedTicks[client] == 0) {
    iFrame.Health = health;
    iFrame.ExtraData |= EXTRA_PLAYERDATA_HEALTH;
    g_iRecordPreviousExtraFrame[client].Health = iFrame.Health;
  }
  // EXTRA_PLAYERDATA_HELMET
  bool helmet = !!GetEntProp(client, Prop_Send, "m_bHasHelmet");
  if (g_iRecordPreviousExtraFrame[client].Helmet != helmet || g_iRecordedTicks[client] == 0) {
    iFrame.Helmet = helmet;
    iFrame.ExtraData |= EXTRA_PLAYERDATA_HELMET;
    g_iRecordPreviousExtraFrame[client].Helmet = iFrame.Helmet;
  }
  // EXTRA_PLAYERDATA_ARMOR
  int armor = GetClientArmor(client);
  if (g_iRecordPreviousExtraFrame[client].Armor != armor || g_iRecordedTicks[client] == 0) {
    iFrame.Armor = armor;
    iFrame.ExtraData |= EXTRA_PLAYERDATA_ARMOR;
    g_iRecordPreviousExtraFrame[client].Armor = iFrame.Armor;
  }
  // EXTRA_PLAYERDATA_ON_GROUND
  bool onGround = !!(GetEntityFlags(client) & FL_ONGROUND);
  if (g_iRecordPreviousExtraFrame[client].OnGround != onGround || g_iRecordedTicks[client] == 0) {
    iFrame.OnGround = onGround;
    iFrame.ExtraData |= EXTRA_PLAYERDATA_ON_GROUND;
    g_iRecordPreviousExtraFrame[client].OnGround = iFrame.OnGround;
  }
  // EXTRA_PLAYERDATA_GRENADE
    // Handled in ThrowGrenade
  // EXTRA_PLAYERDATA_INVENTORY
    // TODO
  // EXTRA_PLAYERDATA_EQUIPWEAPON
  int currentWeaponEnt = weapon ? weapon : Client_GetActiveWeapon(client);
  if (currentWeaponEnt > 0) {
    CSWeaponID iWeaponId = CS_ItemDefIndexToID(GetEntProp(currentWeaponEnt, Prop_Send, "m_iItemDefinitionIndex"));
    if (g_iRecordPreviousExtraFrame[client].ActiveWeapon != iWeaponId || g_iRecordedTicks[client] == 0) {
      iFrame.ActiveWeapon = iWeaponId;
      iFrame.ExtraData |= EXTRA_PLAYERDATA_EQUIPWEAPON;
      g_iRecordPreviousExtraFrame[client].ActiveWeapon = iFrame.ActiveWeapon;
    }
  }
  // EXTRA_PLAYERDATA_MONEY
  int money = Client_GetMoney(client);
  if (g_iRecordPreviousExtraFrame[client].Money != money || g_iRecordedTicks[client] == 0) {
    iFrame.Money = money;
    iFrame.ExtraData |= EXTRA_PLAYERDATA_MONEY;
    g_iRecordPreviousExtraFrame[client].Money = iFrame.Money;
  }
  // EXTRA_PLAYERDATA_CHAT
    // TODO

  g_hRecording[client].PushArray(iFrame, sizeof(iFrame));
  g_iRecordedTicks[client]++;

  // // FIX: store origin?
  // if (g_hRecordingSizeLimit[client] > 0) {
  //   if (g_hRecording[client].Length > g_hRecordingSizeLimit[client]) {
  //     // Option 1 -> FIX: store origin?
  //     // S_FrameInfo newFirstFrame;
  //     // g_hRecording[client].GetArray(0, newFirstFrame, sizeof(newFirstFrame));
  //     // g_fInitialAngles[client] = newFirstFrame.predictedAngles;
  //     // g_hRecording[client].Erase(0);
  //     // g_iRecordedTicks[client]--;
  //     // Option 2 -> Start Again
  //     GetClientEyeAngles(client, g_fInitialAngles[client]);
  //     GetClientAbsOrigin(client, g_fInitialPosition[client]);
  //     g_hRecording[client].Clear();
  //     g_iRecordedTicks[client] = 0;
  //   }
  // }
}

/**
 * 
 * @param client      client
 * @param buttons     buttons
 * @param angles      angles
 * @param vel         vel
 * @param weapon      weapon
 * @return            Action
 * 
 * Plugin_Handled = stop
 * 
 * Plugin_Changed = Handled by Bot/AI, stop
 *
 * Plugin_Continue = Continue
 */
public Action Versus_RunCmd(int client, int &buttons, float angles[3], float vel[3], int &weapon) {
  // Sees player -> saves current position as "POS1" -> turns into bot that crouches and strafes randomly
  // stops seeing player/kills player -> hold that position (random seconds)?
  // stopped holding position -> ai navmesh Move To "POS1"
  // Gets to "POS1" -> continues replay
  // Replay finishes -> Handled by actual bot AI
  int currentTarget = -1;
  float nearestDist = -1.0;
  bool HoldingWeapon = true;
  if (g_iBotActiveWeapon[client] != INVALID_ENT_REFERENCE) {
    char sAlias[64];
    Entity_GetClassName(g_iBotActiveWeapon[client], sAlias, sizeof(sAlias));
    if (StrContains(sAlias, "grenade") != -1
    || StrContains(sAlias, "flashbang") != -1
    || StrContains(sAlias, "knife") != -1
    || StrContains(sAlias, "decoy") != -1
    || StrContains(sAlias, "molotov") != -1) {
      HoldingWeapon = false;
    }
  }
  
  if (GetEntityFlags(client) & FL_ONGROUND && HoldingWeapon && GetFlashDuration(client) < 2.0) {
    for (int i = 0; i < MaxClients; i++) {
      int target = i;
      if (IsPlayer(target)) {
        if (!IsPlayerAlive(target)) {
          continue;
        }
        if (GetClientTeam(target) == GetClientTeam(client)) {
          continue;
        }
        float clientVec[3], targetVec[3];
        GetClientEyePosition(client, clientVec);
        GetClientEyePosition(target, targetVec);
        float Dist = GetVectorDistance(clientVec, targetVec);
        if (LineGoesThroughSmoke(clientVec, targetVec)) {
          continue;
        }
        if (Dist > nearestDist && nearestDist > -1.0) {
          continue;
        }
        if (!IsAbleToSee(client, target, 0.9)) {
          continue;
        }
        nearestDist = Dist;
        currentTarget = target;
        break;
      }
    }
  }

  if (currentTarget > 0) {
    g_VersusModeHandledByAi[client] = false;
    g_VersusModeAiStarted[client] = false;
    float clientEyepos[3], viewTarget[3];
    GetClientEyePosition(client, clientEyepos);
    GetClientEyePosition(currentTarget, viewTarget);
    viewTarget[2] -= 5.0;
    SubtractVectors(viewTarget, clientEyepos, viewTarget);
    GetVectorAngles(viewTarget, viewTarget);
    TeleportEntity(client, NULL_VECTOR, viewTarget, NULL_VECTOR);
    // Strafe movement perpendicular to player->bot vector
    if (g_VersusMode_Time[client] >= g_VersusMode_ReactTime &&
        g_VersusMode_Time[client] <= (g_VersusMode_ReactTime+g_VersusMode_AttackTimeCvar.IntValue)) { // bot will attack for (2 + 1) frames
      vel[1] = 0.0;
      buttons |= IN_ATTACK;
      // buttons &= ~IN_SPEED;
      if (g_VersusMode_Time[client] == (g_VersusMode_ReactTime+g_VersusMode_AttackTimeCvar.IntValue)) {
        g_VersusMode_Duck[client] = !!GetRandomInt(0, 1);
        g_VersusMode_Time[client] = 0;
      }
      else g_VersusMode_Time[client]++;
    } else {
      buttons &= ~IN_ATTACK;
      buttons &= ~IN_DUCK;
      // buttons &= ~IN_SPEED;
      if (g_VersusMode_Time[client] == g_VersusMode_ReactTime - g_VersusMode_MoveDistance) { // the bot will be moving RKBOT_MOVEDISTANCE frames
        g_VersusMode_MoveRight[client] = !!GetRandomInt(0, 1);
        g_VersusMode_Duck[client] = !!GetRandomInt(0, 1);
        // g_RetakeBotWalk[client] = GetRandomInt(0, 1);
      } else {
        if (g_VersusMode_Time[client] > g_VersusMode_ReactTime - g_VersusMode_MoveDistance) { // while the bot is moving
          if (g_VersusMode_MoveRight[client]) vel[1] = 250.0;
          else vel[1] = -250.0;
          if (g_VersusMode_Duck[client]) buttons |= IN_DUCK;

          // if (g_RetakeBotWalk[client]) buttons |= IN_SPEED;
          if (g_VersusMode_Time[client] == g_VersusMode_ReactTime - g_VersusMode_MoveDistance + 5) { // just after the bot started moving to check if IS STUCK
            float fAbsVel[3];
            Entity_GetAbsVelocity(client, fAbsVel);
            if (GetVectorLength(fAbsVel) < 5.0) {
              // Jump to Attack Time ?
              // g_VersusMode_Time[client] = g_VersusMode_ReactTime;
              g_VersusMode_MoveRight[client] = !g_VersusMode_MoveRight[client];
            }
          }
        }
      }
      g_VersusMode_Time[client]++;
    }
    return Plugin_Changed;
  } else {
    // If it even has mimiced before
    if (g_VersusMode_Time[client] > -1) {
      g_VersusMode_Time[client] = 0;
      // check if its in the correct position, if not send him there
      float currentPosition[3];
      GetClientAbsOrigin(client, currentPosition);
      float vec1[3], vec2[3], zDiff;
      vec1 = currentPosition;
      vec1[2] = 0.0;
      vec2 = g_VersusModeLastMimicPosition[client];
      vec2[2] = 0.0;
      zDiff = FloatAbs(currentPosition[2]-g_VersusModeLastMimicPosition[client][2]);
      float distance = GetVectorDistance(vec1, vec2); //, true?
      if (distance <= VersusMode_MaxPositionDiff && zDiff <= 80) {
        g_VersusModeHandledByAi[client] = false;
      } else {
        if (distance > 500.0) {
          BotMimic_StopBotMimicing(client);
          return Plugin_Handled;
        }
        g_VersusModeHandledByAi[client] = true;
      }
    }
  }

  if (g_VersusModeHandledByAi[client]) {
    if (!g_VersusModeAiStarted[client]) {
      // Bot started to being handle by AI
      g_VersusModeAiStarted[client] = true;
      g_VersusModeAiStartedTime[client] = GetGameTime();
      BotMoveTo(client, g_VersusModeLastMimicPosition[client], FASTEST_ROUTE);
    }
    if (g_VersusModeAiStarted[client]) {
      // Bot is being handled by AI
      float currentPosition[3];
      GetClientAbsOrigin(client, currentPosition);
      float vec1[3], vec2[3], zDiff;
      vec1 = currentPosition;
      vec1[2] = 0.0;
      vec2 = g_VersusModeLastMimicPosition[client];
      vec2[2] = 0.0;
      zDiff = FloatAbs(currentPosition[2]-g_VersusModeLastMimicPosition[client][2]);
      float distance = GetVectorDistance(vec1, vec2); //, true?
      if (distance <= VersusMode_MaxPositionDiff && zDiff <= 80) { // Entity_GetAbsVelocity(client, currentVelocity); also?
        // Reached Expected Point
        g_VersusModeHandledByAi[client] = false;
        g_VersusModeAiStarted[client] = false;
      } else {
        // Bot should still be moving towards last mimic pos
        float currentTime = GetGameTime();
        if (currentTime-g_VersusModeAiStartedTime[client] > 5.0) {
          // Force Move Again
          g_VersusModeAiStartedTime[client] = currentTime;
          BotMoveTo(client, g_VersusModeLastMimicPosition[client], FASTEST_ROUTE);
        }
        return Plugin_Changed;
      }
    }
  }
  return Plugin_Continue;
}

public Action Mimic_RunCmd(int client, int &buttons, float angles[3], float vel[3], int &weapon) {
  // Is Bot mimicing something ?
  if (g_hBotMimicsRecord[client] == null) {
    return Plugin_Continue;
  }

  // Is this a valid living bot?
  if (!IsPlayerAlive(client) || GetClientTeam(client) <= CS_TEAM_SPECTATOR) {
    return Plugin_Continue;
  }

  if (g_iBotMimicTick[client] >= g_iBotMimicRecordTickCount[client]) {
    // Reset Mimic
    g_iBotMimicTick[client] = 0;
    Action result;
    Call_StartForward(g_OnBotMimicLoopsForward);
    Call_PushCell(client);
    Call_Finish(result);

    // Someone doesn't want this guy to loop this mimic.
    if (result >= Plugin_Handled) {
      BotMimic_StopBotMimicing(client);
      return Plugin_Continue;
    }
  }
  
  S_FrameInfo iFrame;
  g_hBotMimicsRecord[client].GetArray(g_iBotMimicTick[client], iFrame, sizeof(iFrame));

  g_bValidTeleportCall[client] = true;
  // For each frame

  buttons = iFrame.PlayerButtons;
  // vel = iFrame.PlayerVelocity;
  angles = iFrame.PlayerAngles;
  if (g_iBotMimicTick[client] == 0) {
    // This is the first tick. Teleport him to the initial position
    buttons = iFrame.PlayerButtons & ~IN_ATTACK; // Prevent it from attacking in spawn
    TeleportEntity(client, g_fInitialPosition[client], g_fInitialAngles[client], ZERO_VECTOR); //iFrame.PlayerVelocity
    if (g_bBotWaitingDelay[client]) {
      return Plugin_Continue;
    }
    // Strip Weapons
    /* void CSGO_StripAllWeapons(int client) {
      int weapon;
      for (int i = 0; i < 3; i++)
      {
        if ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
        {
          if (GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") != client)
            SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);

          SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
          AcceptEntityInput(weapon, "Kill");
        }
      }
    } */
    // (FIX|REPLACE) CSGO_StripAllWeapons
    // Client_RemoveAllWeapons(client);
  }
  if (g_BotMimic_GameMode == BM_GameMode_Versus) {
    Action result = Versus_RunCmd(client, buttons, angles, vel, weapon);
    if (result > Plugin_Continue) {
      return Plugin_Changed;
    }
  }

  float curPos[3], predVel[3];
  GetClientAbsOrigin(client, curPos);
  MakeVectorFromPoints(curPos, iFrame.PlayerOrigin, predVel);
  ScaleVector(predVel, float(g_iServerTickRate));
  float flSpeed = GetVectorLength(predVel);
  if (flSpeed > 4000) {
    TeleportEntity(client, iFrame.PlayerOrigin, iFrame.PlayerAngles, NULL_VECTOR);
  } else {
    TeleportEntity(client, NULL_VECTOR, iFrame.PlayerAngles, predVel);
  }

  if (g_iBotMimicRecordRunCount[client] == 0) {
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_HEALTH) {
      SetEntityHealth(client, iFrame.Health);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_HELMET) {
      SetEntProp(client, Prop_Send, "m_bHasHelmet", iFrame.Helmet);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_ARMOR) {
      SetEntProp(client, Prop_Data, "m_ArmorValue", iFrame.Armor);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_ON_GROUND) {
      SetEntityFlags(client, GetEntityFlags(client) | FL_ONGROUND);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_GRENADE) {
      GrenadeType grenadeType;
      switch (iFrame.GrenadeType) {
        case 501:
          grenadeType = GrenadeType_Decoy;
        case 502:
          grenadeType = GrenadeType_Molotov;
        case 503:
          grenadeType = GrenadeType_Incendiary;
        case 504:
          grenadeType = GrenadeType_Flash;
        case 505:
          grenadeType = GrenadeType_Smoke;
        case 506:
          grenadeType = GrenadeType_HE;
      }
      PM_ThrowGrenade(client, grenadeType, iFrame.GrenadeStartPos, iFrame.GrenadeStartVel);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_EQUIPWEAPON) {
      if (iFrame.ActiveWeapon != CSWeapon_NONE) {
        // new weapon, equip it
        int currentWeapon = ClientGetWeapon(client, iFrame.ActiveWeapon);
        if (currentWeapon != INVALID_ENT_REFERENCE) {
          weapon = currentWeapon;
          g_iBotActiveWeapon[client] = weapon;
          g_bBotSwitchedWeapon[client] = true;
        } else {
          char sAlias[64];
          CS_WeaponIDToAlias(iFrame.ActiveWeapon, sAlias, sizeof(sAlias));
          Format(sAlias, sizeof(sAlias), "weapon_%s", sAlias);
          // Bot doesnt have Weapon, Give It
          weapon = GivePlayerItem(client, sAlias);
          if (weapon != INVALID_ENT_REFERENCE) {
            g_iBotActiveWeapon[client] = weapon;
            g_bBotSwitchedWeapon[client] = true;
            // // Grenades shouldn't be equipped.
            // // Otherwise Bot Drops Them Immediatly and doesnt "throw them"
            // // The throw is handled By practicemode
            if (StrContains(sAlias, "grenade") == -1 
            && StrContains(sAlias, "flashbang") == -1 
            && StrContains(sAlias, "decoy") == -1 
            && StrContains(sAlias, "molotov") == -1) {
              EquipPlayerWeapon(client, weapon);
            }
          }
        }
      } else if (g_bBotSwitchedWeapon[client]) {
        // Switch the weapon on the next frame after it was selected.
        g_bBotSwitchedWeapon[client] = false;
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", g_iBotActiveWeapon[client]);
        Client_SetActiveWeapon(client, g_iBotActiveWeapon[client]);
      }
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_MONEY) {
      SetEntProp(client, Prop_Send, "m_iAccount", iFrame.Money);
    }
  }

  g_iBotMimicRecordRunCount[client]++;
  if (g_iBotMimicRecordRunCount[client] >= (g_iServerTickRate/g_iBotMimicRecordTickRate[client])) {
    g_iBotMimicRecordRunCount[client] = 0;
    g_iBotMimicTick[client]++;
  }

  return Plugin_Changed;
}

/* Timer Callbacks */
public Action Timer_DelayedRespawn(Handle timer, any userid) {
  int client = GetClientOfUserId(userid);
  if (!IsValidClient(client))
    return Plugin_Stop;

  if (g_hBotMimicsRecord[client] != null && IsClientInGame(client) && !IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) >= CS_TEAM_T)
    CS_RespawnPlayer(client);

  return Plugin_Stop;
}

// caca
public Action Hook_WeaponCanSwitchTo(int client, int weapon) {
  if (g_hBotMimicsRecord[client] == null)
    return Plugin_Continue;

  if (g_iBotActiveWeapon[client] != weapon) {
    return Plugin_Stop;
  }
  return Plugin_Continue;
}

public MRESReturn DHooks_OnTeleport(int client, Handle hParams) {
  // This one is currently mimicing something.
  if (g_hBotMimicsRecord[client] != null) {
    // We didn't allow that teleporting. STOP THAT.
    if (!g_bValidTeleportCall[client])
      return MRES_Supercede;
    g_bValidTeleportCall[client] = false;
    return MRES_Ignored;
  }

  // Don't care if he's not recording.
  if (g_hRecording[client] == null)
    return MRES_Ignored;

  float origin[3], angles[3], velocity[3];
  bool bOriginNull = DHookIsNullParam(hParams, 1);
  bool bAnglesNull = DHookIsNullParam(hParams, 2);
  bool bVelocityNull = DHookIsNullParam(hParams, 3);

  if (!bOriginNull)
    DHookGetParamVector(hParams, 1, origin);

  if (!bAnglesNull) {
    for(int i=0;i<3;i++)
      angles[i] = DHookGetParamObjectPtrVar(hParams, 2, i*4, ObjectValueType_Float);
  }

  if (!bVelocityNull)
    DHookGetParamVector(hParams, 3, velocity);

  if (bOriginNull && bAnglesNull && bVelocityNull)
    return MRES_Ignored;

  return MRES_Ignored;
}

/**
 * @param sPath Parent Directory.
 * @param sCategory
 * @param subdir used in the recursion
 * Do LoadRecordFromFile for all files inside sPath and sub-directories
 */
void ParseRecordsInDirectory(const char[] sPath, const char[] sCategory, bool subdir) {
  char sMapFilePath[PLATFORM_MAX_PATH];
  // We already are in the map folder? Don't add it again!
  if (subdir) {
    strcopy(sMapFilePath, sizeof(sMapFilePath), sPath);
  }
  // We're in a category. add the mapname to load the correct records for the current map
  else
  {
    char sMapName[64];
    GetCurrentMap(sMapName, sizeof(sMapName));
    Format(sMapFilePath, sizeof(sMapFilePath), "%s/%s", sPath, sMapName);
  }

  DirectoryListing hDir = OpenDirectory(sMapFilePath);
  if (hDir == null)
    return;

  char sFile[64], sFilePath[PLATFORM_MAX_PATH];
  FileType fileType;
  S_FileData rawFileData;
  while(hDir.GetNext(sFile, sizeof(sFile), fileType)) {
    switch(fileType) {
      // This is a record for this map.
      case FileType_File:
      {
        Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
        LoadRecordFromFile(sFilePath, sCategory, rawFileData, true, false);
      }
      // There's a subdir containing more records.
      case FileType_Directory:
      {
        // INFINITE RECURSION ANYONE?
        if (StrEqual(sFile, ".") || StrEqual(sFile, ".."))
          continue;
        
        Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
        ParseRecordsInDirectory(sFilePath, sCategory, true);
      }
    }
    
  }
  delete hDir;
}

/**
 * @param sPath The file be created here.
 * @param sCategory Unknown.
 * @param headerInfo All the data from file will go here.
 * @param onlyHeader If true, ignore frames.
 * @param forceReload If true, update g_hLoadedRecords.
 * Return ref from g_hLoadedRecords if file is loaded, else load File from sPath.
 */
BMError LoadRecordFromFile(const char[] sPath, const char[] sCategory, S_FileData headerInfo, bool onlyHeader, bool forceReload) {
  if (!FileExists(sPath))
    return BM_FileNotFound;

  // Make sure the handle references are null in the input structure.
  headerInfo.frames = null;

  // Already loaded that file?
  bool bAlreadyLoaded = false;
  if (g_hLoadedRecords.GetArray(sPath, headerInfo, sizeof(headerInfo))) {
    // Header already loaded.
    if (onlyHeader && !forceReload)
      return BM_NoError;
    
    bAlreadyLoaded = true;
  }

  File hFile = OpenFile(sPath, "rb");
  if (hFile == null)
    return BM_FileNotFound;

  int iMagic;
  hFile.ReadInt32(iMagic);
  // PrintToChatAll("read iMagic %d, original magic: %d", iMagic, BM_MAGIC);
  if (iMagic != BM_MAGIC) {
    delete hFile;
    return BM_BadFile;
  }

  int iBinaryFormatVersion;
  hFile.ReadUint8(iBinaryFormatVersion);
  // PrintToChatAll("read iBinaryFormatVersion %d", iBinaryFormatVersion);
  headerInfo.binaryFormatVersion = iBinaryFormatVersion;

  if (iBinaryFormatVersion != BINARY_FORMAT_VERSION) {
    delete hFile;
    return BM_NewerBinaryVersion;
  }

  int iRecordTime, iNameLength;
  hFile.ReadInt32(iRecordTime);
  // PrintToChatAll("file iRecordTime %d", iRecordTime);
  hFile.ReadUint8(iNameLength);
  // PrintToChatAll("file iNameLength %d", iNameLength);
  char[] sRecordName = new char[iNameLength+1];
  hFile.ReadString(sRecordName, iNameLength+1, iNameLength);
  // PrintToChatAll("file sRecordName %s", sRecordName);
  sRecordName[iNameLength] = '\0';

  hFile.Read(view_as<int>(headerInfo.playerSpawnPos), 3, 4);
  // PrintToChatAll("file headerInfo.playerSpawnPos %f %f %f", headerInfo.playerSpawnPos[0], headerInfo.playerSpawnPos[1], headerInfo.playerSpawnPos[2]);
  hFile.Read(view_as<int>(headerInfo.playerSpawnAng), 2, 4);
  // PrintToChatAll("file headerInfo.playerSpawnPos %f %f", headerInfo.playerSpawnAng[0], headerInfo.playerSpawnAng[1]);

  int iTickCount;
  hFile.ReadInt32(iTickCount);
  // PrintToChatAll("file iTickCount %d", iTickCount);

  int iTickRate;
  if (iBinaryFormatVersion >= 0x03) {
    hFile.ReadInt32(iTickRate);
  } else {
    iTickRate = g_iServerTickRate;
  }
  // PrintToChatAll("file iTickRate %d", iTickRate);

  headerInfo.recordEndTime = iRecordTime;
  strcopy(headerInfo.playerName, MAX_RECORD_NAME_LENGTH, sRecordName);
  headerInfo.tickCount = iTickCount;
  headerInfo.tickRate = iTickRate;

  delete headerInfo.frames;

  //PrintToServer("Record %s:", sRecordName);
  //PrintToServer("File %s:", sPath);
  //PrintToServer("EndTime: %d, BinaryVersion: 0x%x, ticks: %d, initialPosition: %f,%f,%f, initialAngles: %f,%f,%f", iRecordTime, iBinaryFormatVersion, iTickCount, headerInfo.playerSpawnPos[0], headerInfo.playerSpawnPos[1], headerInfo.playerSpawnPos[2], headerInfo.playerSpawnAng[0], headerInfo.playerSpawnAng[1], headerInfo.playerSpawnAng[2]);

  g_hLoadedRecords.SetArray(sPath, headerInfo, sizeof(headerInfo));
  g_hLoadedRecordsCategory.SetString(sPath, sCategory);

  if (!bAlreadyLoaded)
    g_hSortedRecordList.PushString(sPath);

  if (g_hSortedCategoryList.FindString(sCategory) == -1)
    g_hSortedCategoryList.PushString(sCategory);

  // Sort it by record end time
  SortRecordList();

  if (onlyHeader) {
    delete hFile;
    return BM_NoError;
  }

  // Read in all the saved frames
  ArrayList hRecordFrames = new ArrayList(sizeof(S_FrameInfo));

  S_FrameInfo iFrame;
  for (int i=0;i<iTickCount;i++) {
    hFile.ReadInt32(iFrame.PlayerButtons);
    hFile.Read(view_as<int>(iFrame.PlayerOrigin), 3, 4);
    hFile.Read(view_as<int>(iFrame.PlayerAngles), 3, 4);
    hFile.Read(view_as<int>(iFrame.PlayerVelocity), 3, 4);
    hFile.ReadInt32(iFrame.ExtraData);
    // PrintToConsoleAll("%d. %d, [%f,%f,%f], [%f,%f], [%f,%f,%f]", i, iFrame.PlayerButtons
      // , iFrame.PlayerOrigin[0], iFrame.PlayerOrigin[1], iFrame.PlayerOrigin[2], iFrame.PlayerAngles[0], iFrame.PlayerAngles[1]
      // , iFrame.PlayerVelocity[0], iFrame.PlayerVelocity[1], iFrame.PlayerVelocity[2]);
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_HEALTH) {
      hFile.ReadInt32(iFrame.Health);
      // PrintToConsoleAll("--health %d", iFrame.Health);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_HELMET) {
      hFile.ReadInt8(iFrame.Helmet);
      // PrintToConsoleAll("--Helmet %d", iFrame.Helmet);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_ARMOR) {
      hFile.ReadInt32(iFrame.Armor);
      // PrintToConsoleAll("--Armor %d", iFrame.Armor);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_ON_GROUND) {
      hFile.ReadInt8(iFrame.OnGround);
      // PrintToConsoleAll("--OnGround %d", iFrame.OnGround);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_GRENADE) {
      hFile.ReadInt32(iFrame.GrenadeType);
      hFile.Read(view_as<int>(iFrame.GrenadeStartPos), 3, 4);
      hFile.Read(view_as<int>(iFrame.GrenadeStartVel), 3, 4);
      // PrintToConsoleAll("--GrenadeType %d", iFrame.GrenadeType);
      // PrintToConsoleAll("--GrenadeOrigin %d", iFrame.GrenadeStartPos[0], iFrame.GrenadeStartPos[1], iFrame.GrenadeStartPos[2]);
      // PrintToConsoleAll("--GrenadeVelocity %d", iFrame.GrenadeStartVel[0], iFrame.GrenadeStartVel[1], iFrame.GrenadeStartVel[2]);
    }
    // if (iFrame.ExtraData & EXTRA_PLAYERDATA_INVENTORY) {
    //   hFile.Read();
    // }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_EQUIPWEAPON) {
      hFile.ReadInt32(view_as<int>(iFrame.ActiveWeapon));
      // PrintToConsoleAll("--ActiveWeapon %d", iFrame.ActiveWeapon);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_MONEY) {
      hFile.ReadInt32(iFrame.Money);
      // PrintToConsoleAll("--Money %d", iFrame.Money);
    }
    // if (iFrame.ExtraData & EXTRA_PLAYERDATA_CHAT) {
    //   hFile.Read();
    // }
    hRecordFrames.PushArray(iFrame, sizeof(iFrame));
  }

  headerInfo.frames = hRecordFrames;

  g_hLoadedRecords.SetArray(sPath, headerInfo, sizeof(headerInfo));
  delete hFile;
  return BM_NoError;
}

/**
 * @param sPath The file be created here.
 * @param rawFileData All the data that will be saved.
 * Simple File Save
 */
void WriteRecordToDisk(const char[] sPath, S_FileData rawFileData) {
  File hFile = OpenFile(sPath, "wb");
  if (hFile == null) {
    PrintToServer("[WriteRecordToDisk]Can't open the record file for writing! (%s)", sPath);
    return;
  }

  hFile.WriteInt32(BM_MAGIC);
  hFile.WriteInt8(rawFileData.binaryFormatVersion);
  hFile.WriteInt32(rawFileData.recordEndTime);
  hFile.WriteInt8(strlen(rawFileData.playerName));
  hFile.WriteString(rawFileData.playerName, false);

  hFile.Write(view_as<int>(rawFileData.playerSpawnPos), 3, 4);
  hFile.Write(view_as<int>(rawFileData.playerSpawnAng), 2, 4);

  int iTickCount = rawFileData.tickCount;
  hFile.WriteInt32(iTickCount);

  int iTickRate = rawFileData.tickRate;
  hFile.WriteInt32(iTickRate);

  S_FrameInfo iFrame;
  for(int i=0;i<iTickCount;i++) {
    rawFileData.frames.GetArray(i, iFrame, sizeof(iFrame));
    hFile.WriteInt32(iFrame.PlayerButtons);
    hFile.Write(view_as<int>(iFrame.PlayerOrigin), 3, 4);
    hFile.Write(view_as<int>(iFrame.PlayerAngles), 3, 4);
    hFile.Write(view_as<int>(iFrame.PlayerVelocity), 3, 4);
    hFile.WriteInt32(iFrame.ExtraData);

    if (iFrame.ExtraData & EXTRA_PLAYERDATA_HEALTH) {
      hFile.WriteInt32(iFrame.Health);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_HELMET) {
      hFile.WriteInt8(iFrame.Helmet);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_ARMOR) {
      hFile.WriteInt32(iFrame.Armor);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_ON_GROUND) {
      hFile.WriteInt8(iFrame.OnGround);
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_GRENADE) {
      hFile.WriteInt32(iFrame.GrenadeType);
      hFile.Write(view_as<int>(iFrame.GrenadeStartPos), 3, 4);
      hFile.Write(view_as<int>(iFrame.GrenadeStartVel), 3, 4);
    }
    // if (iFrame.ExtraData & EXTRA_PLAYERDATA_INVENTORY) {
    //   hFile.Write();
    // }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_EQUIPWEAPON) {
      hFile.WriteInt32(view_as<int>(iFrame.ActiveWeapon));
    }
    if (iFrame.ExtraData & EXTRA_PLAYERDATA_MONEY) {
      hFile.WriteInt32(iFrame.Money);
    }
    // if (iFrame.ExtraData & EXTRA_PLAYERDATA_CHAT) {
    //   hFile.Write();
    // }
  }

  delete hFile;
}


/**
 * @param client Bot that will mimic.
 * @param sPath Mimic File.
 * @param startDelay Repeat first tick (seconds).
 * Set g_hBotMimicsRecord[client] to the frames from sPath
 */
BMError PlayRecord(int client, const char[] sPath, float startDelay) {
  // He's currently recording. Don't start to play some record on him at the same time.
  if (g_hRecording[client] != null) {
    return BM_BadClient;
  }

  S_FileData rawFileData;
  g_hLoadedRecords.GetArray(sPath, rawFileData, sizeof(rawFileData));

  // That record isn't fully loaded yet. Do that now.
  if (rawFileData.frames == null) {
    char sCategory[64];
    if (!g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory)))
      strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
    BMError error = LoadRecordFromFile(sPath, sCategory, rawFileData, false, true);
    if (error != BM_NoError)
      return error;
  }

  g_hBotMimicsRecord[client] = rawFileData.frames;
  g_iBotMimicTick[client] = 0;
  g_iBotMimicRecordTickCount[client] = rawFileData.tickCount;
  g_iBotMimicRecordTickRate[client] = rawFileData.tickRate;
  g_iBotMimicRecordRunCount[client] = 0;
  // PrintToChatAll("son g_iBotMimicRecordTickCount[client] = %d ticks ", g_iBotMimicRecordTickCount[client]);
  g_iBotActiveWeapon[client] = INVALID_ENT_REFERENCE;
  g_bBotSwitchedWeapon[client] = false;
  if (startDelay > 0.0) {
    g_bBotWaitingDelay[client] = true;
    CreateTimer(startDelay, Timer_AllowPlayRecord, GetClientSerial(client));
  }

  Array_Copy(rawFileData.playerSpawnPos, g_fInitialPosition[client], 3);
  Array_Copy(rawFileData.playerSpawnAng, g_fInitialAngles[client], 3);

  SDKHook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);

  // Respawn him to get him moving!
  if (IsClientInGame(client) && !IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_T) //cacacaca
    CS_RespawnPlayer(client);

  char sCategory[64];
  g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory));

  Action result;
  Call_StartForward(g_OnBotStartsMimicForward);
  Call_PushCell(client);
  Call_PushString(rawFileData.playerName);
  Call_PushString(sCategory);
  Call_PushString(sPath);
  Call_Finish(result);

  // Someone doesn't want this guy to play that record.
  if (result >= Plugin_Handled) {
    g_hBotMimicsRecord[client] = null;
    g_iBotMimicRecordTickCount[client] = 0;
    g_iBotMimicRecordTickRate[client] = g_iServerTickRate;
    g_iBotMimicRecordRunCount[client] = 0;
  }

  return BM_NoError;
}

Action Timer_AllowPlayRecord(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  g_bBotWaitingDelay[client] = false;
  return Plugin_Handled;
}


/**
 * @param frames The file be created here.
 * @param buffer Store the path here.
 * @param size Max size of string.
 * Get path from mimicing bot frames ref.
 */
stock void GetFileFromFrameHandle(ArrayList frames, char[] buffer, int size) {
  int iSize = g_hSortedRecordList.Length;
  char sPath[PLATFORM_MAX_PATH];
  S_FileData rawFileData;
  for(int i=0;i<iSize;i++) {
    g_hSortedRecordList.GetString(i, sPath, sizeof(sPath));
    g_hLoadedRecords.GetArray(sPath, rawFileData, sizeof(rawFileData));
    if (rawFileData.frames != frames)
      continue;
    
    strcopy(buffer, size, sPath);
    break;
  }
}
