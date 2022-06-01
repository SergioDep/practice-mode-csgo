int g_CurrentNadeGroupControl[MAXPLAYERS + 1] = {-1, ...};
int g_CurrentNadeControl[MAXPLAYERS + 1] = {-1, ...};

enum GrenadeMenuType {
  GrenadeMenuType_NadeGroup = 0,
  GrenadeMenuType_TypeFilter = 1
};
GrenadeMenuType g_ClientLastMenuType[MAXPLAYERS + 1];
GrenadeType g_ClientLastMenuGrenadeTypeFilter[MAXPLAYERS + 1] = {GrenadeType_None, ...};

public void GiveNadeMenuInContext(int client) {
  if (g_ClientLastMenuType[client] == GrenadeMenuType_TypeFilter) {
    if (g_CurrentNadeControl[client] > -1) {
      GiveSingleNadeMenu(client, g_CurrentNadeControl[client]);
    } else {
      GiveNadeFilterMenu(client, g_ClientLastMenuGrenadeTypeFilter[client]);
    }
  } else if (g_ClientLastMenuType[client] == GrenadeMenuType_NadeGroup && g_CurrentNadeGroupControl[client] > -1) {
    if (g_CurrentNadeControl[client] > -1) {
      GiveSingleNadeMenu(client, g_CurrentNadeControl[client]);
    } else {
      GiveNadeGroupMenu(client, g_CurrentNadeGroupControl[client]);
    }
  } else {
    // All Nades Menu.
    GiveNadesMainMenu(client);
  }
}

stock void GiveNadesMainMenu(int client) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return;
  }
  g_ClientLastMenuType[client] = GrenadeMenuType_NadeGroup;
  g_CurrentNadeGroupControl[client] = -1;
  g_CurrentNadeControl[client] = -1;
  Menu menu = new Menu(NadesMainMenuHandler);
  menu.SetTitle("Menu de Granadas");
  menu.AddItem("savenade", "Guardar granada\n ");
  char auth[AUTH_LENGTH], buffer[128], grenadeString[32];

  GrenadeTypeString(g_ClientLastMenuGrenadeTypeFilter[client], grenadeString, sizeof(grenadeString));
  StrEqual(grenadeString, "")
  ? strcopy(grenadeString, sizeof(grenadeString), "todas")
  : 1;
  grenadeString[0] = CharToUpper(grenadeString[0]);
  Format(buffer, sizeof(buffer), "Filtro de Granadas: (%s)", grenadeString);
  menu.AddItem("filternades", buffer);
  
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  int filterNadesCount = CountGrenadesForPlayer(auth, g_ClientLastMenuGrenadeTypeFilter[client]);
  Format(buffer, sizeof(buffer), "Mis granadas(%s) [%i/%i]\n "
  , grenadeString , filterNadesCount
  , MAX_GRENADE_SAVES_PLAYER)
  menu.AddItem("mynades", buffer, filterNadesCount ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

  menu.AddItem("loadmynades", "Mostrar mis granadas");
  menu.AddItem("disablemynades", "Ocultar mis granadas");
  
  Format(buffer, sizeof(buffer), "Granadas por Defecto: %s"
  , g_HoloNadeLoadDefault ? "Activadas": "Desactivadas");
  menu.AddItem("defaultnades", buffer);

  menu.ExitBackButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
}

