/* SingleDemoEditorMenu
*/
stock void GiveReplayEditorMenu(int client, int pos = 0) {
  if (StrEqual(g_ReplayId[client], "")) {
    IntToString(GetNextReplayId(), g_ReplayId[client], REPLAY_NAME_LENGTH);
    SetReplayName(g_ReplayId[client], DEFAULT_REPLAY_NAME);
  }

  // Reset role specific data.
  g_CurrentEditingRole[client] = -1;

  Menu menu = new Menu(ReplayMenuHandler);
  char replayName[REPLAY_NAME_LENGTH];
  GetReplayName(g_ReplayId[client], replayName, REPLAY_NAME_LENGTH);
  bool frozen = IsReplayFrozen(g_ReplayId[client]);
  menu.SetTitle("Editor de Repeticiones: %s (id %s)", replayName, g_ReplayId[client]);

  /* Page 1 */
  for (int i = 0; i < MAX_REPLAY_CLIENTS; i++) {
    bool recordedLastRole = true;
    if (i > 0) {
      recordedLastRole = HasRoleRecorded(g_ReplayId[client], i - 1);
    }
    int style = EnabledIf(recordedLastRole);
    if (HasRoleRecorded(g_ReplayId[client], i)) {
      char roleName[REPLAY_NAME_LENGTH];
      if (GetRoleName(g_ReplayId[client], i, roleName, sizeof(roleName))) {
        AddMenuIntStyle(menu, i, style, "Cambiar rol %s de jugador %d", roleName, i + 1);
      } else {
        AddMenuIntStyle(menu, i, style, "Cambiar rol de jugador %d", i + 1);
      }
    } else {
      AddMenuIntStyle(menu, i, style, "Añadir rol de jugador %d", i + 1);
    }
  }

  menu.AddItem("replay", "Reproducir Repetición");

  /* Page 2 */
  menu.AddItem("recordall", "Graba los roles de todos los jugadores a la vez");
  menu.AddItem("stop", "Para la repetición actual");
  menu.AddItem("name", "Nombra esta repetición");
  menu.AddItem("copy", "Copia esta repetición a otra nueva");
  if (!frozen)
    menu.AddItem("freeze", "Congelar data de roles (evita ediciones accidentales)");
  else
    menu.AddItem("unfreeze", "Descongelar data de roles para edición");
  menu.AddItem("delete", "Elimina completamente esta repetición");

  char display[128];
  Format(display, sizeof(display), "Muestra temporizador de la ronda: %s",
         g_ReplayPlayRoundTimer[client] ? "si" : "no");
  menu.AddItem("round_timer", display);

  //menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public int ReplayMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    ServerCommand("sm_botmimic_snapshotinterval 64");

    if (StrEqual(buffer, "replay")) {
      bool already_playing = false;
      for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && BotMimic_IsPlayerMimicing(i)) {
          already_playing = true;
          break;
        }
      }
      if (already_playing) {
        PM_Message(client, "Espera que termine la repetición actual primero.");
      } else {
        char replayName[REPLAY_NAME_LENGTH];
        GetReplayName(g_ReplayId[client], replayName, sizeof(replayName));
        PM_MessageToAll("Reproduciendo repetición: %s", replayName);
        RunReplay(g_ReplayId[client]);
      }

      GiveReplayEditorMenu(client, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "stop")) {
      CancelAllReplays();
      if (BotMimic_IsPlayerRecording(client)) {
        BotMimic_StopRecording(client, false /* save */);
        PM_Message(client, "Grabación cancelada.");
      }
      GiveReplayEditorMenu(client, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "delete")) {
      char replayName[REPLAY_NAME_LENGTH];
      GetReplayName(g_ReplayId[client], replayName, REPLAY_NAME_LENGTH);
      GiveReplayDeleteConfirmationMenu(client);

    } else if (StrEqual(buffer, "round_timer")) {
      g_ReplayPlayRoundTimer[client] = !g_ReplayPlayRoundTimer[client];
      GiveReplayEditorMenu(client, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "copy")) {
      char replayName[REPLAY_NAME_LENGTH];
      GetReplayName(g_ReplayId[client], replayName, REPLAY_NAME_LENGTH);
      PM_Message(client, "Copiando repetición: %s", replayName);

      char oldReplayId[REPLAY_ID_LENGTH];
      strcopy(oldReplayId, sizeof(oldReplayId), g_ReplayId[client]);
      IntToString(GetNextReplayId(), g_ReplayId[client], REPLAY_NAME_LENGTH);
      CopyReplay(oldReplayId, g_ReplayId[client]);

      char newName[REPLAY_NAME_LENGTH];
      Format(newName, sizeof(newName), "Copia de %s", replayName);
      SetReplayName(g_ReplayId[client], newName);

      GiveReplayEditorMenu(client, GetMenuSelectionPosition());

    } else if (StrContains(buffer, "name") == 0) {
      PM_Message(client, "Usa .namereplay <nombre> para nombrar esta repetición.");
      GiveReplayEditorMenu(client, GetMenuSelectionPosition());
    
    } else if (StrContains(buffer, "freeze") == 0) {
      PM_Message(client, "Repetición congelada. Botones de edición de roles seran desactivados hasta que la repetición se descongele.");
      SetReplayFrozen(g_ReplayId[client], true);
      GiveReplayEditorMenu(client, GetMenuSelectionPosition());
    } else if (StrContains(buffer, "unfreeze") == 0) {
      PM_Message(client, "Repeticion Descongelada.");
      SetReplayFrozen(g_ReplayId[client], false);
      // Going back to the same page in the replay menu makes sense for menu consistency,
      // but if a user pressed this they probably want to do some edits, so there's a case
      // to be made for not using GetMenuSelectionPosition here. Let's favor consistency in 
      // the menu behavior for a simpler user experience.
      GiveReplayEditorMenu(client, GetMenuSelectionPosition());
    } else if (StrEqual(buffer, "recordall")) {
      int count = 0;
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && !BotMimic_IsPlayerRecording(i)) {
          count++;
        }
      }
      if (count == 0) {
        PM_Message(client, "No puedes grabar una repetición completa sin jugadores en CT/T.");
        return 0;
      }
      if (count > MAX_REPLAY_CLIENTS) {
        PM_Message(
            client,
            "No puedes grabar una repeticióno con %d jugadores. Solo %d son soportados. Los otros jugadores deberán ser movidos a espectador.",
            count, MAX_REPLAY_CLIENTS);
        return 0;
      }

      if (BotMimic_IsPlayerRecording(client)) {
        PM_Message(client, "Termina tu grabación actual primero.");
        GiveReplayEditorMenu(client, GetMenuSelectionPosition());
        return 0;
      }

      if (IsReplayPlaying()) {
        PM_Message(client, "Termina tu repetición actual primero.");
        GiveReplayEditorMenu(client, GetMenuSelectionPosition());
        return 0;
      }

      int role = 0;
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && !BotMimic_IsPlayerRecording(i) && GetClientTeam(i)) {
          g_CurrentEditingRole[i] = role;
          g_ReplayId[i] = g_ReplayId[client];
          StartReplayRecording(i, role, false);
          role++;
        }
      }
      g_RecordingFullReplay = true;
      g_RecordingFullReplayClient = client;
      PM_MessageToAll("Grabando repetición de jugador-%d.", count);
      PM_MessageToAll(
          "La grabación terminara cuando cualquier jugador use la tecla (F).");

    } else {
      // Handling for recording players [0, 4]
      for (int i = 0; i < MAX_REPLAY_CLIENTS; i++) {
        char idxString[16];
        IntToString(i, idxString, sizeof(idxString));
        if (StrEqual(buffer, idxString)) {
          GiveReplayRoleMenu(client, i);
          break;
        }
      }
    }

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveMainReplaysMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

