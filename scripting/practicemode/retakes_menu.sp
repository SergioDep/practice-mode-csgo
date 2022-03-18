
public void RetakesEditorMenu(int client) {
  strcopy(g_SelectedRetakeId, RETAKE_ID_LENGTH, "-1");
  UpdateHoloRetakeEntities();
  Menu menu = new Menu(RetakesEditorMenuHandler);
  menu.SetTitle("Editar Zonas de Retake: ");
  menu.AddItem("add_new", "Añadir Nueva Zona");
  char id[RETAKE_ID_LENGTH];
  char name[RETAKE_NAME_LENGTH];
  if (g_RetakesKv.GotoFirstSubKey()) {
    do {
      g_RetakesKv.GetSectionName(id, sizeof(id));
      g_RetakesKv.GetString("name", name, sizeof(name));
      char display[128];
      Format(display, sizeof(display), "%s (id %s)", name, id);
      menu.AddItem(id, display);
    } while (g_RetakesKv.GotoNextKey());
    g_RetakesKv.GoBack();
  }
  menu.AddItem("exit_edit", "Salir de Modo Edición");
  menu.ExitButton = false;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int RetakesEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[RETAKE_ID_LENGTH + 1];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "add_new")) {
      g_WaitForRetakeSave[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre del retake a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
    } else if (StrEqual(buffer, "exit_edit")) {
      PM_Message(client, "{ORANGE}Modo Edición Descativado.");
      RemoveHoloRetakeEntities();
    } else {
      strcopy(g_SelectedRetakeId, RETAKE_ID_LENGTH, buffer);
      SingleRetakeEditorMenu(client);
      UpdateHoloRetakeEntities();
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void SingleRetakeEditorMenu(int client, int pos = 0) {
  Menu menu = new Menu(SingleRetakeEditorMenuHandler);
  char retakeName[RETAKE_NAME_LENGTH];
  GetRetakeName(g_SelectedRetakeId, retakeName, RETAKE_NAME_LENGTH);
  menu.SetTitle("Editor de Retake: %s (id %s)", retakeName, g_SelectedRetakeId);
  menu.AddItem("edit_enemies", "Editar Spawns de Bots");
  menu.AddItem("edit_players", "Editar Spawns de Jugadores");
  menu.AddItem("edit_grenades", "Editar Spawns de Granadas");
  menu.AddItem("delete", "Eliminar este Retake");

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int SingleRetakeEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));

    if (StrEqual(buffer, "edit_enemies")) {
      RetakeSpawnsEditorMenu(client, KV_BOTSPAWN);
    } else if (StrEqual(buffer, "edit_players")) {
      RetakeSpawnsEditorMenu(client, KV_PLAYERSPAWN);
    } else if (StrEqual(buffer, "edit_grenades")) {
      RetakeGrenadesEditorMenu(client);
    } else if (StrEqual(buffer, "delete")) {
      char retakeName[RETAKE_NAME_LENGTH];
      GetRetakeName(g_SelectedRetakeId, retakeName, RETAKE_NAME_LENGTH);
      RetakeDeleteConfirmationMenu(client);
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    RetakesEditorMenu(client);
  }
  return 0;
}

public void RetakeSpawnsEditorMenu(int client, const char[] spawnType){
  Menu menu = new Menu(RetakeSpawnsEditorMenuHandler);
  menu.SetTitle("Editar Spawns Tipo %s", spawnType); //Bot || Player
  menu.AddItem("add_new", "Añadir Nuevo Spawn");

  char spawn_id[RETAKE_ID_LENGTH];
  char spawn_display[RETAKE_NAME_LENGTH];
  if (g_RetakesKv.JumpToKey(g_SelectedRetakeId)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.GotoFirstSubKey()) {
        do {
          g_RetakesKv.GetSectionName(spawn_id, sizeof(spawn_id));
          Format(spawn_display, RETAKE_NAME_LENGTH, "Spawn %s %s", spawnType, spawn_id);
          menu.AddItem(spawn_id, spawn_display);
        } while (g_RetakesKv.GotoNextKey());
      }
    }
  }
  g_RetakesKv.Rewind();

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int RetakeSpawnsEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    char title[OPTION_NAME_LENGTH];
    menu.GetTitle(title, sizeof(title));
    char SelectedRetakeInfo[4][OPTION_NAME_LENGTH];
    ExplodeString(title, " ", SelectedRetakeInfo, sizeof(SelectedRetakeInfo), sizeof(SelectedRetakeInfo[]));
    //Editar Spawns Tipo (Bot | Player)
    if (StrEqual(buffer, "add_new")) {
      char nextSpawnId[RETAKE_ID_LENGTH];
      GetRetakeSpawnsNextId(g_SelectedRetakeId, SelectedRetakeInfo[3], nextSpawnId, RETAKE_ID_LENGTH);
      SpawnEditorMenu(client, SelectedRetakeInfo[3], nextSpawnId);
    } else {
      SpawnEditorMenu(client, SelectedRetakeInfo[3], buffer);
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    SingleRetakeEditorMenu(client);
  }
  return 0;
}

