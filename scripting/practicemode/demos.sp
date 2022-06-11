//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Commands */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/




public Action Command_DemosMenu(int client, int args) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }

  if (!g_BotMimicLoaded) {
    PrintToServer("You need the botmimic plugin loaded to use demo functions.");
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PrintToServer("You need the csutils plugin loaded to use demo functions.");
    return Plugin_Handled;
  }

  if (!g_InBotDemoMode) {
    Command_DemoCancel(client, 0);
    InitDemoFunctions();
  }

  SetCvarIntSafe("mp_respawn_on_death_ct", 0);
  SetCvarIntSafe("mp_respawn_on_death_t", 0);
  SetCvarIntSafe("mp_suicide_penalty", 0);
  SetCvarIntSafe("mp_suicide_time", 0);

  GiveDemoMenuInContext(client);
  return Plugin_Handled;
}

public Action Command_DemoCancel(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int numActiveDemos = 0;
  for (int i = 0; i < g_DemoBots.Length; i++) {
    int bot = g_DemoBots.Get(i);
    if (IsDemoBot(bot) && BotMimic_IsPlayerMimicing(bot)) {
      numActiveDemos++;
    }
  }

  if (g_RecordingFullDemo) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && BotMimic_IsPlayerRecording(i)) {
        BotMimic_StopRecording(client, false /* save */);
      }
    }
  } else if (BotMimic_IsPlayerRecording(client)) {
    BotMimic_StopRecording(client, false /* save */);
  } else if (numActiveDemos > 0) {
    CancelAllDemos();
    PM_MessageToAll("{ORANGE}Se Quitaron Todas las Demos Activas.");
  }

  return Plugin_Handled;
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

stock void DemosMenu(int client) {
  Menu menu = new Menu(DemosMenuHandler);
  menu.SetTitle("Menu de Demos");
  menu.AddItem("record_new", "Grabar Nuevo Demo");
  menu.AddItem("show_list", "Lista de Demos Grabadas");
  char gameModeDisplayStr[OPTION_NAME_LENGTH];
  BMGameMode bmGameMode = BotMimic_GetGameMode();
  Format(gameModeDisplayStr, OPTION_NAME_LENGTH, "Modo de Demo: %s",
    bmGameMode == BM_GameMode_Spect ? "Espectador" :
    bmGameMode == BM_GameMode_Versus ? "Versus" :
    bmGameMode == BM_GameMode_Practice ? "Practica" :
    "error");
  menu.AddItem("toggle_gamemode", gameModeDisplayStr);
  menu.AddItem("versus_settings", "Opciones de Versus", bmGameMode != BM_GameMode_Versus);

  menu.AddItem("exit_demo", "Salir De Modo Demos");
  menu.Pagination = MENU_NO_PAGINATION;
  menu.ExitButton = true;
  menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
}

public int DemosMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "record_new")) {
      g_WaitForDemoSave[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre de la Demo a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
      return 0;
    } else if (StrEqual(buffer, "show_list")) {
      DemoShowListMenu(client);
      return 0;
    } else if (StrEqual(buffer, "toggle_gamemode")) {
      if (IsDemoPlaying()) {
        PM_Message(client, "{ORANGE}Pausa tu demo actual primero.");
      } else {
        BMGameMode bmGameMode = BotMimic_GetGameMode();
        bmGameMode++;
        if (bmGameMode > BM_GameMode_Practice)
          bmGameMode = BM_GameMode_Spect
        BotMimic_GetGameMode(bmGameMode);
        PM_Message(client, "{ORANGE}Modo %s activado.",
          bmGameMode == BM_GameMode_Spect ? "Espectador" :
          bmGameMode == BM_GameMode_Versus ? "Versus" :
          bmGameMode == BM_GameMode_Practice ? "Practica" :
          "error");
      }
    } else if (StrEqual(buffer, "versus_settings")) {
      DemoVersusSettingsMenu(client);
      return 0;
    } else if (StrEqual(buffer, "exit_demo")) {
      ExitDemoMode();
      PM_Message(client, "{ORANGE}Modo Demos Desactivado.");
      return 0;
    }
    DemosMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

stock void DemoShowListMenu(int client) {
  Menu menu = new Menu(DemoShowListMenuHandler);
  menu.SetTitle("Lista de Demos");
  char demo_id[OPTION_ID_LENGTH];
  char demo_name[OPTION_NAME_LENGTH];
  if (g_DemosKv.GotoFirstSubKey()) {
    do {
      g_DemosKv.GetSectionName(demo_id, sizeof(demo_id));
      g_DemosKv.GetString("name", demo_name, sizeof(demo_name));
      char display[128];
      Format(display, sizeof(display), "Demo N-%s: %s", demo_id, demo_name);
      menu.AddItem(demo_id, display);
    } while (g_DemosKv.GotoNextKey());
    g_DemosKv.GoBack();
  }
  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
}

public int DemoShowListMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    strcopy(g_SelectedDemoId[client], OPTION_ID_LENGTH, buffer);
    SingleDemoEditorMenu(client);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    DemosMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void DemoVersusSettingsMenu(int client) {
  Menu menu = new Menu(DemoVersusSettingsMenuHandler);
  menu.SetTitle("Opciones de Versus");
  int currentBotDiffCvar = GetCvarIntSafe("bot_difficulty");
  char displayStr[OPTION_NAME_LENGTH];
  Format(displayStr, sizeof(displayStr), "Cambiar Dificultad: %s", 
    (currentBotDiffCvar == 0)
      ? "Muy Dificil"
    : (currentBotDiffCvar == 1)
      ? "Dificil"
    : (currentBotDiffCvar == 2)
      ? "Medio"
    : (currentBotDiffCvar == 3)
      ? "Facil" : "Error"
  );
  menu.AddItem("difficulty", displayStr);
  Format(displayStr, sizeof(displayStr), "Tiempo de Reacción de Bots: %.1f ms", BotMimic_GetVersusModeReactionTime()*5.5556);
  menu.AddItem("reacttime", displayStr);
  Format(displayStr, sizeof(displayStr), "Tiempo Máximo de Movimiento de Bot: %.1f ms", BotMimic_GetVersusModeMoveDistance()*5.5556);
  menu.AddItem("movedistance", displayStr);

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
}

public int DemoVersusSettingsMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "difficulty")) {
      int currentBotDiffCvar = GetCvarIntSafe("bot_difficulty");
      currentBotDiffCvar += 1;
      currentBotDiffCvar = (currentBotDiffCvar > 3)
        ? 0
        : currentBotDiffCvar;
      SetCvarIntSafe("bot_difficulty", currentBotDiffCvar);
    } else if (StrEqual(buffer, "reacttime")) {
      BotMimic_GetVersusModeReactionTime(true);
    } else if (StrEqual(buffer, "movedistance")) {
      BotMimic_GetVersusModeMoveDistance(true);
    }
    DemoVersusSettingsMenu(client);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    DemosMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void SingleDemoEditorMenu(int client, bool playing = false) {
  g_SelectedRoleId[client] = -1;
  // g_CurrentEditingDemoRole[client] = -1;

  ServerCommand("sm_botmimic_snapshotinterval 64");

  Menu menu = new Menu(SingleDemoEditorMenuHandler);
  char demo_name[OPTION_NAME_LENGTH];
  GetDemoName(g_SelectedDemoId[client], demo_name, OPTION_NAME_LENGTH);
  menu.SetTitle("Editor de Demo N-%s: %s", g_SelectedDemoId[client], demo_name);

  char displayStr[OPTION_NAME_LENGTH];
  menu.AddItem("play_pause", "Reproducir(▶)/Detener(⬜) Demo");
  if (g_DemoOption_RoundRestart[client] == 0) {
    strcopy(displayStr, sizeof(displayStr), "No")
  } else {
    Format(displayStr, sizeof(displayStr), "%d segundos", g_DemoOption_RoundRestart[client]);
  }
  Format(displayStr, sizeof(displayStr), "Reiniciar Ronda: %s\n ", displayStr);
  menu.AddItem("round_restart", displayStr);
  menu.AddItem("record", "Grabar las demos de los jugadores\n ");
  menu.AddItem("rename", "Cambiar Nombre De Esta Demo");
  menu.AddItem("delete", "Eliminar Demo");

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
}