void FinishRecording(int client, bool printOnFail) {
  if (g_RecordingFullReplay) {
    for (int i = 0; i <= MaxClients; i++) {
      if (IsPlayer(i) && BotMimic_IsPlayerRecording(i)) {
        BotMimic_StopRecording(i, true /* save */);
      }
    }

  } else {
    if (BotMimic_IsPlayerRecording(client)) {
      BotMimic_StopRecording(client, true /* save */);
    } else if (printOnFail) {
      PM_Message(client, "No estas grabando una repetición ahora mismo.");
    }
  }
}

public Action Command_FinishRecording(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  FinishRecording(client, true);
  return Plugin_Handled;
}

public Action Command_Cancel(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int numReplaying = 0;
  for (int i = 0; i < MAX_REPLAY_CLIENTS; i++) {
    int bot = g_ReplayBotClients[i];
    if (IsValidClient(bot) && BotMimic_IsPlayerMimicing(bot)) {
      numReplaying++;
    }
  }

  if (g_RecordingFullReplay) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) && BotMimic_IsPlayerRecording(i)) {
        BotMimic_StopRecording(client, false /* save */);
      }
    }

  } else if (BotMimic_IsPlayerRecording(client)) {
    BotMimic_StopRecording(client, false /* save */);

  } else if (numReplaying > 0) {
    CancelAllReplays();
    PM_MessageToAll("Cancelled all replays.");
  }

  return Plugin_Handled;
}

