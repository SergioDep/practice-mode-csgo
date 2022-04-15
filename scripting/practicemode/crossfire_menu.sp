public void CrossfiresSetupMenu(int client) {
  Menu menu = new Menu(CrossfiresSetupMenuHandler);

  menu.SetTitle("Opciones De Crossfire");
  // menu.AddItem("togglerepeat", "Repetir: %");
  // menu.AddItem("togglerandom", "RandomWeapons: %");
  // menu.AddItem("togglezone", "");
  menu.AddItem("start", "Empezar Crossfires");
  menu.AddItem("stop", "Salir de Crossfires");
  menu.AddItem("edit", "Editar Crossfires");
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int CrossfiresSetupMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if(action == MenuAction_Select) {
    char buffer[128];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "start")) {
      InitCrossfire(client);
    } else if (StrEqual(buffer, "stop")) {
      StopCrossfiresMode();
    } else if (StrEqual(buffer, "edit")) {
      CrossfiresEditorMenu(client);
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public void CrossfiresEditorMenu(int client) {
  strcopy(g_SelectedCrossfireId, CROSSFIRE_ID_LENGTH, "-1");
  UpdateHoloCFireEnts();
  Menu menu = new Menu(CrossfiresEditorMenuHandler);
  menu.SetTitle("Editar Zonas de Crossfire: ");
  menu.AddItem("add_new", "Añadir Nueva Zona");
  char id[CROSSFIRE_ID_LENGTH];
  char name[CROSSFIRE_NAME_LENGTH];
  if (g_CrossfiresKv.GotoFirstSubKey()) {
    do {
      g_CrossfiresKv.GetSectionName(id, sizeof(id));
      g_CrossfiresKv.GetString("name", name, sizeof(name));
      char display[128];
      Format(display, sizeof(display), "%s (id %s)", name, id);
      menu.AddItem(id, display);
    } while (g_CrossfiresKv.GotoNextKey());
    g_CrossfiresKv.GoBack();
  }
  menu.AddItem("exit_edit", "Salir de Modo Edición");
  menu.ExitButton = false;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int CrossfiresEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[CROSSFIRE_ID_LENGTH + 1];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "add_new")) {
      g_WaitForCrossfireSave[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre del crossfire a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
    } else if (StrEqual(buffer, "exit_edit")) {
      PM_Message(client, "{ORANGE}Modo Edición Desactivado.");
      RemoveHoloCFireEnts();
    } else {
      strcopy(g_SelectedCrossfireId, CROSSFIRE_ID_LENGTH, buffer);
      SingleCrossfireEditorMenu(client);
      UpdateHoloCFireEnts();
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void SingleCrossfireEditorMenu(int client, int pos = 0) {
  Menu menu = new Menu(SingleCrossfireEditorMenuHandler);
  char crossfireName[CROSSFIRE_NAME_LENGTH];
  GetCrossfireName(g_SelectedCrossfireId, crossfireName, CROSSFIRE_NAME_LENGTH);
  menu.SetTitle("Editor de Crossfire: %s (id %s)", crossfireName, g_SelectedCrossfireId);
  menu.AddItem("edit_enemies", "Editar Spawns de Bots");
  menu.AddItem("edit_players", "Editar Spawns de Jugadores");
  menu.AddItem("edit_grenades", "Editar Spawns de Granadas");
  menu.AddItem("delete", "Eliminar este Crossfire");

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int SingleCrossfireEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));

    if (StrEqual(buffer, "edit_enemies")) {
      CrossfireSpawnsEditorMenu(client, KV_BOTSPAWN);
    } else if (StrEqual(buffer, "edit_players")) {
      CrossfireSpawnsEditorMenu(client, KV_PLAYERSPAWN);
    } else if (StrEqual(buffer, "edit_grenades")) {
      CrossfireGrenadesEditorMenu(client);
    } else if (StrEqual(buffer, "delete")) {
      char crossfireName[CROSSFIRE_NAME_LENGTH];
      GetCrossfireName(g_SelectedCrossfireId, crossfireName, CROSSFIRE_NAME_LENGTH);
      CrossfireDeleteConfirmationMenu(client);
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    CrossfiresEditorMenu(client);
  }
  return 0;
}

