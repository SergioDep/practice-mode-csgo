#define PLUGIN_VERSION "3.0"

#include <clientprefs> // disable
#include <cstrike>
#include <dhooks>
#include <sdkhooks>
#include <sdktools>
#include <smlib>
#include <sourcemod>
#include <vector>
#include <profiler> // disable
#include <PTaH>

#include <botmimic>
#include <navmesh>
#include <weapons>
#include <gloves>
#include <practicemode>

#undef REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

bool g_startedPrueba[MAXPLAYERS + 1] = {false, ...};
ArrayList g_pruebaVelocities = null;
// Handle g_Prueba_SmokeSetTimer;
// Handle g_Prueba_SmokeCreate;

#include "practicemode/util.sp"
#include "practicemode/globals.sp"
#include "practicemode/bots.sp"
#include "practicemode/demos.sp"
#include "practicemode/retakes.sp"
#include "practicemode/crossfire.sp"
#include "practicemode/grenades.sp"
// #include "practicemode/grenade_accuracy.sp"
// #include "practicemode/learn.sp"

// #include "practicemode/pugsetup_integration.sp"

public Action FUNCION_PRUEBA(int client, int args) {
  char arg[128];
  GetCmdArg(1, arg, sizeof(arg));

  // for (int i = 0; i < g_Demo_Matches.Length; i++) {
  //   S_Demo_Match demoMatch;
  //   g_Demo_Matches.GetArray(i, demoMatch, sizeof(demoMatch));
  //   // PrintToChatAll("analyzing demo id_%d: %s", demoMatch.id, demoMatch.name);
  //   for (int j = 0; j < demoMatch.roundIds.Length; j++) {
  //     // PrintToChatAll("> round %d", demoMatch.roundIds.Get(j));
  //   }
  // }
  // PrintToChatAll("Analyzed %d demos succesfuly!", demo_folder_count);
  return Plugin_Handled;
}

// TODO CACA PEDO USE SMOKE EXPLOSION AND MOLLY EXPLOSION (ongameframe, etc)
// public Action CommandTogglePauseMode(int client, int args) {
//   if (!g_InPracticeMode) {
//       return Plugin_Handled;
//   }
//   if (!g_InBotReplayMode || !IsReplayPlaying()) {
//     PM_Message(client, "Empieza una Demo primero!");
//     return Plugin_Handled;
//   }
//   ServerCommand("botmimictoggle_pausemode");
//   pauseMode = !pauseMode;
//   PM_Message(client, "Estado de repetición cambiado a: %s", !pauseMode ? "jugando" : "pausado");
//   if (pauseMode) {
//       GrenadeReplay_PauseGrenades();
//   } else {
//       GrenadeReplay_ResumeGrenades();
//   }
//   return Plugin_Handled;
// }

// public void GrenadeReplay_PauseGrenades() {
//   int lastEnt = GetMaxEntities();
//   for (int entity = MaxClients + 1; entity <= lastEnt; entity++) {
//     if (!IsValidEntity(entity)) {
//         continue;
//     }
//     char classnameEnt[64];
//     GetEntityClassname(entity, classnameEnt, sizeof(classnameEnt));
//     if (IsGrenadeProjectile(classnameEnt)) {
//       int GrenadeEntity = GetEntProp(entity, Prop_Data, "m_iTeamNum");
//       if (ExplodeNadeTimer[GrenadeEntity] != INVALID_HANDLE) {
//           KillTimer(ExplodeNadeTimer[GrenadeEntity]);
//           ExplodeNadeTimer[GrenadeEntity] = INVALID_HANDLE;
//       }
//       int client = Entity_GetOwner(entity);
//       if(!IsReplayBot(client)){
//           continue;
//       }
//       g_ReplayGrenadeLastPausedTime = GetEngineTime();
//       SetEntityMoveType(entity, MOVETYPE_NONE);
//       SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);
//     }
//   } 
// }

// public void GrenadeReplay_ResumeGrenades() {
//   int lastEnt = GetMaxEntities();
//   for (int entity = MaxClients + 1; entity <= lastEnt; entity++) {
//     if (!IsValidEntity(entity)) {
//       continue;
//     }
//     char classnameEnt[64];
//     GetEntityClassname(entity, classnameEnt, sizeof(classnameEnt));
//     if (IsGrenadeProjectile(classnameEnt)) {
//       int client = Entity_GetOwner(entity);
//       if(!IsReplayBot(client)){
//         continue;
//       }
//       SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
//       if(GrenadeFromProjectileName(classnameEnt) == GrenadeType_Smoke || GrenadeFromProjectileName(classnameEnt) == GrenadeType_Decoy) {
//         SetEntProp(entity, Prop_Data, "m_nNextThinkTick", 1);
//         continue;
//       } 
//       else {
//         int GrenadeEntity = GetEntProp(entity, Prop_Data, "m_iTeamNum");
//         g_ReplayGrenadeLastLastResumedTime[GrenadeEntity] = g_ReplayGrenadeLastResumedTime[GrenadeEntity];
//         if(g_ReplayGrenadeLastLastResumedTime[GrenadeEntity] <= 0.0) {
//           g_ReplayGrenadeLastLastResumedTime[GrenadeEntity] = g_ClientReplayGrenadeThrowTime[GrenadeEntity];
//         }
//         g_ReplayGrenadeLastResumedTime[GrenadeEntity] = GetEngineTime();
//         g_TiempoRecorrido[GrenadeEntity] += (g_ReplayGrenadeLastPausedTime - g_ReplayGrenadeLastLastResumedTime[GrenadeEntity]);
//         if(GrenadeFromProjectileName(classnameEnt) == GrenadeType_Flash || GrenadeFromProjectileName(classnameEnt) == GrenadeType_HE) {
//           float RemainingTime = GRENADE_DETONATE_FLASH_TIME - g_TiempoRecorrido[GrenadeEntity];
//           ExplodeNadeTimer[GrenadeEntity] = CreateTimer(RemainingTime, Timer_ForceExplodeNade, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
//         } else {
//           float RemainingTime = GRENADE_DETONATE_MOLOTOV_TIME - g_TiempoRecorrido[GrenadeEntity];
//           ExplodeNadeTimer[GrenadeEntity] = CreateTimer(RemainingTime, Timer_ForceExplodeNade, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
//         }
//       }
//     }
//   }
// }

// public Action Timer_ForceExplodeNade(Handle timer, int ref) {
//   int entity = EntRefToEntIndex(ref);
//   if(entity != -1) {
//     int GrenadeEntity = GetEntProp(entity, Prop_Data, "m_iTeamNum");
//     g_TiempoRecorrido[GrenadeEntity] = 0.0;
//     g_ReplayGrenadeLastLastResumedTime[GrenadeEntity] = -1.0;
//     g_ReplayGrenadeLastResumedTime[GrenadeEntity] = -1.0;
//     SetEntProp(entity, Prop_Data, "m_nNextThinkTick", 1);
//     SDKHooks_TakeDamage(entity, entity, entity, 1.0);
//     ExplodeNadeTimer[GrenadeEntity] = INVALID_HANDLE;
//   }
//   return Plugin_Handled;
// }

/*******************************************************************/
/**************************** Commands *****************************/
/*******************************************************************/

public Action Command_GotoSpawn(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  return TeleportToSpawn(client, args, GetClientTeam(client));
}

public Action Command_GotoCTSpawn(int client, int args) {
  return TeleportToSpawn(client, args, CS_TEAM_CT);
}

public Action Command_GotoTSpawn(int client, int args) {
  return TeleportToSpawn(client, args, CS_TEAM_T);
}

public Action Command_DryRun(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int startMoney = 800;
  float roundTime = 2.0;
  g_InDryMode = !g_InDryMode;
  if (g_InDryMode || args >= 1) {
    if (args >= 1) {
      char startMoneyStr[COMMAND_LENGTH];
      GetCmdArg(1, startMoneyStr, sizeof(startMoneyStr));
      startMoney = StringToInt(startMoneyStr);
      if (args >= 2) {
        char roundTimeStr[COMMAND_LENGTH];
        GetCmdArg(2, roundTimeStr, sizeof(roundTimeStr));
        roundTime = StringToFloat(roundTimeStr);
      }
    }

    SetCvarIntSafe("mp_startmoney", startMoney);
    SetConVarFloatSafe("mp_roundtime_defuse", roundTime);

    SetCvarIntSafe("mp_freezetime", g_DryRunFreezeTimeCvar.IntValue);
    SetCvarIntSafe("mp_radar_showall", 0);
    SetCvarIntSafe("sm_glow_pmbots", 0);
    SetCvarIntSafe("sv_grenade_trajectory", 0);
    SetCvarIntSafe("mp_ignore_round_win_conditions", 0);
    SetCvarIntSafe("sv_grenade_trajectory", 0);
    SetCvarIntSafe("sv_infinite_ammo", 2);
    SetCvarIntSafe("sm_allow_noclip", 0);
    SetCvarIntSafe("mp_respawn_on_death_ct", 0);
    SetCvarIntSafe("mp_respawn_on_death_t", 0);
    // SetCvarIntSafe("mp_buy_anywhere", 0);
    // SetCvarIntSafe("mp_buytime", 40);
    SetCvarIntSafe("sv_showimpacts", 0);
    SetCvarIntSafe("sm_holo_spawns", 0);
    SetCvarIntSafe("sm_bot_collision", 1);

    for (int i = 1; i <= MaxClients; i++) {
      g_TestingFlash[i] = false;
      g_NoFlash_Active[client] = false;
      if (IsPlayer(i)) {
        SetEntityMoveType(i, MOVETYPE_WALK);
      }
    }
  } else {
    startMoney = 10000;
    roundTime = 60.0;
    SetConVarFloatSafe("mp_roundtime_defuse", roundTime);
    SetCvarIntSafe("mp_freezetime", 0);
    SetCvarIntSafe("mp_radar_showall", 1);
    SetCvarIntSafe("sm_glow_pmbots", 1);
    SetCvarIntSafe("sv_grenade_trajectory", 1);
    SetCvarIntSafe("mp_ignore_round_win_conditions", 1);
    SetCvarIntSafe("sv_grenade_trajectory", 1);
    SetCvarIntSafe("sv_infinite_ammo", 1);
    SetCvarIntSafe("sm_allow_noclip", 1);
    SetCvarIntSafe("mp_respawn_on_death_ct", 1);
    SetCvarIntSafe("mp_respawn_on_death_t", 1);
    // SetCvarIntSafe("mp_buy_anywhere", 1);
    // SetCvarIntSafe("mp_buytime", 99999);
    SetCvarIntSafe("sv_showimpacts", 1);
    SetCvarIntSafe("sm_holo_spawns", 1);
    SetCvarIntSafe("sm_bot_collision", 0);
  }

  PM_Message(client, "%t", "DryParams", startMoney, roundTime);
  ServerCommand("mp_restartgame 1");
  return Plugin_Handled;
}

public Action Command_God(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!GetCvarIntSafe("sv_cheats")) {
    // PM_Message(client, ".god requiere que sv_cheats este activado.");
    return Plugin_Handled;
  }

  FakeClientCommand(client, "god");
  return Plugin_Handled;
}

public Action Command_Break(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  BreakBreakableEnts();
  return Plugin_Handled;
}

public Action Command_Restart(int client, int args){
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char argString[256];
  GetCmdArgString(argString, sizeof(argString));
  int freezeTime = StringToInt(argString);
  SetCvarIntSafe("mp_freezetime", freezeTime);

  for (int i = 1; i <= MaxClients; i++) {
    g_TestingFlash[i] = false;
    g_NoFlash_Active[client] = false;
    if (IsPlayer(i)) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  ServerCommand("mp_restartgame 1");
  return Plugin_Handled;
}

// Stops Bots Joining When Changin Team
public Action Command_TeamJoin(int client, const char[] command, int argc) {
  if (!IsValidClient(client) || argc < 1)
    return Plugin_Handled;

  if (g_InCrossfireMode || g_InRetakeMode) {
    return Plugin_Handled;
  }

  if (g_InPracticeMode) {
    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int team = StringToInt(arg);
    SwitchPlayerTeam(client, team);

    // // Since we force respawns off during bot demo, make teamswitches respawn players.
    // if (g_InBotDemoMode && team != CS_TEAM_SPECTATOR && team != CS_TEAM_NONE) {
    //   CS_RespawnPlayer(client);
    // }

    return Plugin_Handled;
  }

  return Plugin_Continue;
}

public Action Command_Noclip(int client, const char[] command, int argc) {
  PerformNoclipAction(client);
  return Plugin_Handled;
}

public Action Command_SetPos(int client, const char[] command, int argc) {
  SetEntityMoveType(client, MOVETYPE_WALK);
  return Plugin_Continue;
}

public Action Command_Respawn(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!IsPlayerAlive(client)) {
    CS_RespawnPlayer(client);
    return Plugin_Handled;
  }

  return Plugin_Handled;
}

public Action Command_Spec(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i) && i != client) {
      FakeClientCommand(i, "jointeam 1");
      SetEntPropEnt(i, Prop_Send, "m_hObserverTarget", client);
    }
  }

  return Plugin_Handled;
}

public Action Command_JoinT(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      FakeClientCommand(i, "jointeam 2");
    }
  }

  return Plugin_Handled;
}

public Action Command_JoinCT(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      FakeClientCommand(i, "jointeam 3");
    }
  }

  return Plugin_Handled;
}

public Action Command_StopAll(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (g_TestingFlash[client]) {
    g_TestingFlash[client] = false;
  }
  if (g_Timer_RunningCommand[client]) {
    StopClientTimer(client);
  }
  if (g_BotMimicLoaded && IsDemoPlaying()) {
    CancelAllDemos();
  }
  if (g_BotMimicLoaded && BotMimic_IsPlayerRecording(client)) {
    BotMimic_StopRecording(client, false /* save */);
  }
  // if (LearnIsActive(client)) {
  //   Command_StopLearn(client, 0);
  // }
  return Plugin_Handled;
}

public Action Command_ClearMap(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  BreakBreakableEnts();
  RespawnBreakableEnts();
  return Plugin_Handled;
}

public Action Command_ClearNades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  bool clearAll = false;
  char arg[128];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    if (StrEqual(arg, "all")) {
      clearAll = true;
    }
  }
  CEffectData smokeData;
  smokeData.m_nEntIndex = 0;
  smokeData.m_nHitBox = GetParticleSystemIndex("explosion_smokegrenade_fallback");
  DispatchEffect(clearAll ? 0 : client, "ParticleEffectStop", smokeData);
  int clearEntity = -1;
  while ((clearEntity = FindEntityByClassname(clearEntity, "smokegrenade_projectile")) != -1) {
    // TODO: get only detonated grenades?
    int owner = GetEntPropEnt(clearEntity, Prop_Send, "m_hThrower");
    if (clearAll || (owner == client || owner <= 0)) {
      StopSound(clearEntity, SNDCHAN_STATIC, "weapons/smokegrenade/smoke_emit.wav");
      StopSound(clearEntity, SNDCHAN_STATIC, "~)weapons/smokegrenade/smoke_emit.wav");
      AcceptEntityInput(clearEntity, "Kill");
    }
  }
  clearEntity = -1;
  CEffectData infernoData;
  infernoData.m_nEntIndex = 0;
  infernoData.m_nHitBox = GetParticleSystemIndex("molotov_groundfire_fallback2");
  DispatchEffect(client, "ParticleEffectStop", infernoData);
  while ((clearEntity = FindEntityByClassname(clearEntity, "inferno")) != -1) {
    int owner = GetEntPropEnt(clearEntity, Prop_Data, "m_hOwnerEntity");
    if (clearAll || (owner == client || owner <= 0)) {
      StopSound(clearEntity, SNDCHAN_STATIC, "weapons/molotov/fire_loop_1.wav");
      StopSound(clearEntity, SNDCHAN_STATIC, "~)weapons/molotov/fire_loop_1.wav");
      AcceptEntityInput(clearEntity, "Kill");
    }
  }

  if (clearAll) {
    for (int i = 0; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        g_Nade_LastEntity[i] = -1;
        g_Nade_HistoryInfo[i].Clear();
      }
    }
  } else {
    g_Nade_LastEntity[client] = -1;
    g_Nade_HistoryInfo[client].Clear();
  }
  
  return Plugin_Handled;
}