/*SingleDemoRoleMenu 
*/
stock void GiveReplayRoleMenu(int client, int role, int pos = 0) {
  Menu menu = new Menu(ReplayRoleMenuHandler);
  g_CurrentEditingRole[client] = role;

  char replayName[REPLAY_NAME_LENGTH];
  GetReplayName(g_ReplayId[client], replayName, sizeof(replayName));

  char roleName[REPLAY_NAME_LENGTH];
  GetRoleName(g_ReplayId[client], role, roleName, sizeof(roleName));

  if (StrEqual(roleName, "")) {
    menu.SetTitle("%s: role %d", replayName, role + 1, roleName);
  } else {
    menu.SetTitle("%s: role %d (%s)", replayName, role + 1, roleName);
  }

  menu.ExitButton = true;
  menu.ExitBackButton = true;

  bool recorded = HasRoleRecorded(g_ReplayId[client], role);
  bool frozen = IsReplayFrozen(g_ReplayId[client]);
  if (recorded) {
    menu.AddItem("record", "Grabar Rol otra vez", EnabledIf(!frozen));
  } else {
    menu.AddItem("record", "Grabar Rol", EnabledIf(!frozen));
  }

  menu.AddItem("spawn", "Ir a la posición inicial", EnabledIf(recorded));
  menu.AddItem("nades", "Ver alineamientos de granadas", EnabledIf(recorded));
  menu.AddItem("play", "Ejecuta esta repetición", EnabledIf(recorded));
  menu.AddItem("name", "Nombra este Rol", EnabledIf(recorded && !frozen));
  menu.AddItem("delete", "Elimina esta repetición", EnabledIf(recorded && !frozen));
  menu.DisplayAt(client, MENU_TIME_FOREVER, pos);
}