public int SingleDemoEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "record")) {
      SingleDemoSoloRecordMenu(client);
      return 0;
    } else if (StrEqual(buffer, "play_pause")) {
      if (IsDemoPlaying()) {
        // Stop
        CancelAllDemos();
        if (BotMimic_IsPlayerRecording(client)) {
          BotMimic_StopRecording(client, false);
          PM_Message(client, "{ORANGE}Grabación cancelada.");
        } else {
          PM_Message(client, "{ORANGE}Cancelando demo...");
        }
      } else {
        // Play
        char demo_name[OPTION_NAME_LENGTH];
        GetDemoName(g_SelectedDemoId[client], demo_name, sizeof(demo_name));
        PM_MessageToAll("{ORANGE}Empezando demo: {PURPLE}\"%s\"", demo_name);
        if (g_DemoOption_RoundRestart[client] > 0) {
          SetCvarIntSafe("mp_freezetime", g_DemoOption_RoundRestart[client]);
          CS_TerminateRound(0.0, CSRoundEnd_Draw);
          PlayDemo(g_SelectedDemoId[client], _, float(g_DemoOption_RoundRestart[client]));
        } else {
          PlayDemo(g_SelectedDemoId[client]);
        }
        SingleDemoEditorMenu(client, true);
        return 0;
      }
    } else if (StrEqual(buffer, "rename")) {
      PM_Message(client, "{ORANGE}Ingrese El Nuevo Nombre: ");
      g_WaitForSingleDemoName[client] = true;
      return 0;
    } else if (StrEqual(buffer, "delete")) {
      char demo_name[OPTION_NAME_LENGTH];
      GetDemoName(g_SelectedDemoId[client], demo_name, OPTION_NAME_LENGTH);
      DemoDeletionMenu(client);
      return 0;
    } else if (StrEqual(buffer, "round_restart")) {
      g_DemoOption_RoundRestart[client] += 2;
      if (g_DemoOption_RoundRestart[client] > DemoOption_RoundRestart_MAX)
        g_DemoOption_RoundRestart[client] = 0;
    }
    SingleDemoEditorMenu(client);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    DemoShowListMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void SingleDemoSoloRecordMenu(int client, bool playing = false) {
  // g_CurrentEditingDemoRole[client] = -1;
  Menu menu = new Menu(SingleDemoSoloRecordMenuHandler);
  char demo_name[OPTION_NAME_LENGTH];
  GetDemoName(g_SelectedDemoId[client], demo_name, OPTION_NAME_LENGTH);
  menu.SetTitle("Editor de Demo %s", demo_name);
  for (int i = 0; i < MAX_DEMO_BOTS; i++) {
    bool recordedLastRole = true;
    if (i > 0) recordedLastRole = CheckDemoRoleKVString(g_SelectedDemoId[client], i-1, "file");
    int style = recordedLastRole ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;

    char iStr[OPTION_ID_LENGTH];
    IntToString(i, iStr, sizeof(iStr));

    char roleName[OPTION_NAME_LENGTH];
    if (!GetDemoRoleKVString(g_SelectedDemoId[client], iStr, "name", roleName, sizeof(roleName))) {
      IntToString(i + 1, roleName, sizeof(roleName));
    }
    char teamName[OPTION_NAME_LENGTH];
    if (!GetDemoRoleKVString(g_SelectedDemoId[client], iStr, "team", roleName, sizeof(roleName))) {
      (GetClientTeam(client) == CS_TEAM_CT) ? strcopy(teamName, sizeof(teamName), "CT") : strcopy(teamName, sizeof(teamName), "TT") ;
    }
    if (CheckDemoRoleKVString(g_SelectedDemoId[client], i, "file")) {
      AddMenuIntStyle(menu, i, style, "Demo %s de jugador %s [EXISTE]%s", teamName, roleName, (i == MAX_DEMO_BOTS-1) ? "\n " : "");
    } else {
      AddMenuIntStyle(menu, i, style, "Demo %s de jugador %s [VACIO]%s", teamName, roleName, (i == MAX_DEMO_BOTS-1) ? "\n " : "");
    }
  }

  menu.AddItem("record_all", "Grabar a todos en mi equipo");

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
}

public int SingleDemoSoloRecordMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "record_all")) {
      if (BotMimic_IsPlayerRecording(client)) {
        PM_Message(client, "{ORANGE}Termina tu grabación actual primero.");
      } else if (IsDemoPlaying()) {
        PM_Message(client, "{ORANGE}Pausa tu demo actual primero.");
      } else {
        int playerCount = 0;
        for (int i = 1; i <= MaxClients; i++) {
          if (IsPlayer(i) && !BotMimic_IsPlayerRecording(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
            playerCount++;
          }
        }
        if (playerCount == 0) {
          PM_Message(client, "{ORANGE}No puedes grabar una demo completa sin jugadores en CT/T.");\
        } else if (playerCount > g_DemoBots.Length) {
          PM_Message(
              client,
              "No puedes grabar una demo con %d jugadores. Solo hay %d bots soportados. Los otros jugadores deberán ser movidos a espectador.",
              playerCount, g_DemoBots.Length);\
        } else {
          int demoRole = 0;
          for (int i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i) && !BotMimic_IsPlayerRecording(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
              g_CurrentEditingDemoRole[i] = demoRole;
              g_SelectedDemoId[i] = g_SelectedDemoId[client];
              StartDemoRecording(i, demoRole, false);
              demoRole++;
            }
          }
          g_RecordingFullDemo = true;
          g_RecordingFullDemoClient = client;
          PM_MessageToAll("{ORANGE}Grabando demo con %d jugadores.", playerCount);
          PM_MessageToAll("{ORANGE}La grabación terminara automáticamente cuando cualquier jugador use noclip.");
          return 0;
        }
      }
    } else {
      for (int roleId = 0; roleId < g_DemoBots.Length; roleId++) {
        char roleIdStr[16];
        IntToString(roleId, roleIdStr, sizeof(roleIdStr));
        if (StrEqual(buffer, roleIdStr)) {
          SingleDemoRoleMenu(client, roleId);
          return 0;
        }
      }
    }
    SingleDemoSoloRecordMenu(client);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    SingleDemoEditorMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void SingleDemoRoleMenu(int client, int roleId, int pos = 0) {
  Menu menu = new Menu(SingleDemoRoleMenuHandler);
  g_CurrentEditingDemoRole[client] = roleId;

  char demoName[OPTION_NAME_LENGTH];
  GetDemoName(g_SelectedDemoId[client], demoName, sizeof(demoName));

  char roleName[OPTION_NAME_LENGTH];
  char roleIdStr[OPTION_ID_LENGTH];
  IntToString(roleId, roleIdStr, sizeof(roleIdStr));
  GetDemoRoleKVString(g_SelectedDemoId[client], roleIdStr, "name", roleName, sizeof(roleName));
  if (StrEqual(roleName, "")) {
    IntToString(roleId + 1, roleName, sizeof(roleName));
  }

  menu.SetTitle("Demo %s: Jugador %s", demoName, roleName);
  bool recorded = CheckDemoRoleKVString(g_SelectedDemoId[client], roleId, "file");
  if (recorded) {
    menu.AddItem("record", "Grabar Demo otra vez");
  } else {
    menu.AddItem("record", "Grabar Demo de Jugador");
  }

  menu.AddItem("spawn", "Ir a su posición inicial", recorded ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
  menu.AddItem("nades", "Ver granadas de esta demo", recorded ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
  menu.AddItem("play", "Reproducir el demo de este jugador", recorded ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
  menu.AddItem("rename", "Cambiar nombre de este jugador");

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.DisplayAt(client, MENU_TIME_FOREVER, pos);
}

public int SingleDemoRoleMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    int roleId = g_CurrentEditingDemoRole[client];
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));

    if (StrEqual(buffer, "record")) {
      if (BotMimic_IsPlayerRecording(client)) {
        PM_Message(client, "{ORANGE}Termina tu Grabación actual primero!");
      } else if (IsDemoPlaying()) {
        PM_Message(client, "{ORANGE}Termina tu Demo actual primero!");
      } else {
        StartDemoRecording(client, roleId);
        PlayDemo(g_SelectedDemoId[client], roleId);
        return 0;
      }
    } else if (StrEqual(buffer, "spawn")) {
      GotoDemoRoleStart(client, g_SelectedDemoId[client], roleId);
    } else if (StrEqual(buffer, "play")) {
      int bot = g_DemoBots.Get(roleId); // g_ReplayBotClients[roleId];
      if (IsDemoBot(bot) && CheckDemoRoleKVString(g_SelectedDemoId[client], roleId, "file")) {
        PlayRoleFromDemo(bot, g_SelectedDemoId[client], roleId);
      }
    } else if (StrEqual(buffer, "rename")) {
      PM_Message(client, "{ORANGE}Ingrese El Nuevo Nombre: ");
      g_WaitForSingleDemoRoleName[client] = true;
      return 0;
    } else if (StrEqual(buffer, "nades")) {
      DemoRoleNadesMenu(client);
      return 0;
    }
    SingleDemoRoleMenu(client, roleId, GetMenuSelectionPosition());
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    SingleDemoSoloRecordMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

public void DemoDeletionMenu(int client) {
  char demoName[OPTION_NAME_LENGTH];
  GetDemoName(g_SelectedDemoId[client], demoName, sizeof(demoName));

  Menu menu = new Menu(DemoDeletionMenuHandler);
  menu.SetTitle("Confirma la eliminación de demo: %s", demoName);
  
  menu.ExitBackButton = false;
  menu.ExitButton = false;
  menu.Pagination = MENU_NO_PAGINATION;

  for (int i = 0; i < 7; i++) {
    menu.AddItem("", "", ITEMDRAW_NOTEXT);
  }

  menu.AddItem("no", "No, cancelar");
  menu.AddItem("yes", "Si, eliminar");
  menu.Display(client, MENU_TIME_FOREVER);
}

public int DemoDeletionMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));

    if (StrEqual(buffer, "yes")) {
      char demoName[OPTION_NAME_LENGTH];
      GetDemoName(g_SelectedDemoId[client], demoName, sizeof(demoName));
      DeleteDemo(g_SelectedDemoId[client]);
      PM_MessageToAll("{ORANGE}Demo {PURPLE}\"%s\" {ORANGE}eliminado.", demoName);
      DemosMenu(client);
    } else {
      SingleDemoEditorMenu(client);
    }
  }
  return 0;
}