public Action Command_ExitPracticeMode(int client, int args) {
  if (g_InPracticeMode) {
    ExitPracticeMode();
  }
  return Plugin_Handled;
}

public Action Command_BotsMenu(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  GiveBotsMenu(client);
  return Plugin_Handled;
}

public Action Command_NadesMenu(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  GiveNadeMenuInContext(client);
  return Plugin_Handled;
}

public Action Command_NoFlash(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  g_NoFlash_Active[client] = !g_NoFlash_Active[client];
  if (g_NoFlash_Active[client]) {
    // PM_Message(client, "Noflash activado. Usa .noflash de nuevo para desactivar.");
    RequestFrame(KillFlashEffect, GetClientSerial(client));
  } else {
    // PM_Message(client, "Noflash desactivado.");
  }
  return Plugin_Handled;
}

public Action Command_BackAll(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (g_InCrossfireMode) {
    Command_NextCrossfire(client, args);
    return Plugin_Handled;
  }

  Command_GrenadeBack(client, args);
  return Plugin_Handled;
}

public Action Command_NextAll(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (g_InCrossfireMode) {
    Command_PrevCrossfire(client, args);
    return Plugin_Handled;
  }

  Command_GrenadeForward(client, args);
  return Plugin_Handled;
}

public Action Command_Time(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_Timer_RunningCommand[client]) {
    // Start command.
    PM_Message(client, "%t", "Timer1");
    g_Timer_RunningCommand[client] = true;
    g_Timer_RunningLiveCommand[client] = false;
    g_TimerType[client] = TimerType_Increasing_Movement;
  } else {
    // Early stop command.
    StopClientTimer(client);
  }

  return Plugin_Handled;
}

public Action Command_Time2(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_Timer_RunningCommand[client]) {
    // Start command.
    PM_Message(client, "%t", "Timer2");
    g_Timer_RunningCommand[client] = true;
    g_Timer_RunningLiveCommand[client] = false;
    g_TimerType[client] = TimerType_Increasing_Manual;
    StartClientTimer(client);
  } else {
    // Stop command.
    StopClientTimer(client);
  }

  return Plugin_Handled;
}

public Action Command_CountDown(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  // float timer_duration = float(GetRoundTimeSeconds());
  // char arg[PLATFORM_MAX_PATH];
  // if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
  //   timer_duration = StringToFloat(arg);
  // }

  // PM_Message(client, "El cronómetro empezará cuando te muevas y terminará cuando escribar .stop");
  // g_Timer_RunningCommand[client] = true;
  // g_Timer_RunningLiveCommand[client] = false;
  // g_TimerType[client] = TimerType_Countdown_Movement;
  // g_Timer_Duration[client] = timer_duration;
  // StartClientTimer(client);

  return Plugin_Handled;
}

public Action Command_Help(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  int page;
  page = GetCmdArgInt(args);
  if (page <= 1) {
    ShowHelpInfo(client, 1);
  } else if (page == 2) {
    ShowHelpInfo(client, 2);
  }
  return Plugin_Handled;
}

public Action Command_GivePracticeSetupMenu(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (!IsPracticeSetupClient(client)) {
    return Plugin_Handled;
  }
  PracticeSetupMenu(client);
  return Plugin_Handled;
}

/*******************************************************************/
/****************************** Menus ******************************/
/*******************************************************************/


public Action Command_Map(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (!IsPracticeSetupClient(client)) {
    return Plugin_Handled;
  }
  char arg[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    // Before trying to change to the arg first, check to see if
    // there's a clear match in the maplist
    int mapIndex = FindStringInArray2(_mapNames, sizeof(_mapNames), arg, false);
    if (mapIndex > -1) {
      PM_MessageToAll("{ORANGE}Cambiando mapa a %s...", _mapNames[mapIndex]);
      ChangeMap(_mapCodes[mapIndex]);
      return Plugin_Handled;
    }
  }
  Menu menu = new Menu(ChangeMapHandler);
  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.SetTitle("%t", "SelectMap", client);
  for (int i = 0; i < sizeof(_mapNames); i++) {
    AddMenuInt(menu, i, _mapNames[i]);
  }
  DisplayMenu(menu, client, MENU_TIME_FOREVER);

  return Plugin_Handled;
}

public int ChangeMapHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int index = GetMenuInt(menu, param2);
    PM_MessageToAll("{ORANGE}Cambiando mapa a %s...", _mapNames[index]);
    ChangeMap(_mapCodes[index]);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    PracticeSetupMenu(param1);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public Action Command_Kick(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (!IsPracticeSetupClient(client)) {
    return Plugin_Handled;
  }
  char arg[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    // Before trying to change to the arg first, check to see if
    // there's a clear match in the players list
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        char playerName[MAX_NAME_LENGTH];
        GetClientName(i, playerName, sizeof(playerName));
        if (StrEqual(playerName, arg)) {
          KickClient(i);
          // PM_MessageToAll("%N {ORANGE}Fue Kickeado del Servidor.", i);
          return Plugin_Handled;
        }
      }
    }
  }
  Menu menu = new Menu(KickPlayersMenuHandler);
  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.SetTitle("%t", "KickPlayers", client);
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      char playerName[MAX_NAME_LENGTH];
      GetClientName(i, playerName, sizeof(playerName));
      AddMenuInt(menu, i, playerName);
    }
  }
  DisplayMenu(menu, client, MENU_TIME_FOREVER);
  return Plugin_Handled;
}

public int KickPlayersMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    int kickPlayer = GetMenuInt(menu, item);
    KickPlayerConfirmationMenu(client, kickPlayer);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    PracticeSetupMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public void KickPlayerConfirmationMenu(int client, int kickPlayer) {
  if (!IsPlayer(kickPlayer)) {
    return;
  }
  Menu menu = new Menu(KickPlayerMenuHandler);
  menu.SetTitle("%t: %N ?", "KickPlayer", client, kickPlayer);

  menu.ExitBackButton = false;
  menu.ExitButton = false;
  menu.Pagination = MENU_NO_PAGINATION;

  char kickIndexStr[16];
  IntToString(kickPlayer, kickIndexStr, sizeof(kickIndexStr));
  menu.AddItem(kickIndexStr, "", ITEMDRAW_IGNORE);

  for (int i = 0; i < 6; i++) {
    menu.AddItem("", "", ITEMDRAW_NOTEXT);
  }

  char displayStr[128];
  Format(displayStr, sizeof(displayStr), "%t", "SelectNo", client);
  menu.AddItem("no", displayStr);
  Format(displayStr, sizeof(displayStr), "%t", "SelectYes", client);
  menu.AddItem("yes", displayStr);
  menu.Display(client, MENU_TIME_FOREVER);
}

public int KickPlayerMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "yes")) {
      char kickIndexStr[16];
      menu.GetItem(0, kickIndexStr, sizeof(kickIndexStr));
      int kickPlayer = StringToInt(kickIndexStr);
      if (IsPlayer(kickPlayer) && IsPlayer(client)) {
        KickClient(kickPlayer);
        // PM_MessageToAll("%N {ORANGE}Fue Kickeado del Servidor.", kickPlayer);
      }
    } else {
      Command_Kick(client, 0);
    }
  }
  return 0;
}

