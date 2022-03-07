public Action Command_LaunchPracticeMode(int client, int args) {
  if (!CanStartPracticeMode(client)) {
    // PM_Message(client, "You cannot start practice mode right now.");
    return Plugin_Handled;
  }

  if (!g_InPracticeMode) {
    if (g_PugsetupLoaded && PugSetup_GetGameState() >= GameState_Warmup) {
      return Plugin_Continue;
    }
    LaunchPracticeMode();
    if (IsPlayer(client)) {
      GivePracticeMenu(client);
    }
  }
  return Plugin_Handled;
}

public Action Command_ExitPracticeMode(int client, int args) {
  if (g_InPracticeMode) {
    ExitPracticeMode();
  }
  return Plugin_Handled;
}

public Action Command_NoFlash(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  g_ClientNoFlash[client] = !g_ClientNoFlash[client];
  if (g_ClientNoFlash[client]) {
    // PM_Message(client, "Noflash activado. Usa .noflash de nuevo para desactivar.");
    RequestFrame(KillFlashEffect, GetClientSerial(client));
  } else {
    // PM_Message(client, "Noflash desactivado.");
  }
  return Plugin_Handled;
}

public Action Command_Time(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_RunningTimeCommand[client]) {
    // Start command.
    PM_Message(client, "El cronómetro empezará cuando te muevas y terminará cuando pares.");
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = false;
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

  if (!g_RunningTimeCommand[client]) {
    // Start command.
    PM_Message(client, "Escribe .timer2 para parar el cronometro.");
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = false;
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

  float timer_duration = float(GetRoundTimeSeconds());
  char arg[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    timer_duration = StringToFloat(arg);
  }

  PM_Message(client, "El cronómetro empezará cuando te muevas y terminará cuando escribar .stop");
  g_RunningTimeCommand[client] = true;
  g_RunningLiveTimeCommand[client] = false;
  g_TimerType[client] = TimerType_Countdown_Movement;
  g_TimerDuration[client] = timer_duration;
  StartClientTimer(client);

  return Plugin_Handled;
}

public void StartClientTimer(int client) {
  g_LastTimeCommand[client] = GetEngineTime();
  CreateTimer(0.1, Timer_DisplayClientTimer, GetClientSerial(client),
              TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void StopClientTimer(int client) {
  g_RunningTimeCommand[client] = false;
  g_RunningLiveTimeCommand[client] = false;

  // Only display the elapsed duration for increasing timers (not a countdown).
  TimerType timer_type = g_TimerType[client];
  if (timer_type == TimerType_Increasing_Manual || timer_type == TimerType_Increasing_Movement) {
    float dt = GetEngineTime() - g_LastTimeCommand[client];
    PM_Message(client, "Resultado Cronómetro: %.2f segundos", dt);
    PrintCenterText(client, "Tiempo: %.2f segundos", dt);
  }
}

public Action Timer_DisplayClientTimer(Handle timer, int serial) {
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client) && g_RunningTimeCommand[client]) {
    TimerType timer_type = g_TimerType[client];
    if (timer_type == TimerType_Countdown_Movement) {
      float time_left = g_TimerDuration[client];
      if (g_RunningLiveTimeCommand[client]) {
        float dt = GetEngineTime() - g_LastTimeCommand[client];
        time_left -= dt;
      }
      if (time_left >= 0.0) {
        int seconds = RoundToCeil(time_left);
        PrintCenterText(client, "Tiempo: %d:%2d", seconds / 60, seconds % 60);
      } else {
        StopClientTimer(client);
      }
      // TODO: can we clear the hint text here quicker? Perhaps an empty PrintHintText(client, "")
      // call works?
    } else {
      float dt = GetEngineTime() - g_LastTimeCommand[client];
      PrintCenterText(client, "Tiempo: %.1f segundos", dt);
    }
    return Plugin_Continue;
  }
  return Plugin_Stop;
}

public Action Command_Respawn(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!IsPlayerAlive(client)) {
    CS_RespawnPlayer(client);
    return Plugin_Handled;
  }

  g_SavedRespawnActive[client] = true;
  GetClientAbsOrigin(client, g_SavedRespawnOrigin[client]);
  GetClientEyeAngles(client, g_SavedRespawnAngles[client]);
  PM_Message(
      client,
      "Saved respawn point. When you die will you respawn here, use {GREEN}.stop {NORMAL}to cancel.");
  return Plugin_Handled;
}

