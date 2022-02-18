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

public Action Command_NextGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  int nextId = FindNextGrenadeId(client, nadeId);
  if (nextId != -1) {
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));

    char idBuffer[GRENADE_ID_LENGTH];
    IntToString(nextId, idBuffer, sizeof(idBuffer));
    TeleportToSavedGrenadePosition(client, idBuffer);
  }

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

public Action Command_SavePos(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  AddGrenadeToHistory(client);
  PM_Message(client, "Posición guardada. Usa .back para regresar.");
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

public Action Command_ClearNades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  ClearArray(g_GrenadeHistoryPositions[client]);
  ClearArray(g_GrenadeHistoryAngles[client]);
  PM_Message(client, "Historial de granadas eliminado.");

  return Plugin_Handled;
}

public Action Command_GotoNade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  char arg[GRENADE_ID_LENGTH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    char id[GRENADE_ID_LENGTH];
    if (!FindGrenade(arg, id) || !TeleportToSavedGrenadePosition(client, arg)) {
      PM_Message(client, "Id de granada %s no encontrado.", arg);
      return Plugin_Handled;
    }
  } else {
    PM_Message(client, "Uso: .goto <id de granada>");
  }

  return Plugin_Handled;
}

// public Action Command_Grenades(int client, int args) {
//   if (!g_InPracticeMode) {
//     return Plugin_Handled;
//   }

//   char arg[MAX_NAME_LENGTH];
//   if (args >= 1 && GetCmdArgString(arg, sizeof(arg))) {
//     ArrayList ids = new ArrayList(GRENADE_ID_LENGTH);
//     char data[256];
//     GrenadeMenuType type = FindGrenades(arg, ids, data, sizeof(data));
//     if (type != GrenadeMenuType_Invalid) {
//       GiveGrenadeMenu(client, type, 0, data, ids);
//     } else {
//       PM_Message(client, "No se encontraron coincidencias.");
//     }
//     delete ids;

//   } else {
//     bool categoriesOnly = (g_SharedAllNadesCvar.IntValue != 0);
//     if (categoriesOnly) {
//       GiveGrenadeMenu(client, GrenadeMenuType_Categories);
//     } else {
//       GiveGrenadeMenu(client, GrenadeMenuType_PlayersAndCategories);
//     }
//   }

//   return Plugin_Handled;
// }

// public Action Command_Find(int client, int args) {
//   if (!g_InPracticeMode) {
//     return Plugin_Handled;
//   }

//   char arg[MAX_NAME_LENGTH];
//   if (args >= 1 && GetCmdArgString(arg, sizeof(arg))) {
//     GiveGrenadeMenu(client, GrenadeMenuType_MatchingName, 0, arg, null,
//                     GrenadeMenuType_MatchingName);
//   } else {
//     PM_Message(client, "Uso: .find <cualquiera>");
//   }

//   return Plugin_Handled;
// }

// public Action Command_GrenadeDescription(int client, int args) {
//   if (!g_InPracticeMode) {
//     return Plugin_Handled;
//   }

//   int nadeId = g_CurrentSavedGrenadeId[client];
//   if (nadeId < 0) {
//     return Plugin_Handled;
//   }

//   if (!CanEditGrenade(client, nadeId)) {
//     PM_Message(client, "No eres el dueño de esta granada.");
//     return Plugin_Handled;
//   }

//   char description[GRENADE_DESCRIPTION_LENGTH];
//   GetCmdArgString(description, sizeof(description));

//   UpdateGrenadeDescription(nadeId, description);
//   PM_Message(client, "Descripción de granada agregada.");
//   return Plugin_Handled;
// }

public Action Command_RenameGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  char name[GRENADE_NAME_LENGTH];
  GetCmdArgString(name, sizeof(name));
  
  UpdateGrenadeName(nadeId, name);
  PM_Message(client, "Nombre de Granada Actualizado.");
  return Plugin_Handled;
}