/*SingleDemoRoleMenuHandler
*/
public int ReplayRoleMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    int role = g_CurrentEditingRole[client];
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "record")) {
      if (BotMimic_IsPlayerRecording(client)) {
        PM_Message(client, "Termina tu grabación actual primero!");
        GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());
        return 0;
      }
      if (IsReplayPlaying()) {
        PM_Message(client, "Termina tu repetición actual primero!");
        GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());
        return 0;
      }
      StartReplayRecording(client, role);
      RunReplay(g_ReplayId[client], role);

    } else if (StrEqual(buffer, "spawn")) {
      GotoReplayStart(client, g_ReplayId[client], role);
      GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "play")) {
      if (IsReplayPlaying()) {
        PM_Message(client, "Termina tu Repetición actual primero!");
        GiveMainReplaysMenu(client);
        return 0;
      }

      int bot = g_ReplayBotClients[role];
      if (IsValidClient(bot) && HasRoleRecorded(g_ReplayId[client], role)) {
        ReplayRole(g_ReplayId[client], bot, role);
      }
      GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "name")) {
      PM_Message(client, "Usa .namerole <nombre> para nombrar este Rol.");
      GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());

    } else if (StrEqual(buffer, "nades")) {
      if (g_NadeReplayData[client].Length == 0) {
        PM_Message(client, "Este Rol no tiene granadas guardadas en el.");
        GiveReplayRoleMenu(client, role, GetMenuSelectionPosition());
      } else {
        GiveReplayRoleNadesMenu(client);
      }

    } else if (StrEqual(buffer, "delete")) {
      DeleteReplayRole(g_ReplayId[client], role);
      PM_Message(client, "Rol %d eliminado.", role + 1);
      GiveReplayEditorMenu(client);
    }

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveReplayEditorMenu(client);

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}
/*DemoRoleNadesMenu
 */
stock void GiveReplayRoleNadesMenu(int client, int pos = 0) {
  Menu menu = new Menu(ReplayRoleNadesMenuHandler);
  menu.SetTitle("Granadas de Rol %d", g_CurrentEditingRole[client] + 1);
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  GetRoleNades(g_ReplayId[client], g_CurrentEditingRole[client], client);
  for (int i = 0; i < g_NadeReplayData[client].Length; i++) {
    GrenadeType type;
    float delay;
    float personOrigin[3];
    float personAngles[3];
    float grenadeOrigin[3];
    float grenadeVelocity[3];
    GetReplayNade(client, i, type, delay, personOrigin, personAngles, grenadeOrigin,
                  grenadeVelocity);

    char displayString[128];
    GrenadeTypeString(type, displayString, sizeof(displayString));
    AddMenuInt(menu, i, displayString);
  }

  menu.DisplayAt(client, MENU_TIME_FOREVER, pos);
}

public int ReplayRoleNadesMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    int nadeIndex = GetMenuInt(menu, param2);

    GrenadeType type;
    float delay;
    float personOrigin[3];
    float personAngles[3];
    float grenadeOrigin[3];
    float grenadeVelocity[3];
    GetReplayNade(client, nadeIndex, type, delay, personOrigin, personAngles, grenadeOrigin,
                  grenadeVelocity);

    TeleportEntity(client, personOrigin, personAngles, NULL_VECTOR);

    if (type != GrenadeType_None) {
      char weaponName[64];
      GetGrenadeWeapon(type, weaponName, sizeof(weaponName));
      FakeClientCommand(client, "use %s", weaponName);
      GiveReplayRoleNadesMenu(client, GetMenuSelectionPosition());
    }

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    int client = param1;
    GiveReplayRoleMenu(client, g_CurrentEditingRole[client]);

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

public void GiveReplayDeleteConfirmationMenu(int client) {
  char replayName[REPLAY_NAME_LENGTH];
  GetReplayName(g_ReplayId[client], replayName, sizeof(replayName));

  Menu menu = new Menu(ReplayDeletionMenuHandler);
  menu.SetTitle("Confirma la eliminación de repetición: %s", replayName);
  menu.ExitButton = false;
  menu.ExitBackButton = false;
  menu.Pagination = MENU_NO_PAGINATION;

  // Add rows of padding to move selection out of "danger zone"
  for (int i = 0; i < 7; i++) {
    menu.AddItem("", "", ITEMDRAW_NOTEXT);
  }

  // Add actual choices
  menu.AddItem("no", "No, cancelar");
  menu.AddItem("yes", "Si, eliminar");
  menu.Display(client, MENU_TIME_FOREVER);
}