public Action Command_StopRespawn(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  g_SavedRespawnActive[client] = false;
  PM_Message(client, "Cancelled respawning at your saved position.");
  return Plugin_Handled;
}

public Action Command_Spec(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  FakeClientCommand(client, "jointeam 1");
  return Plugin_Handled;
}

public Action Command_JoinT(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  FakeClientCommand(client, "jointeam 2");
  return Plugin_Handled;
}

public Action Command_JoinCT(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  FakeClientCommand(client, "jointeam 3");
  return Plugin_Handled;
}

public Action Command_StopAll(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (g_SavedRespawnActive[client]) {
    Command_StopRespawn(client, 0);
  }
  if (g_TestingFlash[client]) {
    g_TestingFlash[client] = false;
  }
  if (g_RunningTimeCommand[client]) {
    StopClientTimer(client);
  }
  if (g_BotMimicLoaded && IsReplayPlaying()) {
    //CancelAllReplays();
    ExitReplayMode();
  }
  if (g_BotMimicLoaded && BotMimic_IsPlayerRecording(client)) {
    BotMimic_StopRecording(client, false /* save */);
  }
  // if (LearnIsActive(client)) {
  //   Command_StopLearn(client, 0);
  // }
  return Plugin_Handled;
}

public Action Command_ClearNades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  CEffectData smokeData;
  smokeData.m_nEntIndex = 0;
  smokeData.m_nHitBox = GetParticleSystemIndex("explosion_smokegrenade_fallback");
  DispatchEffect("ParticleEffectStop", smokeData);
  int smokeEnt = -1;
  while ((smokeEnt = FindEntityByClassname(smokeEnt, "smokegrenade_projectile")) != -1) {
    StopSound(smokeEnt, SNDCHAN_STATIC, "~)weapons/smokegrenade/smoke_emit.wav");
    StopSound(smokeEnt, SNDCHAN_STATIC, "weapons/smokegrenade/smoke_emit.wav");
    AcceptEntityInput(smokeEnt, "Kill");
  }

  int infernoEnt = -1;
  CEffectData infernoData;
  infernoData.m_nEntIndex = 0;
  infernoData.m_nHitBox = GetParticleSystemIndex("molotov_groundfire_fallback2");
  DispatchEffect("ParticleEffectStop", infernoData);
  while ((infernoEnt = FindEntityByClassname(infernoEnt, "inferno")) != -1) {
    StopSound(smokeEnt, SNDCHAN_STATIC, "~)weapons/molotov/fire_loop_1.wav");
    StopSound(smokeEnt, SNDCHAN_STATIC, "weapons/molotov/fire_loop_1.wav");
    AcceptEntityInput(infernoEnt, "Kill");
  }
  
  return Plugin_Handled;
}

public Action Timer_ResetTimescale(Handle timer) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  SetCvar("host_timescale", 1);

  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      SetEntityMoveType(i, g_PreFastForwardMoveTypes[i]);
    }
  }
  return Plugin_Handled;
}

public Action Command_Map(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  if (client != g_PracticeSetupClient) {
    if (IsPlayer(g_PracticeSetupClient)) {
      PM_Message(client, "{ORANGE}Cliente con permisos de Administrador: {NORMAL}%N.", g_PracticeSetupClient);
      return Plugin_Handled;
    } else {
      LogError("ERROR: %d not valid, %N promoted to SetupClient", g_PracticeSetupClient , client);
      g_PracticeSetupClient = client;
    }
  }
  char arg[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    // Before trying to change to the arg first, check to see if
    // there's a clear match in the maplist
    for (int i = 0; i < g_MapList.Length; i++) {
      char map[PLATFORM_MAX_PATH];
      g_MapList.GetString(i, map, sizeof(map));
      if (StrContains(map, arg, false) >= 0) {
        ChangeMap(map);
        return Plugin_Handled;
      }
    }
  }
  Menu menu = new Menu(ChangeMapHandler);
  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.SetTitle("Selecciona un mapa:");
  for (int i = 0; i < g_MapList.Length; i++) {
    char map[PLATFORM_MAX_PATH];
    g_MapList.GetString(i, map, sizeof(map));
    char cleanedMapName[PLATFORM_MAX_PATH];
    CleanMapName(map, cleanedMapName, sizeof(cleanedMapName));
    AddMenuInt(menu, i, cleanedMapName);
  }
  DisplayMenu(menu, client, MENU_TIME_FOREVER);

  return Plugin_Handled;
}