stock void DemoRoleNadesMenu(int client, int pos = 0) {
  Menu menu = new Menu(DemoRoleNadesMenuHandler);
  menu.SetTitle("Granadas de jugador %d", g_CurrentEditingDemoRole[client] + 1);
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  char roleIdStr[OPTION_ID_LENGTH];
  IntToString(g_CurrentEditingDemoRole[client], roleIdStr, sizeof(roleIdStr));
  GetDemoRoleKVNades(client, g_SelectedDemoId[client], roleIdStr);
  for (int i = 0; i < g_DemoNadeData[client].Length; i++) {
    DemoNadeData demoNadeData;
    g_DemoNadeData[client].GetArray(i, demoNadeData, sizeof(demoNadeData));
    char display[128];
    GrenadeTypeString(demoNadeData.grenadeType, display, sizeof(display));
    UpperString(display);
    AddMenuInt(menu, i, display);
  }
  if (g_DemoNadeData[client].Length == 0) {
    PM_Message(client, "{ORANGE}Este Jugador No Tiene Granadas en su Demo.");
    SingleDemoRoleMenu(client, g_CurrentEditingDemoRole[client]);
    delete menu;
    return;
  }

  menu.DisplayAt(client, MENU_TIME_FOREVER, pos);
}

public int DemoRoleNadesMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    int nadeIndex = GetMenuInt(menu, item);
    DemoNadeData demoNadeData;
    g_DemoNadeData[client].GetArray(nadeIndex, demoNadeData, sizeof(demoNadeData));
    TeleportEntity(client, demoNadeData.origin, demoNadeData.angles, ZERO_VECTOR);
    if (demoNadeData.grenadeType != GrenadeType_None) {
      char weaponName[64];
      GetGrenadeWeapon(demoNadeData.grenadeType, weaponName, sizeof(weaponName));
      FakeClientCommand(client, "use %s", weaponName);
      DemoRoleNadesMenu(client, GetMenuSelectionPosition());
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    SingleDemoRoleMenu(client, g_CurrentEditingDemoRole[client]);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public void GiveDemoMenuInContext(int client) {
  if (DemoExists(g_SelectedDemoId[client])) {
    if (g_CurrentEditingDemoRole[client] >= 0) {
      // Demo-role specific menu.
      SingleDemoRoleMenu(client, g_CurrentEditingDemoRole[client]);
    } else {
      // Demo-specific menu.
      SingleDemoEditorMenu(client);
    }
  } else {
    // Demos menu.
    DemosMenu(client);
  }
}

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Events, Forwards, Hooks */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

public void Demos_ClientDisconnect(int client) {
  g_SelectedDemoId[client] = "";
  g_SelectedRoleId[client] = -1; //g_CurrentEditingRole[client] = -1;
  g_DemoOption_RoundRestart[client] = 0;
  g_CurrentEditingDemoRole[client] = -1;
  // g_CurrentDemoRecordingStartTime[client];
  g_CurrentDemoNadeIndex[client] = 0;
  g_DemoBotStopped[client] = false; // g_StopBotSignal
  g_DemoPlayRoundTimer[client] = false;
  g_DemoNadeData[client].Clear();
}

public void Demos_PluginStart() {
  g_DemoBots = new ArrayList();
}

public void Demos_MapStart() {
  delete g_DemosKv;
  g_DemosKv = new KeyValues("Demos");

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  char demoFile[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, demoFile, sizeof(demoFile), "data/practicemode/demos/%s.cfg", map);
  g_DemosKv.ImportFromFile(demoFile);

  for (int i = 0; i <= MaxClients; i++) {
    delete g_DemoNadeData[i];
    g_DemoNadeData[i] = new ArrayList(sizeof(DemoNadeData));
    // g_DemoPlayRoundTimer[i] = false; it starts with false
  }
}

public void Demos_MapEnd() {
  MaybeWriteNewDemoData();
}

public Action Event_DemoBot_Death(int victim, Event event, const char[] name, bool dontBroadcast) {
  int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
  CreateTimer(0.5, Timer_RemoveRagdoll, EntIndexToEntRef(ragdoll), TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Continue;
}

public Action BotMimic_OnPlayerMimicLoops(int client) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Handled;
  }
  if (BotMimic_GetGameMode() == BM_GameMode_Practice) {
    PrintToChatAll("looping");
    return Plugin_Continue;
  }
  // //if (g_InBotDemoMode) {
  // if (g_DemoBotStopped[client]) {
  //   // Second Loop
  //   return Plugin_Handled;
  // }
  // // First Loop
  // g_DemoBotStopped[client] = true;
  // //}
  return Plugin_Handled; ////
  // return Plugin_Continue;
}