public Action Command_DeleteGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  // get the grenade id first
  char grenadeIdStr[32];
  if (args < 1 || !GetCmdArg(1, grenadeIdStr, sizeof(grenadeIdStr))) {
    // if this fails, use the last grenade position
    IntToString(g_CurrentSavedGrenadeId[client], grenadeIdStr, sizeof(grenadeIdStr));
  }

  if (!CanEditGrenade(client, StringToInt(grenadeIdStr))) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  DeleteGrenadeFromKv(grenadeIdStr);
  PM_Message(client, "Id de granada %s eliminado.", grenadeIdStr);

  OnGrenadeKvMutate();
  return Plugin_Handled;
}

public Action Command_SaveGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }
  char name[GRENADE_NAME_LENGTH];
  GetCmdArgString(name, sizeof(name));
  TrimString(name);
  
  SaveClientGrenade(client, name);
  return Plugin_Handled;
}

public Action Command_MoveGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  if (GetEntityMoveType(client) == MOVETYPE_NOCLIP) {
    PM_Message(client, "No puedes mover granadas mientras usas noclip.");
    return Plugin_Handled;
  }

  float origin[3];
  float angles[3];
  GetClientAbsOrigin(client, origin);
  GetClientEyeAngles(client, angles);
  SetClientGrenadeVectors(nadeId, origin, angles);
  PM_Message(client, "Se actualizó la posición de esta granada.");
  OnGrenadeKvMutate();
  return Plugin_Handled;
}

public Action Command_SaveThrow(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PM_Message(client, "You need the csutils plugin installed to use that command.");
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  SetClientGrenadeParameters(
    nadeId, 
    g_LastGrenadeType[client], 
    g_LastGrenadeOrigin[client],
    g_LastGrenadeVelocity[client], 
    g_LastGrenadeEntity[client], 
    g_LastGrenadeDetonationOrigin[client]
  );
  PM_Message(client, "Parametros de tiro de esta granada actualizados.");
  g_LastGrenadeType[client] = GrenadeType_None;
  return Plugin_Handled;
}

public Action Command_UpdateGrenade(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  if (GetEntityMoveType(client) == MOVETYPE_NOCLIP) {
    PM_Message(client, "No puedes actualizar granadas mientras usas noclip.");
    return Plugin_Handled;
  }

  float origin[3];
  float angles[3];
  GetClientAbsOrigin(client, origin);
  GetClientEyeAngles(client, angles);
  SetClientGrenadeVectors(nadeId, origin, angles);
  bool updatedParameters = false;
  if (g_CSUtilsLoaded && IsGrenade(g_LastGrenadeType[client])) {
    updatedParameters = true;
    SetClientGrenadeParameters(
      nadeId, 
      g_LastGrenadeType[client], 
      g_LastGrenadeOrigin[client],
      g_LastGrenadeVelocity[client], 
      g_LastGrenadeEntity[client], 
      g_LastGrenadeDetonationOrigin[client]
    );
  }

  if (updatedParameters) {
    PM_Message(client, "Se actualizaron la posicion y parametros de tiro de esta granada.");
  } else {
    PM_Message(client, "Se actualizo la posicion de esta granada.");
  }

  OnGrenadeKvMutate();
  g_LastGrenadeType[client] = GrenadeType_None;
  return Plugin_Handled;
}

public Action Command_SetDelay(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PM_Message(client, "You need the csutils plugin installed to use that command.");
    return Plugin_Handled;
  }

  if (args < 1) {
    PM_Message(client, "Uso: .delay <duracion en segundos>");
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  char arg[64];
  GetCmdArgString(arg, sizeof(arg));
  float delay = StringToFloat(arg);
  SetClientGrenadeFloat(nadeId, "delay", delay);
  PM_Message(client, "Delay de %.1f segundos guardado para granada id: %d.", delay, nadeId);
  return Plugin_Handled;
}

