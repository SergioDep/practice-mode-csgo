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

  g_ClientNoFlash[client] = !g_ClientNoFlash[client];
  if (g_ClientNoFlash[client]) {
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

  if (!g_RunningTimeCommand[client]) {
    // Start command.
    PM_Message(client, "%t", "Timer1");
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
    PM_Message(client, "%t", "Timer2");
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

  // float timer_duration = float(GetRoundTimeSeconds());
  // char arg[PLATFORM_MAX_PATH];
  // if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
  //   timer_duration = StringToFloat(arg);
  // }

  // PM_Message(client, "El cronómetro empezará cuando te muevas y terminará cuando escribar .stop");
  // g_RunningTimeCommand[client] = true;
  // g_RunningLiveTimeCommand[client] = false;
  // g_TimerType[client] = TimerType_Countdown_Movement;
  // g_TimerDuration[client] = timer_duration;
  // StartClientTimer(client);

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
    // PM_Message(client, "Resultado Cronómetro: %.2f segundos", dt);
    PrintCenterText(client, "%t", "Time", client, dt);
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
        PrintCenterText(client, "%t", "Time2", client, seconds / 60, seconds % 60);
      } else {
        StopClientTimer(client);
      }
      // TODO: can we clear the hint text here quicker? Perhaps an empty PrintHintText(client, "")
      // call works?
    } else {
      float dt = GetEngineTime() - g_LastTimeCommand[client];
      PrintCenterText(client, "%t", "Time", client, dt);
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
  if (g_RunningTimeCommand[client]) {
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
        g_LastGrenadeEntity[i] = -1;
        g_ClientGrenadeThrowTimes[i].Clear()
      }
    }
  } else {
    g_LastGrenadeEntity[client] = -1;
    g_ClientGrenadeThrowTimes[client].Clear()
  }
  
  return Plugin_Handled;
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

static char _mapNames[][] = {"Dust2", "Inferno", "Mirage",
                              "Nuke", "Overpass", "Train", "Vertigo", "Cache", "Cobble"};
static char _mapCodes[][] = {"de_dust2", "de_inferno", "de_mirage",
                              "de_nuke", "de_overpass", "de_train", "de_vertigo", "de_cache", "de_cbble"};

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

public Action Command_

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
      g_ClientNoFlash[client] = false;
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
    g_ClientNoFlash[client] = false;
    if (IsPlayer(i)) {
      SetEntityMoveType(i, MOVETYPE_WALK);
    }
  }

  ServerCommand("mp_restartgame 1");
  return Plugin_Handled;
}