public void CrossfireSpawnsEditorMenu(int client, const char[] spawnType){
  Menu menu = new Menu(CrossfireSpawnsEditorMenuHandler);
  menu.SetTitle("Editar Spawns Tipo %s", spawnType); //Bot || Player
  menu.AddItem("add_new", "Añadir Nuevo Spawn");

  char spawn_id[CROSSFIRE_ID_LENGTH];
  char spawn_display[CROSSFIRE_NAME_LENGTH];
  if (g_CrossfiresKv.JumpToKey(g_SelectedCrossfireId)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.GotoFirstSubKey()) {
        do {
          g_CrossfiresKv.GetSectionName(spawn_id, sizeof(spawn_id));
          Format(spawn_display, CROSSFIRE_NAME_LENGTH, "Spawn %s %s", spawnType, spawn_id);
          menu.AddItem(spawn_id, spawn_display);
        } while (g_CrossfiresKv.GotoNextKey());
      }
    }
  }
  g_CrossfiresKv.Rewind();

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int CrossfireSpawnsEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    char title[OPTION_NAME_LENGTH];
    menu.GetTitle(title, sizeof(title));
    char SelectedCrossfireInfo[4][OPTION_NAME_LENGTH];
    ExplodeString(title, " ", SelectedCrossfireInfo, sizeof(SelectedCrossfireInfo), sizeof(SelectedCrossfireInfo[]));
    //Editar Spawns Tipo (Bot | Player)
    if (StrEqual(buffer, "add_new")) {
      char nextSpawnId[CROSSFIRE_ID_LENGTH];
      GetCrossfireSpawnsNextId(g_SelectedCrossfireId, SelectedCrossfireInfo[3], nextSpawnId, CROSSFIRE_ID_LENGTH);
      CrossfireSpawnEditorMenu(client, SelectedCrossfireInfo[3], nextSpawnId);
    } else {
      CrossfireSpawnEditorMenu(client, SelectedCrossfireInfo[3], buffer, true);
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    SingleCrossfireEditorMenu(client);
  }
  return 0;
}