public void Demos_OnThrowGrenade(int client, int entity, GrenadeType grenadeType, const float origin[3], const float velocity[3]) {
  if (!g_BotMimicLoaded) {
    return;
  }

  if (g_InBotDemoMode && g_CurrentEditingDemoRole[client] >= 0 && BotMimic_IsPlayerRecording(client) ||
      (!g_InBotDemoMode && g_recordingNadeDemoStatus[client] == 2)) {
    DemoNadeData demoNadeData;
    demoNadeData.delay = GetGameTime() - g_CurrentDemoRecordingStartTime[client];
    GetClientAbsOrigin(client, demoNadeData.origin);
    GetClientEyeAngles(client, demoNadeData.angles);
    demoNadeData.grenadeOrigin = origin;
    demoNadeData.grenadeType = grenadeType;
    demoNadeData.grenadeVelocity = velocity;
    g_DemoNadeData[client].PushArray(demoNadeData, sizeof(demoNadeData));
    // if (demoNadeData.delay < 1.27) {  // Takes 1.265625s to pull out a grenade.
    //   PM_Message(
    //       client,
    //       "{LIGHT_RED}Advertencia: {NORMAL}Tirar una granada justo despues de empezar la grabación puede no guardarla. {LIGHT_RED}Espera un segundo {NORMAL}despues de empezar la grabacion para tirar la granada.");
    // }
  }

  if (BotMimic_IsPlayerMimicing(client)) {
    int index = g_CurrentDemoNadeIndex[client];
    if (index < g_DemoNadeData[client].Length) {
      DemoNadeData demoNadeData;
      g_DemoNadeData[client].GetArray(index, demoNadeData, sizeof(demoNadeData));
      TeleportEntity(entity, demoNadeData.grenadeOrigin, NULL_VECTOR, demoNadeData.grenadeVelocity);
      g_CurrentDemoNadeIndex[client]++;
    }
  }
}

public void BotMimic_OnRecordSaved(int client, char[] name, char[] category, char[] subdir, char[] file) {
  if (g_InBotDemoMode) {
    if (g_CurrentEditingDemoRole[client] >= 0) {
      char roleIdStr[OPTION_ID_LENGTH];
      IntToString(g_CurrentEditingDemoRole[client], roleIdStr, sizeof(roleIdStr));
      SetDemoRoleKVString(g_SelectedDemoId[client], roleIdStr, "file", file);
      SetDemoRoleKVNades(client, g_SelectedDemoId[client], roleIdStr);
      SetDemoRoleKVString(g_SelectedDemoId[client], roleIdStr, "team", GetClientTeam(client) == CS_TEAM_CT ? "CT" : "TT");

      if (g_RecordingFullDemo && g_RecordingFullDemoClient == client) {
        PM_MessageToAll("{ORANGE}Terminó la grabación completa de esta demo.");
        RequestFrame(ResetFullDemoRecording, GetClientSerial(client));
      } else {
        PM_Message(client, "{ORANGE}Terminó la grabación de jugador rol %d", g_CurrentEditingDemoRole[client] + 1);
        GiveDemoMenuInContext(client);
      }
      MaybeWriteNewDemoData();
    }
    return;
  } else if (g_savedNewNadeDemo[client]) {
    DemoNadeData demoNadeData;
    g_DemoNadeData[client].GetArray(0, demoNadeData, sizeof(demoNadeData));
    SetClientGrenadeFloat(g_CurrentSavedGrenadeId[client], "delay", demoNadeData.delay);
    SetClientGrenadeData(g_CurrentSavedGrenadeId[client], "record", file);

    MaybeWriteNewGrenadeData();
    g_savedNewNadeDemo[client] = false;
  }
}