public void SpawnEditorMenu(int client, const char[] spawnType, char[] spawnId) {
  Menu menu = new Menu(SpawnEditorMenuHandler);
  // pass the id through the title, so i dont need more global variables
  menu.SetTitle("Editar %s Spawn %s", spawnType, spawnId);
  menu.AddItem("settomypos", "Mover a mi Posición");
  menu.AddItem("delete", "Eliminar Spawn");

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int SpawnEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  char SelectedSpawnInfo[4][RETAKE_ID_LENGTH];
  char title[OPTION_NAME_LENGTH];
  menu.GetTitle(title, sizeof(title));
  // TrimString(title);
  ExplodeString(title, " ", SelectedSpawnInfo, sizeof(SelectedSpawnInfo), sizeof(SelectedSpawnInfo[]));
  // spawntype = SelectedSpawnInfo[1]
  // spawnid = SelectedSpawnInfo[3]
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "settomypos")) {
      float fOrigin[3], fAngles[3];
      GetClientAbsOrigin(client, fOrigin);
      GetClientEyeAngles(client, fAngles);
      SetRetakeSpawnVectorKV(g_SelectedRetakeId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "origin", fOrigin);
      SetRetakeSpawnVectorKV(g_SelectedRetakeId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "angles", fAngles);
      PM_Message(client, "{ORANGE}%s Spawn {GREEN}%s {ORANGE}actualizado.", SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
    } else if (StrEqual(buffer, "delete")) {
      DeleteRetakeSpawn(g_SelectedRetakeId, SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
      PM_Message(client, "{ORANGE}%s Spawn {GREEN}%s {ORANGE}eliminado.", SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
      RetakeSpawnsEditorMenu(client, SelectedSpawnInfo[1]);
      return 0;
    }
    SpawnEditorMenu(client, SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    RetakeSpawnsEditorMenu(client, SelectedSpawnInfo[1]);
  }
  return 0;
}

public void RetakeGrenadesEditorMenu(int client){
  Menu menu = new Menu(RetakeGrenadesEditorMenuHandler);
  menu.SetTitle("Editar Granadas");
  menu.AddItem("add_new", "Añadir Nueva Granada");

  char spawn_id[RETAKE_ID_LENGTH];
  char spawn_display[RETAKE_NAME_LENGTH];
  if (g_RetakesKv.JumpToKey(g_SelectedRetakeId)) {
    if (g_RetakesKv.JumpToKey(KV_NADESPAWN)) {
      if (g_RetakesKv.GotoFirstSubKey()) {
        do {
          g_RetakesKv.GetSectionName(spawn_id, sizeof(spawn_id));
          char grenadeType[RETAKE_NAME_LENGTH];
          g_RetakesKv.GetString("type", grenadeType, RETAKE_NAME_LENGTH);
          UpperString(grenadeType);
          Format(spawn_display, RETAKE_NAME_LENGTH, "Granada %s[%s]", spawn_id, grenadeType);
          menu.AddItem(spawn_id, spawn_display);
        } while (g_RetakesKv.GotoNextKey());
      }
    }
  }
  g_RetakesKv.Rewind();

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int RetakeGrenadesEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "add_new")) {
      char nextSpawnId[RETAKE_ID_LENGTH];
      GetRetakeSpawnsNextId(g_SelectedRetakeId, KV_NADESPAWN, nextSpawnId, RETAKE_ID_LENGTH);
      GrenadeSpawnEditorMenu(client, nextSpawnId);
    } else {
      GrenadeSpawnEditorMenu(client, buffer);
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    SingleRetakeEditorMenu(client);
  }
  return 0;
}