stock void CrossfireSpawnEditorMenu(int client, const char[] spawnType, char[] spawnId, bool teleport = false) {
  Menu menu = new Menu(CrossfireSpawnEditorMenuHandler);
  // pass the id through the title, so i dont need more global variables
  menu.SetTitle("Editar %s Spawn %s", spawnType, spawnId);
  menu.AddItem("settomypos", "Mover Punto de Spawn a mi Posición");

  if (teleport) {
    float fOrigin[3], fAngles[3];
    GetCrossfireSpawnVectorKV(g_SelectedCrossfireId, spawnType, spawnId, "origin", fOrigin);
    GetCrossfireSpawnVectorKV(g_SelectedCrossfireId, spawnType, spawnId, "angles", fAngles);
    if (!Math_VectorsEqual(fOrigin, ZERO_VECTOR)) {
      TeleportEntity(client, fOrigin, fAngles, ZERO_VECTOR);
    }
  }

  if (StrEqual(spawnType, KV_PLAYERSPAWN)) {
    menu.AddItem("vecmin", "(Zona) Mover Primer Punto");
    menu.AddItem("vecmax", "(Zona) Mover Segundo Punto");
  }

  menu.AddItem("delete", "Eliminar Spawn");

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int CrossfireSpawnEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  char SelectedSpawnInfo[4][CROSSFIRE_ID_LENGTH];
  char title[OPTION_NAME_LENGTH];
  menu.GetTitle(title, sizeof(title));
  // TrimString(title);
  ExplodeString(title, " ", SelectedSpawnInfo, sizeof(SelectedSpawnInfo), sizeof(SelectedSpawnInfo[]));
  // spawntype = SelectedSpawnInfo[1]
  // spawnid = SelectedSpawnInfo[3]
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    float fOrigin[3], fAngles[3];
    if (StrEqual(buffer, "settomypos")) {
      GetClientAbsOrigin(client, fOrigin);
      GetClientEyeAngles(client, fAngles);
      SetCrossfireSpawnVectorKV(g_SelectedCrossfireId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "origin", fOrigin);
      SetCrossfireSpawnVectorKV(g_SelectedCrossfireId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "angles", fAngles);
      // PM_Message(client, "{ORANGE}%s Spawn {GREEN}%s {ORANGE}actualizado.", SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
    } else if (StrEqual(buffer, "delete")) {
      DeleteCrossfireSpawn(g_SelectedCrossfireId, SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
      PM_Message(client, "{ORANGE}%s Spawn {GREEN}%s {ORANGE}eliminado.", SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
      CrossfireSpawnsEditorMenu(client, SelectedSpawnInfo[1]);
      return 0;
    } else {
      GetClientAbsOrigin(client, fOrigin);
      if (StrEqual(buffer, "vecmin")) {
        SetCrossfireSpawnVectorKV(g_SelectedCrossfireId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "vecmin", fOrigin);
      } else if (StrEqual(buffer, "vecmax")) {
        SetCrossfireSpawnVectorKV(g_SelectedCrossfireId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "vecmax", fOrigin);
      }
    }
    CrossfireSpawnEditorMenu(client, SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    CrossfireSpawnsEditorMenu(client, SelectedSpawnInfo[1]);
  }
  return 0;
}

public void CrossfireGrenadesEditorMenu(int client){
  Menu menu = new Menu(CrossfireGrenadesEditorMenuHandler);
  menu.SetTitle("Editar Granadas");
  menu.AddItem("add_new", "Añadir Nueva Granada");

  char spawn_id[CROSSFIRE_ID_LENGTH];
  char spawn_display[CROSSFIRE_NAME_LENGTH];
  if (g_CrossfiresKv.JumpToKey(g_SelectedCrossfireId)) {
    if (g_CrossfiresKv.JumpToKey(KV_NADESPAWN)) {
      if (g_CrossfiresKv.GotoFirstSubKey()) {
        do {
          g_CrossfiresKv.GetSectionName(spawn_id, sizeof(spawn_id));
          char grenadeType[CROSSFIRE_NAME_LENGTH];
          g_CrossfiresKv.GetString("type", grenadeType, CROSSFIRE_NAME_LENGTH);
          UpperString(grenadeType);
          Format(spawn_display, CROSSFIRE_NAME_LENGTH, "Granada %s[%s]", spawn_id, grenadeType);
          menu.AddItem(spawn_id, spawn_display);
        } while (g_CrossfiresKv.GotoNextKey());
      }
    }
  }
  g_CrossfiresKv.Rewind();

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int CrossfireGrenadesEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "add_new")) {
      char nextSpawnId[CROSSFIRE_ID_LENGTH];
      GetCrossfireSpawnsNextId(g_SelectedCrossfireId, KV_NADESPAWN, nextSpawnId, CROSSFIRE_ID_LENGTH);
      CrossfireGrenadeSpawnEditorMenu(client, nextSpawnId);
    } else {
      CrossfireGrenadeSpawnEditorMenu(client, buffer);
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    SingleCrossfireEditorMenu(client);
  }
  return 0;
}