public void BotMimic_OnPlayerStopsMimicing(int client, char[] name, char[] category, char[] path) {
  if (g_CurrentDemoNadeIndex[client] < g_DemoNadeData[client].Length) {
    PrintToServer("[BotMimic_OnPlayerStopsMimicing]ERROR: %d didnt throw all his nades", client);
  }
  if (IsDemoBot(client)) {
    if (BotMimic_GetGameMode() == BM_GameMode_Versus) {
      SetupVersusDemoBot(client);
      CreateTimer(0.1, Timer_CheckVersusDemoPlayerFast, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    } else {
      ForcePlayerSuicide(client);
    }
  } else if (g_IsNadeDemoBot[client]) {
    CreateTimer(1.5, Timer_KickBot, client);
  }
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

// Cancels all current playing demos.
public void CancelAllDemos() {
  for (int i = 0; i < g_DemoBots.Length; i++) {
    int bot = g_DemoBots.Get(i);
    if (IsDemoBot(bot)) {
      if (BotMimic_IsPlayerMimicing(bot)) {
        BotMimic_StopPlayerMimic(bot);
      }
      if (BotMimic_GetGameMode() == BM_GameMode_Versus && IsPlayerAlive(bot)) {
        ForcePlayerSuicide(bot);
      }
    }
  }
}

// Returns if a demo is currently playing.
stock bool IsDemoPlaying(int role = -1) {
  for (int i = 0; i < g_DemoBots.Length; i++) {
    if (role != -1 && role != i) {
      continue;
    }

    int bot = g_DemoBots.Get(i);
    if (
      IsDemoBot(bot) &&
      (BotMimic_IsPlayerMimicing(bot) || (IsPlayerAlive(bot) && BotMimic_GetGameMode() == BM_GameMode_Versus))
    ) return true; //(versusMode && IsPlayerAlive(bot)
  }
  return false;
}

stock void PlayDemo(const char[] demoId, int exclude = -1, float delay = 0.0) {
  g_currentDemoGrenade = -1;
  for (int i = 0; i < g_DemoBots.Length; i++) {
    if (i == exclude) {
      continue;
    }
    int bot = g_DemoBots.Get(i);
    if (IsDemoBot(bot) && CheckDemoRoleKVString(demoId, i, "file")) {
      PlayRoleFromDemo(bot, demoId, i, delay);
    }
  }
}

/**
 * Delayed Demo start until after the respawn is done to prevent crashes.
 *
 * @param client          Mimic Client Index.
 * @param filepath        Path for .rec File.
 * @param startDelay      Delay before starting the actual mimic.
 * @error          Not enough variables in datapack.
 * @noreturn
 */
public void StartBotMimicDemo(DataPack pack) {
  pack.Reset();
  int client = pack.ReadCell();
  char filepath[PLATFORM_MAX_PATH];
  pack.ReadString(filepath, sizeof(filepath));
  float startDelay = pack.ReadFloat();

  BMError err = BotMimic_PlayRecordFromFile(client, filepath, startDelay);
  if (err != BM_NoError) {
    char errString[128];
    BotMimic_GetErrorString(err, errString, sizeof(errString));
    PrintToServer("[StartBotMimicDemo]Error playing record %s on client %d: %s", filepath, client, errString);
  }

  delete pack;
}

stock void PlayRoleFromDemo(int client, const char[] demoId, int roleId, float delay = 0.0) {
  if (!IsDemoBot(client)) {
    PrintToServer("[PlayRoleFromDemo][ERROR] Called PlayRoleFromDemo on non-demo bot %L", client);
    return;
  }
  char roleIdStr[OPTION_ID_LENGTH];
  IntToString(roleId, roleIdStr, sizeof(roleIdStr));
  char filepath[PLATFORM_MAX_PATH + 1];
  GetDemoRoleKVString(demoId, roleIdStr, "file", filepath, sizeof(filepath));

  if (BotMimic_IsPlayerMimicing(client)) {
    // Check if its different file
    char lastMimicFilePath[PLATFORM_MAX_PATH];
    BotMimic_GetRecordPlayerMimics(client, lastMimicFilePath, sizeof(lastMimicFilePath));
    if (StrEqual(lastMimicFilePath, filepath)) {
      BotMimic_ResetPlayback(client);
      return;
    } else {
      BotMimic_StopPlayerMimic(client);
    }
  }

  GetDemoRoleKVNades(client, demoId, roleIdStr);

  char roleName[OPTION_NAME_LENGTH];
  if (GetDemoRoleKVString(demoId, roleIdStr, "name", roleName, sizeof(roleName))) {
    // TODO: format [DEMOBOT]
    SetClientName(client, roleName);
  }

  int roleTeam;
  g_CurrentDemoNadeIndex[client] = 0;
  char roleTeamStr[OPTION_ID_LENGTH];
  GetDemoRoleKVString(demoId, roleIdStr, "team", roleTeamStr, sizeof(roleTeamStr));
  roleTeam = view_as<int>(StrEqual(roleTeamStr, "CT")) + 2; // 0 + 2 = 2 = cs_team_t 1 + 2 = 3 = cs_team_ct
  // CS_SwitchTeam(client, roleTeam);
  // CS_RespawnPlayer(client);
  
  if (GetClientTeam(client) != roleTeam) {
    PrintToServer("LOG: Switched Client %d from %d to roleTeam %d", client, GetClientTeam(client), roleTeam);
    CS_SwitchTeam(client, roleTeam);
  } else {
    PrintToServer("LOG: Client %d is same team(CT = 3, TT = 2) as roleTeam = %d", client, roleTeam);
  }
  if (!IsPlayerAlive(client)) {
    CS_RespawnPlayer(client);
  } else {
    PrintToServer("ERROR: Client %d was alive in PlayRoleFromDemo, prevented crash.", client);
  }
  DataPack pack = new DataPack();
  pack.WriteCell(client);
  pack.WriteString(filepath);
  pack.WriteFloat(delay);
  RequestFrame(StartBotMimicDemo, pack);
  g_DemoBotStopped[client] = false;
  g_CurrentDemoNadeIndex[client] = 0;
}

// Teleports a client to the point where a demo begins.
public void GotoDemoRoleStart(int client, const char[] demoId, int roleId) {
  char filepath[PLATFORM_MAX_PATH + 1];
  char roleIdStr[OPTION_ID_LENGTH];
  IntToString(roleId, roleIdStr, sizeof(roleIdStr));
  GetDemoRoleKVString(demoId, roleIdStr, "file", filepath, sizeof(filepath));
  BMFileHeader header;
  BMError error = BotMimic_GetFileHeaders(filepath, header, sizeof(header));
  if (error != BM_NoError) {
    char errorString[128];
    BotMimic_GetErrorString(error, errorString, sizeof(errorString));
    PrintToServer("[GotoDemoRoleStart]Failed to get %s headers: %s", filepath, errorString);
    return;
  }
  TeleportEntity(client, header.BMFH_initialPosition, header.BMFH_initialAngles, {0.0, 0.0, 0.0});
}

public void ExitDemoMode() {
  for (int i = 0; i < g_DemoBots.Length; i++) {
    int bot = g_DemoBots.Get(i);
    if (IsDemoBot(bot)) {
      ServerCommand("bot_kick \"%s\"", g_BotOriginalName[bot]);
    }
  }
  g_DemoBots.Clear();
  g_InBotDemoMode = false;
  g_RecordingFullDemo = false;
  SetCvarIntSafe("mp_respawn_on_death_ct", 1);
  SetCvarIntSafe("mp_respawn_on_death_t", 1);
}

public void InitDemoFunctions() {
  ResetDemoClientsData();
  for (int i = 0; i <= MaxClients; i++) {
    g_IsDemoBot[i] = 0; //g_ReplayBotClients[i] = -1;
  }
  g_DemoBots.Clear();

  GetDemoBots();

  g_InBotDemoMode = true;
  g_RecordingFullDemo = false;

  // NOTE: mp_death_drop_gun should be set to 1, or bots dont get weapon when executing give weapon_... command
}

public void ResetDemoClientsData() {
  for (int i = 0; i <= MaxClients; i++) {
    g_DemoBotStopped[i] = false;
    g_CurrentEditingDemoRole[i] = -1;
    g_SelectedDemoId[i] = "";
  }
}

public void GetDemoBots() {
  ServerCommand("bot_quota_mode normal");
  for (int i = 0; i < MAX_DEMO_BOTS; i++) {
    ServerCommand("bot_add");
  }

  CreateTimer(0.1, Timer_GetDemoBots);
}

public Action Timer_GetDemoBots(Handle timer) {
  for (int i = 0; i < MAX_DEMO_BOTS; i++) {
    char name[MAX_NAME_LENGTH];
    Format(name, sizeof(name), "Demo Bot %d", i + 1);
    if (i < g_DemoBots.Length) {
      if (IsDemoBot(g_DemoBots.Get(i))) {
        continue;
      }
    }
    int bot = GetLiveBot();
    if (bot < 0) {
      continue;
    }
    GetClientName(bot, g_BotOriginalName[bot], MAX_NAME_LENGTH);
    ChangeClientTeam(bot, CS_TEAM_T);
    ForcePlayerSuicide(bot);
    SetClientName(bot, name);
    g_IsDemoBot[bot] = true;
    g_DemoBots.Push(bot); // g_ReplayBotClients[i] = GetLiveBot(name);
  }
  return Plugin_Handled;
}

public void ResetFullDemoRecording(int serial) {
  g_RecordingFullDemo = false;
  g_RecordingFullDemoClient = -1;
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client)) {
    GiveDemoMenuInContext(client);
  }
}