stock void PracticeSetupMenu(int client, int pos = 0) {
  Menu menu = new Menu(PracticeSetupMenuHandler);
  menu.SetTitle("%t", "Server_Settings");

  char buffer[128];
  GetCvarStringSafe("sv_password", buffer, sizeof(buffer));
  if (!StrEqual(buffer, "")) {
    Format(buffer, sizeof(buffer), "%t", "ServerAccessPass", client);
    menu.AddItem("password", buffer);
    Format(buffer, sizeof(buffer), "%t\n ", "ChangePassword", client);
    menu.AddItem("changepassword", buffer);
  } else {
    Format(buffer, sizeof(buffer), "%t", "ServerAccessNoPass", client);
    menu.AddItem("password", buffer);
    Format(buffer, sizeof(buffer), "%t\n ", "ChangePassword", client);
    menu.AddItem("changepassword", buffer, ITEMDRAW_DISABLED);
  }

  menu.AddItem("", "", ITEMDRAW_NOTEXT);
  menu.AddItem("", "", ITEMDRAW_NOTEXT);

  Format(buffer, sizeof(buffer), "%t", "ChangeMap", client);
  menu.AddItem("changemap", buffer);
  Format(buffer, sizeof(buffer), "%t", "KickPlayers", client);
  menu.AddItem("kickplayers", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_ShowImpacts",
  (GetCvarIntSafe("sv_showimpacts") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("showimpacts", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_InfiniteAmmo",
  (GetCvarIntSafe("sv_infinite_ammo") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("infiniteammo", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_BotsWallhack",
  (GetCvarIntSafe("sm_glow_pmbots") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("glowbots", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_GrenadeTrajectory",
  (GetCvarIntSafe("sv_grenade_trajectory") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("grenadetrajectory", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_ShowSpawns",
  (GetCvarIntSafe("sm_holo_spawns") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("glowspawns", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_AllowNoclip",
  (GetCvarIntSafe("sm_allow_noclip") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("noclip", buffer);

  Format(buffer, sizeof(buffer), "%t: %t", "Option_Collisions",
  (GetCvarIntSafe("sm_bot_collision") == 0) ? "Disabled" : "Enabled", client);
  menu.AddItem("collision", buffer);

  // menu.Pagination = MENU_NO_PAGINATION;
  menu.ExitButton = true;

  menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public int PracticeSetupMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    int menuPos = 0;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "password")) {
      char SvPassword[32];
      GetConVarString(FindConVar("sv_password"), SvPassword, sizeof(SvPassword));
      if (!StrEqual(SvPassword, "")) {
        SetConVarString(FindConVar("sv_password"), "");
      } else {
        PM_Message(client, "%t", "WriteNewPassword");
        g_WaitForServerPassword = true;
      }
    } else if (StrEqual(buffer, "changepassword")) {
        PM_Message(client, "%t", "WriteNewPassword");
        g_WaitForServerPassword = true;
    } else if (StrEqual(buffer, "kickplayers")) {
      Command_Kick(client, 0);
      return 0;
    } else if (StrEqual(buffer, "changemap")) {
      Command_Map(client, 0);
      return 0;
    } else {
      if (StrEqual(buffer, "showimpacts")) {
        (GetCvarIntSafe("sv_showimpacts") == 1)
        ? SetCvarIntSafe("sv_showimpacts", 0)
        : SetCvarIntSafe("sv_showimpacts", 1);
      }
      else if (StrEqual(buffer, "infiniteammo")) {
        (GetCvarIntSafe("sv_infinite_ammo") == 1)
        ? SetCvarIntSafe("sv_infinite_ammo", 0)
        : SetCvarIntSafe("sv_infinite_ammo", 1);
      }
      else if (StrEqual(buffer, "glowbots")) {
        (GetCvarIntSafe("sm_glow_pmbots") == 1)
        ? SetCvarIntSafe("sm_glow_pmbots", 0)
        : SetCvarIntSafe("sm_glow_pmbots", 1);
      }
      else if (StrEqual(buffer, "grenadetrajectory")) {
        (GetCvarIntSafe("sv_grenade_trajectory") == 1)
        ? SetCvarIntSafe("sv_grenade_trajectory", 0)
        : SetCvarIntSafe("sv_grenade_trajectory", 1);
      }
      else if (StrEqual(buffer, "glowspawns")) {
        (GetCvarIntSafe("sm_holo_spawns") == 1)
        ? SetCvarIntSafe("sm_holo_spawns", 0)
        : SetCvarIntSafe("sm_holo_spawns", 1);
      }
      else if (StrEqual(buffer, "noclip")) {
        (GetCvarIntSafe("sm_allow_noclip") == 1)
        ? SetCvarIntSafe("sm_allow_noclip", 0)
        : SetCvarIntSafe("sm_allow_noclip", 1);
      }
      else if (StrEqual(buffer, "collision")) {
        (GetCvarIntSafe("sm_bot_collision") == 1)
        ? SetCvarIntSafe("sm_bot_collision", 0)
        : SetCvarIntSafe("sm_bot_collision", 1);
      }
      menuPos = 6;
    }
    PracticeSetupMenu(client, menuPos);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void GivePracticeMenu(int client, int style = ITEMDRAW_DEFAULT) {
  Menu menu = new Menu(PracticeMenuHandler);
  menu.SetTitle("%t", "PracticeMenu", client);
  char displayStr[OPTION_NAME_LENGTH];
  Format(displayStr, sizeof(displayStr), "%t", "BotsMenu", client);
  menu.AddItem("bots_menu", displayStr);
  Format(displayStr, sizeof(displayStr), "%t", "NadesMenu", client);
  menu.AddItem("nades_menu", displayStr);
  Format(displayStr, sizeof(displayStr), "%t\n ", "DemosMenu", client);
  menu.AddItem("demos_menu", displayStr);
  
  Format(displayStr, sizeof(displayStr), "%t\n ", "Help", client);
  menu.AddItem("help", displayStr);

  menu.Pagination = MENU_NO_PAGINATION;
  menu.ExitButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
}

public int PracticeMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    
    if (StrEqual(buffer, "bots_menu")) {
      Command_BotsMenu(client, 0);
    } else if (StrEqual(buffer, "nades_menu")) {
      Command_NadesMenu(client, 0);
    } else if (StrEqual(buffer, "demos_menu")) {
      Command_DemosMenu(client, 0);
    } else {
      if (StrEqual(buffer, "help")) {
        ShowHelpInfo(client);
      }
      GivePracticeMenu(client);
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

/*******************************************************************/
/********************* Events, Forwards, Hooks *********************/
/*******************************************************************/

public Plugin myinfo = {
  name = "Practicemode Lite",
  author = "sergio",
  description = "",
  version = PLUGIN_VERSION,
  url = "https://steamcommunity.com/profiles/76561199016822889/"
};

public void OnPluginStart() {
  LoadTranslations("common.phrases");
  LoadTranslations("practicemode.phrases");

  // Forwards
  g_OnGrenadeSaved = CreateGlobalForward("PM_OnGrenadeSaved", ET_Hook, Param_Cell,
                                         Param_Array, Param_Array, Param_String);
  g_OnPracticeModeDisabled = CreateGlobalForward("PM_OnPracticeModeEnabled", ET_Ignore);
  g_OnPracticeModeEnabled = CreateGlobalForward("PM_OnPracticeModeDisabled", ET_Ignore);
  g_Nade_OnGrenadeThrownForward = CreateGlobalForward("PM_OnThrowGrenade",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Array, Param_Array, Param_Array, Param_Array);
  g_Nade_OnGrenadeExplodeForward = CreateGlobalForward("PM_OnGrenadeExplode",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Array);
  g_Nade_OnManagedGrenadeExplodeForward = CreateGlobalForward("PM_OnManagedGrenadeExplode",
    ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Array);
      
  HudSync = CreateHudSynchronizer();
  // New Plugin cvars
  g_BotRespawnTimeCvar = CreateConVar("sm_practicemode_bot_respawn_time", "3.0",
                                      "How long it should take bots placed with .bot to respawn");
  g_AutostartCvar = CreateConVar("sm_practicemode_autostart", "1",
                                 "Whether the plugin is automatically started on mapstart");
  g_DryRunFreezeTimeCvar = CreateConVar("sm_practicemode_dry_run_freeze_time", "6",
                                        "Freezetime after running the .dry command.");
  g_MaxHistorySizeCvar = CreateConVar(
      "sm_practicemode_max_grenade_history_size", "50",
      "Maximum number of previous grenade throws saved in temporary history per-client. The temporary history is reset every map change. Set to 0 to disable.");
  g_MaxPlacedBotsCvar =
      CreateConVar("sm_practicemode_max_placed_bots", "10",
                   "Maximum number of static bots a single client may have placed at once.");

  g_FlashEffectiveThresholdCvar =
      CreateConVar("sm_practicemode_flash_effective_threshold", "2.0",
                   "How many seconds a flash must last to be considered effective");
  g_TestFlashTeleportDelayCvar =
      CreateConVar("sm_practicemode_test_flash_delay", "0.3",
                   "Seconds to wait before teleporting a player using .flash");

  g_VersionCvar = CreateConVar("sm_practicemode_version", PLUGIN_VERSION,
                               "Current practicemode version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
  g_VersionCvar.SetString(PLUGIN_VERSION);

  // New cvars we don't want saved in the autoexec'd file
  g_InfiniteMoneyCvar = CreateConVar("sm_infinite_money", "0",
                                     "Whether clients recieve infinite money", FCVAR_DONTRECORD);
  g_AllowNoclipCvar =
      CreateConVar("sm_allow_noclip", "1",
                   "Whether players may use .noclip in chat to toggle noclip", FCVAR_DONTRECORD);

  g_PatchGrenadeTrajectoryCvar =
      CreateConVar("sm_patch_grenade_trajectory_cvar", "1",
                   "Whether the plugin patches sv_grenade_trajectory with its own grenade trails");
  g_GlowPMBotsCvar =
      CreateConVar("sm_glow_pmbots", "0",
                   "Whether to glow all PM Bots");
  g_HoloSpawnsCvar =
      CreateConVar("sm_holo_spawns", "0",
                   "Whether to show spawns holos");
  
  g_InPracticeMode = false;
  AddCommandListener(Command_TeamJoin, "jointeam");
  AddCommandListener(Command_Noclip, "noclip");
  AddCommandListener(Command_SetPos, "setpos");

  HookEvent("weapon_fire", Event_WeaponFired);
  HookEvent("flashbang_detonate", Event_FlashDetonate);
  HookEvent("smokegrenade_detonate", Event_SmokeDetonate, EventHookMode_Pre);
  HookEvent("smokegrenade_detonate", Event_GrenadeDetonate);
  HookEvent("hegrenade_detonate", Event_GrenadeDetonate);
  HookEvent("decoy_started", Event_GrenadeDetonate);
  HookEvent("player_blind", Event_PlayerBlind);
  HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
  HookEvent("player_death", Event_PlayerDeath);
  HookEvent("round_freeze_end", Event_FreezeEnd);
  HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
  HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
  HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
  HookUserMessage(GetUserMessageId("SayText2"), Hook_SayText2, true);
  HookEventEx("weapon_zoom", OnWeaponZoom);
  HookEventEx("weapon_fire", OnWeaponFire);
  HookConVarChange(g_GlowPMBotsCvar, GlowPMBotsChanged);
  HookConVarChange(g_HoloSpawnsCvar, HoloSpawnsChanged);

  // Patched builtin cvars
  g_Nade_TrajectoryCvar = GetCvar("sv_grenade_trajectory");
  g_Nade_ThicknessCvar = GetCvar("sv_grenade_trajectory_thickness");
  g_Nade_TimeCvar = GetCvar("sv_grenade_trajectory_time");
  g_Nade_SpecTimeCvar = GetCvar("sv_grenade_trajectory_time_spectator");

  // Remove cheats so sv_cheats isn't required for this:
  RemoveCvarFlag(g_Nade_TrajectoryCvar, FCVAR_CHEAT);

  // AutoExecConfig(true, "practicemode");
  ServerCommand("exec practicemode.cfg");

  LoadSDK();
  LoadDetours();

  CommandsBlocker_PluginStart();
  Demos_PluginStart();
  HoloNade_PluginStart();
  // GrenadeAccuracy_PluginStart();
  Breakables_PluginStart();
  AfkManager_PluginStart();
  Retakes_PluginStart();
  Crossfire_PluginStart();
  NadePrediction_PluginStart();
  Spawns_PluginStart();
  CsgoSvPassowrd_PluginStart();

  for (int i = 0; i <= MaxClients; i++) {
    g_Nade_HistoryPositions[i] = new ArrayList(3);
    g_Nade_HistoryAngles[i] = new ArrayList(3);
    g_Nade_HistoryInfo[i] = new ArrayList(3);
    g_ClientBots[i] = new ArrayList();
  }
  
  RegConsoleCmd("sm_practicesetup", Command_GivePracticeSetupMenu);
  PM_AddChatAlias(".setup", "sm_practicesetup");

  RegConsoleCmd("sm_practicemap", Command_Map);
  PM_AddChatAlias(".map", "sm_practicemap");

  RegConsoleCmd("sm_practicekick", Command_Kick);
  PM_AddChatAlias(".kick", "sm_practicekick");

  RegConsoleCmd("sm_helpinfo", Command_Help);
  PM_AddChatAlias(".help", "sm_helpinfo");

  RegAdminCmd("sm_exitpractice", Command_ExitPracticeMode, ADMFLAG_CHANGEMAP, "Salir del modo practica");

  RegConsoleCmd("sm_backall", Command_BackAll);
  PM_AddChatAlias(".back", "sm_backall");

  RegConsoleCmd("sm_nextall", Command_NextAll);
  PM_AddChatAlias(".next", "sm_nextall");

  RegConsoleCmd("sm_lastgrenade", Command_LastGrenade);
  PM_AddChatAlias(".last", "sm_lastgrenade");

  RegConsoleCmd("sm_throw", Command_Throw);
  PM_AddChatAlias(".throw", "sm_throw");
  PM_AddChatAlias(".rethrow", "sm_throw");

  RegConsoleCmd("sm_gotospawn", Command_GotoSpawn);
  PM_AddChatAlias(".spawn", "sm_gotospawn");
  PM_AddChatAlias(".spawns", "sm_gotospawn");

  RegConsoleCmd("sm_gotoctspawn", Command_GotoCTSpawn);
  PM_AddChatAlias(".ctspawn", "sm_gotoctspawn");

  RegConsoleCmd("sm_gototspawn", Command_GotoTSpawn);
  PM_AddChatAlias(".tspawn", "sm_gototspawn");

  RegConsoleCmd("sm_botsmenu", Command_BotsMenu);
  PM_AddChatAlias(".bots", "sm_botsmenu");
  PM_AddChatAlias(".bot", "sm_botsmenu");

  RegConsoleCmd("sm_nadesmenu", Command_NadesMenu);
  PM_AddChatAlias(".nades", "sm_nadesmenu");
  PM_AddChatAlias(".grenades", "sm_nadesmenu");
  PM_AddChatAlias(".smokes", "sm_nadesmenu");

  RegConsoleCmd("sm_removeallbots", Command_RemoveAllBots);
  PM_AddChatAlias(".nobots", "sm_removeallbots");

  RegConsoleCmd("sm_prueba", FUNCION_PRUEBA);
  PM_AddChatAlias(".prueba", "sm_prueba");

  RegConsoleCmd("sm_predictdata", Command_PredictData);
  PM_AddChatAlias(".preddata", "sm_predictdata");

  RegConsoleCmd("sm_predictnades", Command_PredictNades);
  PM_AddChatAlias(".pred", "sm_predictnades");

  RegConsoleCmd("sm_allowpredict", Command_AllowPredict);
  PM_AddChatAlias(".trajectory", "sm_allowpredict");
  PM_AddChatAlias(".traj", "sm_allowpredict");

  // RegConsoleCmd("sm_predictdev", Command_PredictDev);
  // PM_AddChatAlias(".dev", "sm_predictdev");
  
  RegConsoleCmd("sm_predictedsmenu", Command_PredictResultsMenu);
  PM_AddChatAlias(".predmenu", "sm_predictedsmenu");

  // RegConsoleCmd("sm_pausemode", CommandTogglePauseMode);
  // PM_AddChatAlias(".pause", "sm_pausemode");

  RegConsoleCmd("sm_demo", Command_DemosMenu);
  PM_AddChatAlias(".demo", "sm_demo");
  PM_AddChatAlias(".demos", "sm_demo");

  // RegConsoleCmd("sm_pausemode", CommandTogglePauseMode);
  // PM_AddChatAlias(".pause", "sm_pausemode");

  RegConsoleCmd("sm_cancel", Command_DemoCancel);
  PM_AddChatAlias(".cancel", "sm_cancel");

  RegConsoleCmd("sm_finishrecording", Command_FinishRecordingDemo);
  PM_AddChatAlias(".finish", "sm_finishrecording");

  RegConsoleCmd("sm_savenade", Command_SaveNade);
  PM_AddChatAlias(".save", "sm_savenade");

  RegConsoleCmd("sm_savenadecode", Command_ImportNade);
  PM_AddChatAlias(".import", "sm_savenadecode");

  // RegConsoleCmd("sm_savedelay", Command_SetDelay);
  // PM_AddChatAlias(".setdelay", "sm_savedelay");

  RegConsoleCmd("sm_copylastplayer", Command_CopyPlayerLastGrenade);
  PM_AddChatAlias(".copy", "sm_copylastplayer");

  RegConsoleCmd("sm_spec", Command_Spec);
  PM_AddChatAlias(".spec", "sm_spec");
  PM_AddChatAlias(".spect", "sm_spec");

  RegConsoleCmd("sm_joint", Command_JoinT);
  PM_AddChatAlias(".t", "sm_joint");

  RegConsoleCmd("sm_joinct", Command_JoinCT);
  PM_AddChatAlias(".ct", "sm_joinct");

  RegConsoleCmd("sm_respawn", Command_Respawn);
  PM_AddChatAlias(".respawn", "sm_respawn");

  // RegConsoleCmd("sm_learn", Command_Learn);
  // PM_AddChatAlias(".learn", "sm_learn");

  // RegConsoleCmd("sm_skip", Command_Skip);
  // PM_AddChatAlias(".skip", "sm_skip");

  // RegConsoleCmd("sm_stoplearn", Command_StopLearn);
  // PM_AddChatAlias(".stoplearn", "sm_stoplearn");
  // PM_AddChatAlias(".stoplearning", "sm_stoplearn");

  // RegConsoleCmd("sm_show", Command_Show);
  // PM_AddChatAlias(".show", "sm_show");

  RegConsoleCmd("sm_retakes_editormenu", Command_RetakesEditorMenu);
  PM_AddChatAlias(".editretakes", "sm_retakes_editormenu");

  RegConsoleCmd("sm_retakes_setupmenu", Command_RetakesSetupMenu);
  PM_AddChatAlias(".retakes", "sm_retakes_setupmenu");
  PM_AddChatAlias(".retake", "sm_retakes_setupmenu");

  RegConsoleCmd("sm_crossfires_editormenu", Command_CrossfiresEditorMenu);
  PM_AddChatAlias(".editcrossfires", "sm_crossfires_editormenu");

  RegConsoleCmd("sm_crossfires_setupmenu", Command_CrossfiresSetupMenu);
  PM_AddChatAlias(".crossfires", "sm_crossfires_setupmenu");
  PM_AddChatAlias(".crossfire", "sm_crossfires_setupmenu");

  RegConsoleCmd("sm_testflash", Command_TestFlash);
  PM_AddChatAlias(".flash", "sm_testflash");

  RegConsoleCmd("sm_noflash", Command_NoFlash);
  PM_AddChatAlias(".noflash", "sm_noflash");

  // TODO: A timer menu may be more accesible to users, as the number of timer types continues to
  // increase...
  RegConsoleCmd("sm_time", Command_Time);
  PM_AddChatAlias(".timer", "sm_time");

  RegConsoleCmd("sm_time2", Command_Time2);
  PM_AddChatAlias(".timer2", "sm_time2");

  RegConsoleCmd("sm_countdown", Command_CountDown);
  PM_AddChatAlias(".countdown", "sm_countdown");

  RegConsoleCmd("sm_clearnades", Command_ClearNades);
  PM_AddChatAlias(".clear", "sm_clearnades");
  PM_AddChatAlias(".clearsmokes", "sm_clearnades");

  RegConsoleCmd("sm_clearmap", Command_ClearMap);
  PM_AddChatAlias(".clearmap", "sm_clearmap");
  PM_AddChatAlias(".cleanmap", "sm_clearmap");

  RegConsoleCmd("sm_stopall", Command_StopAll);
  PM_AddChatAlias(".stop", "sm_stopall");

  RegConsoleCmd("sm_dryrun", Command_DryRun);
  PM_AddChatAlias(".dry", "sm_dryrun");

  RegConsoleCmd("sm_god", Command_God);
  PM_AddChatAlias(".god", "sm_god");
  
  RegConsoleCmd("sm_break", Command_Break);
  PM_AddChatAlias(".break", "sm_break");

  RegConsoleCmd("sm_rr", Command_Restart);
  PM_AddChatAlias(".rr", "sm_rr");
  PM_AddChatAlias(".restart", "sm_rr");
}

public void CsgoSvPassowrd_PluginStart() {
  /* https://forums.alliedmods.net/showthread.php?t=330847 */
	GameData temp = new GameData("csgo_sv_password.games");
	if(temp == null) SetFailState("Why you no has csgo_sv_password.games.txt gamedata?");
	hSvPasswordChangeCallback = DHookCreateDetour(Address_Null, CallConv_CDECL, ReturnType_Void, ThisPointer_Ignore);
	if (!hSvPasswordChangeCallback)
		SetFailState("Failed to setup detour for SvPasswordChangeCallback DHookCallback");

	if (!DHookSetFromConf(hSvPasswordChangeCallback, temp, SDKConf_Signature, "SvPasswordChangeCallback"))
		SetFailState("Failed to load SvPasswordChangeCallback signature from csgo_sv_password.games.txt gamedata");

	delete temp;
	DHookAddParam(hSvPasswordChangeCallback, HookParamType_ObjectPtr);
	DHookAddParam(hSvPasswordChangeCallback, HookParamType_StringPtr);
	DHookAddParam(hSvPasswordChangeCallback, HookParamType_Float);

	if (!DHookEnableDetour(hSvPasswordChangeCallback, false, Detour_OnCSWeaponDrop))
		SetFailState("Failed to detour hSvPasswordChangeCallback.");
}

public MRESReturn Detour_OnCSWeaponDrop(DHookParam hParams) {
  //PrintToServer("hSvPasswordChangeCallback Pre");
  // Skip real function. Bypass player and reserved cookie check.
  return MRES_Supercede;
}

// Not in use
public MRESReturn Detour_OnCSWeaponDrop_Post(DHookParam hParams) {
  //PrintToServer("hSvPasswordChangeCallback Post");
  return MRES_Supercede;
}

public void AfkManager_PluginStart() {
  // name = "Sammy's Afker Kicker",
  // author = "NBK - Sammy-ROCK!",
	g_AFK_autoCheck = true;
	g_AFK_AdminImmune= CreateConVar("pmg_AFK_AdminImmune",	"0", "Should Sammy's Afker Kicker skip admins?", 0, true, 0.0, true, 1.0);
	g_AFK_TimerDelay = CreateConVar("pmafk_check_delay", "300.0", "Delay between checks. How low it is heavier is the plugin.", 0, true, 1.0);
	g_AFK_MaxTime = CreateConVar("pmafk_time_needed", "1200.0", "How long player can stay afk before getting kicked", 0, true, 5.0);
}

public void CommandsBlocker_PluginStart() {
  g_cBlockPlugins = CreateConVar("sbp_block_plugins", "1", "Block 'sm plugins'?", _, true, 0.0, true, 1.0);
  g_cBlockSM = CreateConVar("sbp_block_sm", "1", "Block 'sm'?", _, true, 0.0, true, 1.0);

  PTaH(PTaH_ConsolePrintPre, Hook, ConsolePrint);
  PTaH(PTaH_ExecuteStringCommandPre, Hook, ExecuteStringCommand);

  char sDate[18];
  FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
  BuildPath(Path_SM, g_sLogs, sizeof(g_sLogs), "logs/sbp-%s.log", sDate);
}

public void Breakables_PluginStart() {
  g_Breakable_Doors = new ArrayList(sizeof(S_Breakable_Door));
  g_Breakable_FuncBks = new ArrayList(sizeof(S_Breakable_FuncBk));
  g_Breakable_Dynamics = new ArrayList(sizeof(S_Breakable_Dynamic));
}

public void AfkManager_MapStart() {
	CreateTimer(GetConVarFloat(g_AFK_TimerDelay), CheckAfkUsers, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void Spawns_PluginStart() {
  g_Spawns = new ArrayList(6); //spawn ent, trigger ent, 4 beams
}

public void AfkManager_ClientDisconnect(int client) {
	g_AFK_Warned[client] = false;
	g_AFK_LastCheckTime[client] = 0.0;
	g_AFK_LastMovementTime[client] = 0.0;
}

public Action ConsolePrint(int client, char message[1024]) {
  if (IsClientConnected(client)) {    
    if(g_cBlockPlugins.BoolValue) {
      if(StrContains(message, ".smx\" ") != -1) {
        return Plugin_Handled;
      }
      else if(StrContains(message, "To see more, type \"sm ", false) != -1) {
        LogToFile(g_sLogs, "\"%L\" tried to get -> %s", client, message);
        return Plugin_Handled;
      }
    }
  }
  return Plugin_Continue;
}

public Action ExecuteStringCommand(int client, char sCommandString[512]) {
  if (IsPlayer(client)) {
    char message[512];
    strcopy(message, sizeof(message), sCommandString);
    TrimString(message);

    if(g_cBlockSM.BoolValue && StrContains(message, "sm ") == 0 || StrEqual(message, "sm", false)) {
      LogToFile(g_sLogs, "\"%L\" failed to use %s.", client, message);
      return Plugin_Handled;
    }
  }
  return Plugin_Continue; 
}

public void Breakables_MapStart() {
  g_Breakable_Doors.Clear();
  g_Breakable_FuncBks.Clear();
  g_Breakable_Dynamics.Clear();
  SaveBreakbaleEnts();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  g_ChatAliases = new ArrayList(ALIAS_LENGTH);
  g_ChatAliasesCommands = new ArrayList(COMMAND_LENGTH);
  CreateNative("PM_StartPracticeMode", Native_StartPracticeMode);
  CreateNative("PM_ExitPracticeMode", Native_ExitPracticeMode);
  CreateNative("PM_IsPracticeModeEnabled", Native_IsPracticeModeEnabled);
  CreateNative("PM_Message", Native_Message);
  CreateNative("PM_MessageToAll", Native_MessageToAll);
  CreateNative("PM_AddChatAlias", Native_AddChatAlias);
  CreateNative("PM_ThrowGrenade", Native_ThrowGrenade);
  RegPluginLibrary("practicemode");
  return APLRes_Success;
}

public void Spawns_MapStart() {
  g_Spawns.Clear();
  g_SpawnsLengthCt = 0;
  AddMapSpawnsForTeam("info_player_counterterrorist");
  g_SpawnsLengthCt = g_Spawns.Length;
  AddMapSpawnsForTeam("info_player_terrorist");
}

public void Spawns_MapEnd() {
  RemoveHoloSpawnEntities();
}

public void HologramSpawn_OnEndTouch(int entity, int other) {
  if (!IsValidClient(other))
    return;
  char targetName[MAX_TARGET_LENGTH];
  GetEntPropString(entity, Prop_Data, "m_iName", targetName, sizeof(targetName));
  int index = StringToInt(targetName);
  if (index==0 && !StrEqual(targetName, "0")) {
    return;
  }
  int spawnEnts[6];
  g_Spawns.GetArray(index, spawnEnts, sizeof(spawnEnts));
  for (int i = 2; i < 6; i++) {
    SetEntityRenderColor(spawnEnts[i], 255, 0, 0, 255);
  }
}

public void HologramSpawn_OnStartTouch(int entity, int other) {
  if (!IsValidClient(other))
    return;
  char targetName[MAX_TARGET_LENGTH];
  GetEntPropString(entity, Prop_Data, "m_iName", targetName, sizeof(targetName));
  int index = StringToInt(targetName);
  if (index==0 && !StrEqual(targetName, "0")) {
    return;
  }
  int spawnEnts[6];
  g_Spawns.GetArray(index, spawnEnts, sizeof(spawnEnts));
  for (int i = 2; i < 6; i++) {
    SetEntityRenderColor(spawnEnts[i], 0, 255, 0, 255);
  }
}

public Action GrenadeTouch(int entity, int other) {
  int client = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
  if (IsPlayer(client)) {
    for (int i = 0; i < g_Nade_HistoryInfo[client].Length; i++) {
      int ref = g_Nade_HistoryInfo[client].Get(i, 0);
      if (EntRefToEntIndex(ref) == entity) {
        g_Nade_HistoryInfo[client].Set(i, g_Nade_HistoryInfo[client].Get(i, 2) + 1, 2);
        return Plugin_Continue;
      }
    }
  }
  SDKUnhook(entity, SDKHook_StartTouch, GrenadeTouch);
  return Plugin_Continue;
}

public void PM_OnThrowGrenade(int client, int entity, GrenadeType grenadeType, const float origin[3], const float velocity[3]) {
  if (client <= 0) {
    return;
  }
  g_Nade_LastType[client] = grenadeType;
  g_Nade_LastOrigin[client] = origin;
  g_Nade_LastVelocity[client] = velocity;
  g_Nade_LastDetonationOrigin[client] = view_as<float>({0.0, 0.0, 0.0});
  g_Nade_LastEntity[client] = entity;
  // Demos_OnThrowGrenade(client, entity, grenadeType, origin, velocity);
  // GrenadeAccuracy_OnThrowGrenade(client, entity);
}

public void PM_OnGrenadeExplode(
  int client,
  int currentEntity, 
  GrenadeType grenade,
  const float grenadeDetonationOrigin[3]
) {
  if (client == -1) {
    // I guess this is possible in some race conditions involving map change or disconnect.
    return;
  }
  if (currentEntity == g_Nade_LastEntity[client]) {
    g_Nade_LastDetonationOrigin[client] = grenadeDetonationOrigin;
  }
  // GrenadeAccuracy_OnGrenadeExplode(client, currentEntity, grenade, grenadeDetonationOrigin);
  // Learn_OnGrenadeExplode(client, currentEntity, grenade, grenadeDetonationOrigin);
}

public void OnClientDisconnect(int client) {
  MaybeWriteNewGrenadeData();
  if (IsPracticeBot(client)) {
    SetNotPracticeBot(client);
    return;
  }
  if (g_PracticeSetupClient == client) {
    g_PracticeSetupClient = -1;
  }
  if (g_InPracticeMode) {
    KickAllClientBots(client);
  }

  // If the server empties out, exit practice mode.
  int playerCount = 0;
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      if (g_PracticeSetupClient == -1) {
        g_PracticeSetupClient = i;
      }
      playerCount++;
    }
  }
  if (playerCount == 0 && g_InPracticeMode) {
    ExitPracticeMode();
  }

  // Reset Variables
  g_Demo_WaitForSave[client] = false;
  g_Demo_WaitForRoleSave[client] = false;
  g_Demo_WaitForDemoSave[client] = false;
  g_Nade_WaitForSave[client] = false;
  g_Nade_DemoRecordingStatus[client] = 0;
  g_Nade_NewDemoSaved[client] = false;
  g_Nade_CurrentSavedId[client] = -1;
  g_Nade_HistoryIndex[client] = -1;
  g_Nade_HistoryPositions[client].Clear();
  g_Nade_HistoryAngles[client].Clear();
  g_Nade_HistoryInfo[client].Clear();
  g_TestingFlash[client] = false;
  g_TestingFlash_Origins[client] = ZERO_VECTOR;
  g_TestingFlash_Angles[client] = ZERO_VECTOR;
  g_NoFlash_Active[client] = false;
  // g_Nade_LastFlashDetonateTime[client];
  g_Nade_LastType[client] = GrenadeType_None;
  g_Nade_PulledPinButtons[client] = 0;
  g_Nade_PulledPin[client] = false;
  g_Nade_LastPinPulledPos[client] = ZERO_VECTOR;
  g_Nade_LastPinPulledAng[client] = ZERO_VECTOR;
  g_Nade_LastOrigin[client] = ZERO_VECTOR;
  g_Nade_LastVelocity[client] = ZERO_VECTOR;
  g_Nade_LastDetonationOrigin[client] = ZERO_VECTOR;
  g_Nade_LastEntity[client] = -1;
  g_Nade_ClientSpecBot[client] = -1;
  g_Demo_LastSpecPos[client] = ZERO_VECTOR;
  g_Demo_LastSpecAng[client] = ZERO_VECTOR;
  g_Nade_LastSpecPlayerTeam[client] = -1;
  g_Bots_OriginalName[client] = "-1";
  g_Is_PMBot[client] = false;
  g_Is_DemoBot[client] = 0;
  g_Is_Demo_Match_Bot[client] = false;
  g_Is_RetakeBot[client] = false;
  g_Is_CrossfireBot[client] = false;
  g_Is_NadeBot[client] = false;
  g_Bots_SpawnOrigin[client] = ZERO_VECTOR;
  g_Bots_SpawnAngles[client] = ZERO_VECTOR;
  g_Bots_SpawnWeapon[client] = "-1";
  g_Bots_Duck[client] = false;
  g_Bots_Jump[client] = false;
  g_Bots_MindControlOwner[client] = -1;
  g_Bots_NameNumber[client] = 0;
  g_LastNoclipCommand[client] = 0;
  g_Timer_RunningCommand[client] = false;
  g_Timer_RunningLiveCommand[client] = false;
  // g_Timer_Duration[client];
  g_TimerType[client] = TimerType_Increasing_Movement;
  // g_Timer_LastCommand[client];
  g_Misc_InUseButtons[client] = false;

  AfkManager_ClientDisconnect(client);
  Bots_ClientDisconnect(client);
  NadePrediction_ClientDisconnect(client);
  Crossfire_ClientDisconnect(client);
  Demos_ClientDisconnect(client);
  {
    // nades
    g_Nade_CurrentGroupControl[client] = -1;
    g_Nade_CurrentControl[client] = -1;
    g_Nade_LastMenuType[client] = Grenade_MenuType_NadeGroup;
    g_Nade_LastMenuTypeFilter[client] = GrenadeType_None;
  }
  ManicoBots_ClientDisconnect(client);
  Retakes_ClientDisconnect(client);

  // Learn_ClientDisconnect(client);
}

public void OnMapEnd() {
  MaybeWriteNewGrenadeData();

  if (g_InPracticeMode) {
    ExitPracticeMode();
  }

  Spawns_MapEnd();
  Demos_MapEnd();
  HoloNade_MapEnd();
  Retakes_MapEnd();
  Crossfires_MapEnd();
  delete g_NadesKv;
}

public void OnClientPutInServer(int client) {
  if (!IsPlayer(client)) {
    return;
  }
  HoloNade_ClientPutInServer(client);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3],
                      int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed,
                      int mouse[2]) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  if (!IsPlayer(client)) {
    if (IsPMBot(client)) {
      return PMBot_PlayerRunCmd(client, buttons, vel, angles, weapon);
    } else if (g_Is_NadeBot[client]) {
      return NadeDemoBot_PlayerRunCmd(client, buttons, vel, angles, weapon);
    } else if (IsRetakeBot(client)) {
      return RetakeBot_PlayerRunCmd(client, buttons, vel, angles, weapon);
    } else if (IsCrossfireBot(client)) {
      return CrossfireBot_PlayerRunCmd(client, buttons, vel, angles, weapon);
    } else if (g_Is_DemoVersusBot[client]) {
      return DemoVersusBot_PlayerRunCmd(client, buttons);
    }
    return Plugin_Continue;
  }

  if (g_InRetakeMode || g_InCrossfireMode) {
    return Plugin_Continue;
  }

  // test
  if (g_startedPrueba[client]) {
    float absVel[3];
    Entity_GetAbsVelocity(client, absVel);
    g_pruebaVelocities.PushArray(absVel, sizeof(absVel));
  }
  // test

  bool moving = MovingButtons(buttons);
  E_TimerType timer_type = g_TimerType[client];
  bool is_movement_timer =
      (timer_type == TimerType_Increasing_Movement || timer_type == TimerType_Countdown_Movement);
  bool is_movement_end_timer = timer_type == TimerType_Increasing_Movement;

  if (g_Timer_RunningCommand[client] && is_movement_timer) {
    if (g_Timer_RunningLiveCommand[client]) {
      // The movement timer is already running; stop it.
      if (is_movement_end_timer && !moving && GetEntityFlags(client) & FL_ONGROUND) {
        g_Timer_RunningCommand[client] = false;
        g_Timer_RunningLiveCommand[client] = false;
        StopClientTimer(client);
      }
    } else {
      //  We're pending a movement timer start.
      if (moving) {
        g_Timer_RunningLiveCommand[client] = true;
        StartClientTimer(client);
      }
    }
  }

  if (!IsPlayerAlive(client)) {
    return Plugin_Continue;
  }

  // Interaction
  if ((buttons & IN_USE) && !g_Misc_InUseButtons[client]) {
    g_Misc_InUseButtons[client] = true;
    // Grenade Hologram
    float eyeOrigin[3], eyeForward[3], eyeEnd[3];
    GetClientEyePosition(client, eyeOrigin);
    GetClientEyeAngles(client, eyeForward);
    GetAngleVectors(eyeForward, eyeForward, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(eyeForward, eyeForward);
    ScaleVector(eyeForward, 80.0); //interacting_distance
    AddVectors(eyeOrigin, eyeForward, eyeEnd);
    float entOrigin[3];
    int holoNadeIndex = GetNearestNadeGroupIndex(eyeOrigin, entOrigin);
    if (PointInsideViewRange(entOrigin, eyeOrigin, eyeEnd)) {
      GiveNadeGroupMenu(client, holoNadeIndex);
      return Plugin_Continue;
    }
    // Spawn Entity
    if (GetCvarIntSafe("sm_holo_spawns") == 1) {
      ScaleVector(eyeForward, 3.0);
      AddVectors(eyeOrigin, eyeForward, eyeEnd);
      float entAngles[3];
      int spawnIndex = GetNearestSpawnEntsIndex(eyeOrigin, entOrigin, entAngles);
      if (PointInsideViewRange(entOrigin, eyeOrigin, eyeEnd)) {
        TeleportEntity(client, entOrigin, entAngles, ZERO_VECTOR);
        char spawnclassName[CLASS_LENGTH];
        int spawnEnt = g_Spawns.Get(spawnIndex, 0);
        if (IsValidEntity(spawnEnt)) {
          GetEntityClassname(spawnEnt, spawnclassName, sizeof(spawnclassName));
          if (StrEqual(spawnclassName, "info_player_counterterrorist")) {
            PM_Message(client, "%t", "TeleportingToCTSpawn", spawnIndex + 1);
          } else {
            PM_Message(client, "%t", "TeleportingToTSpawn", spawnIndex + 1 - g_SpawnsLengthCt);
          }
        }
        return Plugin_Continue;
      }
    }
  } else if (g_Misc_InUseButtons[client] && !(buttons & IN_USE)) {
    g_Misc_InUseButtons[client] = false;
  }
  
  char weaponName[64];
  GetClientWeapon(client, weaponName, sizeof(weaponName));
  bool isGrenade = StrContains(nadelist, weaponName, false) != -1;
  if (isGrenade) {
    if (((buttons & IN_ATTACK) || (buttons & IN_ATTACK2)) && !g_Nade_PulledPin[client]) {
        GetClientAbsOrigin(client, g_Nade_LastPinPulledPos[client]);
        GetClientEyeAngles(client, g_Nade_LastPinPulledAng[client]);
        g_Nade_PulledPinButtons[client] = 0;
        g_Nade_PulledPin[client] = true;
        // DEMOS
        if (!g_InBotDemoMode) { // && g_Nade_DemoRecordingStatus[client] == 0
          if (BotMimic_IsPlayerRecording(client)) {
            BotMimic_StopRecording(client, false); // delete
            g_Nade_DemoRecordingStatus[client] = 0;
          }
          char recordName[128];
          Format(recordName, sizeof(recordName), "player %N %s", client, weaponName);
          g_Demo_CurrentRecordingStartTime[client] = GetGameTime();
          g_Nade_DemoRecordingStatus[client] = 1;
          g_DemoNadeData[client].Clear();
          BotMimic_StartRecording(client, recordName, "practicemode", _, 600);
        }
    } else if (g_Nade_PulledPin[client] && !((buttons & IN_ATTACK) || (buttons & IN_ATTACK2))) {
        g_Nade_PulledPinButtons[client] |= buttons;
        // DEMOS
        if (g_Nade_DemoRecordingStatus[client]) {
          if (!g_InBotDemoMode && BotMimic_IsPlayerRecording(client)) {
            g_Nade_DemoRecordingStatus[client] = 2;
            CreateTimer(0.2, Timer_Botmimic_PauseRecording, GetClientSerial(client));
          }
        }
    }
    if (g_Nade_PulledPin[client]) {
      float exxvel[3];
      Entity_GetAbsVelocity(client, exxvel);
      if (GetVectorDotProduct(exxvel, exxvel) <= 0.01) {
        g_Nade_PulledPinButtons[client] = 0;
        GetClientAbsOrigin(client, g_Nade_LastPinPulledPos[client]);
        GetClientEyeAngles(client, g_Nade_LastPinPulledAng[client]);
      } else {
        g_Nade_PulledPinButtons[client] |= buttons;
      }
    }
  } else {
    // DEMOS
    if (g_Nade_DemoRecordingStatus[client] == 1) {
      if (!g_InBotDemoMode && BotMimic_IsPlayerRecording(client)) {
        g_Nade_DemoRecordingStatus[client] = 0;
        BotMimic_StopRecording(client, false); // delete
      }
    }
  }
  if (g_Nade_Pred_Allowed[client]) {
    GrenadeType grenadeType = isGrenade ? GrenadeTypeFromWeapon(client, weaponName) : GrenadeType_None;
    NadePrediction_PlayerRunCmd(client, buttons, isGrenade, grenadeType);
  }
  //HoloSpawn_PlayerRunCmd(client, buttons, impulse, vel, angles, weapon);
  return Plugin_Continue;
}

public Action CS_OnBuyCommand(int client, const char[] weapon) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }
  if (!IsPlayer(client)) {
    return Plugin_Handled;
  }
  Format(g_Crossfire_PlayerWeapon[client], sizeof(g_Crossfire_PlayerWeapon[]), "weapon_%s", weapon);
  TryCleanDroppedWeapons();
  RequestFrame(TryGivePlayerMaxMoney, client);
  return Plugin_Continue;
}

public void OnPluginEnd() {
  OnMapEnd();
}

public void OnLibraryAdded(const char[] name) {
  g_BotMimicLoaded = LibraryExists("botmimic");
}

public void OnLibraryRemoved(const char[] name) {
  g_BotMimicLoaded = LibraryExists("botmimic");
}

public void OnClientConnected(int client) {
  SetClientInfo(client, "cl_use_opens_buy_menu", "0");
  g_Demo_CurrentEditingRole[client] = -1;
  g_Demo_SelectedId[client] = "";
  CheckAutoStart();
}

public void OnMapStart() {
  ServerCommand("exec practicemode.cfg");
  // g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
  g_PredictTrail = PrecacheModel("sprites/laserbeam.spr");
  g_BeamSprite = PrecacheModel("materials/sprites/white.vmt");
  PrecacheModel("models/chicken/festive_egg.mdl");
  PrecacheModel("models/error.mdl");
  PrecacheParticle("silvershot_string_lights_02");

  EnforceDirectoryExists("data/practicemode");
  EnforceDirectoryExists("data/practicemode/bots");
  EnforceDirectoryExists("data/practicemode/bots/backups");
  EnforceDirectoryExists("data/practicemode/grenades");
  EnforceDirectoryExists("data/practicemode/grenades/backups");
  EnforceDirectoryExists("data/practicemode/retakes");
  EnforceDirectoryExists("data/practicemode/retakes/backups");
  EnforceDirectoryExists("data/practicemode/crossfires");
  EnforceDirectoryExists("data/practicemode/crossfires/backups");
  EnforceDirectoryExists("data/practicemode/entries");
  EnforceDirectoryExists("data/practicemode/entries/backups");
  EnforceDirectoryExists("data/practicemode/demos");
  EnforceDirectoryExists("data/practicemode/demos/matches");
  EnforceDirectoryExists("data/practicemode/demos/backups");

  // This supports backwards compatability for grenades saved in the old location
  // data/practicemode_grenades. The data is transferred to the new
  // location if they are read from the legacy location.
  char legacyDir[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, legacyDir, sizeof(legacyDir), "data/practicemode_grenades");

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  char legacyFile[PLATFORM_MAX_PATH];
  Format(legacyFile, sizeof(legacyFile), "%s/%s.cfg", legacyDir, map);

  BuildPath(Path_SM, g_Nade_LocationsFile, sizeof(g_Nade_LocationsFile),
            "data/practicemode/grenades/%s.cfg", map);

  if (!FileExists(g_Nade_LocationsFile) && FileExists(legacyFile)) {
    PrintToServer("Moving legacy grenade data from %s to %s", legacyFile, g_Nade_LocationsFile);
    g_NadesKv = new KeyValues("Grenades");
    g_NadesKv.ImportFromFile(legacyFile);
    g_Nade_UpdatedKv = true;
  } else {
    g_NadesKv = new KeyValues("Grenades");
    // g_NadesKv.SetEscapeSequences(true); // Avoid fatals from special chars in user data
    g_NadesKv.ImportFromFile(g_Nade_LocationsFile);
    g_Nade_UpdatedKv = false;
  }

  MaybeCorrectGrenadeIds();

  Spawns_MapStart();
  Demos_MapStart();
  HoloNade_MapStart();
  // GrenadeAccuracy_MapStart();
  Breakables_MapStart();
  AfkManager_MapStart();
  Retakes_MapStart();
  Crossfires_MapStart();
  // Learn_MapStart();
}

public void OnConfigsExecuted() {
  // Disable legacy plugin if found.
  char legacyPluginFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, legacyPluginFile, sizeof(legacyPluginFile),
            "plugins/pugsetup_practicemode.smx");
  if (FileExists(legacyPluginFile)) {
    char disabledLegacyPluginName[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, disabledLegacyPluginName, sizeof(disabledLegacyPluginName),
              "plugins/disabled/pugsetup_practicemode.smx");
    ServerCommand("sm plugins unload pugsetup_practicemode");
    if (FileExists(disabledLegacyPluginName))
      DeleteFile(disabledLegacyPluginName);
    RenameFile(disabledLegacyPluginName, legacyPluginFile);
    PrintToServer("%s was unloaded and moved to %s", legacyPluginFile, disabledLegacyPluginName);
  }

  CheckAutoStart();
}

public void OnEntityCreated(int entity, const char[] className) {
  if (!IsValidEntity(entity)) {
    return;
  }
  Nades_OnEntityCreated(entity, className);
  SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}

// We artifically delay the work here in OnEntitySpawned because
// plugin will spawn grenades and set the owner on spawn, and we want to be sure
// the owner is set by the time practicemode gets to the grenade.

public void OnEntitySpawned(int entity) {
  RequestFrame(DelayedOnEntitySpawned, entity);
}

public void DelayedOnEntitySpawned(int entity) {
  if (!IsValidEdict(entity)) {
    return;
  }

  char className[CLASS_LENGTH];
  GetEdictClassname(entity, className, sizeof(className));

  if (IsGrenadeProjectile(className)) {

    // Get the cl_color value for the client that threw this grenade.
    int client = Entity_GetOwner(entity);

    if (IsPlayer(client) && g_InPracticeMode &&
    GrenadeFromProjectileName(className) == GrenadeType_Smoke) {
      int index = g_Nade_HistoryInfo[client].Push(EntIndexToEntRef(entity));
      g_Nade_HistoryInfo[client].Set(index, view_as<int>(GetEngineTime()), 1);
      g_Nade_HistoryInfo[client].Set(index, 0, 2);
      SDKHook(entity, SDKHook_StartTouch, GrenadeTouch);
    }
    if (IsDemoBot(client) && g_InPracticeMode &&
    (GrenadeFromProjectileName(className) != GrenadeType_None || GrenadeFromProjectileName(className) != GrenadeType_Smoke)) {
      g_Demo_CurrentNade++;
      SetEntProp(entity, Prop_Data, "m_iTeamNum", g_Demo_CurrentNade);
      g_Demo_GrenadeThrowTime[g_Demo_CurrentNade] = GetEngineTime();
    }

    if (IsValidEntity(entity)) {
      if (g_Nade_TrajectoryCvar.IntValue != 0 && g_PatchGrenadeTrajectoryCvar.IntValue != 0) {
        // Send a temp ent beam that follows the grenade entity to all other clients.
        for (int i = 1; i <= MaxClients; i++) {
          if (!IsClientConnected(i) || !IsClientInGame(i)) {
            continue;
          }

          // Note: the technique using temporary entities is taken from InternetBully's NadeTails
          // plugin which you can find at https://forums.alliedmods.net/showthread.php?t=240668
          float time = (GetClientTeam(i) == CS_TEAM_SPECTATOR) ? g_Nade_SpecTimeCvar.FloatValue
                                                               : g_Nade_TimeCvar.FloatValue;

          // int colors[4];
          // colors[0] = GetRandomInt(0, 255);
          // colors[1] = GetRandomInt(0, 255);
          // colors[2] = GetRandomInt(0, 255);
          // colors[3] = 255;

          TE_SetupBeamFollow(entity, g_BeamSprite, 0, time, g_Nade_ThicknessCvar.FloatValue * 5,
                             g_Nade_ThicknessCvar.FloatValue * 5, 1, { 0, 255, 255, 255 });
          TE_SendToClient(i);
        }
      }

      // If the user recently indicated they are testing a flash (.flash),
      // teleport to that spot.
      if (IsPlayer(client)) {
        if (GrenadeFromProjectileName(className) == GrenadeType_Flash && g_TestingFlash[client]) {
          float delay = g_TestFlashTeleportDelayCvar.FloatValue;
          if (delay <= 0.0) {
            delay = 0.1;
          }
          CreateTimer(delay, Timer_TeleportClient, GetClientSerial(client));
        }
      }
    }
  }
}

public void OnEntityDestroyed(int entity) {
  Nades_OnEntityDestroyed(entity);
}

public Action Event_WeaponFired(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  char weapon[CLASS_LENGTH];
  event.GetString("weapon", weapon, sizeof(weapon));

  if (IsGrenadeWeapon(weapon) && IsPlayer(client)) {
    AddGrenadeToHistory(client);
  }
  return Plugin_Continue;
}

public Action Event_FlashDetonate(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  if (IsPlayer(client) && g_TestingFlash[client]) {
    // Get the impact of the flash next frame, since doing it in
    // this frame doesn't work.
    //RequestFrame(GetTestingFlashInfo, GetClientSerial(client));
    CreateTimer(1.5, Timer_FakeGrenadeBack, GetClientSerial(client));
  }
  g_Nade_LastFlashDetonateTime[client] = GetGameTime();
  return Plugin_Continue;
}

public Action Event_PlayerBlind(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int victim = GetClientOfUserId(event.GetInt("userid"));
  // Did anyone throw a flash recently? If so, they probably care about this bot being blinded.
  float now = GetGameTime();
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && FloatAbs(now - g_Nade_LastFlashDetonateTime[i]) < 0.001) {
      char T_CB[16];
      if(GetFlashDuration(victim)>=g_FlashEffectiveThresholdCvar.FloatValue) T_CB="{GREEN}";
      else T_CB="{DARK_RED}";
      PM_Message(i, "{PURPLE}---------------");
      char victimName[MAX_NAME_LENGTH];
      GetClientName(victim, victimName, sizeof(victimName));
      PM_Message(i, "%t", "BlindedPlayer", victimName);
      float accuracy = GetFlashDuration(victim)/5.21*100;
      accuracy > 100.0 ? (accuracy=100.0) : accuracy;
      PM_Message(i, "%t", "FlashPrecision", T_CB, accuracy);
      PM_Message(i, "%t", "FlashDuration", T_CB, GetFlashDuration(victim));
      PM_Message(i, "{PURPLE}---------------");
      break;
    }
  }

  if (g_NoFlash_Active[victim]) {
    RequestFrame(KillFlashEffect, GetClientSerial(victim));
  }
  return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  TryCleanDroppedWeapons();
  int victim = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(victim)) {
    if (g_InRetakeMode) {
      int index = g_Retake_Players.FindValue(victim);
      if (index != -1) {
        g_Retake_DeathPlayersCount++;
        if (g_Retake_DeathPlayersCount == g_Retake_Players.Length) {
          EndSingleRetake(false);
        }
      }
    } else if (g_InCrossfireMode) {
      int index = g_Crossfire_Players.FindValue(victim);
      if (index != -1) {
        g_Crossfire_DeathPlayersCount++;
        if (g_Crossfire_DeathPlayersCount == g_Crossfire_Players.Length) {
          EndSingleCrossfire(false);
        }
      }
    } else {
      CreateTimer(1.5, Timer_RespawnClient, GetClientSerial(victim), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
  } else {
    if (IsPMBot(victim)) {
      return Event_PMBot_Death(victim, event, name, dontBroadcast);
    } else if (IsDemoBot(victim)) {
      return Event_DemoBot_Death(victim, event, name, dontBroadcast);
    } else if (IsRetakeBot(victim)) {
      return Event_RetakeBot_Death(victim, event, name, dontBroadcast);
    } else if (IsCrossfireBot(victim)) {
      return Event_CrossfireBot_Death(victim, event, name, dontBroadcast);
    }
  }
  return Plugin_Continue;
}

public Action Event_GrenadeDetonate(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }
  int userid = event.GetInt("userid");
  int client = GetClientOfUserId(userid);
  int entity = event.GetInt("entityid");

  if (IsPlayer(client)) {
    for (int i = 0; i < g_Nade_HistoryInfo[client].Length; i++) {
      int ref = g_Nade_HistoryInfo[client].Get(i, 0);
      if (EntRefToEntIndex(ref) == entity) {
        float dt = GetEngineTime() - view_as<float>(g_Nade_HistoryInfo[client].Get(i, 1));
        int bounces = g_Nade_HistoryInfo[client].Get(i, 2);
        g_Nade_HistoryInfo[client].Erase(i);
        char grenadeName[CLASS_LENGTH];
        GetEntityClassname(entity, grenadeName, sizeof(grenadeName));
        GrenadeType grenadeType = GrenadeTypeFromWeapon(client, grenadeName);
        GrenadeTypeString(grenadeType, grenadeName, sizeof(grenadeName));
        UpperString(grenadeName);
        PM_Message(client, "%t", "AirTime", grenadeName, dt, bounces);
        if (grenadeType == GrenadeType_Smoke) {
          ForceGlow(entity);
        }
        break;
      }
    }
  }
  return Plugin_Continue;
}

public Action Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  for (int i = 1; i <= MaxClients; i++) {
    if (!IsPlayer(i)) {
      if (IsDemoBot(i)) {
        if (!BotMimic_IsBotMimicing(i) && IsPlayerAlive(i)) {
          ForcePlayerSuicide(i);
        }
      }
      continue;
    }

    if (g_NoFlash_Active[i]) {
      g_NoFlash_Active[i] = false;
    }

    if (GetEntityMoveType(i) == MOVETYPE_NOCLIP) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  return Plugin_Handled;
}

public Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
  if (g_InPracticeMode) {
    event.BroadcastDisabled = true;
  }
  return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  CheckAutoStart();
  if (!g_InPracticeMode) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(client)) {
    TryGivePlayerMaxMoney(client);
    if (g_PracticeSetupClient == -2) {
      if (IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_T) {
        ServerCommand("bot_kick");
        ServerCommand("mp_warmup_end");
        PrintToServer("Give Setup to Client %d", client);
        g_PracticeSetupClient = client;
        PracticeSetupMenu(client);
        ShowHelpInfo(client);
      } else {
        // Fix so when adding the first bot the match doesnt restart
        ServerCommand("mp_restartgame 1");
        ServerCommand("bot_add_ct");
        ServerCommand("bot_add_t");
      }
    }
  } else if (IsPMBot(client)) { //|| IsDemoBot(client)
    if (g_GlowPMBotsCvar.IntValue != 0) {
      RemoveSkin(client);
      CreateGlow(client);
    }
    if (IsPMBot(client)) {
      GiveBotParams(client);
    }
  }

  if (g_InBotDemoMode && BotMimic_GetGameMode() != BM_GameMode_Versus) {
    Entity_SetCollisionGroup(client, COLLISION_GROUP_NONE); // COLLISION_GROUP_DEBRIS
  }

  // TODO: move this elsewhere and save it properly.
  if (g_InBotDemoMode && g_BotMimicLoaded && IsDemoBot(client)) {
    Client_SetArmor(client, 100);
    SetEntData(client, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
  }

  return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));

  if ((IsDemoBot(victim) || IsPMBot(victim)) && IsPlayer(attacker)) {
    int damage = event.GetInt("dmg_health");
    int postDamageHealth = event.GetInt("health");
    char botName[128];
    GetClientName(victim, botName, sizeof(botName));
    PM_Message(attacker, "%t", "BotDamageEvent", damage, botName, postDamageHealth);
  }

  return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  if (g_InRetakeMode) {
    return Event_Retakes_RoundStart(event, name, dontBroadcast);
  }

  UpdateHoloNadeEntities();
  UpdateHoloSpawnEntities();

  g_Manico_EveryoneDead = false;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsDemoBot(i) && IsPlayerAlive(i)) {
      g_Manico_UncrouchChance[i] = Math_GetRandomInt(1, 100);
      g_Manico_DontSwitch[i] = false;
      g_Manico_Target[i] = -1;
        
      if(GetClientTeam(i) == CS_TEAM_CT)
        SetEntData(i, g_Manico_BotMoraleOffset, -3);
      else if(GetClientTeam(i) == CS_TEAM_T) {
        SetEntData(i, g_Manico_BotMoraleOffset, 1);
      }
    }
  }

  return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  if (g_InRetakeMode) {
    Event_Retakes_RoundEnd(event, name, dontBroadcast);
  }
  return Plugin_Continue;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsPracticeBot(client)) {
      SetEventBroadcast(event, true);
      if (IsDemoBot(client)) {
        SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
      }
      return Plugin_Continue;
    }
    return Plugin_Continue;
}

public void OnWeaponZoom(Event eEvent, const char[] szName, bool bDontBroadcast) {
  int client = GetClientOfUserId(eEvent.GetInt("userid"));
  
  if (IsValidClient(client) && IsFakeClient(client) && IsPlayerAlive(client))
    CreateTimer(0.3, Timer_Zoomed, GetClientUserId(client));
}

public void OnWeaponFire(Event eEvent, const char[] szName, bool bDontBroadcast) {
  int client = GetClientOfUserId(eEvent.GetInt("userid"));
  if(IsValidClient(client) && IsFakeClient(client) && IsPlayerAlive(client)) {
    char szWeaponName[64];
    eEvent.GetString("weapon", szWeaponName, sizeof(szWeaponName));
    
    if(IsValidClient(g_Manico_Target[client])) {
      float fClientLoc[3], fTargetLoc[3];
      
      GetClientAbsOrigin(client, fClientLoc);
      GetClientAbsOrigin(g_Manico_Target[client], fTargetLoc);
      
      float fRangeToEnemy = GetVectorDistance(fClientLoc, fTargetLoc);
      
      if (strcmp(szWeaponName, "weapon_deagle") == 0 && fRangeToEnemy > 100.0)
        SetEntDataFloat(client, g_Manico_FireWeaponOffset, GetEntDataFloat(client, g_Manico_FireWeaponOffset) + Math_GetRandomFloat(0.35, 0.60));
    }
    
    if (strcmp(szWeaponName, "weapon_awp") == 0 || strcmp(szWeaponName, "weapon_ssg08") == 0) {
      g_Manico_Zoomed[client] = false;
      CreateTimer(0.1, Timer_DelaySwitch, GetClientUserId(client));
    }
  }
}

public Action Hook_SayText2(UserMsg msg_id, any msg, const int[] players, int playersNum, bool reliable, bool init) {
    char[] sMessage = new char[24];
    if(GetUserMessageType() == UM_Protobuf) {
        Protobuf pbmsg = msg;
        pbmsg.ReadString("msg_name", sMessage, 24);
    } else {
        BfRead bfmsg = msg;
        bfmsg.ReadByte();
        bfmsg.ReadByte();
        bfmsg.ReadString(sMessage, 24, false);
    }
    if(StrEqual(sMessage, "#Cstrike_Name_Change")) {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void HoloSpawnsChanged(Handle convar, const char[] oldValue, const char[] newValue) {
  if (StringToInt(newValue) == 1) {
    UpdateHoloSpawnEntities();
  } else if (StringToInt(newValue) == 0) {
    RemoveHoloSpawnEntities();
  }
}

public void GlowPMBotsChanged(Handle convar, const char[] oldValue, const char[] newValue) {
  if (StringToInt(newValue) == 1) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPMBot(i)) {
        RemoveSkin(i);
        CreateGlow(i);
      }
    }
  } else if (StringToInt(newValue) == 0) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPMBot(i)) {
        RemoveSkin(i);
      }
    }
  }
}