public int ChangeMapHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int index = GetMenuInt(menu, param2);
    char map[PLATFORM_MAX_PATH];
    g_MapList.GetString(index, map, sizeof(map));
    ChangeMap(map);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public void ChangeSettingById(const char[] id, bool setting) {
  for (int i = 0; i < g_BinaryOptionIds.Length; i++) {
    char name[OPTION_NAME_LENGTH];
    g_BinaryOptionIds.GetString(i, name, sizeof(name));
    if (StrEqual(name, id, false)) {
      ChangeSetting(i, setting);
    }
  }
}

public Action Command_DryRun(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  SetCvar("mp_freezetime", g_DryRunFreezeTimeCvar.IntValue);
  ChangeSettingById("allradar", false);
  ChangeSettingById("glowbots", false);
  ChangeSettingById("blockroundendings", false);
  ChangeSettingById("grenadetrajectory", false);
  ChangeSettingById("infiniteammo", false);
  ChangeSettingById("noclip", false);
  ChangeSettingById("respawning", false);
  ChangeSettingById("showimpacts", false);

  for (int i = 1; i <= MaxClients; i++) {
    g_TestingFlash[i] = false;
    g_SavedRespawnActive[i] = false;
    g_ClientNoFlash[client] = false;
    if (IsPlayer(i)) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  ServerCommand("mp_restartgame 1");
  return Plugin_Handled;
}

static void ChangeSettingArg(int client, const char[] arg, bool enabled) {
  if (StrEqual(arg, "all", false)) {
    for (int i = 0; i < g_BinaryOptionIds.Length; i++) {
      ChangeSetting(i, enabled);
    }
    return;
  }

  ArrayList indexMatches = new ArrayList();
  for (int i = 0; i < g_BinaryOptionIds.Length; i++) {
    char name[OPTION_NAME_LENGTH];
    g_BinaryOptionNames.GetString(i, name, sizeof(name));
    if (StrContains(name, arg, false) >= 0) {
      indexMatches.Push(i);
    }
  }

  if (indexMatches.Length == 0) {
    PM_Message(client, "No settings matched \"%s\"", arg);
  } else if (indexMatches.Length == 1) {
    if (!ChangeSetting(indexMatches.Get(0), enabled)) {
      PM_Message(client, "That is already enabled.");
    }
  } else {
    PM_Message(client, "Multiple settings matched \"%s\"", arg);
  }

  delete indexMatches;
}

public Action Command_Enable(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char arg[128];
  GetCmdArgString(arg, sizeof(arg));
  ChangeSettingArg(client, arg, true);
  return Plugin_Handled;
}

public Action Command_Disable(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char arg[128];
  GetCmdArgString(arg, sizeof(arg));
  ChangeSettingArg(client, arg, false);
  return Plugin_Handled;
}

public Action Command_God(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!GetCvarIntSafe("sv_cheats")) {
    PM_Message(client, ".god requiere que sv_cheats este activado.");
    return Plugin_Handled;
  }

  FakeClientCommand(client, "god");
  return Plugin_Handled;
}

public Action Command_Break(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int ent = -1;
  while ((ent = FindEntityByClassname(ent, "func_breakable")) != -1) {
    AcceptEntityInput(ent, "Break");
  }
  while ((ent = FindEntityByClassname(ent, "prop_dynamic")) != -1) {
    AcceptEntityInput(ent, "Break");
  }

  PM_MessageToAll("Broke all breakable entities.");
  return Plugin_Handled;
}

public Action Command_Restart(int client, int args){
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char argString[256];
  GetCmdArgString(argString, sizeof(argString));
  int freezeTime = StringToInt(argString);
  ServerCommand("mp_freezetime %d", freezeTime);

  for (int i = 1; i <= MaxClients; i++) {
    g_TestingFlash[i] = false;
    g_SavedRespawnActive[i] = false;
    g_ClientNoFlash[client] = false;
    if (IsPlayer(i)) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  ServerCommand("mp_restartgame 1");
  return Plugin_Handled;
}
