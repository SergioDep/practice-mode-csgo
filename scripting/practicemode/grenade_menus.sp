// stock void GivePracticeMenu(int client, int style = ITEMDRAW_DEFAULT, int pos = -1) {
//   Menu menu = new Menu(PracticeMenuHandler);
//   SetMenuTitle(menu, "Practice Settings");
//   SetMenuExitButton(menu, true);

//   if (!g_InPracticeMode) {
//     bool canLaunch =
//         CanStartPracticeMode(client) && CheckCommandAccess(client, "sm_prac", ADMFLAG_CHANGEMAP);
//     AddMenuItem(menu, "launch_practice", "Start practice mode", EnabledIf(canLaunch));
//     style = ITEMDRAW_DISABLED;
//   } else {
//     AddMenuItem(menu, "end_menu", "Exit practice mode", style);
//   }

//   if (LibraryExists("get5")) {
//     AddMenuItem(menu, "get5", "Get5 options");
//   }

//   for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
//     if (!g_BinaryOptionChangeable.Get(i)) {
//       continue;
//     }

//     char name[OPTION_NAME_LENGTH];
//     g_BinaryOptionNames.GetString(i, name, sizeof(name));

//     char enabled[32];
//     GetEnabledString(enabled, sizeof(enabled), g_BinaryOptionEnabled.Get(i), client);

//     char buffer[128];
//     Format(buffer, sizeof(buffer), "%s: %s", name, enabled);
//     AddMenuItem(menu, name, buffer, style);
//   }

//   if (pos == -1) {
//     DisplayMenu(menu, client, MENU_TIME_FOREVER);
//   } else {
//     DisplayMenuAtItem(menu, client, pos, MENU_TIME_FOREVER);
//   }
// }

// public int PracticeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
//   if (action == MenuAction_Select) {
//     int client = param1;
//     char buffer[OPTION_NAME_LENGTH];
//     int pos = GetMenuSelectionPosition();
//     menu.GetItem(param2, buffer, sizeof(buffer));

//     for (int i = 0; i < g_BinaryOptionNames.Length; i++) {
//       char name[OPTION_NAME_LENGTH];
//       g_BinaryOptionNames.GetString(i, name, sizeof(name));
//       if (StrEqual(name, buffer)) {
//         bool setting = !g_BinaryOptionEnabled.Get(i);
//         ChangeSetting(i, setting);
//         GivePracticeMenu(client, ITEMDRAW_DEFAULT, pos);
//         return 0;
//       }
//     }

//     if (StrEqual(buffer, "launch_practice")) {
//       LaunchPracticeMode();
//       GivePracticeMenu(client);
//     }
//     if (StrEqual(buffer, "get5")) {
//       FakeClientCommand(client, "sm_get5");
//     }
//     if (StrEqual(buffer, "end_menu")) {
//       ExitPracticeMode();
//       if (g_PugsetupLoaded) {
//         PugSetup_GiveSetupMenu(client);
//       }
//     }

//   } else if (action == MenuAction_End) {
//     delete menu;
//   }

//   return 0;
// }