public Action OnClientSayCommand(int client, const char[] command, const char[] text) {
  if (g_AllowNoclipCvar.IntValue != 0 && StrEqual(text, ".noclip") && IsPlayer(client)) {
    PerformNoclipAction(client);
  }
  return Plugin_Continue;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
  if (!IsPlayer(client))
    return;

  // splits to find the first word to do a chat alias command check
  char chatCommand[COMMAND_LENGTH];
  char chatArgs[255];
  int index = SplitString(sArgs, " ", chatCommand, sizeof(chatCommand));

  if (index == -1) {
    strcopy(chatCommand, sizeof(chatCommand), sArgs);
  } else if (index < strlen(sArgs)) {
    strcopy(chatArgs, sizeof(chatArgs), sArgs[index]);
  }
  if (chatCommand[0]) {
    char alias[ALIAS_LENGTH];
    char cmd[COMMAND_LENGTH];
    for (int i = 0; i < GetArraySize(g_ChatAliases); i++) {
      g_ChatAliases.GetString(i, alias, sizeof(alias));
      g_ChatAliasesCommands.GetString(i, cmd, sizeof(cmd));

      if (CheckChatAlias(alias, cmd, chatCommand, chatArgs, client)) {
        break;
      }
    }
  }

  if (StrEqual(chatCommand, ".menu")) {
    GivePracticeMenu(client);
    return;
  }

  char cleanArgs[128];
  strcopy(cleanArgs, sizeof(cleanArgs), sArgs);
  CleanMsgString(cleanArgs, sizeof(cleanArgs));
  if (g_Nade_WaitForSave[client]) {
    g_Nade_WaitForSave[client] = false;
    if (StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "%t", "ActionCanceled");
    } else {
      SaveClientNade(client, cleanArgs);
    }
  } else if (g_WaitForServerPassword && client == g_PracticeSetupClient) {
    g_WaitForServerPassword = false;
    if (StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "%t", "ActionCanceled");
    } else {
      SetConVarStringSafe("sv_password", cleanArgs);
      PM_Message(client, "%t", "PasswordChangedTo", cleanArgs);
    }
    PracticeSetupMenu(client);
  } else if(g_Retake_WaitForSave[client]) {
    g_Retake_WaitForSave[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "%t", "ActionCanceled");
    } else {
      IntToString(GetRetakesNextId(), g_Retake_SelectedId, OPTION_ID_LENGTH);
      SetRetakeName(g_Retake_SelectedId, cleanArgs);
      PM_Message(client, "%t", "CreatedRetake", cleanArgs, g_Retake_SelectedId);
      SingleRetakeEditorMenu(client);
    }
  } else if(g_Crossfire_WaitForSave[client]) {
    g_Crossfire_WaitForSave[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "%t", "ActionCanceled");
    } else {
      IntToString(GetCrossfiresNextId(), g_Crossfire_SelectedId, OPTION_ID_LENGTH);
      SetCrossfireName(g_Crossfire_SelectedId, cleanArgs);
      PM_Message(client, "%t", "CreatedCrossfire", cleanArgs, g_Crossfire_SelectedId);
      SingleCrossfireEditorMenu(client);
    }
  } else if (g_Demo_WaitForSave[client]) {
    g_Demo_WaitForSave[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "%t", "ActionCanceled");
    } else {
      IntToString(GetDemosNextId(), g_Demo_SelectedId[client], OPTION_ID_LENGTH);
      SetDemoName(g_Demo_SelectedId[client], cleanArgs);
      PM_Message(client, "%t", "CreatedDemo", cleanArgs, g_Demo_SelectedId[client]);
      SingleDemoEditorMenu(client);
    }
  } else if (g_Demo_WaitForRoleSave[client]) {
    g_Demo_WaitForRoleSave[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "%t", "ActionCanceled");
    } else {
      char demoRoleStr[OPTION_ID_LENGTH];
      IntToString(g_Demo_CurrentEditingRole[client], demoRoleStr, sizeof(demoRoleStr));
      SetDemoRoleKVString(g_Demo_SelectedId[client], demoRoleStr, "name", cleanArgs);
      PM_Message(client, "%t", "NameChangedTo", cleanArgs);
      SingleDemoRoleMenu(client, g_Demo_CurrentEditingRole[client]);
    }
  } else if (g_Demo_WaitForDemoSave[client]) {
    g_Demo_WaitForDemoSave[client] = false;
    if(StrEqual(cleanArgs, "!no")) {
      PM_Message(client, "%t", "ActionCanceled");
    } else {
      SetDemoName(g_Demo_SelectedId[client], cleanArgs);
      PM_Message(client, "%t", "NameChangedTo", cleanArgs);
      SingleDemoEditorMenu(client);
    }
  }
}

