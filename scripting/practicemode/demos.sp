/**************************** Commands *****************************/
  public Action Command_DemosMenu(int client, int args) {
    if (!g_InPracticeMode || g_InRetakeMode) {
      return Plugin_Handled;
    }

    if (!g_BotMimicLoaded) {
      PrintToServer("You need the botmimic plugin loaded to use demo functions.");
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

    CancelMatchDemo();

    int numActiveDemos = 0;
    for (int i = 0; i < g_Demo_Bots.Length; i++) {
      int bot = g_Demo_Bots.Get(i);
      if (IsDemoBot(bot) && BotMimic_IsBotMimicing(bot)) {
        numActiveDemos++;
      }
    }

    if (g_Demo_FullRecording) {
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

  public Action Command_FinishRecordingDemo(int client, int args) {
    if (!g_InPracticeMode) {
      return Plugin_Handled;
    }
    FinishRecordingDemo(client, true);
    return Plugin_Handled;
  }

/*******************************************************************/

/****************************** Menus ******************************/
  stock void DemosMenu(int client) {
    if (!g_InBotDemoMode) {
      return;
    }
    g_Demo_Match_SelectedId = -1;
    g_Demo_Match_CurrentRoundIndex = -1;
    Menu menu = new Menu(DemosMenuHandler);
    menu.SetTitle("Menu de Demos");
    menu.AddItem("record_new", "Grabar Nuevo Demo");
    menu.AddItem("show_list", "Lista de Demos Grabadas");
    menu.AddItem("show_match_demos", "Lista de Demos De Partidas");
    char gameModeDisplayStr[OPTION_NAME_LENGTH];
    BMGameMode bmGameMode = BotMimic_GetGameMode();
    Format(gameModeDisplayStr, OPTION_NAME_LENGTH, "Modo de Demo: %s",
      bmGameMode == BM_GameMode_Spect ? "Espectador" :
      bmGameMode == BM_GameMode_Versus ? "Versus" :
      bmGameMode == BM_GameMode_Practice ? "Practica" :
      "error");
    menu.AddItem("toggle_gamemode", gameModeDisplayStr);
    menu.AddItem("versus_settings", "Opciones de Versus\n ", bmGameMode != BM_GameMode_Versus);

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
        g_Demo_WaitForSave[client] = true;
        PM_Message(client, "{ORANGE}Ingrese el nombre de la Demo a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
        return 0;
      } else if (StrEqual(buffer, "show_list")) {
        DemoShowListMenu(client);
        return 0;
      } else if (StrEqual(buffer, "show_match_demos")) {
        DemoMatchesListMenu(client);
        return 0;
      }else if (StrEqual(buffer, "toggle_gamemode")) {
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

  stock void DemoMatchesListMenu(int client) {
    Menu menu = new Menu(DemoMatchesListMenuHandler);
    menu.SetTitle("Lista de Demos");
    g_Demo_Match_CurrentRoundIndex = 0;
    g_Demo_Match_CurrentSpeed = 100;
    char match_name[OPTION_NAME_LENGTH];
    for (int i = 0; i < g_Demo_Matches.Length; i++) {
      S_Demo_Match demoMatch;
      g_Demo_Matches.GetArray(i, demoMatch, sizeof(demoMatch));
      char iStr[16];
      IntToString(i, iStr, sizeof(iStr));
      Format(match_name, sizeof(match_name), "Demo N-%d: %s", i, demoMatch.name);
      menu.AddItem(iStr, match_name);
    }
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
  }

  public int DemoMatchesListMenuHandler(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
      char buffer[OPTION_NAME_LENGTH];
      menu.GetItem(item, buffer, sizeof(buffer));
      g_Demo_Match_SelectedId = StringToInt(buffer);
      SingleDemoMatchMenu(client);
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
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
      strcopy(g_Demo_SelectedId[client], OPTION_ID_LENGTH, buffer);
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

  stock void SingleDemoMatchMenu(int client) {
    if (!g_InBotDemoMode) {
      return;
    }
    g_Demo_Match_SelectedPlayerPath[0] = 0;

    Menu menu = new Menu(SingleDemoMatchMenuHandler);
    S_Demo_Match demoMatch;
    g_Demo_Matches.GetArray(g_Demo_Match_SelectedId, demoMatch, sizeof(demoMatch));
    menu.SetTitle("Editor de Demo N-%d: %s", g_Demo_Match_SelectedId, demoMatch.name);

    // char displayStr[OPTION_NAME_LENGTH];
    menu.AddItem("play_stop", "Empezar(▶)/Cancelar(⬜) Demo");
    menu.AddItem("demo_controler", "Menu de Control de Demo");
    menu.AddItem("single_player", "Ver las demos de cada jugador individual\n ");

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
  }

  public int SingleDemoMatchMenuHandler(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
      char buffer[OPTION_NAME_LENGTH];
      menu.GetItem(item, buffer, sizeof(buffer));
      if (StrEqual(buffer, "play_stop")) {
        if (IsDemoMatchPlaying()) {
          // Stop
          CancelMatchDemo();
          PM_Message(client, "{ORANGE}Cancelando demo...");
        } else {
          // Play
          S_Demo_Match demoMatch;
          g_Demo_Matches.GetArray(g_Demo_Match_SelectedId, demoMatch, sizeof(demoMatch));
          PM_MessageToAll("{ORANGE}Empezando demo: {PURPLE}\"%s\"", demoMatch.name);
          PlayDemoMatch(g_Demo_Match_SelectedId, g_Demo_Match_CurrentRoundIndex);
          // // g_Demo_RoundRestart[client] = 15;
          // if (g_Demo_RoundRestart[client] > 0) {
          //   SetCvarIntSafe("mp_freezetime", g_Demo_RoundRestart[client]);
          //   CS_TerminateRound(0.0, CSRoundEnd_Draw);
          //   PlayDemo(g_Demo_SelectedId[client], _, float(g_Demo_RoundRestart[client]));
          // } else {
          //   PlayDemo(g_Demo_SelectedId[client]);
          // }
          SingleDemoMatchControlerMenu(client);
          return 0;
        }
      } else if (StrEqual(buffer, "demo_controler")) {
        SingleDemoMatchControlerMenu(client);
        return 0;
      } else if (StrEqual(buffer, "single_player")) {
        SingleDemoMatchPlayersListMenu(client);
        return 0;
      }
      SingleDemoMatchMenu(client);
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
      DemoMatchesListMenu(client);
    } else if (action == MenuAction_End) {
      delete menu;
    }
    return 0;
  }

  stock void SingleDemoMatchPlayersListMenu(int client) {
    if (!g_InBotDemoMode) {
      return;
    }
    g_Demo_Match_SelectedPlayerPath[0] = 0;

    Menu menu = new Menu(SingleDemoMatchPlayersListMenuHandler);
    S_Demo_Match demoMatch;
    g_Demo_Matches.GetArray(g_Demo_Match_SelectedId, demoMatch, sizeof(demoMatch));
    menu.SetTitle("Jugadores de Demo N-%d: %s", g_Demo_Match_SelectedId, demoMatch.name);
    int roundNum = demoMatch.roundIds.Get(g_Demo_Match_CurrentRoundIndex);
    // int player_rec_count = 0;
    char demoRoundPlayersPath[PLATFORM_MAX_PATH];
    Format(demoRoundPlayersPath, sizeof(demoRoundPlayersPath), "%s/%s/%d", g_Demo_Matches_File, demoMatch.name, roundNum);
    if (!DirExists(demoRoundPlayersPath)) {
      return;
    }
    DirectoryListing demosFolderList = OpenDirectory(demoRoundPlayersPath);
    char fileName[PLATFORM_MAX_PATH];
    while (demosFolderList.GetNext(fileName, sizeof(fileName))) {
      if (StrContains(fileName, ".rec") > 0) {
        // is a valid player
        char playerRecordingPath[PLATFORM_MAX_PATH];
        Format(playerRecordingPath, sizeof(playerRecordingPath), "%s/%s", demoRoundPlayersPath, fileName);
        BMFileHeader header;
        BMError error = BotMimic_GetFileHeaders(playerRecordingPath, header, sizeof(header));
        if (error != BM_NoError) {
          char errorString[128];
          BotMimic_GetErrorString(error, errorString, sizeof(errorString));
          PrintToServer("[PlayersListMenu]Failed to get %s headers: %s", playerRecordingPath, errorString);
          continue;
        }
        menu.AddItem(playerRecordingPath, header.playerName);
        // player_rec_count++;
      }
    }

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
  }

  public int SingleDemoMatchPlayersListMenuHandler(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
      menu.GetItem(item, g_Demo_Match_SelectedPlayerPath, sizeof(g_Demo_Match_SelectedPlayerPath));
      SingleDemoMatchPlayerMenu(client);
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
      SingleDemoMatchMenu(client);
    } else if (action == MenuAction_End) {
      delete menu;
    }
    return 0;
  }

  stock void SingleDemoMatchPlayerMenu(int client) {
    if (!g_InBotDemoMode) {
      return;
    }

    Menu menu = new Menu(SingleDemoMatchPlayerMenuHandler);
    BMFileHeader header;
    BMError error = BotMimic_GetFileHeaders(g_Demo_Match_SelectedPlayerPath, header, sizeof(header));
    if (error != BM_NoError) {
      char errorString[128];
      BotMimic_GetErrorString(error, errorString, sizeof(errorString));
      PrintToServer("[SinglePlayerMenu]Failed to get %s headers: %s", g_Demo_Match_SelectedPlayerPath, errorString);
      return;
    }
    menu.SetTitle("Jugador de Demo N-%d: %s", g_Demo_Match_SelectedId, header.playerName);
    menu.AddItem("play_stop", "Reproducir/Detener Esta Demo");
    menu.AddItem("spawn", "Ir a su posición inicial");

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
  }

  public int SingleDemoMatchPlayerMenuHandler(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
      char buffer[OPTION_NAME_LENGTH];
      menu.GetItem(item, buffer, sizeof(buffer));
      BMFileHeader header;
      BMError error = BotMimic_GetFileHeaders(g_Demo_Match_SelectedPlayerPath, header, sizeof(header));
      if (error != BM_NoError) {
        char errorString[128];
        BotMimic_GetErrorString(error, errorString, sizeof(errorString));
        PrintToServer("[SinglePlayerMenu]Failed to get %s headers: %s", g_Demo_Match_SelectedPlayerPath, errorString);
        return 0;
      }
      if (StrEqual(buffer, "spawn")) {
        TeleportEntity(client, header.playerSpawnPos, header.playerSpawnAng, ZERO_VECTOR);
      } else if (StrEqual(buffer, "play_stop")) {
        for (int i = 0; i < g_Demo_Match_Bots.Length; i++) {
          int bot = g_Demo_Match_Bots.Get(i);
          if (IsDemoMatchBot(bot)) {
            if (BotMimic_IsBotMimicing(bot)) {
              char filePath[PLATFORM_MAX_PATH];
              BotMimic_GetMimicFileFromBot(bot, filePath, sizeof(filePath));
              if (StrEqual(filePath, g_Demo_Match_SelectedPlayerPath)) {
                PM_Message(client, "{ORANGE}Cancelando demo...");
                BotMimic_StopBotMimicing(bot);
                ServerCommand("bot_kick \"%s\"", g_Bots_OriginalName[bot]);
                SingleDemoMatchPlayerMenu(client);
                return 0;
              }
            }
          }
        }
        PM_Message(client, "{ORANGE}Starting Player \"%s\" Demo...", header.playerName);
        GetDemoMatchBot(g_Demo_Match_SelectedPlayerPath);
      }
      SingleDemoMatchPlayerMenu(client);
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
      SingleDemoMatchPlayersListMenu(client);
    } else if (action == MenuAction_End) {
      delete menu;
    }
    return 0;
  }

  stock void SingleDemoMatchControlerMenu(int client) {
    if (!g_InBotDemoMode) {
      return;
    }
    Menu menu = new Menu(SingleDemoMatchControlerMenuHandler);
    menu.SetTitle("Control de Demo");

    char displayStr[OPTION_NAME_LENGTH];
    Format(displayStr, sizeof(displayStr), "Ronda Actual: %d", g_Demo_Match_CurrentRoundIndex);
    menu.AddItem("current_round", displayStr, ITEMDRAW_DISABLED);
    menu.AddItem("next_round", "Ir a siguiente ronda");
    menu.AddItem("prev_round", "Ir a anterior ronda\n ");
    Format(displayStr, sizeof(displayStr), "Velocidad Actual: %d%%", g_Demo_Match_CurrentSpeed);
    menu.AddItem("current_speed", displayStr, ITEMDRAW_DISABLED);
    menu.AddItem("next_speed", "Acelerar");
    menu.AddItem("prev_speed", "Desacelerar");

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
  }

  public int SingleDemoMatchControlerMenuHandler(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
      char buffer[OPTION_NAME_LENGTH];
      menu.GetItem(item, buffer, sizeof(buffer));
      S_Demo_Match demoMatch;
      g_Demo_Matches.GetArray(g_Demo_Match_SelectedId, demoMatch, sizeof(demoMatch));
      if (StrEqual(buffer, "next_round")) {
        if (g_Demo_Match_CurrentRoundIndex >= (demoMatch.roundIds.Length-1)) {
          g_Demo_Match_CurrentRoundIndex=0;
        } else {
          g_Demo_Match_CurrentRoundIndex++;
        }
        //
      } else if (StrEqual(buffer, "prev_round")) {
        if (g_Demo_Match_CurrentRoundIndex <= 0) {
          g_Demo_Match_CurrentRoundIndex = demoMatch.roundIds.Length-1;
        } else {
          g_Demo_Match_CurrentRoundIndex--;
        }
        //
      } else if (StrEqual(buffer, "next_speed")) {
        switch(g_Demo_Match_CurrentSpeed) {
          case -400:
            g_Demo_Match_CurrentSpeed = -200;
          case -200:
            g_Demo_Match_CurrentSpeed = -150;
          case -150:
            g_Demo_Match_CurrentSpeed = -100;
          case -100:
            g_Demo_Match_CurrentSpeed = -50;
          case -50:
            g_Demo_Match_CurrentSpeed = 50;
          case 50:
            g_Demo_Match_CurrentSpeed =  100;
          case 100:
            g_Demo_Match_CurrentSpeed = 150;
          case 150:
            g_Demo_Match_CurrentSpeed = 200;
          case 200:
            g_Demo_Match_CurrentSpeed = 400;
          case 400: {
            PM_Message(client, "{LIGHT_RED}Max Speed!");
            g_Demo_Match_CurrentSpeed = 400;
          }
          default:
            g_Demo_Match_CurrentSpeed = 100;
        }
        // SetConVarFloatSafe("host_timescale", FloatAbs(g_Demo_Match_CurrentSpeed/100.0));
      } else if (StrEqual(buffer, "prev_speed")) {
        switch(g_Demo_Match_CurrentSpeed) {
          case -400: {
            PM_Message(client, "{LIGHT_RED}Min Speed!");
            g_Demo_Match_CurrentSpeed = -400;
          }
          case -200:
            g_Demo_Match_CurrentSpeed = -400;
          case -150:
            g_Demo_Match_CurrentSpeed = -200;
          case -100:
            g_Demo_Match_CurrentSpeed = -150;
          case -50:
            g_Demo_Match_CurrentSpeed = -100;
          case 50:
            g_Demo_Match_CurrentSpeed = -50;
          case 100:
            g_Demo_Match_CurrentSpeed = 50;
          case 150:
            g_Demo_Match_CurrentSpeed =  100;
          case 200:
            g_Demo_Match_CurrentSpeed = 150;
          case 400:
            g_Demo_Match_CurrentSpeed = 200;
          default:
            g_Demo_Match_CurrentSpeed = 100;
        }
        // SetConVarFloatSafe("host_timescale", FloatAbs(g_Demo_Match_CurrentSpeed/100.0));
      }
      SingleDemoMatchControlerMenu(client);
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
      SingleDemoMatchMenu(client);
    } else if (action == MenuAction_End) {
      delete menu;
    }
    return 0;
  }

  stock void SingleDemoEditorMenu(int client, bool playing = false) {
    if (!g_InBotDemoMode) {
      return;
    }
    g_Demo_SelectedRoleId[client] = -1;
    // g_Demo_CurrentEditingRole[client] = -1;

    ServerCommand("sm_botmimic_snapshotinterval 64");

    Menu menu = new Menu(SingleDemoEditorMenuHandler);
    char demo_name[OPTION_NAME_LENGTH];
    GetDemoName(g_Demo_SelectedId[client], demo_name, OPTION_NAME_LENGTH);
    menu.SetTitle("Editor de Demo N-%s: %s", g_Demo_SelectedId[client], demo_name);

    char displayStr[OPTION_NAME_LENGTH];
    menu.AddItem("play_pause", "Reproducir(▶)/Detener(⬜) Demo");
    if (g_Demo_RoundRestart[client] == 0) {
      strcopy(displayStr, sizeof(displayStr), "No")
    } else {
      Format(displayStr, sizeof(displayStr), "%d segundos", g_Demo_RoundRestart[client]);
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
          GetDemoName(g_Demo_SelectedId[client], demo_name, sizeof(demo_name));
          PM_MessageToAll("{ORANGE}Empezando demo: {PURPLE}\"%s\"", demo_name);
          if (g_Demo_RoundRestart[client] > 0) {
            SetCvarIntSafe("mp_freezetime", g_Demo_RoundRestart[client]);
            CS_TerminateRound(0.0, CSRoundEnd_Draw);
            PlayDemo(g_Demo_SelectedId[client], _, float(g_Demo_RoundRestart[client]));
          } else {
            PlayDemo(g_Demo_SelectedId[client]);
          }
          SingleDemoEditorMenu(client, true);
          return 0;
        }
      } else if (StrEqual(buffer, "rename")) {
        PM_Message(client, "{ORANGE}Ingrese El Nuevo Nombre: ");
        g_Demo_WaitForDemoSave[client] = true;
        return 0;
      } else if (StrEqual(buffer, "delete")) {
        DemoDeletionMenu(client);
        return 0;
      } else if (StrEqual(buffer, "round_restart")) {
        g_Demo_RoundRestart[client] += 2;
        if (g_Demo_RoundRestart[client] > DemoOption_RoundRestart_MAX)
          g_Demo_RoundRestart[client] = 0;
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
    // g_Demo_CurrentEditingRole[client] = -1;
    Menu menu = new Menu(SingleDemoSoloRecordMenuHandler);
    char demo_name[OPTION_NAME_LENGTH];
    GetDemoName(g_Demo_SelectedId[client], demo_name, OPTION_NAME_LENGTH);
    menu.SetTitle("Editor de Demo %s", demo_name);
    for (int i = 0; i < MAX_DEMO_BOTS; i++) {
      bool recordedLastRole = true;
      if (i > 0) recordedLastRole = CheckDemoRoleKVString(g_Demo_SelectedId[client], i-1, "file");
      int style = recordedLastRole ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;

      char iStr[OPTION_ID_LENGTH];
      IntToString(i, iStr, sizeof(iStr));

      char roleName[OPTION_NAME_LENGTH];
      if (!GetDemoRoleKVString(g_Demo_SelectedId[client], iStr, "name", roleName, sizeof(roleName))) {
        IntToString(i + 1, roleName, sizeof(roleName));
      }
      char teamName[OPTION_NAME_LENGTH];
      if (!GetDemoRoleKVString(g_Demo_SelectedId[client], iStr, "team", roleName, sizeof(roleName))) {
        (GetClientTeam(client) == CS_TEAM_CT) ? strcopy(teamName, sizeof(teamName), "CT") : strcopy(teamName, sizeof(teamName), "TT") ;
      }
      if (CheckDemoRoleKVString(g_Demo_SelectedId[client], i, "file")) {
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
          } else if (playerCount > MAX_DEMO_BOTS) {
            PM_Message(
                client,
                "No puedes grabar una demo con %d jugadores. Solo hay %d bots soportados. Los otros jugadores deberán ser movidos a espectador.",
                playerCount, MAX_DEMO_BOTS);\
          } else {
            int demoRole = 0;
            for (int i = 1; i <= MaxClients; i++) {
              if (IsPlayer(i) && !BotMimic_IsPlayerRecording(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
                g_Demo_CurrentEditingRole[i] = demoRole;
                g_Demo_SelectedId[i] = g_Demo_SelectedId[client];
                StartDemoRecording(i, demoRole, false);
                demoRole++;
              }
            }
            g_Demo_FullRecording = true;
            g_Demo_FullRecordingClient = client;
            PM_MessageToAll("{ORANGE}Grabando demo con %d jugadores.", playerCount);
            PM_MessageToAll("{ORANGE}La grabación terminara automáticamente cuando cualquier jugador use noclip.");
            return 0;
          }
        }
      } else {
        for (int roleId = 0; roleId < MAX_DEMO_BOTS; roleId++) {
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
    if (!g_InBotDemoMode) {
      return;
    }
    Menu menu = new Menu(SingleDemoRoleMenuHandler);
    g_Demo_CurrentEditingRole[client] = roleId;

    char demoName[OPTION_NAME_LENGTH];
    GetDemoName(g_Demo_SelectedId[client], demoName, sizeof(demoName));

    char roleName[OPTION_NAME_LENGTH];
    char roleIdStr[OPTION_ID_LENGTH];
    IntToString(roleId, roleIdStr, sizeof(roleIdStr));
    GetDemoRoleKVString(g_Demo_SelectedId[client], roleIdStr, "name", roleName, sizeof(roleName));
    if (StrEqual(roleName, "")) {
      IntToString(roleId + 1, roleName, sizeof(roleName));
    }

    menu.SetTitle("Demo %s: Jugador %s", demoName, roleName);
    bool recorded = CheckDemoRoleKVString(g_Demo_SelectedId[client], roleId, "file");
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
      int roleId = g_Demo_CurrentEditingRole[client];
      char buffer[OPTION_NAME_LENGTH];
      menu.GetItem(item, buffer, sizeof(buffer));

      if (StrEqual(buffer, "record")) {
        if (BotMimic_IsPlayerRecording(client)) {
          PM_Message(client, "{ORANGE}Termina tu Grabación actual primero!");
        } else if (IsDemoPlaying()) {
          PM_Message(client, "{ORANGE}Termina tu Demo actual primero!");
        } else {
          StartDemoRecording(client, roleId);
          PlayDemo(g_Demo_SelectedId[client], roleId);
          return 0;
        }
      } else if (StrEqual(buffer, "spawn")) {
        GotoDemoRoleStart(client, g_Demo_SelectedId[client], roleId);
      } else if (StrEqual(buffer, "play")) {
        PlayRoleFromDemo(g_Demo_SelectedId[client], roleId, 0.0);
      } else if (StrEqual(buffer, "rename")) {
        PM_Message(client, "{ORANGE}Ingrese El Nuevo Nombre: ");
        g_Demo_WaitForRoleSave[client] = true;
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
    GetDemoName(g_Demo_SelectedId[client], demoName, sizeof(demoName));

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
        GetDemoName(g_Demo_SelectedId[client], demoName, sizeof(demoName));
        ArrayList roleRecordings = new ArrayList(PLATFORM_MAX_PATH);
        if (g_DemosKv.JumpToKey(g_Demo_SelectedId[client])) {
          if (g_DemosKv.GotoFirstSubKey()) {
            do {
              char filepath[PLATFORM_MAX_PATH];
              g_DemosKv.GetString("file", filepath, sizeof(filepath));
              if (StrEqual(filepath, "")) {
                continue;
              }
              roleRecordings.PushString(filepath);
            } while (g_DemosKv.GotoNextKey())
            g_DemosKv.GoBack();
          }
          g_DemosKv.GoBack();
        }
        for (int i = 0; i < roleRecordings.Length; i++) {
          char filepath[PLATFORM_MAX_PATH];
          roleRecordings.GetString(i, filepath, sizeof(filepath));
          BotMimic_DeleteRecord(filepath);
        }
        DeleteDemo(g_Demo_SelectedId[client]);
        delete roleRecordings;
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
    menu.SetTitle("Granadas de jugador %d", g_Demo_CurrentEditingRole[client] + 1);
    menu.ExitButton = true;
    menu.ExitBackButton = true;

    char roleIdStr[OPTION_ID_LENGTH];
    IntToString(g_Demo_CurrentEditingRole[client], roleIdStr, sizeof(roleIdStr));
    GetDemoRoleKVNades(client, g_Demo_SelectedId[client], roleIdStr);
    for (int i = 0; i < g_DemoNadeData[client].Length; i++) {
      S_Demo_NadeData demoNadeData;
      g_DemoNadeData[client].GetArray(i, demoNadeData, sizeof(demoNadeData));
      char display[128];
      GrenadeTypeString(demoNadeData.grenadeType, display, sizeof(display));
      UpperString(display);
      AddMenuInt(menu, i, display);
    }
    if (g_DemoNadeData[client].Length == 0) {
      PM_Message(client, "{ORANGE}Este Jugador No Tiene Granadas en su Demo.");
      SingleDemoRoleMenu(client, g_Demo_CurrentEditingRole[client]);
      delete menu;
      return;
    }

    menu.DisplayAt(client, MENU_TIME_FOREVER, pos);
  }

  public int DemoRoleNadesMenuHandler(Menu menu, MenuAction action, int client, int item) {
    if (action == MenuAction_Select) {
      int nadeIndex = GetMenuInt(menu, item);
      S_Demo_NadeData demoNadeData;
      g_DemoNadeData[client].GetArray(nadeIndex, demoNadeData, sizeof(demoNadeData));
      TeleportEntity(client, demoNadeData.origin, demoNadeData.angles, ZERO_VECTOR);
      if (demoNadeData.grenadeType != GrenadeType_None) {
        char weaponName[64];
        GetGrenadeWeapon(demoNadeData.grenadeType, weaponName, sizeof(weaponName));
        FakeClientCommand(client, "use %s", weaponName);
        DemoRoleNadesMenu(client, GetMenuSelectionPosition());
      }
    } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
      SingleDemoRoleMenu(client, g_Demo_CurrentEditingRole[client]);
    } else if (action == MenuAction_End) {
      delete menu;
    }
    return 0;
  }

  public void GiveDemoMenuInContext(int client) {
    if (!g_InBotDemoMode) {
      return;
    }
    if (DemoExists(g_Demo_SelectedId[client])) {
      if (g_Demo_CurrentEditingRole[client] >= 0) {
        // Demo-role specific menu.
        SingleDemoRoleMenu(client, g_Demo_CurrentEditingRole[client]);
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

/********************* Events, Forwards, Hooks *********************/
  public void Demos_ClientDisconnect(int client) {
    g_Demo_SelectedId[client] = "";
    g_Demo_SelectedRoleId[client] = -1; //g_CurrentEditingRole[client] = -1;
    g_Demo_RoundRestart[client] = 0;
    g_Demo_CurrentEditingRole[client] = -1;
    // g_Demo_CurrentRecordingStartTime[client];
    g_Demo_BotStopped[client] = false; // g_StopBotSignal
    g_Demo_PlayRoundTimer[client] = false;
    delete g_DemoNadeData[client];
  }

  public void Demos_PluginStart() {
    g_Demo_Bots = new ArrayList();
    g_Demo_Match_Bots = new ArrayList();
  }

  public void Demos_MapStart() {
    delete g_DemosKv;
    g_DemosKv = new KeyValues("Demos");

    char map[PLATFORM_MAX_PATH];
    GetCleanMapName(map, sizeof(map));

    char demoFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, demoFile, sizeof(demoFile), "data/practicemode/demos/%s.cfg", map);
    g_DemosKv.ImportFromFile(demoFile);

    BuildPath(Path_SM, g_Demo_Matches_File, sizeof(g_Demo_Matches_File), "data/practicemode/demos/matches/%s", map);

    delete g_Demo_Matches;
    GetDemoMatches();

    for (int i = 0; i <= MaxClients; i++) {
      delete g_DemoNadeData[i];
      g_DemoNadeData[i] = new ArrayList(sizeof(S_Demo_NadeData));
      // g_Demo_PlayRoundTimer[i] = false; it starts with false
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

  public Action BotMimic_OnBotMimicLoops(int client) {
    if (!g_InPracticeMode || g_InRetakeMode) {
      return Plugin_Handled;
    }
    if (BotMimic_GetGameMode() == BM_GameMode_Practice) {
      // PrintToChatAll("looping");
      return Plugin_Continue;
    }
    // //if (g_InBotDemoMode) {
    // if (g_Demo_BotStopped[client]) {
    //   // Second Loop
    //   return Plugin_Handled;
    // }
    // // First Loop
    // g_Demo_BotStopped[client] = true;
    // //}
    return Plugin_Handled; ////
    // return Plugin_Continue;
  }

  public void BotMimic_OnRecordSaved(int client, char[] name, char[] category, char[] subdir, char[] file) {
    if (g_InBotDemoMode) {
      if (g_Demo_CurrentEditingRole[client] >= 0) {
        char roleIdStr[OPTION_ID_LENGTH];
        IntToString(g_Demo_CurrentEditingRole[client], roleIdStr, sizeof(roleIdStr));
        SetDemoRoleKVString(g_Demo_SelectedId[client], roleIdStr, "file", file);
        SetDemoRoleKVNades(client, g_Demo_SelectedId[client], roleIdStr);
        SetDemoRoleKVString(g_Demo_SelectedId[client], roleIdStr, "team", GetClientTeam(client) == CS_TEAM_CT ? "CT" : "TT");

        if (g_Demo_FullRecording && g_Demo_FullRecordingClient == client) {
          PM_MessageToAll("{ORANGE}Terminó la grabación completa de esta demo.");
          RequestFrame(ResetFullDemoRecording, GetClientSerial(client));
        } else {
          PM_Message(client, "{ORANGE}Terminó la grabación de jugador rol %d", g_Demo_CurrentEditingRole[client] + 1);
          GiveDemoMenuInContext(client);
        }
        MaybeWriteNewDemoData();
      }
      return;
    } else if (g_Nade_NewDemoSaved[client]) {
      S_Demo_NadeData demoNadeData;
      g_DemoNadeData[client].GetArray(0, demoNadeData, sizeof(demoNadeData));
      SetClientGrenadeFloat(g_Nade_CurrentSavedId[client], "delay", demoNadeData.delay);
      SetClientGrenadeData(g_Nade_CurrentSavedId[client], "record", file);

      MaybeWriteNewGrenadeData();
      g_Nade_NewDemoSaved[client] = false;
    }
  }

  public void BotMimic_OnBotStopsMimic(int client, char[] name, char[] category, char[] path) {
    if (IsDemoBot(client)) {
      if (BotMimic_GetGameMode() == BM_GameMode_Versus) {
        SetupVersusDemoBot(client);
        CreateTimer(0.1, Timer_CheckVersusDemoPlayerFast, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
      } else {
        ForcePlayerSuicide(client);
      }
    } else if (g_Is_NadeBot[client]) {
      CreateTimer(1.5, Timer_KickBot, client);
    } else if (g_Is_Demo_Match_Bot[client]) {
      // RequestFrame(ForcePlayerSuicide, client);
      // TODO: GET ALL EVENTS FROM DEMO USING THE PARSER -> replicate all of them :(
      ServerCommand("bot_kick \"%s\"", g_Bots_OriginalName[client]);
    }
  }

/*******************************************************************/

/****************************** Misc *******************************/
  // Cancels all current playing demos.
  public void CancelAllDemos() {
    for (int i = 0; i < g_Demo_Bots.Length; i++) {
      int bot = g_Demo_Bots.Get(i);
      if (IsDemoBot(bot)) {
        if (BotMimic_IsBotMimicing(bot)) {
          BotMimic_StopBotMimicing(bot);
        }
        if (BotMimic_GetGameMode() == BM_GameMode_Versus && IsPlayerAlive(bot)) {
          ForcePlayerSuicide(bot);
        }
      }
    }
  }

  public void CancelMatchDemo() {
    for (int i = 0; i < g_Demo_Match_Bots.Length; i++) {
      int bot = g_Demo_Match_Bots.Get(i);
      if (IsDemoMatchBot(bot)) {
        if (BotMimic_IsBotMimicing(bot)) {
          BotMimic_StopBotMimicing(bot);
        }
        if (BotMimic_GetGameMode() == BM_GameMode_Versus && IsPlayerAlive(bot)) {
          ForcePlayerSuicide(bot);
        }
      }
    }
    g_Demo_Match_Bots.Clear();
  }

  // Returns if a demo is currently playing.
  stock bool IsDemoPlaying(int role = -1) {
    for (int i = 0; i < g_Demo_Bots.Length; i++) {
      if (role != -1 && role != i) {
        continue;
      }

      int bot = g_Demo_Bots.Get(i);
      if (
        IsDemoBot(bot) &&
        (BotMimic_IsBotMimicing(bot) || (IsPlayerAlive(bot) && BotMimic_GetGameMode() == BM_GameMode_Versus))
      ) return true; //(versusMode && IsPlayerAlive(bot)
    }
    return false;
  }

  stock bool IsDemoMatchPlaying() {
    for (int i = 0; i < g_Demo_Match_Bots.Length; i++) {
      int bot = g_Demo_Match_Bots.Get(i);
      if (
        IsDemoMatchBot(bot) &&
        (BotMimic_IsBotMimicing(bot) || (IsPlayerAlive(bot) && BotMimic_GetGameMode() == BM_GameMode_Versus))
      ) return true; //(versusMode && IsPlayerAlive(bot)
    }
    return false;
  }

  stock void PlayDemo(const char[] demoId, int exclude = -1, float delay = 0.0) {
    g_Demo_CurrentNade = -1;
    ArrayList demoRoleIds = new ArrayList();
    if (g_DemosKv.JumpToKey(demoId)) {
      if (g_DemosKv.GotoFirstSubKey()) {
        do {
          char roleIdStr[16];
          g_DemosKv.GetSectionName(roleIdStr, sizeof(roleIdStr));
          int roleId = StringToInt(roleIdStr);
          if (roleId == exclude) {
            continue;
          }
          demoRoleIds.Push(roleId);
        } while (g_DemosKv.GotoNextKey());
        g_DemosKv.GoBack();
      }
      g_DemosKv.GoBack();
    }

    for (int i = 0; i < demoRoleIds.Length; i++) {
      int role = demoRoleIds.Get(i);
      PlayRoleFromDemo(demoId, role, delay);
    }
    delete demoRoleIds;
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
      char errorString[128];
      BotMimic_GetErrorString(err, errorString, sizeof(errorString));
      PM_MessageToAll("{LIGHT_RED}Fatal Error %s", errorString);
      PrintToServer("[StartBotMimicDemo]Error playing record %s on client %d: %s", filepath, client, errorString);
      ExitDemoMode();
    }

    delete pack;
  }

  stock void PlayDemoMatch(int matchId, int roundIndex) {
    S_Demo_Match demoMatch;
    g_Demo_Matches.GetArray(g_Demo_Match_SelectedId, demoMatch, sizeof(demoMatch));
    int roundNum = demoMatch.roundIds.Get(roundIndex);
    // int player_rec_count = 0;
    char demoRoundPlayersPath[PLATFORM_MAX_PATH];
    Format(demoRoundPlayersPath, sizeof(demoRoundPlayersPath), "%s/%s/%d", g_Demo_Matches_File, demoMatch.name, roundNum);
    if (!DirExists(demoRoundPlayersPath)) {
      return;
    }
    DirectoryListing demosFolderList = OpenDirectory(demoRoundPlayersPath);
    char fileName[PLATFORM_MAX_PATH];
    while (demosFolderList.GetNext(fileName, sizeof(fileName))) {
      if (StrContains(fileName, ".rec") > 0) {
        // is a valid player|recording
        char playerRecordingPath[PLATFORM_MAX_PATH];
        Format(playerRecordingPath, sizeof(playerRecordingPath), "%s/%s", demoRoundPlayersPath, fileName);
        BMFileHeader header;
        BMError error = BotMimic_GetFileHeaders(playerRecordingPath, header, sizeof(header));
        if (error != BM_NoError) {
          char errorString[128];
          BotMimic_GetErrorString(error, errorString, sizeof(errorString));
          PrintToServer("[PlayersListMenu]Failed to get %s headers: %s", playerRecordingPath, errorString);
          continue;
        }
        GetDemoMatchBot(playerRecordingPath);
      }
    }
  }

  stock void GetDemoMatchBot(const char[] filepath) {
    ServerCommand("bot_quota_mode normal");
    ServerCommand("bot_add");
    DataPack pack = new DataPack();
    CreateDataTimer(0.2, Timer_GetDemoMatchBot, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteString(filepath);
  }

  public Action Timer_GetDemoMatchBot(Handle timer, DataPack pack) {
    pack.Reset();
    char filepath[PLATFORM_MAX_PATH];
    pack.ReadString(filepath, sizeof(filepath));
    char full_path[15][128];
    int demoTeam = CS_TEAM_T;
    ExplodeString(filepath, "/", full_path, sizeof(full_path), sizeof(full_path[]));
    for (int i = 0; i < sizeof(full_path); i++) {
      if (String_EndsWith(full_path[i], ".rec")) {
        if (full_path[i][0] == 'C') {
          demoTeam = CS_TEAM_CT;
        }
        break;
      }
    }
    int bot = GetLiveBot(demoTeam);
    if (bot < 0) {
      PrintToServer("[Timer_GetDemoMatchBot] error getting bot of %s", filepath);
      return Plugin_Stop;
    }
    GetClientName(bot, g_Bots_OriginalName[bot], MAX_NAME_LENGTH);
    BMFileHeader header;
    BMError error = BotMimic_GetFileHeaders(filepath, header, sizeof(header));
    if (error != BM_NoError) {
      char errorString[128];
      BotMimic_GetErrorString(error, errorString, sizeof(errorString));
      PrintToServer("[Timer_GetDemoMatchBot]Error playing record %s on client %d: %s", filepath, bot, errorString);
      // kick ?
      ServerCommand("bot_kick \"%s\"", g_Bots_OriginalName[bot]);
      return Plugin_Stop;
    }
    SetClientName(bot, header.playerName);

    g_Is_Demo_Match_Bot[bot] = true;
    Client_RemoveAllWeapons(bot);
    Entity_SetCollisionGroup(bot, COLLISION_GROUP_DEBRIS);

    if (!IsPlayerAlive(bot)) {
      CS_RespawnPlayer(bot);
    }

    g_Bots_SpawnAngles[bot] = header.playerSpawnAng;
    TeleportEntity(bot, header.playerSpawnPos, g_Bots_SpawnAngles[bot], {0.0, 0.0, 0.0});
    DataPack demoPack = new DataPack();
    RequestFrame(StartBotMimicDemo, demoPack);
    demoPack.WriteCell(bot);
    demoPack.WriteString(filepath);
    demoPack.WriteFloat(0.0);
    g_Demo_BotStopped[bot] = false;
    g_Demo_Match_Bots.Push(bot);

    return Plugin_Stop;
  }

  stock void PlayRoleFromDemo(const char[] demoId, int roleId, float delay = 0.0) {
    char filepath[PLATFORM_MAX_PATH + 1];
    char roleIdStr[16];
    IntToString(roleId, roleIdStr, sizeof(roleIdStr));
    if (g_DemosKv.JumpToKey(demoId)) {
      if (g_DemosKv.JumpToKey(roleIdStr)) {
        g_DemosKv.GetString("file", filepath, sizeof(filepath));
        g_DemosKv.GoBack();
      }
      g_DemosKv.GoBack();
    }
    if (StrEqual(filepath, "")) {
      PrintToServer("[PlayRoleFromDemo] demo%s role%d NO FILEPATH", demoId, roleId);
      return;
    }
    for (int i = 0; i < g_Demo_Bots.Length; i++) {
      int bot = g_Demo_Bots.Get(i);
      if (IsDemoBot(bot)) {
        if (BotMimic_IsBotMimicing(bot)) {
          // Check if its different file
          char lastMimicFilePath[PLATFORM_MAX_PATH];
          BotMimic_GetMimicFileFromBot(bot, lastMimicFilePath, sizeof(lastMimicFilePath));
          if (StrEqual(lastMimicFilePath, filepath)) {
            BotMimic_StopBotMimicing(bot);
            return;
          }
        }
      }
    }
    GetDemoBot(StringToInt(demoId), roleId, delay);
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
      PM_MessageToAll("{LIGHT_RED}Fatal Error %s", errorString);
      PrintToServer("[GotoDemoRoleStart]Failed to get %s headers: %s", filepath, errorString);
      ExitDemoMode();
      return;
    }
    TeleportEntity(client, header.playerSpawnPos, header.playerSpawnAng, {0.0, 0.0, 0.0});
  }

  public void ExitDemoMode() {
    for (int i = 0; i < g_Demo_Bots.Length; i++) {
      int bot = g_Demo_Bots.Get(i);
      if (IsDemoBot(bot)) {
        ServerCommand("bot_kick \"%s\"", g_Bots_OriginalName[bot]);
      }
    }
    g_Demo_Bots.Clear();
    g_InBotDemoMode = false;
    g_Demo_FullRecording = false;
    SetCvarIntSafe("mp_respawn_on_death_ct", 1);
    SetCvarIntSafe("mp_respawn_on_death_t", 1);
  }

  public void InitDemoFunctions() {
    for (int i = 0; i <= MaxClients; i++) {
      g_Is_DemoBot[i] = 0; //g_ReplayBotClients[i] = -1;
      g_Demo_BotStopped[i] = false;
      g_Demo_CurrentEditingRole[i] = -1;
      g_Demo_SelectedId[i] = "";
    }
    g_Demo_Bots.Clear();

    g_InBotDemoMode = true;
    g_Demo_FullRecording = false;
  }

  public void GetDemoBot(int demoId, int roleId, float delay) {
    ServerCommand("bot_quota_mode normal");
    ServerCommand("bot_add");
    DataPack pack = new DataPack();
    CreateDataTimer(0.2, Timer_GetDemoBot, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(demoId);
    pack.WriteCell(roleId);
    pack.WriteFloat(delay);
  }

  public Action Timer_GetDemoBot(Handle timer, DataPack pack) {
    pack.Reset();
    int demoId = pack.ReadCell();
    int roleId = pack.ReadCell();
    float delay = pack.ReadFloat();
    char filepath[PLATFORM_MAX_PATH + 1];
    char name[MAX_NAME_LENGTH];
    char teamStr[16];
    char demoIdStr[16], roleIdStr[16];
    IntToString(demoId, demoIdStr, sizeof(demoIdStr));
    IntToString(roleId, roleIdStr, sizeof(roleIdStr));
    if (g_DemosKv.JumpToKey(demoIdStr)) {
      if (g_DemosKv.JumpToKey(roleIdStr)) {
        g_DemosKv.GetString("file", filepath, sizeof(filepath));
        g_DemosKv.GetString("name", name, sizeof(name));
        g_DemosKv.GetString("team", teamStr, sizeof(teamStr));
        g_DemosKv.GoBack();
      }
      g_DemosKv.GoBack();
    }

    int team = (StrEqual(teamStr, "CT")) ? CS_TEAM_CT : CS_TEAM_T;

    int bot = GetLiveBot(team);
    if (bot < 0) {
      PrintToServer("[Timer_GetDemoMatchBot] error getting bot of %s", filepath);
      return Plugin_Stop;
    }
    GetClientName(bot, g_Bots_OriginalName[bot], MAX_NAME_LENGTH);
    // double check?
    if (StrEqual(filepath, "")) {
      ServerCommand("bot_kick \"%s\"", g_Bots_OriginalName[bot]);
      return Plugin_Stop;
    }
    BMFileHeader header;
    BMError error = BotMimic_GetFileHeaders(filepath, header, sizeof(header));
    if (error != BM_NoError) {
      char errorString[128];
      BotMimic_GetErrorString(error, errorString, sizeof(errorString));
      PrintToServer("[Timer_GetDemoMatchBot]Error playing record %s on client %d: %s", filepath, bot, errorString);
      ServerCommand("bot_kick \"%s\"", g_Bots_OriginalName[bot]);
      return Plugin_Stop;
    }
    if (StrEqual(name, "")) {
      SetClientName(bot, header.playerName);
    } else {
      SetClientName(bot, name);
    }

    g_Is_DemoBot[bot] = true;
    Client_RemoveAllWeapons(bot);
    Entity_SetCollisionGroup(bot, COLLISION_GROUP_DEBRIS);

    if (GetClientTeam(bot) != team) {
      CS_SwitchTeam(bot, team);
    }
    if (!IsPlayerAlive(bot)) {
      CS_RespawnPlayer(bot);
    }

    g_Bots_SpawnAngles[bot] = header.playerSpawnAng;
    TeleportEntity(bot, header.playerSpawnPos, g_Bots_SpawnAngles[bot], {0.0, 0.0, 0.0});
    DataPack demoPack = new DataPack();
    RequestFrame(StartBotMimicDemo, demoPack);
    demoPack.WriteCell(bot);
    demoPack.WriteString(filepath);
    demoPack.WriteFloat(delay);
    g_Demo_BotStopped[bot] = false;
    g_Demo_Bots.Push(bot);

    return Plugin_Stop;
  }

  public void ResetFullDemoRecording(int serial) {
    g_Demo_FullRecording = false;
    g_Demo_FullRecordingClient = -1;
    int client = GetClientFromSerial(serial);
    if (IsPlayer(client)) {
      GiveDemoMenuInContext(client);
    }
  }

  public void FinishRecordingDemo(int client, bool printOnFail) {
    if (g_Demo_FullRecording) {
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
    if (roleId < 0 || roleId >= MAX_DEMO_BOTS) {
      return;
    }

    g_DemoNadeData[client].Clear();
    g_Demo_CurrentEditingRole[client] = roleId;
    g_Demo_CurrentRecordingStartTime[client] = GetGameTime();

    char recordName[128];
    Format(recordName, sizeof(recordName), "Rol de jugador %d", roleId + 1);
    char roleString[32];
    Format(roleString, sizeof(roleString), "rol %d", roleId);
    BotMimic_StartRecording(client, recordName, "practicemode", roleString);

    if (g_Demo_PlayRoundTimer[client]) {
      float timer_duration = float(GetRoundTimeSeconds());
      g_Timer_RunningCommand[client] = true;
      g_Timer_RunningLiveCommand[client] = true;
      g_TimerType[client] = TimerType_Countdown_Movement;
      g_Timer_Duration[client] = timer_duration;
      StartClientTimer(client);
    }

    if (printCommands) {
      PM_Message(client, "{ORANGE}Grabación de jugador %d empezada.", roleId + 1);
      PM_Message(client, "{ORANGE}Usa .finish o activa noclip para dejar de grabar.");
    }
  }

/*******************************************************************/

/**************************** Helpers ******************************/
  // Update Match Demos List
  public bool GetDemoMatches() {
    int demo_folder_count = 0;
    g_Demo_Matches = new ArrayList(sizeof(S_Demo_Match));

    DirectoryListing demosFolderList = OpenDirectory(g_Demo_Matches_File);
    FileType fileType;
    char folderName[128];
    while (demosFolderList.GetNext(folderName, sizeof(folderName), fileType)) {
      if (!(StrEqual(folderName, ".") || StrEqual(folderName, "..")) && fileType==FileType_Directory) {
        S_Demo_Match matchDemo;
        matchDemo.id = g_Demo_Matches.Length;
        strcopy(matchDemo.name, sizeof(matchDemo.name), folderName);
        char roundsFolderListPath[PLATFORM_MAX_PATH];
        Format(roundsFolderListPath, sizeof(roundsFolderListPath), "%s/%s", g_Demo_Matches_File, folderName);
        if (!DirExists(roundsFolderListPath)) {
          continue;
        }
        matchDemo.roundIds = new ArrayList();
        DirectoryListing roundsFolderList = OpenDirectory(roundsFolderListPath);
        char roundName[16];
        while (roundsFolderList.GetNext(roundName, sizeof(roundName), fileType)) {
          int roundNum = StringToInt(roundName);
          if (!(roundNum == 0 && !StrEqual(roundName, "0")) && fileType==FileType_Directory) {
            matchDemo.roundIds.Push(roundNum);
          }
        }
        SortADTArray(matchDemo.roundIds, Sort_Ascending, Sort_Integer);
        g_Demo_Matches.PushArray(matchDemo, sizeof(matchDemo));
        demo_folder_count++;
      }
    }
    return true;
  }

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
    g_Demo_UpdatedKv = true;
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
      g_Demo_UpdatedKv = true;
      g_DemosKv.DeleteThis();
      g_DemosKv.Rewind();
    }
    MaybeWriteNewDemoData();
  }

  public void DeleteDemoRole(const char[] demoId, const char[] roleId) {
    if (g_DemosKv.JumpToKey(demoId)) {
      if (g_DemosKv.JumpToKey(roleId)) {
        g_Demo_UpdatedKv = true;
        g_DemosKv.DeleteThis();
        g_DemosKv.Rewind();
      }
    }
    MaybeWriteNewDemoData();
  }

  public void MaybeWriteNewDemoData() {
    if (g_Demo_UpdatedKv) {
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
      g_Demo_UpdatedKv = false;
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
    g_Demo_UpdatedKv = true;
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
              S_Demo_NadeData demoNadeData;
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
    g_Demo_UpdatedKv = true;
    if (g_DemosKv.JumpToKey(demoId, true)) {
      if (g_DemosKv.JumpToKey(roleId, true)) {
        if (g_DemosKv.JumpToKey("nades", true)) {
          for (int i = 0; i < g_DemoNadeData[client].Length; i++) {
            char nadeIdStr[OPTION_ID_LENGTH];
            IntToString(i, nadeIdStr, sizeof(nadeIdStr));
            if (g_DemosKv.JumpToKey(nadeIdStr, true)){
              S_Demo_NadeData demoNadeData;
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
    return client > 0 && g_Is_DemoBot[client] && IsClientInGame(client) && IsFakeClient(client);
  }

  public bool IsDemoMatchBot(int client) {
    return client > 0 && g_Is_Demo_Match_Bot[client] && IsClientInGame(client) && IsFakeClient(client);
  }

  public Action Timer_KickBot(Handle timer, int client) {
    int playerSpec = g_Nade_ClientSpecBot[client];
    if (IsValidClient(playerSpec)) {
      ChangeClientTeam(playerSpec, g_Nade_LastSpecPlayerTeam[playerSpec]);
      TeleportEntity(playerSpec, g_Demo_LastSpecPos[playerSpec], g_Demo_LastSpecAng[playerSpec], ZERO_VECTOR);
    }
    if (IsValidClient(client)) {
      ServerCommand("bot_kick \"%s\"", g_Bots_OriginalName[client]);
    }
    return Plugin_Stop;
  }

/*******************************************************************/
