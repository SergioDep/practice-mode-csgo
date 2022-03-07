public Action Command_SaveNade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  char name[GRENADE_NAME_LENGTH];
  GetCmdArgString(name, sizeof(name));
  TrimString(name);
  
  SaveClientNade(client, name);
  return Plugin_Handled;
}

public Action Command_ImportNade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  char code[GRENADE_CODE_LENGTH];
  GetCmdArgString(code, sizeof(code));
  TrimString(code);
  int nadeId = FindGrenadeWithCode(code);
  if (nadeId > -1 && g_CSUtilsLoaded) {
    char nadeIdStr[GRENADE_ID_LENGTH];
    IntToString(nadeId, nadeIdStr, sizeof(nadeIdStr));
    if (CopyGrenade(client, nadeIdStr) > 0) {
      PM_Message(client, "{ORANGE}Granada {ORANGE}guardada.");
      OnGrenadeKvMutate();
    }
  }
  return Plugin_Handled;
}

stock int FindGrenadeWithCode(const char[] code) {
  char auth[AUTH_LENGTH];
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    do {
      g_GrenadeLocationsKv.GetSectionName(auth, AUTH_LENGTH);
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          char currentCode[GRENADE_CODE_LENGTH];
          g_GrenadeLocationsKv.GetString("code", currentCode, sizeof(currentCode));
          if (StrEqual(currentCode, code)) {
            char currentId[GRENADE_ID_LENGTH];
            g_GrenadeLocationsKv.GetSectionName(currentId, sizeof(currentId));
            g_GrenadeLocationsKv.Rewind();
            return StringToInt(currentId);
          }
        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }

    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
  }
  return -1;
}

public Action Command_CopyPlayerLastGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  
  GiveCopyPlayerNadeMenu(client);

  return Plugin_Handled;
}

public Action GiveCopyPlayerNadeMenu(int client) {
    char iStr[16], name[MAX_NAME_LENGTH];
    Menu menu = new Menu(CopyPlayerMenuHandler);
    menu.SetTitle("Copiar la ultima granda de: ");
    for(int i = 1; i <= MaxClients; i++) {
      if(IsPlayer(i)) {
             GetClientName(i, name, sizeof(name));
             IntToString(i, iStr, sizeof(iStr));
             menu.AddItem(iStr, name);
      }
    }
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int CopyPlayerMenuHandler(Menu menu, MenuAction action, int client, int param2) {
    if (action == MenuAction_Select) {
      char buffer[OPTION_NAME_LENGTH];
      menu.GetItem(param2, buffer, sizeof(buffer));
      int CopyClient = StringToInt(buffer);
      int index = g_GrenadeHistoryPositions[CopyClient].Length - 1;
      if (index >= 0) {
        float origin[3];
        float angles[3];
        float velocity[3];
        g_GrenadeHistoryPositions[CopyClient].GetArray(index, origin, sizeof(origin));
        g_GrenadeHistoryAngles[CopyClient].GetArray(index, angles, sizeof(angles));
        TeleportEntity(client, origin, angles, velocity);
        SetEntityMoveType(client, MOVETYPE_WALK);
        PM_Message(client, "Ultima granada de %N copiada.", CopyClient);
      }
    } else if (action == MenuAction_End) {
      delete menu;
    }
    return 0;
}

public Action Command_LastGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int index = g_GrenadeHistoryPositions[client].Length - 1;
  if (index >= 0) {
    TeleportToGrenadeHistoryPosition(client, index);
  }

  return Plugin_Handled;
}

public Action Command_FixGrenades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  CorrectGrenadeIds();
  g_UpdatedGrenadeKv = true;
  ReplyToCommand(client, "Data de granadas arreglada.");
  return Plugin_Handled;
}

public Action Command_FixGrenadeDetonations(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  CorrectGrenadeDetonations(client);
  g_UpdatedGrenadeKv = true;
  ReplyToCommand(client, "Tirando y grabando todas las detonaciones de granadas.");
  return Plugin_Handled;
}

public Action Command_GrenadeBack(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char argString[64];
  if (args >= 1 && GetCmdArg(1, argString, sizeof(argString))) {
    int index = StringToInt(argString) - 1;
    if (index >= 0 && index < g_GrenadeHistoryPositions[client].Length) {
      g_GrenadeHistoryIndex[client] = index;
      TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
    }
    return Plugin_Handled;
  }

  if (g_GrenadeHistoryPositions[client].Length > 0) {
    g_GrenadeHistoryIndex[client]--;
    if (g_GrenadeHistoryIndex[client] < 0)
      g_GrenadeHistoryIndex[client] = 0;

    TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
  }

  return Plugin_Handled;
}

public Action Command_GrenadeForward(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (g_GrenadeHistoryPositions[client].Length > 0) {
    int max = g_GrenadeHistoryPositions[client].Length;
    g_GrenadeHistoryIndex[client]++;
    if (g_GrenadeHistoryIndex[client] >= max)
      g_GrenadeHistoryIndex[client] = max - 1;
    TeleportToGrenadeHistoryPosition(client, g_GrenadeHistoryIndex[client]);
  }

  return Plugin_Handled;
}

static void ClientThrowGrenade(int client, const char[] id, float delay = 0.0) {
  if (!ThrowGrenade(client, id, delay)) {
    LogError("No parameters for grenade id: %s", id);
  }
}

public Action Command_Throw(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    LogError("%N failed .throw, g_CSUtilsLoaded = false", client);
    return Plugin_Handled;
  }

  char argString[256];
  GetCmdArgString(argString, sizeof(argString));
  if (args >= 1) {
    ArrayList ids = new ArrayList(GRENADE_NAME_LENGTH);
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
    FindMatchingGrenadesByName(argString, auth, ids);

    // Actually do the throwing.
    for (int i = 0; i < ids.Length; i++) {
      char id[GRENADE_ID_LENGTH];
      ids.GetString(i, id, sizeof(id));
      ClientThrowGrenade(client, id); // GetClientGrenadeFloat(StringToInt(id), "delay")
    }
    if (ids.Length == 0) {
      PM_Message(client, "{ORANGE}No se encontraron coincidencias para {PURPLE}%s", argString);
    }
    delete ids;

  } else {
    // No arg, throw last nade.
    if (IsGrenade(g_LastGrenadeType[client])) {
      //PM_Message(client, "Lanzando tu ultima granada.");
      CSU_ThrowGrenade(client, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
                       g_LastGrenadeVelocity[client]);
    }
  }

  return Plugin_Handled;
}

public Action Command_TestFlash(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  
  if (!g_TestingFlash[client]) {
    g_TestingFlash[client] = true;
    PM_Message(client, "Posición guardada.");
    PM_Message(client, "Usa {GREEN}.flash {NORMAL} de nuevo para terminar.");
    GetClientAbsOrigin(client, g_TestingFlashOrigins[client]);
    GetClientEyeAngles(client, g_TestingFlashAngles[client]);
  } else {
    g_TestingFlash[client] = false;
    PM_Message(client, "Prueba terminada.");
  }
  return Plugin_Handled;
}
