stock void GiveNadesMenu(int client) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return;
  }
  Menu menu = new Menu(NadesMenuHandler);
  menu.SetTitle("Menu de Granadas");
  menu.AddItem("savenade", "Guardar granada\n ");
  char auth[AUTH_LENGTH], buffer[128], grenadeString[32];

  GrenadeTypeString(g_ClientLastMenuGrenadeTypeFilter[client], grenadeString, sizeof(grenadeString));
  StrEqual(grenadeString, "")
  ? strcopy(grenadeString, sizeof(grenadeString), "todas")
  : 1;
  grenadeString[0] = CharToUpper(grenadeString[0]);
  Format(buffer, sizeof(buffer), "Filtro de Granadas: (%s)", grenadeString);
  menu.AddItem("filternades", buffer); //flashes humos molos?
  
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  Format(buffer, sizeof(buffer), "Mis granadas(%s) [%i/%i]\n "
  , grenadeString , CountGrenadesForPlayer(auth, g_ClientLastMenuGrenadeTypeFilter[client])
  , MAX_GRENADE_SAVES_PLAYER)
  menu.AddItem("mynades", buffer);

  menu.AddItem("loadmynades", "Mostrar mis granadas");
  menu.AddItem("disablemynades", "Ocultar mis granadas");
  
  Format(buffer, sizeof(buffer), "Granadas por Defecto: %s"
  , g_HoloNadeLoadDefault ? "Activadas": "Desactivadas");
  menu.AddItem("defaultnades", buffer);

  menu.ExitBackButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
}

public int NadesMenuHandler(Menu menu, MenuAction action, int client, int param2) {
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
      GiveNadeFilterMenu(client, g_ClientLastMenuGrenadeTypeFilter[client]);
      return 0;
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
    GiveNadesMenu(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GivePracticeMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void GiveNadeFilterMenu(int client, GrenadeType grenadeType = GrenadeType_None) {
  Menu menu = new Menu(NadeFilterMenuHandler);
  char auth[AUTH_LENGTH];
  GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    char userName[MAX_NAME_LENGTH];
    g_GrenadeLocationsKv.GetString("name", userName, sizeof(userName));
    menu.SetTitle("Lista de Grandas de %s", userName);
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
      do {
        char id[GRENADE_ID_LENGTH], name[GRENADE_NAME_LENGTH];
        g_GrenadeLocationsKv.GetSectionName(id, sizeof(id));
        g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
        if (grenadeType == GrenadeType_None) {
          menu.AddItem(id, name);
        } else {
          char type[32]
          g_GrenadeLocationsKv.GetString("grenadeType", type, sizeof(type));
          if (grenadeType == GrenadeTypeFromString(type)) {
            menu.AddItem(id, name);
          }
        }
      } while (g_GrenadeLocationsKv.GotoNextKey());

      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }

  menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int NadeFilterMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char nadeIdStr[OPTION_NAME_LENGTH];
    menu.GetItem(param2, nadeIdStr, sizeof(nadeIdStr));
    g_ClientLastMenuType[client] = GrenadeMenuType_TypeFilter;
    GiveNadeMenu(client, StringToInt(nadeIdStr));
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GiveNadesMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}
