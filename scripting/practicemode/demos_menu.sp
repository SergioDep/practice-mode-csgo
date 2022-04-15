public void DemosMainMenu(int client) {
  strcopy(g_SelectedDemoId[client], DEMO_ID_LENGTH, "");

  Menu menu = new Menu(DemosMainMenuHandler);
  menu.SetTitle("Lista de Demos");
  menu.AddItem("add_new", "Grabar Nueva Demo");

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
  menu.AddItem("exit_edit", "Salir de modo Demos");
  menu.ExitButton = true;
  menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
}

public int DemosMainMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[DEMO_ID_LENGTH + 1];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "add_new")) {
      g_WaitForDemoSave[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre de la Demo a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
    } else if (StrEqual(buffer, "exit_edit")) {
      ExitDemoMode();
      PM_Message(client, "{ORANGE}Modo Demos Desactivado.");
    } else {
      strcopy(g_SelectedDemoId[client], DEMO_ID_LENGTH, buffer);
      SingleDemoEditorMenu(client);
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void SingleDemoEditorMenu(int client, int pos = 0) {
  g_SelectedRoleId[client] = -1;

  ServerCommand("sm_botmimic_snapshotinterval 64");

  Menu menu = new Menu(SingleDemoEditorMenuHandler);
  char demo_name[DEMO_NAME_LENGTH];
  GetDemoName(g_SelectedDemoId[client], demo_name, DEMO_NAME_LENGTH);
  menu.SetTitle("Editor de Demo N-%s: %s", g_SelectedDemoId[client], demo_name);

  for (int i = 0; i < MAX_DEMO_BOTS; i++) {
    bool recordedLastRole = true;
    if (i > 0) recordedLastRole = CheckDemoRoleKVString(g_SelectedDemoId[client], i-1, "file");
    int style = recordedLastRole ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
    if (CheckDemoRoleKVString(g_SelectedDemoId[client], i, "file")) {
      char roleName[DEMO_NAME_LENGTH];
      char iStr[DEMO_ID_LENGTH];
      IntToString(i, iStr, sizeof(iStr));
      if (GetDemoRoleKVString(g_SelectedDemoId[client], iStr, "name", roleName, sizeof(roleName))) {
        AddMenuIntStyle(menu, i, style, "Cambiar demo %s de jugador %d", roleName, i + 1);
      } else {
        AddMenuIntStyle(menu, i, style, "Cambiar demo de jugador %d", i + 1);
      }
    } else {
      AddMenuIntStyle(menu, i, style, "Añadir Demo de jugador %d", i + 1);
    }
  }

  menu.AddItem("play", "Reproducir Demo");
  // menu.AddItem("stop", "Finaliza la Demo Actual");

  /* Page 2 */
  menu.AddItem("recordall", "Graba las demos de todos los jugadores a la vez");
  menu.AddItem("rename", "Renombra esta Demo");
  menu.AddItem("delete", "Eliminar Esta Demo");
  // menu.AddItem("copy", "Copia esta demo a otra nueva");

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public int SingleDemoEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));

    if (StrEqual(buffer, "play")) {
      char demo_name[DEMO_NAME_LENGTH];
      GetDemoName(g_SelectedDemoId[client], demo_name, sizeof(demo_name));
      PM_MessageToAll("{ORANGE}Reproduciendo demo: {PURPLE}\"%s\"", demo_name);
      for (int i = 0; i < g_DemoBots.Length; i++) {
        int bot = g_DemoBots.Get(i);
        if (IsDemoBot(bot) && BotMimic_IsPlayerMimicing(bot)) {
          BotMimic_ResetPlayback(bot);
          SingleDemoEditorMenu(client, GetMenuSelectionPosition());
          return 0;
        }
      }
      PlayDemo(g_SelectedDemoId[client]);
    } else if (StrEqual(buffer, "stop")) {
      // CancelAllDemos(); inside play
      CancelAllDemos();
      if (BotMimic_IsPlayerRecording(client)) {
        BotMimic_StopRecording(client, false);
        PM_Message(client, "{ORANGE}Grabación cancelada.");
      }
      SingleDemoEditorMenu(client, GetMenuSelectionPosition());
    } else if (StrEqual(buffer, "delete")) {
      char demo_name[DEMO_NAME_LENGTH];
      GetDemoName(g_SelectedDemoId[client], demo_name, DEMO_NAME_LENGTH);
      DemoDeletionMenu(client);
      return 0;
    } else if (StrContains(buffer, "rename") == 0) {
      PM_Message(client, "{LIGHT_RED}(FIX) .namereplay override");
      SingleDemoEditorMenu(client, GetMenuSelectionPosition());
    } else if (StrEqual(buffer, "recordall")) {
      if (BotMimic_IsPlayerRecording(client)) {
        PM_Message(client, "{ORANGE}Termina tu grabación actual primero.");
        SingleDemoEditorMenu(client, GetMenuSelectionPosition());
        return 0;
      } else if (IsDemoPlaying()) {
        PM_Message(client, "{ORANGE}Pausa tu demo actual primero.");
        SingleDemoEditorMenu(client, GetMenuSelectionPosition());
        return 0;
      } else {
        int playerCount = 0;
        for (int i = 1; i <= MaxClients; i++) {
          if (IsPlayer(i) && !BotMimic_IsPlayerRecording(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
            playerCount++;
          }
        }
        if (playerCount == 0) {
          PM_Message(client, "{ORANGE}No puedes grabar una demo completa sin jugadores en CT/T.");
          return 0;
        } else if (playerCount > g_DemoBots.Length) {
          PM_Message(
              client,
              "No puedes grabar una demo con %d jugadores. Solo hay %d bots soportados. Los otros jugadores deberán ser movidos a espectador.",
              playerCount, g_DemoBots.Length);
          return 0;
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
        }

      }
    } else {
      for (int roleId = 0; roleId < g_DemoBots.Length; roleId++) {
        char roleIdStr[16];
        IntToString(roleId, roleIdStr, sizeof(roleIdStr));
        if (StrEqual(buffer, roleIdStr)) {
          SingleDemoRoleMenu(client, roleId);
          break;
        }
      }
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    DemosMainMenu(client);
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
      DemosMainMenu(client);
    } else {
      SingleDemoEditorMenu(client);
    }
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

  menu.SetTitle("%s: %s (rol %d)", demoName, roleName, roleId + 1);

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  bool recorded = CheckDemoRoleKVString(g_SelectedDemoId[client], roleId, "file");
  if (recorded) {
    menu.AddItem("record", "Grabar Rol otra vez");
  } else {
    menu.AddItem("record", "Grabar Rol");
  }

  menu.AddItem("spawn", "Ir a la posición inicial");
  menu.AddItem("nades", "Ver granadas de este jugador");
  menu.AddItem("play", "Reproducir el demo de este jugador");
  menu.AddItem("name", "Cambiar nombre de este jugador");
  menu.AddItem("delete", "Elimina esta repetición", recorded ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
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
      if (IsDemoBot(bot) && BotMimic_IsPlayerMimicing(bot)) {
        BotMimic_ResetPlayback(bot);
        DemosMainMenu(client);
        return 0;
      }
      if (IsDemoBot(bot) && CheckDemoRoleKVString(g_SelectedDemoId[client], roleId, "file")) {
        PlayRoleFromDemo(bot, g_SelectedDemoId[client], roleId);
      }
    } else if (StrEqual(buffer, "name")) {
      PM_Message(client, "{ORANGE}(FIX)Usa .namerole <nombre> para nombrar este Rol.");
    } else if (StrEqual(buffer, "nades")) {
      if (g_DemoNadeData[client].Length >= 0) {
        DemoRoleNadesMenu(client);
        return 0;
      }
      PM_Message(client, "Este Jugador No Tiene Granadas en su Demo.");
    } else if (StrEqual(buffer, "delete")) {
      char roleIdStr[DEMO_ID_LENGTH];
      IntToString(roleId, roleIdStr, sizeof(roleIdStr));
      DeleteDemoRole(g_SelectedDemoId[client], roleIdStr);
      PM_Message(client, "Demo de Jugador %d eliminado.", roleId + 1);
      SingleDemoEditorMenu(client);
      return 0;
    }
    SingleDemoRoleMenu(client, roleId, GetMenuSelectionPosition());
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    SingleDemoEditorMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
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