/*******************************************************************/
/*******************************************************************/

/****************************** Misc *******************************/
/*******************************************************************/

public Action CheckAfkUsers(Handle timer) {
	if (g_AFK_autoCheck) {
		float time = GetEngineTime();
		for(int client = 1; client <= MaxClients; client++) {
			if(IsPlayer(client)) {
				float pastTime = time - g_AFK_LastCheckTime[client];
				if (pastTime > GetConVarFloat(g_AFK_TimerDelay) - 2.0) {
					g_AFK_LastCheckTime[client] = time;
					//continue
				} else {
					continue;
				}
				if (GetConVarInt(g_AFK_AdminImmune) && GetUserFlagBits(client)) {
					continue;
				}
				if (CheckClientIsAfk(client)) {
					if (time - g_AFK_LastMovementTime[client] >= GetConVarFloat(g_AFK_MaxTime)) {
						// g_AFK_LastMovementTime[client] = time;
						KickClient(client, "%t", "AFK_KickReason", GetConVarFloat(g_AFK_MaxTime)/60);
					} else if (time - g_AFK_LastMovementTime[client] >= GetConVarFloat(g_AFK_MaxTime) - AFK_WARNING_DELAY) {
						if (!g_AFK_Warned[client]) {
							PM_Message(client, "%t", "AFK_Warning", client, view_as<int>(AFK_WARNING_DELAY));
							g_AFK_Warned[client] = true;
						}
					}
					continue;
				}
				g_AFK_LastMovementTime[client] = time;
			}
		}
	}
	return Plugin_Continue;
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
  for (int i = 0; i < g_Breakable_FuncBks.Length; i++) {
    S_Breakable_FuncBk breakable;
    g_Breakable_FuncBks.GetArray(i, breakable, sizeof(breakable));
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
  for (int i = 0; i < g_Breakable_Doors.Length; i++) {
    S_Breakable_Door door;
    g_Breakable_Doors.GetArray(i, door, sizeof(door));
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
  for (int i = 0; i < g_Breakable_Dynamics.Length; i++) {
    S_Breakable_Dynamic prop;
    g_Breakable_Dynamics.GetArray(i, prop, sizeof(prop));
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
    S_Breakable_FuncBk breakable;
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
    g_Breakable_FuncBks.PushArray(breakable, sizeof(breakable));
  }
  // doors ...
  while ((ent = FindEntityByClassname(ent, "prop_door_rotating")) != -1) {
    S_Breakable_Door door;
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
    g_Breakable_Doors.PushArray(door, sizeof(door));
  }
  // vents ...
  while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1) {
    S_Breakable_Dynamic prop;
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
    g_Breakable_Dynamics.PushArray(prop, sizeof(prop));
  }
  PrintToServer("Saved %d funcbreakable entities.", g_Breakable_FuncBks.Length);
  PrintToServer("Saved %d propdoorrotating entities.", g_Breakable_Doors.Length);
  PrintToServer("Saved %d propdynamic entities.", g_Breakable_Dynamics.Length);
}

public void BackupFiles(const char[] data_dir) {
  char map[PLATFORM_MAX_PATH + 1];
  GetCleanMapName(map, sizeof(map));

  // Example: if kMaxBackupsPerMap == 30
  // Delete backups/de_dust2.30.cfg
  // Backup backups/de_dust.29.cfg -> backups/de_dust.30.cfg
  // Backup backups/de_dust.28.cfg -> backups/de_dust.29.cfg
  // ...
  // Backup backups/de_dust.1.cfg -> backups/de_dust.2.cfg
  // Backup de_dust.cfg -> backups/de_dust.1.cfg
  for (int version = kMaxBackupsPerMap; version >= 1; version--) {
    char olderPath[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, olderPath, sizeof(olderPath), "data/practicemode/%s/backups/%s.%d.cfg",
              data_dir, map, version);

    char newerPath[PLATFORM_MAX_PATH + 1];
    if (version == 1) {
      BuildPath(Path_SM, newerPath, sizeof(newerPath), "data/practicemode/%s/%s.cfg", data_dir,
                map);

    } else {
      BuildPath(Path_SM, newerPath, sizeof(newerPath), "data/practicemode/%s/backups/%s.%d.cfg",
                data_dir, map, version - 1);
    }

    if (version == kMaxBackupsPerMap && FileExists(olderPath)) {
      if (!DeleteFile(olderPath)) {
        PrintToServer("[BackupFiles]Failed to delete old backup file %s", olderPath);
      }
    }

    if (FileExists(newerPath)) {
      if (!RenameFile(olderPath, newerPath)) {
        PrintToServer("[BackupFiles]Failed to rename %s to %s", newerPath, olderPath);
      }
    }
  }
}

public void AddMapSpawnsForTeam(const char[] spawnClassName) {
  int SpawnGroup[6] = {-1, ...};
  // int minPriority = -1;
  // First pass over spawns to find minPriority.
  int ent = -1;
  // while ((ent = FindEntityByClassname(ent, spawnClassName)) != -1) {
  //   int priority = GetEntProp(ent, Prop_Data, "m_iPriority");
  //   if (priority < minPriority || minPriority == -1) {
  //     minPriority = priority;
  //   }
  // }
  // Second pass only adds spawns with the lowest priority to the list.
  ent = -1;
  while ((ent = FindEntityByClassname(ent, spawnClassName)) != -1) {
    // int priority = GetEntProp(ent, Prop_Data, "m_iPriority");
    int enabled = GetEntProp(ent, Prop_Data, "m_bEnabled");
    if (enabled) { //&& priority == minPriority
      SpawnGroup[0] = ent;
      g_Spawns.PushArray(SpawnGroup, sizeof(SpawnGroup));
    }
  }
}

stock Action TeleportToSpawn(int client, int args, int team) {
  float spawnOrigin[3], spawnAngles[3];
  int index;
  if (args >= 1) {
    char arg[16];
    GetCmdArg(args, arg, sizeof(arg));
    index = StringToInt(arg) - 1; // Actual index
    int spawnEnt = -1;
    if (team == CS_TEAM_CT) {
      if (0 <= index < g_SpawnsLengthCt) {
        spawnEnt = g_Spawns.Get(index, 0);
        PM_Message(client, "{ORANGE}Teletransportado a Spawn CT {GREEN}%d", index + 1);
      } else {
        PM_Message(client, "{ORANGE}Numero de Spawn no Válido {GREEN}[%d-%d]", 1, g_SpawnsLengthCt);
        return Plugin_Handled;
      }
    } else {
      index += g_SpawnsLengthCt;
      if (g_SpawnsLengthCt <= index < g_Spawns.Length) {
        spawnEnt = g_Spawns.Get(index, 0);
        PM_Message(client, "{ORANGE}Teletransportado a Spawn T {GREEN}%d", index + 1 - g_SpawnsLengthCt);
      } else {
        PM_Message(client, "{ORANGE}Numero de Spawn no Válido {GREEN}[%d-%d]", 1, g_Spawns.Length - g_SpawnsLengthCt);
        return Plugin_Handled;
      }
    }
    if (!IsValidEntity(spawnEnt)) {
      return Plugin_Handled;
    } else {
      Entity_GetAbsOrigin(spawnEnt, spawnOrigin);
      Entity_GetAbsAngles(spawnEnt, spawnAngles);
    }
  } else {
    float fOrigin[3];
    GetClientAbsOrigin(client, fOrigin);
    index = GetNearestSpawnEntsIndex(fOrigin, spawnOrigin, spawnAngles, team);
  }
  TeleportEntity(client, spawnOrigin, spawnAngles, {0.0, 0.0, 0.0});
  return Plugin_Handled;
}

public void Spawns_ExitPracticeMode() {
  RemoveHoloSpawnEntities();
}

public void UpdateHoloSpawnEntities() {
  RemoveHoloSpawnEntities();
  CreateHoloSpawnEntities();
}

public void RemoveHoloSpawnEntities() {
  for (int i = g_Spawns.Length - 1; i >= 0; i--) {
    int SpawnEnts[6];
    g_Spawns.GetArray(i, SpawnEnts, sizeof(SpawnEnts));
    for (int j=1; j<6; j++) {
      int ent = SpawnEnts[j]; // 0 is the info_player_ ent
      SpawnEnts[j] = -1;
      if (IsValidEntity(ent)) {
        AcceptEntityInput(ent, "Kill");
      }
    }
    g_Spawns.SetArray(i, SpawnEnts, sizeof(SpawnEnts));
  }
}

stock int GetNearestSpawnEntsIndex(
  const float origin[3],
  float nearestEntOrigin[3],
  float nearestEntAngles[3],
  int team = -1
  ) {
  int nearestIndex = -1;
  float distance = -1.0;
  float nearestDistance = -1.0;
  //Find all the entities and compare the distances
  int SpawnEnts[6];
  for (int index = 0; index < g_Spawns.Length; index++) {
    //for each of all current active entities
    g_Spawns.GetArray(index, SpawnEnts, sizeof(SpawnEnts));
    float entOrigin[3], entAngles[3];
    char entClassname[CLASS_LENGTH];
    Entity_GetClassName(SpawnEnts[0], entClassname, sizeof(entClassname));
    if (team != 1) {
      if (StrEqual(entClassname, "info_player_counterterrorist") && team == CS_TEAM_T) {
        continue;
      }
      if (StrEqual(entClassname, "info_player_terrorist") && team == CS_TEAM_CT) {
        continue;
      }
    }
    Entity_GetAbsOrigin(SpawnEnts[0], entOrigin);
    Entity_GetAbsAngles(SpawnEnts[0], entAngles);
    distance = GetVectorDistance(entOrigin, origin);
    if (distance < nearestDistance || nearestDistance == -1.0) {
      nearestIndex = index;
      nearestDistance = distance;
      nearestEntOrigin = entOrigin;
      nearestEntAngles = entAngles;
    }
  }
  return nearestIndex;
}

public void CreateHoloSpawnEntities() {
  char iStr[MAX_TARGET_LENGTH];
  for (int i = 0; i < g_Spawns.Length; i++) {
    int SpawnEnts[6];
    g_Spawns.GetArray(i, SpawnEnts, sizeof(SpawnEnts));
    int player_info_ent = SpawnEnts[0];
    if (IsValidEntity(player_info_ent)) {
      float vOrigin[3];
      Entity_GetAbsOrigin(player_info_ent, vOrigin);
      int triggerEnt = CreateEntityByName("trigger_multiple");
      IntToString(i, iStr, sizeof(iStr));
      DispatchKeyValue(triggerEnt, "spawnflags", "64"); // 1 ?
      DispatchKeyValue(triggerEnt, "wait", "0");
      DispatchKeyValue(triggerEnt, "targetname", iStr);
      DispatchSpawn(triggerEnt);
      ActivateEntity(triggerEnt);
      TeleportEntity(triggerEnt, vOrigin, NULL_VECTOR, NULL_VECTOR);
      SetEntPropVector(triggerEnt, Prop_Send, "m_vecMins", {-16.0, -16.0, 0.0});
      SetEntPropVector(triggerEnt, Prop_Send, "m_vecMaxs", {16.0, 16.0, 0.0});
      SetEntProp(triggerEnt, Prop_Send, "m_nSolidType", SOLID_BBOX);
      Entity_SetCollisionGroup(triggerEnt, COLLISION_GROUP_DEBRIS);
      SDKHook(triggerEnt, SDKHook_StartTouch, HologramSpawn_OnStartTouch);
      SDKHook(triggerEnt, SDKHook_EndTouch, HologramSpawn_OnEndTouch);
      SpawnEnts[1] = triggerEnt;
      float size = 16.0;
      float vMins[3], vMaxs[3];
      vMins[0] = -size; vMaxs[0] = size;
      vMins[1] = -size; vMaxs[1] = size;
      AddVectors(vOrigin, vMaxs, vMaxs);
      AddVectors(vOrigin, vMins, vMins);
      float vPos1[3], vPos2[3];
      vPos1 = vMaxs;
      vPos1[0] = vMins[0];
      vPos2 = vMaxs;
      vPos2[1] = vMins[1];
      SpawnEnts[2] = CreateBeam(vMins, vPos1);
      SpawnEnts[3] = CreateBeam(vPos1, vMaxs);
      SpawnEnts[4] = CreateBeam(vMaxs, vPos2);
      SpawnEnts[5] = CreateBeam(vPos2, vMins);
      g_Spawns.SetArray(i, SpawnEnts, sizeof(SpawnEnts));
    }
  }
}

public void StartClientTimer(int client) {
  g_Timer_LastCommand[client] = GetEngineTime();
  CreateTimer(0.1, Timer_DisplayClientTimer, GetClientSerial(client),
              TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void StopClientTimer(int client) {
  g_Timer_RunningCommand[client] = false;
  g_Timer_RunningLiveCommand[client] = false;

  // Only display the elapsed duration for increasing timers (not a countdown).
  E_TimerType timer_type = g_TimerType[client];
  if (timer_type == TimerType_Increasing_Manual || timer_type == TimerType_Increasing_Movement) {
    float dt = GetEngineTime() - g_Timer_LastCommand[client];
    // PM_Message(client, "Resultado Cronómetro: %.2f segundos", dt);
    PrintCenterText(client, "%t", "Time", client, dt);
  }
}

public Action Timer_DisplayClientTimer(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client) && g_Timer_RunningCommand[client]) {
    E_TimerType timer_type = g_TimerType[client];
    if (timer_type == TimerType_Countdown_Movement) {
      float time_left = g_Timer_Duration[client];
      if (g_Timer_RunningLiveCommand[client]) {
        float dt = GetEngineTime() - g_Timer_LastCommand[client];
        time_left -= dt;
      }
      if (time_left >= 0.0) {
        int seconds = RoundToCeil(time_left);
        PrintCenterText(client, "%t", "Time2", client, seconds / 60, seconds % 60);
      } else {
        StopClientTimer(client);
      }
      // TODO: can we clear the hint text here quicker? Perhaps an empty PrintHintText(client, "")
      // call works?
    } else {
      float dt = GetEngineTime() - g_Timer_LastCommand[client];
      PrintCenterText(client, "%t", "Time", client, dt);
    }
    return Plugin_Continue;
  }
  return Plugin_Stop;
}

public Action Timer_Botmimic_PauseRecording(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  g_Nade_PulledPin[client] = false;
  if (BotMimic_IsPlayerRecording(client)) {
    if (BotMimic_IsRecordingPaused(client)) {
      BotMimic_StopRecording(client, false); // delete
      PrintToServer("Error: Tried to Stop an already Stopped recording");
      return Plugin_Handled;
    }
    BotMimic_PauseRecording(client);
  }
  return Plugin_Handled;
}

public void TryGivePlayerMaxMoney(int client) {
  int maxMoney = GetCvarIntSafe("mp_maxmoney", 16000);
  if (g_InfiniteMoneyCvar.IntValue != 0 && !g_InDryMode) {
    if (IsPlayer(client)) {
      SetEntProp(client, Prop_Send, "m_iAccount", maxMoney);
    }
  }
}

public void PerformNoclipAction(int client) {
  // The move type is also set on the next frame. This is a dirty trick to deal
  // with clients that have a double-bind of "noclip; say .noclip" to work on both
  // ESEA-practice and local sv_cheats servers. Since this plugin can have both enabled
  // (sv_cheats and allow noclip), this double bind would cause the noclip type to be toggled twice.
  // Therefore the fix is to only perform 1 noclip action per-frame per-client at most, implemented
  // by saving the frame count of each use in g_LastNoclipCommand.
  if (g_LastNoclipCommand[client] == GetGameTickCount() ||
      (g_AllowNoclipCvar.IntValue == 0 && GetCvarIntSafe("sv_cheats") == 0)) {
    return;
  }

  if (GetCvarIntSafe("sm_allow_noclip") == 0) {
    SetEntityMoveType(client, MOVETYPE_WALK);
    return;
  }

  // Stop recording if we are.
  if (g_BotMimicLoaded && g_InBotDemoMode) {
    FinishRecordingDemo(client, false);
  }

  g_LastNoclipCommand[client] = GetGameTickCount();
  MoveType t = GetEntityMoveType(client);
  MoveType next = (t == MOVETYPE_WALK) ? MOVETYPE_NOCLIP : MOVETYPE_WALK;
  SetEntityMoveType(client, next);

  if (next == MOVETYPE_WALK) {
    SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
  } else {
    SetEntProp(client, Prop_Data, "m_CollisionGroup", 0);
  }
}

public void LaunchPracticeMode() {
  g_InPracticeMode = true;
  ServerCommand("exec practicemode.cfg");
  SetConVarFloatSafe("mp_roundtime_defuse", 60.0);
  SetCvarIntSafe("mp_radar_showall", 1);
  SetCvarIntSafe("sm_glow_pmbots", 1);
  SetCvarIntSafe("mp_ignore_round_win_conditions", 1);
  SetCvarIntSafe("sv_grenade_trajectory", 1);
  SetCvarIntSafe("sv_infinite_ammo", 1);
  SetCvarIntSafe("sm_allow_noclip", 1);
  SetCvarIntSafe("mp_respawn_on_death_ct", 1);
  SetCvarIntSafe("mp_respawn_on_death_t", 1);
  SetCvarIntSafe("sv_showimpacts", 1);
  SetCvarIntSafe("sm_holo_spawns", 1);
  SetCvarIntSafe("sm_bot_collision", 0);
  SetCvarIntSafe("mp_suicide_time", 0);
  SetCvarIntSafe("mp_suicide_penalty", 0);
  SetCvarIntSafe("bot_difficulty", 3);

  HoloNade_LaunchPracticeMode();

  // PM_MessageToAll("Modo Práctica esta activado.");
  Call_StartForward(g_OnPracticeModeEnabled);
  Call_Finish();
}

public void ExitPracticeMode() {
  if (!g_InPracticeMode) {
    return;
  }

  Call_StartForward(g_OnPracticeModeDisabled);
  Call_Finish();

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && IsFakeClient(i) && IsPracticeBot(i)) {
      KickClient(i);
      SetNotPracticeBot(i);
    }
  }

  SetCvarIntSafe("mp_startmoney", 800);
  SetConVarFloatSafe("mp_roundtime_defuse", 1.92);
  SetCvarIntSafe("mp_freezetime", g_DryRunFreezeTimeCvar.IntValue);
  SetCvarIntSafe("mp_radar_showall", 0);
  SetCvarIntSafe("sm_glow_pmbots", 0);
  SetCvarIntSafe("sv_grenade_trajectory", 0);
  SetCvarIntSafe("mp_ignore_round_win_conditions", 0);
  SetCvarIntSafe("sv_grenade_trajectory", 0);
  SetCvarIntSafe("sv_infinite_ammo", 0);
  SetCvarIntSafe("sm_allow_noclip", 0);
  SetCvarIntSafe("mp_respawn_on_death_ct", 0);
  SetCvarIntSafe("mp_respawn_on_death_t", 0);
  // SetCvarIntSafe("mp_buy_anywhere", 0);
  // SetCvarIntSafe("mp_buytime", 40);
  SetCvarIntSafe("sv_showimpacts", 0);
  SetCvarIntSafe("sm_holo_spawns", 0);
  SetCvarIntSafe("sm_bot_collision", 1);
  SetCvarIntSafe("mp_suicide_time", 0);
  SetCvarIntSafe("mp_suicide_penalty", 0);
  SetCvarIntSafe("bot_difficulty", 3);
  
  SetConVarStringSafe("sv_password", "");

  g_InPracticeMode = false;
  g_PracticeSetupClient = -2;

  // force turn noclip off for everyone
  for (int i = 1; i <= MaxClients; i++) {
    g_TestingFlash[i] = false;
    if (IsValidClient(i)) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  HoloNade_ExitPracticeMode();
  Spawns_ExitPracticeMode();
  // PM_MessageToAll("Modo Práctica esta desactivado.");
}