public Action Command_FinishRecordingDemo(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  FinishRecordingDemo(client, true);
  return Plugin_Handled;
}

public void FinishRecordingDemo(int client, bool printOnFail) {
  if (g_RecordingFullDemo) {
    for (int i = 0; i <= MaxClients; i++) {
      if (IsPlayer(i) && BotMimic_IsPlayerRecording(i)) {
        BotMimic_StopRecording(i, true /* save */);
      }
    }
    
  } else {
    if (BotMimic_IsPlayerRecording(client)) {
      BotMimic_StopRecording(client, true /* save */);
      // CancelAllDemos();
    } else if (printOnFail) {
      PM_Message(client, "No estas grabando una demo ahora mismo.");
    }
  }
}

stock void StartDemoRecording(int client, int roleId, bool printCommands = true) {
  if (roleId < 0 || roleId >= g_DemoBots.Length) {
    return;
  }

  g_DemoNadeData[client].Clear();
  g_CurrentEditingDemoRole[client] = roleId;
  g_CurrentDemoRecordingStartTime[client] = GetGameTime();

  char recordName[128];
  Format(recordName, sizeof(recordName), "Rol de jugador %d", roleId + 1);
  char roleString[32];
  Format(roleString, sizeof(roleString), "rol %d", roleId);
  BotMimic_StartRecording(client, recordName, "practicemode", roleString);

  if (g_DemoPlayRoundTimer[client]) {
    float timer_duration = float(GetRoundTimeSeconds());
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = true;
    g_TimerType[client] = TimerType_Countdown_Movement;
    g_TimerDuration[client] = timer_duration;
    StartClientTimer(client);
  }

  if (printCommands) {
    PM_Message(client, "{ORANGE}Grabación de jugador %d empezada.", roleId + 1);
    PM_Message(client, "{ORANGE}Usa .finish o activa noclip para dejar de grabar.");
  }
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

public int GetDemosNextId() {
  int largest = -1;
  char id[OPTION_ID_LENGTH];
  if (g_DemosKv.GotoFirstSubKey()) {
    do {
      g_DemosKv.GetSectionName(id, sizeof(id));
      int idvalue = StringToInt(id);
      if (idvalue > largest) {
        largest = idvalue;
      }
    } while (g_DemosKv.GotoNextKey());
    g_DemosKv.GoBack();
  }
  return largest + 1;
}

public void SetDemoName(const char[] id, const char[] newName) {
  g_UpdatedDemoKv = true;
  if (g_DemosKv.JumpToKey(id, true)) {
    g_DemosKv.SetString("name", newName);
    g_DemosKv.GoBack();
  }
  MaybeWriteNewDemoData();
}

public void GetDemoName(const char[] id, char[] buffer, int length) {
  if (g_DemosKv.JumpToKey(id)) {
    g_DemosKv.GetString("name", buffer, length);
    g_DemosKv.GoBack();
  }
}

public void DeleteDemo(const char[] demoId) {
  if (g_DemosKv.JumpToKey(demoId)) {
    g_UpdatedDemoKv = true;
    g_DemosKv.DeleteThis();
    g_DemosKv.Rewind();
  }
  MaybeWriteNewDemoData();
}

public void DeleteDemoRole(const char[] demoId, const char[] roleId) {
  if (g_DemosKv.JumpToKey(demoId)) {
    if (g_DemosKv.JumpToKey(roleId)) {
      g_UpdatedDemoKv = true;
      g_DemosKv.DeleteThis();
      g_DemosKv.Rewind();
    }
  }
  MaybeWriteNewDemoData();
}

public void MaybeWriteNewDemoData() {
  if (g_UpdatedDemoKv) {
    g_DemosKv.Rewind();
    BackupFiles("demos");
    char map[PLATFORM_MAX_PATH];
    GetCleanMapName(map, sizeof(map));
    char demoFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, demoFile, sizeof(demoFile), "data/practicemode/demos/%s.cfg", map);
    DeleteFile(demoFile);
    if (!g_DemosKv.ExportToFile(demoFile)) {
      PrintToServer("[MaybeWriteNewDemoData]Failed to write demos to %s", demoFile);
    }
    g_UpdatedDemoKv = false;
  }
}