public Action Command_ClearThrow(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!g_CSUtilsLoaded) {
    PM_Message(client, "You need the csutils plugin installed to use that command.");
    return Plugin_Handled;
  }

  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  SetClientGrenadeParameters(
    nadeId, 
    g_LastGrenadeType[client], 
    g_LastGrenadeOrigin[client],
    g_LastGrenadeVelocity[client], 
    g_LastGrenadeEntity[client], 
    g_LastGrenadeDetonationOrigin[client]
  );

  PM_Message(client, "Paramtros de tiro de esta granada eliminados.");
  return Plugin_Handled;
}

static void ClientThrowGrenade(int client, const char[] id, float delay = 0.0) {
  if (!ThrowGrenade(client, id, delay)) {
    PM_Message(
        client,
        "No se encontraron parametros para la granada id: %s. Prueba \".goto %s\", tira la granada, y \".update\" e intentalo nuevamente.",
        id, id);
  }
}

// public Action Command_Throw(int client, int args) {
//   if (!g_InPracticeMode) {
//     return Plugin_Handled;
//   }

//   if (!g_CSUtilsLoaded) {
//     PM_Message(client, "You need the csutils plugin installed to use that command.");
//     return Plugin_Handled;
//   }

//   char argString[256];
//   GetCmdArgString(argString, sizeof(argString));
//   if (args >= 1) {
//     char data[128];
//     ArrayList ids = new ArrayList(GRENADE_CATEGORY_LENGTH);

//     GrenadeMenuType filterType;
//     if (StrEqual(argString, "current", false)) {
//       filterType = FindGrenades(g_ClientLastMenuData[client], ids, data, sizeof(data));
//     } else {
//       filterType = FindGrenades(argString, ids, data, sizeof(data));
//     }

//     // Print what's about to be thrown.
//     if (filterType == GrenadeMenuType_OneCategory) {
//       PM_Message(client, "Lanzando granadas de categoria: %s", data);

//     } else {
//       char idString[256];
//       for (int i = 0; i < ids.Length; i++) {
//         char id[GRENADE_ID_LENGTH];
//         ids.GetString(i, id, sizeof(id));
//         StrCat(idString, sizeof(idString), id);
//         if (i + 1 != ids.Length) {
//           StrCat(idString, sizeof(idString), ", ");
//         }
//       }
//       if (ids.Length == 1) {
//         PM_Message(client, "Lanzando granada %s", idString);
//       } else if (ids.Length > 1) {
//         PM_Message(client, "Lanzando granada %s", idString);
//       }
//     }

//     // Actually do the throwing.
//     for (int i = 0; i < ids.Length; i++) {
//       char id[GRENADE_ID_LENGTH];
//       ids.GetString(i, id, sizeof(id));
//       float delay = 0.0;
//       // Only support delays when throwing a category.
//       // if (filterType == GrenadeMenuType_OneCategory) {
//       //   delay = GetClientGrenadeFloat(StringToInt(id), "delay");
//       // }
//       delay = GetClientGrenadeFloat(StringToInt(id), "delay");
//       ClientThrowGrenade(client, id, delay);
//     }
//     if (ids.Length == 0) {
//       PM_Message(client, "No se encontraron coincidencias para %s", argString);
//     }
//     delete ids;

//   } else {
//     // No arg, throw last nade.
//     if (IsGrenade(g_LastGrenadeType[client])) {
//       PM_Message(client, "Lanzando tu ultima granada.");
//       CSU_ThrowGrenade(client, g_LastGrenadeType[client], g_LastGrenadeOrigin[client],
//                        g_LastGrenadeVelocity[client]);
//     } else {
//       PM_Message(client, "No se pudo lanzar tu ultima granada, no tiraste ninguna!");
//     }
//   }

//   return Plugin_Handled;
// }