public void CrossfireGrenadeSpawnEditorMenu(int client, char[] spawnId) {
  Menu menu = new Menu(CrossfireGrenadeSpawnEditorMenuHandler);
  menu.SetTitle("Editar Granada %s", spawnId);
  menu.AddItem("updatenade", "Actualizar Granada");
  menu.AddItem("updatetrigger", "Actualizar Trigger");
  menu.AddItem("throw", "Lanzar Granada");
  menu.AddItem("delete", "Eliminar Granada");

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int CrossfireGrenadeSpawnEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    char title[OPTION_NAME_LENGTH];
    menu.GetTitle(title, sizeof(title));
    // TrimString(title);
    char SelectedSpawnInfo[3][CROSSFIRE_ID_LENGTH];
    ExplodeString(title, " ", SelectedSpawnInfo, sizeof(SelectedSpawnInfo), sizeof(SelectedSpawnInfo[]));
    // spawnid = SelectedSpawnInfo[2]
    if (StrEqual(buffer, "updatenade")) {
      if (g_CSUtilsLoaded) {
        if (IsGrenade(g_LastGrenadeType[client])) {
          char grenadeTypeString[128];
          GrenadeTypeString(g_LastGrenadeType[client], grenadeTypeString, sizeof(grenadeTypeString));
          SetCrossfireSpawnStringKV(g_SelectedCrossfireId, KV_NADESPAWN, SelectedSpawnInfo[2], "type", grenadeTypeString);
          SetCrossfireSpawnVectorKV(g_SelectedCrossfireId, KV_NADESPAWN, SelectedSpawnInfo[2], "origin", g_LastGrenadeOrigin[client]);
          SetCrossfireSpawnVectorKV(g_SelectedCrossfireId, KV_NADESPAWN, SelectedSpawnInfo[2], "velocity", g_LastGrenadeVelocity[client]);
          g_LastGrenadeType[client] = GrenadeType_None;
          PM_Message(client, "{ORANGE}Spawn de Granada {GREEN}%s {ORANGE}actualizado.", SelectedSpawnInfo[2]);
        } else {
          PM_Message(client, "{ORANGE}Granada no Válida. Tira una Granada Primero");
        }
      }
    } else if (StrEqual(buffer, "updatetrigger")) {
      // edit last trigger
      PM_Message(client, "{LIGHT_RED}main->CrossfireGrenadeSpawnEditorMenu->verticeEditor = null");
    } else if (StrEqual(buffer, "throw")) {
      float grenadeOrigin[3], grenadeVelocity[3];
      char grenadeTypeString[128];
      GetCrossfireSpawnStringKV(g_SelectedCrossfireId, KV_NADESPAWN, SelectedSpawnInfo[2], "type", grenadeTypeString, sizeof(grenadeTypeString));
      GrenadeType grenadeType = GrenadeTypeFromString(grenadeTypeString);
      if (IsGrenade(grenadeType)) {
        GetCrossfireSpawnVectorKV(g_SelectedCrossfireId, KV_NADESPAWN, SelectedSpawnInfo[2], "origin", grenadeOrigin);
        GetCrossfireSpawnVectorKV(g_SelectedCrossfireId, KV_NADESPAWN, SelectedSpawnInfo[2], "velocity", grenadeVelocity);
        CSU_ThrowGrenade(client, grenadeType, grenadeOrigin, grenadeVelocity);
      } else {
        PM_Message(client, "{ORANGE}Granada no Válida. Tira una Granada Primero");
      }
    } else if (StrEqual(buffer, "delete")) {
      PM_Message(client, "{ORANGE}Spawn de Granada {GREEN}%s {ORANGE}eliminado.", SelectedSpawnInfo[2]);
      DeleteCrossfireSpawn(g_SelectedCrossfireId, KV_NADESPAWN, SelectedSpawnInfo[2]);
      CrossfireGrenadesEditorMenu(client);
      return 0;
    }
    CrossfireGrenadeSpawnEditorMenu(client, SelectedSpawnInfo[2]);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    CrossfireGrenadesEditorMenu(client)
  }
  return 0;
}

public void CrossfireDeleteConfirmationMenu(int client) {
  char crossfireName[CROSSFIRE_NAME_LENGTH];
  GetCrossfireName(g_SelectedCrossfireId, crossfireName, sizeof(crossfireName));

  Menu menu = new Menu(CrossfireDeletionMenuHandler);
  menu.SetTitle("Confirma la eliminación de zona: %s", crossfireName);
  
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

public int CrossfireDeletionMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));

    if (StrEqual(buffer, "yes")) {
      char crossfireName[CROSSFIRE_NAME_LENGTH];
      GetCrossfireName(g_SelectedCrossfireId, crossfireName, sizeof(crossfireName));
      DeleteCrossfire(g_SelectedCrossfireId);
      PM_MessageToAll("{ORANGE}Zona {GREEN}%s {ORANGE}eliminada.", crossfireName);
      CrossfiresEditorMenu(client);
    } else {
      SingleCrossfireEditorMenu(client);
    }
  }
  return 0;
}