public bool GetDemoRoleKVString(const char[] demoId, const char[] roleId, const char[] key, char[] buffer, int size) {
  bool success = false;
  if (g_DemosKv.JumpToKey(demoId)) {
    if (g_DemosKv.JumpToKey(roleId)) {
      g_DemosKv.GetString(key, buffer, size);
      success = !StrEqual(buffer, "");
      g_DemosKv.GoBack();
    }
    g_DemosKv.GoBack();
  }
  return success;
}

public bool SetDemoRoleKVString(const char[] demoId, const char[] roleId, const char[] key, const char[] value) {
  g_UpdatedDemoKv = true;
  bool ret = false;
  if (g_DemosKv.JumpToKey(demoId, true)) {
    if (g_DemosKv.JumpToKey(roleId, true)) {
      ret = true;
      g_DemosKv.SetString(key, value);
      g_DemosKv.GoBack();
    }
    g_DemosKv.GoBack();
  }
  return ret;
}

public void GetDemoRoleKVNades(int client, const char[] demoId, const char[] roleId) {
  g_DemoNadeData[client].Clear();
  if (g_DemosKv.JumpToKey(demoId)) { // , true
    if (g_DemosKv.JumpToKey(roleId)) { // , true
      if (g_DemosKv.JumpToKey("nades")) { // , true
        if (g_DemosKv.GotoFirstSubKey()) {
          do {
            DemoNadeData demoNadeData;
            g_DemosKv.GetVector("origin", demoNadeData.origin);
            g_DemosKv.GetVector("angles", demoNadeData.angles);
            g_DemosKv.GetVector("grenadeOrigin", demoNadeData.grenadeOrigin);
            g_DemosKv.GetVector("grenadeVelocity", demoNadeData.grenadeVelocity);

            char typeString[OPTION_NAME_LENGTH];
            g_DemosKv.GetString("grenadeType", typeString, sizeof(typeString));
            demoNadeData.grenadeType = GrenadeTypeFromString(typeString);
            demoNadeData.delay = g_DemosKv.GetFloat("delay");
            g_DemoNadeData[client].PushArray(demoNadeData, sizeof(demoNadeData));
          } while (g_DemosKv.GotoNextKey());
        }
      }
    }
  }
  g_DemosKv.Rewind();
}

public void SetDemoRoleKVNades(int client, const char[] demoId, const char[] roleId) {
  g_UpdatedDemoKv = true;
  if (g_DemosKv.JumpToKey(demoId, true)) {
    if (g_DemosKv.JumpToKey(roleId, true)) {
      if (g_DemosKv.JumpToKey("nades", true)) {
        for (int i = 0; i < g_DemoNadeData[client].Length; i++) {
          char nadeIdStr[OPTION_ID_LENGTH];
          IntToString(i, nadeIdStr, sizeof(nadeIdStr));
          if (g_DemosKv.JumpToKey(nadeIdStr, true)){
            DemoNadeData demoNadeData;
            g_DemoNadeData[client].GetArray(i, demoNadeData, sizeof(demoNadeData));
            
            char grenadeTypeStr[OPTION_NAME_LENGTH];
            GrenadeTypeString(demoNadeData.grenadeType, grenadeTypeStr, sizeof(grenadeTypeStr));
            g_DemosKv.SetVector("origin", demoNadeData.origin);
            g_DemosKv.SetVector("angles", demoNadeData.angles);
            g_DemosKv.SetVector("grenadeOrigin", demoNadeData.grenadeOrigin);
            g_DemosKv.SetVector("grenadeVelocity", demoNadeData.grenadeVelocity);
            g_DemosKv.SetString("grenadeType", grenadeTypeStr);
            g_DemosKv.SetFloat("delay", demoNadeData.delay);
            g_DemosKv.GoBack();
          }
        }
      }
    }
  }
  g_DemosKv.Rewind();
}

public bool CheckDemoRoleKVString(const char[] demoId, int roleId, const char[] key) {
  char buffer[PLATFORM_MAX_PATH];
  char roleIdStr[OPTION_ID_LENGTH];
  IntToString(roleId, roleIdStr, sizeof(roleIdStr));
  return GetDemoRoleKVString(demoId, roleIdStr, key, buffer, sizeof(buffer));
}

public bool DemoExists(const char[] demoId) {
  if (StrEqual(demoId, "")) {
    return false;
  }

  bool ret = false;
  if (g_DemosKv.JumpToKey(demoId)) {
    ret = true;
    g_DemosKv.GoBack();
  }
  return ret;
}


public bool IsDemoBot(int client) {
  return client > 0 && g_IsDemoBot[client] && IsClientInGame(client) && IsFakeClient(client);
}

public Action Timer_KickBot(Handle timer, int client) {
  int playerSpec = g_ClientSpecBot[client];
  if (IsValidClient(playerSpec)) {
    ChangeClientTeam(playerSpec, g_LastSpecPlayerTeam[playerSpec]);
    TeleportEntity(playerSpec, g_LastSpecPlayerPos[playerSpec], g_LastSpecPlayerAng[playerSpec], ZERO_VECTOR);
  }
  if (IsValidClient(client)) {
    ServerCommand("bot_kick \"%s\"", g_BotOriginalName[client]);
  }
  return Plugin_Stop;
}