public Action Command_TestFlash(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  g_TestingFlash[client] = true;
  PM_Message(
      client,
      "Posición guardada.");
  PM_Message(client, "Usa {GREEN}.stop {NORMAL}cuando termines la prueba.");
  GetClientAbsOrigin(client, g_TestingFlashOrigins[client]);
  GetClientEyeAngles(client, g_TestingFlashAngles[client]);
  return Plugin_Handled;
}

public Action Command_StopFlash(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  g_TestingFlash[client] = false;
  PM_Message(client, "Prueba de flash finalizada.");
  return Plugin_Handled;
}

public Action Command_AddCategory(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || !g_InPracticeMode || args < 1) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  char category[GRENADE_CATEGORY_LENGTH];
  GetCmdArgString(category, sizeof(category));
  AddGrenadeCategory(nadeId, category);

  PM_Message(client, "Categoria de granada añadida.");
  return Plugin_Handled;
}

public Action Command_AddCategories(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || !g_InPracticeMode || args < 1) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  char category[GRENADE_CATEGORY_LENGTH];
  for (int i = 1; i <= args; i++) {
    GetCmdArg(i, category, sizeof(category));
    AddGrenadeCategory(nadeId, category);
  }

  PM_Message(client, "Categoria de granada añadida.");
  return Plugin_Handled;
}

public Action Command_RemoveCategory(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || !g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  char category[GRENADE_CATEGORY_LENGTH];
  GetCmdArgString(category, sizeof(category));

  if (StrEqual(category, "")) {
    PM_Message(client, "Necesitas brindar un nombre de categoria.");
    return Plugin_Handled;
  }

  if (RemoveGrenadeCategory(nadeId, category)) {
    PM_Message(client, "Categoria de granada quitada.");
  } else {
    PM_Message(client, "Categoria no encontrada.");
  }

  return Plugin_Handled;
}

public Action Command_DeleteCategory(int client, int args) {
  char category[GRENADE_CATEGORY_LENGTH];
  GetCmdArgString(category, sizeof(category));

  if (StrEqual(category, "")) {
    PM_Message(client, "Necesitas brindar un nombre de categoria.");
    return Plugin_Handled;
  }

  if (DeleteGrenadeCategory(client, category) > 0) {
    PM_Message(client, "Categoria de granada quitada.");
  } else {
    PM_Message(client, "Categoria no encontrada.");
  }
  return Plugin_Handled;
}

public Action Command_ClearGrenadeCategories(int client, int args) {
  int nadeId = g_CurrentSavedGrenadeId[client];
  if (nadeId < 0 || !g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (!CanEditGrenade(client, nadeId)) {
    PM_Message(client, "No eres el dueño de esta granada.");
    return Plugin_Handled;
  }

  SetClientGrenadeData(nadeId, "categories", "");
  PM_Message(client, "Categorias de granada %d eliminadas.", nadeId);

  return Plugin_Handled;
}

public Action Command_TranslateGrenades(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (args != 3) {
    ReplyToCommand(client, "Uso: sm_translategrenades <dx> <dy> <dz>");
    return Plugin_Handled;
  }

  char buffer[32];
  GetCmdArg(1, buffer, sizeof(buffer));
  float dx = StringToFloat(buffer);

  GetCmdArg(2, buffer, sizeof(buffer));
  float dy = StringToFloat(buffer);

  GetCmdArg(3, buffer, sizeof(buffer));
  float dz = StringToFloat(buffer);

  TranslateGrenades(dx, dy, dz);

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

public Action Command_HoloNadeToggle(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  if (g_HoloNadeClientAllowed[client]) {
    //TODO CACA ERROR FIX, hacer variable global
    g_HoloNadeClientEnabled[client] = !g_HoloNadeClientEnabled[client];
    if (g_HoloNadeClientEnabled[client]) {
      InitHoloNadeEntities();
    } else {
      RemoveHoloNadeEntities();
    }
  }

  return Plugin_Handled;
}