public void TryCleanDroppedWeapons() {
  if (!g_CleaningDroppedWeapons) {
    CreateTimer(0.5, Timer_CleanUpDroppedWeapons, _, TIMER_FLAG_NO_MAPCHANGE);
    g_CleaningDroppedWeapons = true;
  }
}

public Action Timer_CleanUpDroppedWeapons(Handle timer, any data) {
  // By Kigen (c) 2008 - Please give me credit. :)
  int maxent = GetMaxEntities();
  char weapon[64];
  for (int i = MaxClients; i < maxent; i++) {
    if (IsValidEdict(i) && IsValidEntity(i)) {
      GetEdictClassname(i, weapon, sizeof(weapon));
      if ((StrContains(weapon, "weapon_") != -1 || StrContains(weapon, "item_") != -1 )) {
        if (HasEntProp(i, Prop_Data, "m_hOwner")) {
          if (Weapon_GetOwner(i) != -1) {
            continue;
          }
        }
        AcceptEntityInput(i, "Kill");
      }
    }
  }
  g_CleaningDroppedWeapons = false;
  return Plugin_Handled;
}

public Action Timer_TeleportClient(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (g_InPracticeMode && IsPlayer(client) && g_TestingFlash[client]) {
    float velocity[3];
    TeleportEntity(client, g_TestingFlash_Origins[client], g_TestingFlash_Angles[client], velocity);
    SetEntityMoveType(client, MOVETYPE_NONE);
  }
  return Plugin_Handled;
}