public int NadesMainMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    
    if (StrEqual(buffer, "savenade")) {
      g_WaitForSaveNade[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre de la granada a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
    } else if (StrEqual(buffer, "filternades")) {
      g_ClientLastMenuGrenadeTypeFilter[client] += GrenadeType_Smoke;
      if (g_ClientLastMenuGrenadeTypeFilter[client] == GrenadeType_Decoy)
        g_ClientLastMenuGrenadeTypeFilter[client] = GrenadeType_Incendiary;
      else if (g_ClientLastMenuGrenadeTypeFilter[client] > GrenadeType_Incendiary)
        g_ClientLastMenuGrenadeTypeFilter[client] = GrenadeType_None;
    } else if (StrEqual(buffer, "mynades")) {
      g_ClientLastMenuType[client] = GrenadeMenuType_TypeFilter;
    } else if (StrEqual(buffer, "defaultnades")) {
      g_HoloNadeLoadDefault = !g_HoloNadeLoadDefault;
      if (g_HoloNadeLoadDefault) {
        int index = g_EnabledHoloNadeAuth.FindString("default");
        if(index == -1) {
          g_EnabledHoloNadeAuth.PushString("default");
          UpdateHoloNadeEntities();
        }
      } else {
        int index = g_EnabledHoloNadeAuth.FindString("default");
        if(index > -1) {
          g_EnabledHoloNadeAuth.Erase(index);
          UpdateHoloNadeEntities();
        }
      }
    } else {
      char auth[AUTH_LENGTH];
      if (StrEqual(buffer, "loadmynades")) {
        GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
        int index = g_EnabledHoloNadeAuth.FindString(auth);
        if(index == -1) {
          g_EnabledHoloNadeAuth.PushString(auth);
          UpdateHoloNadeEntities();
        }
        PM_MessageToAll("{ORANGE} Granadas Actualizadas para {NORMAL}%N.", client);
      } else if (StrEqual(buffer, "disablemynades")) {
        GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
        int index = g_EnabledHoloNadeAuth.FindString(auth);
        if(index > -1) {
          g_EnabledHoloNadeAuth.Erase(index);
          UpdateHoloNadeEntities();
        }
        PM_Message(client, "{ORANGE} Granadas Ocultadas.");
      }
    }
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GivePracticeMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void GiveNadeFilterMenu(int client, GrenadeType grenadeType = GrenadeType_None) {
  g_CurrentNadeControl[client] = -1;
  g_ClientLastMenuType[client] = GrenadeMenuType_TypeFilter;
  int nadesCount = 0;
  Menu menu = new Menu(NadeFilterMenuHandler);
  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    char userName[MAX_NAME_LENGTH];
    g_GrenadeLocationsKv.GetString("name", userName, sizeof(userName));
    menu.SetTitle("Lista de Granadas de %s", userName);
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
      do {
        char id[GRENADE_ID_LENGTH], name[GRENADE_NAME_LENGTH];
        g_GrenadeLocationsKv.GetSectionName(id, sizeof(id));
        g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
        char type[32]
        g_GrenadeLocationsKv.GetString("grenadeType", type, sizeof(type));
        if (grenadeType == GrenadeTypeFromString(type) || grenadeType == GrenadeType_None) {
          UpperString(type);
          Format(name, sizeof(name), "%s [%s]", name, type);
          menu.AddItem(id, name);
          nadesCount++;
        }
      } while (g_GrenadeLocationsKv.GotoNextKey());

      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }

  if (nadesCount == 0) {
    g_ClientLastMenuType[client] = GrenadeMenuType_NadeGroup;
    delete menu;
    GiveNadeMenuInContext(client);
    return;
  }
  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int NadeFilterMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char nadeIdStr[OPTION_NAME_LENGTH];
    menu.GetItem(param2, nadeIdStr, sizeof(nadeIdStr));
    g_CurrentNadeControl[client] = StringToInt(nadeIdStr);
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GiveNadesMainMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public Action GiveSingleNadeMenu(int client, int NadeId) {
    g_CurrentNadeControl[client] = NadeId;
    char name[64];
    GetClientGrenadeData(NadeId, "name", name, sizeof(name));
    Menu menu = new Menu(SingleNadeMenuHandler);
    Format(name, sizeof(name), "Granada: %s", name);
    menu.SetTitle(name);

    menu.AddItem("goto", "Ir a Lineup");
    menu.AddItem("preview", "Ver Demo de Esta granada(con bot)");
    menu.AddItem("throw", "Lanzar esta granada");
    menu.AddItem("exportcode", "Compartir el Codigo de esta Granada\n ");

    char display[64];
    GetClientGrenadeData(NadeId, "grenadeType", display, sizeof(display));
    display[0] &= ~(1<<5);
    char executionType[64];
    GetClientGrenadeData(NadeId, "execution", executionType, sizeof(executionType));
    executionType[0] &= ~(1<<5);
    Format(display, sizeof(display), "Eliminar\n \nTipo: %s\nEjecución: %s", display, executionType);

    menu.AddItem("delete", display,
    (CanEditGrenade(client, NadeId))
    ? ITEMDRAW_DEFAULT
    : ITEMDRAW_DISABLED);

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int SingleNadeMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    char NadeIdStr[64];
    menu.GetItem(param2, buffer, sizeof(buffer));
    int NadeId = g_CurrentNadeControl[client];
    IntToString(NadeId, NadeIdStr, sizeof(NadeIdStr));
    if (StrEqual(buffer, "goto")) {
      TeleportToSavedGrenadePosition(client, NadeIdStr);
    } else if (StrEqual(buffer, "delete")) {
      GiveNadeDeleteConfirmationMenu(client);
      return 0;
    } else if (StrEqual(buffer, "exportcode")) {
      ExportClientNade(client, NadeIdStr);
    } else if (StrEqual(buffer, "preview")) {
      InitHoloNadeDemo(client, NadeId);
    } else if (StrEqual(buffer, "throw")) {
      ThrowGrenade(client, NadeIdStr);
    }
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    g_CurrentNadeControl[client] = -1;
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public int NadeGroupMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    g_CurrentNadeControl[client] = StringToInt(buffer);
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GiveNadesMainMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public Action GiveNadeDeleteConfirmationMenu(int client) {
  Menu menu = new Menu(NadeDeletionMenuHandler);
  char name[64];
  GetClientGrenadeData(g_CurrentNadeControl[client], "name", name, sizeof(name));
  menu.SetTitle("Confirmar la eliminación de la granada: %s", name);
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

  return Plugin_Handled;
}

public int NadeDeletionMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    if (StrEqual(buffer, "yes")) {
      char NadeIdStr[64];
      IntToString(g_CurrentNadeControl[client], NadeIdStr, sizeof(NadeIdStr));
      g_CurrentNadeControl[client] = -1;
      DeleteGrenadeFromKv(NadeIdStr);
      OnGrenadeKvMutate();
    }
    GiveNadeMenuInContext(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}