public int ReplayDeletionMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "yes")) {
      char replayName[REPLAY_NAME_LENGTH];
      GetReplayName(g_ReplayId[client], replayName, sizeof(replayName));
      DeleteReplay(g_ReplayId[client]);
      PM_MessageToAll("Repetición %s eliminada.", replayName);
      GiveMainReplaysMenu(client);
    } else {
      GiveReplayEditorMenu(client);
    }

  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

/*StartDemoRecording
 */
stock void StartReplayRecording(int client, int role, bool printCommands = true) {
  if (role < 0 || role >= MAX_REPLAY_CLIENTS) {
    return;
  }

  g_NadeReplayData[client].Clear();
  g_CurrentEditingRole[client] = role;
  g_CurrentRecordingStartTime[client] = GetGameTime();

  char recordName[128];
  Format(recordName, sizeof(recordName), "Rol de jugador %d", role + 1);
  char roleString[32];
  Format(roleString, sizeof(roleString), "role%d", role);
  BotMimic_StartRecording(client, recordName, "practicemode", roleString);

  if (g_ReplayPlayRoundTimer[client]) {
    // Effectively a .countdown command, but already started (g_RunningLiveTimeCommand=true).
    float timer_duration = float(GetRoundTimeSeconds());
    g_RunningTimeCommand[client] = true;
    g_RunningLiveTimeCommand[client] = true;
    g_TimerType[client] = TimerType_Countdown_Movement;
    g_TimerDuration[client] = timer_duration;
    StartClientTimer(client);
  }

  if (printCommands) {
    PM_Message(client, "Grabación de jugador rol %d empezada.", role + 1);
    PM_Message(client, "Usa .finish o activa noclip para dejar de grabar.");
  }
}

public Action BotMimic_OnStopRecording(int client, char[] name, char[] category, char[] subdir,
                                char[] path, bool& save) {
  if (g_ReplayPlayRoundTimer[client]) {
    StopClientTimer(client);
  }

  if (g_CurrentEditingRole[client] >= 0) {
    if (!save) {
      // We only handle the not-saving case here because BotMimic_OnRecordSaved below
      // is handling the saving case.
      PM_Message(client, "Grabacion de jugador rol %d cancelada.", g_CurrentEditingRole[client] + 1);
      GiveReplayMenuInContext(client);
    }
    return Plugin_Continue;
  }

  return Plugin_Continue;
}

// public void BotMimic_OnRecordSaved(int client, char[] name, char[] category, char[] subdir, char[] file) {
//   if (g_InBotReplayMode) {
//     if (g_CurrentEditingRole[client] >= 0) {
//       SetRoleFile(g_ReplayId[client], g_CurrentEditingRole[client], file);
//       SetRoleNades(g_ReplayId[client], g_CurrentEditingRole[client], client);
//       SetRoleTeam(g_ReplayId[client], g_CurrentEditingRole[client], GetClientTeam(client));

//       if (!g_RecordingFullReplay) {
//         PM_Message(client, "Terminó la grabación de jugador rol %d", g_CurrentEditingRole[client] + 1);
//         GiveReplayMenuInContext(client);
//       } else {
//         if (g_RecordingFullReplayClient == client) {
//           g_CurrentEditingRole[client] = -1;
//           PM_MessageToAll("Terminó la grabación completa de esta repetición.");
//           RequestFrame(ResetFullReplayRecording, GetClientSerial(client));
//         }
//       }

//       MaybeWriteNewReplayData();
//     }
//     return;
//   }

//   PM_Message(client, "saved: current: %d, file %s", g_CurrentSavedGrenadeId[client], file);
//   SetClientGrenadeData(g_CurrentSavedGrenadeId[client], "record", file);
//   MaybeWriteNewGrenadeData();
// }
/* ResetFullDemoRecording
*/
public void ResetFullReplayRecording(int serial) {
  g_RecordingFullReplay = false;
  g_RecordingFullReplayClient = -1;
  int client = GetClientFromSerial(serial);
  if (IsPlayer(client)) {
    GiveReplayMenuInContext(client);
  }
}