public void KillFlashEffect(int serial) {
  int client = GetClientFromSerial(serial);
  // Idea used from SAMURAI16 @ https://forums.alliedmods.net/showthread.php?p=685111
  SetEntDataFloat(client, FindSendPropInfo("CCSPlayer", "m_flFlashMaxAlpha"), 0.5);
}

public void OnGrenadeKvMutate() {
  HoloNade_GrenadeKvMutate();
}

public void CheckAutoStart() {
  // Autostart practicemode if enabled.
  if (g_AutostartCvar.IntValue != 0 && !g_InPracticeMode) {
    LaunchPracticeMode();
  }
}

stock void Dev_SpawnGrenade(
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
  Entity_GetAbsVelocity(client, clientvelocity);
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
  CloseHandle(trace);

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
      Entity_SetCollisionGroup(grenadeTest, COLLISION_GROUP_PROJECTILE);
      TeleportEntity(grenadeTest, predictednadepos, NULL_VECTOR, predictednadevel);
    }
  }
}

public Action Timer_FakeGrenadeBack(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (g_InPracticeMode && IsPlayer(client)) {
    FakeClientCommand(client, "sm_lastgrenade");
  }
  return Plugin_Handled;
}

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] chatCommand,
                           const char[] chatArgs, int client) {
  if (StrEqual(chatCommand, alias, false)) {
    // Get the original cmd reply source so it can be restored after the fake client command.
    // This means and ReplyToCommand will go into the chat area, rather than console, since
    // chat aliases are for chat commands.
    ReplySource replySource = GetCmdReplySource();
    SetCmdReplySource(SM_REPLY_TO_CHAT);
    char fakeCommand[256];
    Format(fakeCommand, sizeof(fakeCommand), "%s %s", command, chatArgs);
    FakeClientCommand(client, fakeCommand);
    SetCmdReplySource(replySource);
    return true;
  }
  return false;
}