stock void GiveNadesMenu(int client) {
  if (!g_InPracticeMode) {
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
  
  GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
  Format(buffer, sizeof(buffer), "Mis granadas(%s) [%i/%i]\n "
  , grenadeString , CountGrenadesForPlayer(auth, g_ClientLastMenuGrenadeTypeFilter[client])
  , MAX_GRENADE_SAVES_PLAYER)
  menu.AddItem("mynades", buffer);

  menu.AddItem("loadmynades", "Cargar mis granadas");
  menu.AddItem("disablemynades", "Quitar mis granadas");
  
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
      g_WaitingForSaveNade[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre de la granada a guardar:");
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
        GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
        int index = g_EnabledHoloNadeAuth.FindString(auth);
        if(index == -1) {
          g_EnabledHoloNadeAuth.PushString(auth);
          UpdateHoloNadeEntities();
        }
      } else if (StrEqual(buffer, "disablemynades")) {
        GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
        int index = g_EnabledHoloNadeAuth.FindString(auth);
        if(index > -1) {
          g_EnabledHoloNadeAuth.Erase(index);
          UpdateHoloNadeEntities();
        }
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
  GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
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

// stock void GiveGrenadeMenu(int client, GrenadeMenuType type, int position = 0,
//                            const char[] data = "", ArrayList ids = null,
//                            GrenadeMenuType forceMatch = GrenadeMenuType_Invalid) {
//   g_ClientLastMenuType[client] = type;
//   strcopy(g_ClientLastMenuData[client], AUTH_LENGTH, data);

//   if (type == GrenadeMenuType_PlayersAndCategories || type == GrenadeMenuType_Categories) {
//     g_ClientLastTopMenuType[client] = type;
//     strcopy(g_ClientLastTopMenuData[client], AUTH_LENGTH, data);
//   }

//   Menu menu;
//   int count = 0;
//   if (type == GrenadeMenuType_PlayersAndCategories) {
//     menu = new Menu(Grenade_PlayerAndCategoryHandler);
//     menu.SetTitle("Selecciona un jugador/categoria:");
//     menu.AddItem("all", "Todas las granadas");
//     count = AddPlayersToMenu(menu) + AddCategoriesToMenu(menu);

//   } else if (type == GrenadeMenuType_Categories) {
//     menu = new Menu(Grenade_PlayerAndCategoryHandler);
//     menu.SetTitle("Selecciona una categoria:");
//     menu.AddItem("all", "Todas las granadas");
//     count = AddCategoriesToMenu(menu);

//     // Fall back to all nades.
//     if (count == 0) {
//       GiveGrenadeMenu(client, GrenadeMenuType_OneCategory, 0, "all");
//       delete menu;
//       return;
//     }

//   } else {
//     menu = new Menu(Grenade_NadeHandler);
//     bool deleteIds = false;
//     if (ids == null) {
//       deleteIds = true;
//       char unused[128];
//       ids = new ArrayList(GRENADE_ID_LENGTH);
//       FindGrenades(data, ids, unused, sizeof(unused), forceMatch);
//     }
//     count = ids.Length;
//     AddIdsToMenu(menu, ids);
//     if (deleteIds) {
//       delete ids;
//     }

//     if (type == GrenadeMenuType_OnePlayer) {
//       char name[MAX_NAME_LENGTH];
//       FindTargetNameByAuth(data, name, sizeof(name));
//       menu.SetTitle("Granadas para %s:", name);
//     } else if (type == GrenadeMenuType_OneCategory) {
//       if (StrEqual(data, "") || StrEqual(data, "all")) {
//         menu.SetTitle("Todas las granadas");
//       } else {
//         menu.SetTitle("Categoria: %s", data);
//       }
//     } else if (type == GrenadeMenuType_MatchingName) {
//       menu.SetTitle("%s", data);
//     } else {
//       menu.SetTitle("Granadas:");
//     }
//   }

//   if (count == 0) {
//     PM_Message(client, "No se encontraron coincidencias.");
//     delete menu;
//     return;
//   }

//   menu.ExitButton = true;
//   menu.ExitBackButton = true;
//   menu.DisplayAt(client, position, MENU_TIME_FOREVER);
// }

// static int AddPlayersToMenu(Menu menu) {
//   int count = 0;
//   if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
//     do {
//       int nadeCount = 0;
//       if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
//         do {
//           nadeCount++;
//         } while (g_GrenadeLocationsKv.GotoNextKey());
//         g_GrenadeLocationsKv.GoBack();
//       }

//       char auth[AUTH_LENGTH];
//       char name[MAX_NAME_LENGTH];
//       g_GrenadeLocationsKv.GetSectionName(auth, sizeof(auth));
//       g_GrenadeLocationsKv.GetString("name", name, sizeof(name));

//       char info[256];
//       Format(info, sizeof(info), "%s %s", auth, name);

//       char display[256];
//       Format(display, sizeof(display), "%s (%d guardado)", name, nadeCount);
//       if (nadeCount > 0) {
//         count++;
//         menu.AddItem(info, display);
//       }

//     } while (g_GrenadeLocationsKv.GotoNextKey());
//     g_GrenadeLocationsKv.GoBack();
//   }
//   return count;
// }

// static int AddCategoriesToMenu(Menu menu) {
//   int numCategories = 0;

//   for (int i = 0; i < g_KnownNadeCategories.Length; i++) {
//     char cat[64];
//     g_KnownNadeCategories.GetString(i, cat, sizeof(cat));
//     int categoryCount = CountCategoryNades(cat);

//     char info[256];
//     Format(info, sizeof(info), "cat %s", cat);
//     char display[256];
//     Format(display, sizeof(display), "Categoria: %s (%d guardado)", cat, categoryCount);

//     if (categoryCount > 0) {
//       numCategories++;
//       menu.AddItem(info, display);
//     }
//   }
//   return numCategories;
// }

// static void AddIdsToMenu(Menu menu, ArrayList ids) {
//   if (g_AlphabetizeNadeMenusCvar.BoolValue) {
//     SortADTArrayCustom(ids, SortIdArrayByName);
//   }

//   char id[GRENADE_ID_LENGTH];
//   char auth[AUTH_LENGTH];
//   char name[MAX_NAME_LENGTH];
//   for (int i = 0; i < ids.Length; i++) {
//     ids.GetString(i, id, sizeof(id));
//     if (TryJumpToOwnerId(id, auth, sizeof(auth), name, sizeof(name))) {
//       // TODO: do we need the owner name here?
//       AddKvGrenadeToMenu(menu, g_GrenadeLocationsKv, name);
//       g_GrenadeLocationsKv.Rewind();
//     }
//   }
// }

// Handlers for the grenades menu.

// public int Grenade_PlayerAndCategoryHandler(Menu menu, MenuAction action, int param1, int param2) {
//   if (action == MenuAction_Select && g_InPracticeMode) {
//     int client = param1;
//     g_ClientLastTopMenuPos[client] = GetMenuSelectionPosition();
//     char buffer[MAX_NAME_LENGTH + AUTH_LENGTH + 1];
//     menu.GetItem(param2, buffer, sizeof(buffer));

//     if (StrEqual(buffer, "all")) {
//       GiveGrenadeMenu(client, GrenadeMenuType_OneCategory, 0, "all");
//       return 0;
//     }

//     // split buffer from "auth name" (seperated by whitespace)
//     char arg1[AUTH_LENGTH];      // 'cat' or ownerAuth
//     char arg2[MAX_NAME_LENGTH];  // categoryName or ownerName
//     SplitOnSpace(buffer, arg1, sizeof(arg1), arg2, sizeof(arg2));

//     if (StrEqual(arg1, "cat")) {
//       GiveGrenadeMenu(client, GrenadeMenuType_OneCategory, 0, arg2);
//     } else {
//       GiveGrenadeMenu(client, GrenadeMenuType_OnePlayer, 0, arg1);
//     }
//   } else if (action == MenuAction_End) {
//     delete menu;
//   }
//   return 0;
// }

// public int Grenade_NadeHandler(Menu menu, MenuAction action, int param1, int param2) {
//   if (action == MenuAction_Select && g_InPracticeMode) {
//     int client = param1;
//     g_ClientLastMenuPos[client] = GetMenuSelectionPosition();
//     HandleGrenadeSelected(client, menu, param2);
//     if (GetSetting(client, UserSetting_LeaveNadeMenuOpen)) {
//       GiveGrenadeMenu(client, g_ClientLastMenuType[client], g_ClientLastMenuPos[client],
//                       g_ClientLastMenuData[client], null, g_ClientLastMenuType[client]);
//     }
//   } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
//     int client = param1;
//     GiveGrenadeMenu(client, g_ClientLastTopMenuType[client], g_ClientLastTopMenuPos[client],
//                     g_ClientLastTopMenuData[client]);
//   } else if (action == MenuAction_End) {
//     delete menu;
//   }
//   return 0;
// }

// int SortIdArrayByName(int index1, int index2, Handle array, Handle hndl) {
//   // This code is totally pointless, but is harmless and there's no way to supress the warning
//   // for hndl being unused. :/
//   if (hndl != INVALID_HANDLE) {
//     delete hndl;
//   }

//   char id1[GRENADE_ID_LENGTH];
//   char id2[GRENADE_ID_LENGTH];
//   GetArrayString(array, index1, id1, sizeof(id1));
//   GetArrayString(array, index2, id2, sizeof(id2));

//   char name1[GRENADE_EXECUTION_LENGTH];
//   char name2[GRENADE_EXECUTION_LENGTH];

//   if (TryJumpToId(id1)) {
//     g_GrenadeLocationsKv.GetString("name", name1, sizeof(name1));
//     g_GrenadeLocationsKv.Rewind();
//   }
//   if (TryJumpToId(id2)) {
//     g_GrenadeLocationsKv.GetString("name", name2, sizeof(name2));
//     g_GrenadeLocationsKv.Rewind();
//   }

//   return strcmp(name1, name2, false);
// }

stock void AddGrenadeToMenu(Menu menu, const char[] ownerName, const char[] strId,
                            const char[] name, bool showPlayerName = false) {
  char display[128];
  if (showPlayerName && g_SharedAllNadesCvar.IntValue == 0 && !StrEqual(ownerName, "")) {
    Format(display, sizeof(display), "%s (%s-%s)", name, ownerName, strId);
  } else {
    Format(display, sizeof(display), "%s (id %s)", name, strId);
  }

  menu.AddItem(strId, display);
}

public void AddKvGrenadeToMenu(Menu menu, KeyValues kv, const char[] ownerName) {
  char name[GRENADE_NAME_LENGTH];
  char strId[GRENADE_ID_LENGTH];
  kv.GetSectionName(strId, sizeof(strId));
  kv.GetString("name", name, sizeof(name));
  AddGrenadeToMenu(menu, ownerName, strId, name);
}

public void HandleGrenadeSelected(int client, Menu menu, int param2) {
  char id[GRENADE_ID_LENGTH];
  menu.GetItem(param2, id, sizeof(id));
  GiveNadeMenu(client, StringToInt(id));
}

public int CountCategoryNades(const char[] category) {
  DataPack p = CreateDataPack();
  p.WriteCell(0);
  p.WriteString(category);
  IterateGrenades(_CountCategoryNades_Helper, p);
  p.Reset();
  int count = p.ReadCell();
  delete p;
  return count;
}

public Action _CountCategoryNades_Helper(
  const char[] ownerName, 
  const char[] ownerAuth, 
  const char[] name, 
  const char[] execution, 
  ArrayList categories,
  const char[] grenadeId, 
  const float origin[3], 
  const float angles[3], 
  const char[] grenadeType, 
  const float grenadeOrigin[3],
  const float grenadeVelocity[3], 
  const float grenadeDetonationOrigin[3], 
  any data
) {
  DataPack p = view_as<DataPack>(data);
  ResetPack(p, false);
  int count = p.ReadCell();
  char cat[64];
  p.ReadString(cat, sizeof(cat));

  if (FindStringInList(categories, GRENADE_CATEGORY_LENGTH, cat, false) >= 0) {
    count++;
    ResetPack(p, true);
    p.WriteCell(count);
    p.WriteString(cat);
  }
  return Plugin_Handled;
}
