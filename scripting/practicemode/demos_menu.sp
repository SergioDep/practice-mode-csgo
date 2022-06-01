stock void DemosMenu(int client) {
  Menu menu = new Menu(DemosMenuHandler);
  menu.SetTitle("Menu de Demos");
  menu.AddItem("record_new", "Grabar Nuevo Demo");
  menu.AddItem("show_list", "Lista de Demos Grabadas");
  char gameModeDisplayStr[OPTION_NAME_LENGTH];
  bool versusModeActive = BotMimic_IsVersusGameMode();
  Format(gameModeDisplayStr, OPTION_NAME_LENGTH, "Modo de Demo: %s", versusModeActive ? "Versus" : "Espectador");
  menu.AddItem("toggle_gamemode", gameModeDisplayStr);
  menu.AddItem("versus_settings", "Opciones de Versus", versusModeActive ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

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
        PM_Message(client, "{ORANGE}Modo %s activado.", BotMimic_IsVersusGameMode(true) ? "Versus" : "Espectador");
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
  char demo_id[DEMO_ID_LENGTH];
  char demo_name[DEMO_NAME_LENGTH];
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
    strcopy(g_SelectedDemoId[client], DEMO_ID_LENGTH, buffer);
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
  char demo_name[DEMO_NAME_LENGTH];
  GetDemoName(g_SelectedDemoId[client], demo_name, DEMO_NAME_LENGTH);
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
        char demo_name[DEMO_NAME_LENGTH];
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
      char demo_name[DEMO_NAME_LENGTH];
      GetDemoName(g_SelectedDemoId[client], demo_name, DEMO_NAME_LENGTH);
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
  char demo_name[DEMO_NAME_LENGTH];
  GetDemoName(g_SelectedDemoId[client], demo_name, DEMO_NAME_LENGTH);
  menu.SetTitle("Editor de Demo %s", demo_name);
  for (int i = 0; i < MAX_DEMO_BOTS; i++) {
    bool recordedLastRole = true;
    if (i > 0) recordedLastRole = CheckDemoRoleKVString(g_SelectedDemoId[client], i-1, "file");
    int style = recordedLastRole ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;

    char iStr[DEMO_ID_LENGTH];
    IntToString(i, iStr, sizeof(iStr));

    char roleName[DEMO_NAME_LENGTH];
    if (!GetDemoRoleKVString(g_SelectedDemoId[client], iStr, "name", roleName, sizeof(roleName))) {
      IntToString(i + 1, roleName, sizeof(roleName));
    }
    char teamName[DEMO_NAME_LENGTH];
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

  char demoName[DEMO_NAME_LENGTH];
  GetDemoName(g_SelectedDemoId[client], demoName, sizeof(demoName));

  char roleName[DEMO_NAME_LENGTH];
  char roleIdStr[DEMO_ID_LENGTH];
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
  char demoName[DEMO_NAME_LENGTH];
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
      char demoName[DEMO_NAME_LENGTH];
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

  char roleIdStr[DEMO_ID_LENGTH];
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