stock void ShowHelpInfo(int client, int page = 1) {
  PM_Message(client, "{PURPLE}Lista de Comandos (%d): ", page);
  if (page == 1) {
    PM_Message(client, "{ORANGE}\".setup\"");
    PM_Message(client, "{ORANGE}\".map\"");
    PM_Message(client, "{ORANGE}\".kick\"");
    PM_Message(client, "{ORANGE}\".help\"");
    PM_Message(client, "{PURPLE}\".bots\", \".bot\"");
    PM_Message(client, "{ORANGE}  \".nobots\"");
    PM_Message(client, "{PURPLE}\".demo\", \".demos\"");
    PM_Message(client, "{ORANGE}  \".stop\"");
    PM_Message(client, "{PURPLE}\".nades\", \".grenades\", \".smokes\"");
    PM_Message(client, "{ORANGE}  \".throw\", \".rethrow\"");
    PM_Message(client, "{ORANGE}  \".trajectory\", \".traj\"");
    PM_Message(client, "{ORANGE}  \".back\"");
    PM_Message(client, "{ORANGE}  \".next\"");
    PM_Message(client, "{ORANGE}  \".last\"");
    PM_Message(client, "{ORANGE}  \".pred\"");
    PM_Message(client, "{ORANGE}  \".predmenu\"");
    PM_Message(client, "{ORANGE}  \".noflash\"");
    PM_Message(client, "{ORANGE}  \".clear\", \".clearsmokes\"");
    PM_Message(client, "{ORANGE}  \".copy\"");
    PM_Message(client, "{ORANGE}\".spawn\", \".spawns\", \".ctspawn\", \".tspawn\"");
    PM_Message(client, "{ORANGE}\".spec\", \".spect\", \".t\", \".ct\"");
    PM_Message(client, "{ORANGE}\".rr\", \".restart\"");
    PM_Message(client, "{ORANGE}\".dry\"");
    PM_Message(client, "{ORANGE}\".clearmap\", \".cleanmap\"");
    // PM_Message(client, "\".prueba\"");
    // PM_Message(client, "\".preddata\"");
    // char setupClientName[MAX_NAME_LENGTH];
    // if (IsPlayer(g_PracticeSetupClient)) {
    //   GetClientName(g_PracticeSetupClient, setupClientName, MAX_NAME_LENGTH);
    // }
    // PM_Message(client, "%t", "Help_Setup", setupClientName);
    // PM_Message(client, "%t", "Help_Menu");
    // PM_Message(client, "%t", "Help_Save");
    // PM_Message(client, "%t", "Help_Copy");
    // PM_Message(client, "%t", "Help_Throw");
    // PM_Message(client, "%t", "Help_Flash");
    // PM_Message(client, "%t", "Help_Last");
    // PM_Message(client, "%t", "Help_Clear");
    // PM_Message(client, "%t", "Help_ClearMap");
    // PM_Message(client, "%t", "Help_Map");
    // PM_Message(client, "%t", "Help_Bots");
    // PM_Message(client, "%t", "Help_Predict1");
    // PM_Message(client, "%t", "Help_Predict2");
    // PM_Message(client, "%t", "Help_Predict3");
    // PM_Message(client, "%t", "Help_Predict4");
    // PM_Message(client, "%t", "Help_Page");
  } else if (page == 2) {
    PM_Message(client, "{ORANGE}\".respawn\"");
    PM_Message(client, "{ORANGE}\".god\"");
    PM_Message(client, "{ORANGE}\".break\"");
    PM_Message(client, "{ORANGE}\".cancel\"");
    PM_Message(client, "{ORANGE}\".finish\"");
    PM_Message(client, "{ORANGE}\".save\"");
    PM_Message(client, "{ORANGE}\".import\"");
    PM_Message(client, "{PURPLE}\".editretakes\"");
    PM_Message(client, "{ORANGE}  \".retakes\", \".retake\"");
    PM_Message(client, "{PURPLE}\".editcrossfires\"");
    PM_Message(client, "{ORANGE}  \".crossfires\", \".crossfire\"");
    PM_Message(client, "{ORANGE}\".flash\"");
    PM_Message(client, "{ORANGE}\".timer\"");
    PM_Message(client, "{ORANGE}\".timer2\"");
    PM_Message(client, "{ORANGE}\".countdown\"");
    // PM_Message(client, "%t", "Help_Back");
    // PM_Message(client, "%t", "Help_Next");
    // PM_Message(client, "%t", "Help_NoFlash");
    // PM_Message(client, "%t", "Help_Timer");
    // PM_Message(client, "%t", "Help_God");
    // PM_Message(client, "%t", "Help_RR");
  }
}

bool IsPracticeSetupClient(int client) {
  if (client != g_PracticeSetupClient) {
    if (IsPlayer(g_PracticeSetupClient)) {
      PM_Message(client, "{ORANGE}Cliente con permisos de Administrador: {NORMAL}%N.", g_PracticeSetupClient);
      return false;
    } else {
      PrintToServer("ERROR: %d not valid, %N promoted to SetupClient", g_PracticeSetupClient , client);
      g_PracticeSetupClient = client;
    }
  }
  return true;
}

public void MaybeWriteNewGrenadeData() {
  if (g_Nade_UpdatedKv) {
    g_NadesKv.Rewind();
    BackupFiles("grenades");
    DeleteFile(g_Nade_LocationsFile);
    if (!g_NadesKv.ExportToFile(g_Nade_LocationsFile)) {
      PrintToServer("[MaybeWriteNewGrenadeData]Failed to write grenade data to %s", g_Nade_LocationsFile);
    }
    g_Nade_UpdatedKv = false;
  }
}

/*******************************************************************/
/* Helpers and Natives */
/*******************************************************************/

stock bool CheckClientIsAfk(int client) {
	float origin[3], angles[3];
	GetClientAbsOrigin(client, origin);
	GetClientEyeAngles(client, angles);
	if (VecEqual(origin, g_AFK_LastPosition[client]) && VecEqual(angles, g_AFK_LastEyeAngle[client])) {
		return true;
	}
	g_AFK_LastPosition[client] = origin;
	g_AFK_LastEyeAngle[client] = angles;
	return false;
}

public int CreateBeam(float origin[3], float end[3]) {
  int beament = CreateEntityByName("env_beam");
  SetEntityModel(beament, "sprites/laserbeam.spr");
  SetEntityRenderColor(beament, 255, 0, 0, 255);
  TeleportEntity(beament, origin, NULL_VECTOR, NULL_VECTOR); // Teleport the beam
  SetEntPropVector(beament, Prop_Data, "m_vecEndPos", end);
  DispatchKeyValue(beament, "texture", "sprites/laserbeam.spr");
  SetEntPropFloat(beament, Prop_Data, "m_fWidth", 1.0);
  SetEntPropFloat(beament, Prop_Data, "m_fEndWidth", 1.0);
  AcceptEntityInput(beament,"TurnOn");
  return beament;
}

stock void ForceGlow(int parentEnt) {
  int glowEnt = CreateEntityByName("prop_dynamic_override");
  if (glowEnt > 0) {
    char entModel[512];
    Entity_GetModel(parentEnt, entModel, sizeof(entModel));
    DispatchKeyValue(glowEnt, "classname", "prop_dynamic_override");
    DispatchKeyValue(glowEnt, "spawnflags", "1");
    DispatchKeyValue(glowEnt, "renderamt", "255");
    DispatchKeyValue(glowEnt, "rendermode", "1");
    DispatchKeyValue(glowEnt, "model", entModel);
    if (DispatchSpawn(glowEnt)) {
      float origin[3], angles[3];
      Entity_GetAbsOrigin(parentEnt, origin);
      Entity_GetAbsAngles(parentEnt, angles);
      TeleportEntity(glowEnt, origin, angles, NULL_VECTOR);
      SetEntProp(glowEnt, Prop_Send, "m_bShouldGlow", true, true);
      SetEntProp(glowEnt, Prop_Send, "m_nGlowStyle", 0);
      SetEntPropFloat(glowEnt, Prop_Send, "m_flGlowMaxDist", 10000.0);
      SetVariantString("!activator");
      AcceptEntityInput(glowEnt, "SetParent", parentEnt);
    }
  }
}

stock void CleanMsgString(char[] msg, int size) {
  ReplaceString(msg, size, "%", "％");
  StripQuotes(msg);
}

static bool MovingButtons(int buttons) {
  return buttons & IN_FORWARD != 0 || buttons & IN_MOVELEFT != 0 || buttons & IN_MOVERIGHT != 0 ||
         buttons & IN_BACK != 0;
}

void PrecacheParticle(const char[] sEffectName) {
	static int table = INVALID_STRING_TABLE;
	if (table == INVALID_STRING_TABLE) {
		table = FindStringTable("ParticleEffectNames");
	}

	if (FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX) {
		bool save = LockStringTables(false);
		AddToStringTable(table, sEffectName);
		LockStringTables(save);
	}
}

public int Native_StartPracticeMode(Handle plugin, int numParams) {
  if (g_InPracticeMode) {
    return false;
  } else {
    LaunchPracticeMode();
    return true;
  }
}

public int Native_ExitPracticeMode(Handle plugin, int numParams) {
  if (g_InPracticeMode) {
    ExitPracticeMode();
    return true;
  } else {
    return false;
  }
}

public int Native_IsPracticeModeEnabled(Handle plugin, int numParams) {
  return g_InPracticeMode;
}

public int Native_Message(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  if (client != 0 && (!IsClientConnected(client) || !IsClientInGame(client)))
    return 0;

  char buffer[1024];
  int bytesWritten = 0;
  SetGlobalTransTarget(client);
  FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

  char prefix[64] = MESSAGE_PREFIX;

  char finalMsg[1024];
  if (StrEqual(prefix, ""))
    Format(finalMsg, sizeof(finalMsg), " %s", buffer);
  else
    Format(finalMsg, sizeof(finalMsg), "%s %s", prefix, buffer);

  if (client == 0) {
    Colorize(finalMsg, sizeof(finalMsg), false);
    PrintToConsole(client, finalMsg);
  } else if (IsClientInGame(client)) {
    Colorize(finalMsg, sizeof(finalMsg));
    PrintToChat(client, finalMsg);
  }
  return 0;
}

public int Native_MessageToAll(Handle plugin, int numParams) {
  char prefix[64] = MESSAGE_PREFIX;
  char buffer[1024];
  int bytesWritten = 0;

  for (int i = 0; i <= MaxClients; i++) {
    if (i != 0 && (!IsClientConnected(i) || !IsClientInGame(i)))
      continue;

    SetGlobalTransTarget(i);
    FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

    char finalMsg[1024];
    if (StrEqual(prefix, ""))
      Format(finalMsg, sizeof(finalMsg), " %s", buffer);
    else
      Format(finalMsg, sizeof(finalMsg), "%s %s", prefix, buffer);

    if (i != 0) {
      Colorize(finalMsg, sizeof(finalMsg));
      PrintToChat(i, finalMsg);
    } else {
      Colorize(finalMsg, sizeof(finalMsg), false);
      PrintToConsole(i, finalMsg);
    }
  }
  return 0;
}

public int Native_AddChatAlias(Handle plugin, int numParams) {
  char alias[ALIAS_LENGTH];
  char command[COMMAND_LENGTH];
  GetNativeString(1, alias, sizeof(alias));
  GetNativeString(2, command, sizeof(command));

  // don't allow duplicate aliases to be added
  if (g_ChatAliases.FindString(alias) == -1) {
    g_ChatAliases.PushString(alias);
    g_ChatAliasesCommands.PushString(command);
  }
  return 0;
}