public void GrenadeSpawnEditorMenu(int client, char[] spawnId) {
  Menu menu = new Menu(GrenadeSpawnEditorMenuHandler);
  menu.SetTitle("Editar Granada %s", spawnId);
  menu.AddItem("updatenade", "Actualizar Granada");
  menu.AddItem("updatetrigger", "Actualizar Trigger");
  menu.AddItem("throw", "Lanzar Granada");
  menu.AddItem("delete", "Eliminar Granada");

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int GrenadeSpawnEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    char title[OPTION_NAME_LENGTH];
    menu.GetTitle(title, sizeof(title));
    // TrimString(title);
    char SelectedSpawnInfo[3][RETAKE_ID_LENGTH];
    ExplodeString(title, " ", SelectedSpawnInfo, sizeof(SelectedSpawnInfo), sizeof(SelectedSpawnInfo[]));
    // spawnid = SelectedSpawnInfo[2]
    if (StrEqual(buffer, "updatenade")) {
      if (g_CSUtilsLoaded) {
        if (IsGrenade(g_LastGrenadeType[client])) {
          char grenadeTypeString[128];
          GrenadeTypeString(g_LastGrenadeType[client], grenadeTypeString, sizeof(grenadeTypeString));
          SetRetakeSpawnStringKV(g_SelectedRetakeId, KV_NADESPAWN, SelectedSpawnInfo[2], "type", grenadeTypeString);
          SetRetakeSpawnVectorKV(g_SelectedRetakeId, KV_NADESPAWN, SelectedSpawnInfo[2], "origin", g_LastGrenadeOrigin[client]);
          SetRetakeSpawnVectorKV(g_SelectedRetakeId, KV_NADESPAWN, SelectedSpawnInfo[2], "velocity", g_LastGrenadeVelocity[client]);
          g_LastGrenadeType[client] = GrenadeType_None;
          PM_Message(client, "{ORANGE}Spawn de Granada {GREEN}%s {ORANGE}actualizado.", SelectedSpawnInfo[2]);
        } else {
          PM_Message(client, "{ORANGE}Granada no Válida. Tira una Granada Primero");
        }
      }
    } else if (StrEqual(buffer, "updatetrigger")) {
      // edit last trigger
      PM_Message(client, "main->GrenadeSpawnEditorMenu->verticeEditor = null");
    } else if (StrEqual(buffer, "throw")) {
      float grenadeOrigin[3], grenadeVelocity[3];
      char grenadeTypeString[128];
      GetRetakeSpawnStringKV(g_SelectedRetakeId, KV_NADESPAWN, SelectedSpawnInfo[2], "type", grenadeTypeString, sizeof(grenadeTypeString));
      GrenadeType grenadeType = GrenadeTypeFromString(grenadeTypeString);
      if (IsGrenade(grenadeType)) {
        GetRetakeSpawnVectorKV(g_SelectedRetakeId, KV_NADESPAWN, SelectedSpawnInfo[2], "origin", grenadeOrigin);
        GetRetakeSpawnVectorKV(g_SelectedRetakeId, KV_NADESPAWN, SelectedSpawnInfo[2], "velocity", grenadeVelocity);
        CSU_ThrowGrenade(client, grenadeType, grenadeOrigin, grenadeVelocity);
      } else {
        PM_Message(client, "{ORANGE}Granada no Válida. Tira una Granada Primero");
      }
    } else if (StrEqual(buffer, "delete")) {
      PM_Message(client, "{ORANGE}Spawn de Granada {GREEN}%s {ORANGE}eliminado.", SelectedSpawnInfo[2]);
      DeleteRetakeSpawn(g_SelectedRetakeId, KV_NADESPAWN, SelectedSpawnInfo[2]);
      RetakeGrenadesEditorMenu(client);
      return 0;
    }
    GrenadeSpawnEditorMenu(client, SelectedSpawnInfo[2]);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    RetakeGrenadesEditorMenu(client)
  }
  return 0;
}

public void RetakeDeleteConfirmationMenu(int client) {
  char retakeName[RETAKE_NAME_LENGTH];
  GetRetakeName(g_SelectedRetakeId, retakeName, sizeof(retakeName));

  Menu menu = new Menu(RetakeDeletionMenuHandler);
  menu.SetTitle("Confirma la eliminación de retake: %s", retakeName);
  
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

public int RetakeDeletionMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));

    if (StrEqual(buffer, "yes")) {
      char retakeName[RETAKE_NAME_LENGTH];
      GetRetakeName(g_SelectedRetakeId, retakeName, sizeof(retakeName));
      DeleteRetake(g_SelectedRetakeId);
      PM_MessageToAll("Retake %s eliminado.", retakeName);
      RetakesEditorMenu(client);
    } else {
      SingleRetakeEditorMenu(client);
    }
  }
  return 0;
}
