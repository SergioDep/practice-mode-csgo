//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////

/*******************************************************************/
/**************************** Commands *****************************/
/*******************************************************************/

public Action Command_NextCrossfire(int client, int args) {
  int currentCrossfireIndex = g_Crossfire_Arenas.FindString(g_Crossfire_ActiveId);
  if (currentCrossfireIndex < g_Crossfire_Arenas.Length - 1) {
    // go to next crossfire
    currentCrossfireIndex++;
    StartSingleCrossfire(client, currentCrossfireIndex);
  }
  return Plugin_Handled;
}

public Action Command_PrevCrossfire(int client, int args) {
  int currentCrossfireIndex = g_Crossfire_Arenas.FindString(g_Crossfire_ActiveId);
  if (currentCrossfireIndex > 0) {
    // go to prev crossfire
    currentCrossfireIndex--;
    StartSingleCrossfire(client, currentCrossfireIndex);
  }
  return Plugin_Handled;
}

public Action Command_CrossfiresSetupMenu(int client, int args) {
  if (!IsPlayer(client)) {
    return Plugin_Handled;
  }
  CrossfiresSetupMenu(client);
  return Plugin_Handled;
}

public Action Command_CrossfiresEditorMenu(int client, int args) {
  if (g_InCrossfireMode) {
    PM_Message(client, "{ORANGE}Crossfire Ya Empezado.");
    return Plugin_Continue;
  }
  PM_Message(client, "{ORANGE}Modo Edición Activado.");
  CrossfiresEditorMenu(client);
  return Plugin_Handled;
}

/*******************************************************************/
/****************************** Menus ******************************/
/*******************************************************************/

public void CrossfiresSetupMenu(int client) {
  Menu menu = new Menu(CrossfiresSetupMenuHandler);

  menu.SetTitle("Menu De Crossfire");
  menu.AddItem("start", "Empezar Crossfire");
  char displayStr[OPTION_NAME_LENGTH];
  Format(displayStr, sizeof(displayStr), "Cambiar Dificultad: %s", 
    (g_Crossfire_BotsDifficulty == 0)
      ? "Práctica"
    : (g_Crossfire_BotsDifficulty == 1)
      ? "Facil"
    : (g_Crossfire_BotsDifficulty == 2)
      ? "Medio"
    : (g_Crossfire_BotsDifficulty == 3)
      ? "Dificil"
    : (g_Crossfire_BotsDifficulty == 4)
      ? "Mas Dificil"
    : (g_Crossfire_BotsDifficulty == 5)
      ? "Avanzado" : "Error"
  );
  menu.AddItem("difficulty", displayStr);
  Format(displayStr, sizeof(displayStr), "Endless: %s", (g_Crossfire_EndlessMode) ? "Si" : "No");
  menu.AddItem("endless", displayStr);
  menu.AddItem("options", "Opciones Personalizadas");
  menu.AddItem("stop", "Salir de Crossfire");
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
    } else if (StrEqual(buffer, "difficulty")) {
      g_Crossfire_BotsDifficulty++;
      g_Crossfire_BotsDifficulty = (g_Crossfire_BotsDifficulty > CFOption_BotsDifficultyMAX)
        ? CFOption_BotsDifficultyMIN
        : g_Crossfire_BotsDifficulty;
      switch(g_Crossfire_BotsDifficulty) {
        case 0: {
          g_Crossfire_MaxSimBots = 2;
          g_Crossfire_BotReactTime = 180;
          g_Crossfire_BotStartDelay = 100;
          g_Crossfire_BotsAttack = false;
          g_Crossfire_BotsFlash = true;
          g_Crossfire_BotStrafeChance = 2;
        }
        case 1: {
          g_Crossfire_MaxSimBots = 1;
          g_Crossfire_BotReactTime = 300;
          g_Crossfire_BotStartDelay = 250;
          g_Crossfire_BotsAttack = true;
          g_Crossfire_BotsFlash = false;
          g_Crossfire_BotStrafeChance = 0;
        }
        case 2: {
          g_Crossfire_MaxSimBots = 2;
          g_Crossfire_BotReactTime = 240;
          g_Crossfire_BotStartDelay = 100;
          g_Crossfire_BotsAttack = true;
          g_Crossfire_BotsFlash = false;
          g_Crossfire_BotStrafeChance = 1;
        }
        case 3: {
          g_Crossfire_MaxSimBots = 2;
          g_Crossfire_BotReactTime = 180;
          g_Crossfire_BotStartDelay = 100;
          g_Crossfire_BotsAttack = true;
          g_Crossfire_BotsFlash = false;
          g_Crossfire_BotStrafeChance = 2;
        }
        case 4: {
          g_Crossfire_MaxSimBots = 2;
          g_Crossfire_BotReactTime = 180;
          g_Crossfire_BotStartDelay = 100;
          g_Crossfire_BotsAttack = true;
          g_Crossfire_BotsFlash = true;
          g_Crossfire_BotStrafeChance = 3;
        }
        case 5: {
          g_Crossfire_MaxSimBots = 2;
          g_Crossfire_BotReactTime = 120;
          g_Crossfire_BotStartDelay = 100;
          g_Crossfire_BotsAttack = true;
          g_Crossfire_BotsFlash = true;
          g_Crossfire_BotStrafeChance = 3;
        }
      }
      CrossfiresSetupMenu(client);
    } else if (StrEqual(buffer, "endless")) {
      g_Crossfire_EndlessMode = !g_Crossfire_EndlessMode;
      CrossfiresSetupMenu(client);
    } else if (StrEqual(buffer, "options")) {
      CrossfireOptionsMenu(client);
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

public void CrossfireOptionsMenu(int client) {
  Menu menu = new Menu(CrossfireOptionsMenuHandler);
  menu.SetTitle("Cambiar Opciones Personalizadas");
  char displayStr[OPTION_NAME_LENGTH];
  Format(displayStr, sizeof(displayStr), "Máximo Numero De Bots Simultaneos: %d", g_Crossfire_MaxSimBots);
  menu.AddItem("maxsimbots", displayStr);
  Format(displayStr, sizeof(displayStr), "Tiempo de Reacción de Bots: %.0f ms", g_Crossfire_BotReactTime*5.5556);
  menu.AddItem("reacttime", displayStr);
  Format(displayStr, sizeof(displayStr), "Tiempo para que un Bot Salga: %.0f ms", g_Crossfire_BotStartDelay*5.5556);
  menu.AddItem("botdelay", displayStr);
  Format(displayStr, sizeof(displayStr), "Bots Atacan: %s", g_Crossfire_BotsAttack ? "Si" : "No");
  menu.AddItem("botsattack", displayStr);
  Format(displayStr, sizeof(displayStr), "Bots Lanzan Flash: %s", g_Crossfire_BotsFlash ? "Si" : "No");
  menu.AddItem("botsflash", displayStr);
  Format(displayStr, sizeof(displayStr), "Swingeo de Bots (A-D): %s", 
    (g_Crossfire_BotStrafeChance == 0)
      ? "Ninguno"
    : (g_Crossfire_BotStrafeChance == 1)
      ? "Pocos"
    : (g_Crossfire_BotStrafeChance == 2)
      ? "Normal"
    : (g_Crossfire_BotStrafeChance == 3)
      ? "Muchos" : "Error"
  )
  menu.AddItem("botsstrafe", displayStr);
  Format(displayStr, sizeof(displayStr), "Armas de Bots: %s\n ", 
    (g_Crossfire_BotWeapons == 0)
      ? "Cuchillo"
    : (g_Crossfire_BotWeapons == 1)
      ? "Pistola"
    : (g_Crossfire_BotWeapons == 2)
      ? "MP9"
    : (g_Crossfire_BotWeapons == 3)
      ? "Deagle"
    : (g_Crossfire_BotWeapons == 4)
      ? "AK-47"
    : (g_Crossfire_BotWeapons == 5)
      ? "AWP" : "Error"
  )
  menu.AddItem("weapons", displayStr);

  menu.Pagination = MENU_NO_PAGINATION;
  menu.AddItem("back", "Back"); // menu.ExitBackButton = true;
  menu.AddItem("exit", "Exit"); // menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int CrossfireOptionsMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_ID_LENGTH];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "botsstrafe")) {
      g_Crossfire_BotStrafeChance++;
      g_Crossfire_BotStrafeChance = (g_Crossfire_BotStrafeChance > CFOption_BotStrafeChanceMAX)
        ? CFOption_BotStrafeChanceMIN
        : g_Crossfire_BotStrafeChance;
    } else if (StrEqual(buffer, "weapons")) {
      g_Crossfire_BotWeapons++;
      g_Crossfire_BotWeapons = (g_Crossfire_BotWeapons > CFOption_BotWeaponsMAX)
        ? CFOption_BotWeaponsMIN
        : g_Crossfire_BotWeapons;
    } else if (StrEqual(buffer, "maxsimbots")) {
      g_Crossfire_MaxSimBots++;
      g_Crossfire_MaxSimBots = (g_Crossfire_MaxSimBots > CFOption_MaxSimBotsMAX)
        ? CFOption_MaxSimBotsMIN
        : g_Crossfire_MaxSimBots;
    } else if (StrEqual(buffer, "reacttime")) {
      g_Crossfire_BotReactTime += 30;
      g_Crossfire_BotReactTime = (g_Crossfire_BotReactTime > CFOption_BotReactTimeMAX)
        ? CFOption_BotReactTimeMIN
        : g_Crossfire_BotReactTime;
    } else if (StrEqual(buffer, "botdelay")) {
      g_Crossfire_BotStartDelay += 50;
      g_Crossfire_BotStartDelay = (g_Crossfire_BotStartDelay > CFOption_BotStartDelayMAX)
        ? CFOption_BotStartDelayMIN
        : g_Crossfire_BotStartDelay;
    } else if (StrEqual(buffer, "botsattack")) {
      g_Crossfire_BotsAttack = !g_Crossfire_BotsAttack;
    } else if (StrEqual(buffer, "botsflash")) {
      g_Crossfire_BotsFlash = !g_Crossfire_BotsFlash;
    } else if (StrEqual(buffer, "back")) {
      CrossfiresSetupMenu(client);
      return 0;
    } else if (StrEqual(buffer, "exit")) {
      return 0;
    }
    CrossfireOptionsMenu(client);
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    CrossfiresSetupMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public void CrossfiresEditorMenu(int client) {
  strcopy(g_Crossfire_SelectedId, OPTION_ID_LENGTH, "-1");
  UpdateHoloCFireEnts();
  Menu menu = new Menu(CrossfiresEditorMenuHandler);
  menu.SetTitle("Editar Zonas de Crossfire: ");
  menu.AddItem("add_new", "Añadir Nueva Zona");
  char id[OPTION_ID_LENGTH];
  char name[OPTION_NAME_LENGTH];
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
    char buffer[OPTION_ID_LENGTH + 1];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "add_new")) {
      g_Crossfire_WaitForSave[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre del crossfire a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
    } else if (StrEqual(buffer, "exit_edit")) {
      PM_Message(client, "{ORANGE}Modo Edición Desactivado.");
      RemoveHoloCFireEnts();
    } else {
      strcopy(g_Crossfire_SelectedId, OPTION_ID_LENGTH, buffer);
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
  char crossfireName[OPTION_NAME_LENGTH];
  GetCrossfireName(g_Crossfire_SelectedId, crossfireName, OPTION_NAME_LENGTH);
  menu.SetTitle("Editor de Crossfire: %s (id %s)", crossfireName, g_Crossfire_SelectedId);
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
      CrossfireSpawnsEditorMenu(client, "bot");
    } else if (StrEqual(buffer, "edit_players")) {
      CrossfireSpawnsEditorMenu(client, "player");
    } else if (StrEqual(buffer, "edit_grenades")) {
      CrossfireGrenadesEditorMenu(client);
    } else if (StrEqual(buffer, "delete")) {
      char crossfireName[OPTION_NAME_LENGTH];
      GetCrossfireName(g_Crossfire_SelectedId, crossfireName, OPTION_NAME_LENGTH);
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

  char spawn_id[OPTION_ID_LENGTH];
  char spawn_display[OPTION_NAME_LENGTH];
  if (g_CrossfiresKv.JumpToKey(g_Crossfire_SelectedId)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.GotoFirstSubKey()) {
        do {
          g_CrossfiresKv.GetSectionName(spawn_id, sizeof(spawn_id));
          Format(spawn_display, OPTION_NAME_LENGTH, "Spawn %s %s", spawnType, spawn_id);
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
      char nextSpawnId[OPTION_ID_LENGTH];
      GetCrossfireSpawnsNextId(g_Crossfire_SelectedId, SelectedCrossfireInfo[3], nextSpawnId, OPTION_ID_LENGTH);
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
    GetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, spawnType, spawnId, "origin", fOrigin);
    GetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, spawnType, spawnId, "angles", fAngles);
    if (!VecEqual(fOrigin, ZERO_VECTOR)) {
      TeleportEntity(client, fOrigin, fAngles, ZERO_VECTOR);
    }
  }

  if (StrEqual(spawnType, "player")) {
    menu.AddItem("vecmin", "(Zona) Mover Primer Punto");
    menu.AddItem("vecmax", "(Zona) Mover Segundo Punto");
  } else {
    menu.AddItem("maxorigin", "Mover Linea de Desplazamiento");
  }

  menu.AddItem("delete", "Eliminar Spawn");

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int CrossfireSpawnEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  char SelectedSpawnInfo[4][OPTION_ID_LENGTH];
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
      SetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "origin", fOrigin);
      SetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "angles", fAngles);
      // PM_Message(client, "{ORANGE}%s Spawn {GREEN}%s {ORANGE}actualizado.", SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
    } else if (StrEqual(buffer, "delete")) {
      DeleteCrossfireSpawn(g_Crossfire_SelectedId, SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
      PM_Message(client, "{ORANGE}%s Spawn {GREEN}%s {ORANGE}eliminado.", SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
      CrossfireSpawnsEditorMenu(client, SelectedSpawnInfo[1]);
      return 0;
    } else {
      GetClientAbsOrigin(client, fOrigin);
      if (StrEqual(buffer, "vecmin")) {
        SetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "vecmin", fOrigin);
      } else if (StrEqual(buffer, "vecmax")) {
        SetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "vecmax", fOrigin);
      } else if (StrEqual(buffer, "maxorigin")) {
        SetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "maxorigin", fOrigin);
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

  char spawn_id[OPTION_ID_LENGTH];
  char spawn_display[OPTION_NAME_LENGTH];
  if (g_CrossfiresKv.JumpToKey(g_Crossfire_SelectedId)) {
    if (g_CrossfiresKv.JumpToKey("grenade")) {
      if (g_CrossfiresKv.GotoFirstSubKey()) {
        do {
          g_CrossfiresKv.GetSectionName(spawn_id, sizeof(spawn_id));
          char grenadeType[OPTION_NAME_LENGTH];
          g_CrossfiresKv.GetString("type", grenadeType, OPTION_NAME_LENGTH);
          UpperString(grenadeType);
          Format(spawn_display, OPTION_NAME_LENGTH, "Granada %s[%s]", spawn_id, grenadeType);
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
      char nextSpawnId[OPTION_ID_LENGTH];
      GetCrossfireSpawnsNextId(g_Crossfire_SelectedId, "grenade", nextSpawnId, OPTION_ID_LENGTH);
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
    char SelectedSpawnInfo[3][OPTION_ID_LENGTH];
    ExplodeString(title, " ", SelectedSpawnInfo, sizeof(SelectedSpawnInfo), sizeof(SelectedSpawnInfo[]));
    // spawnid = SelectedSpawnInfo[2]
    if (StrEqual(buffer, "updatenade")) {
      if (g_Nade_LastType[client] != GrenadeType_None) {
        char grenadeTypeString[128];
        GrenadeTypeString(g_Nade_LastType[client], grenadeTypeString, sizeof(grenadeTypeString));
        SetCrossfireSpawnStringKV(g_Crossfire_SelectedId, "grenade", SelectedSpawnInfo[2], "type", grenadeTypeString);
        SetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, "grenade", SelectedSpawnInfo[2], "origin", g_Nade_LastOrigin[client]);
        SetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, "grenade", SelectedSpawnInfo[2], "velocity", g_Nade_LastVelocity[client]);
        g_Nade_LastType[client] = GrenadeType_None;
        PM_Message(client, "{ORANGE}Spawn de Granada {GREEN}%s {ORANGE}actualizado.", SelectedSpawnInfo[2]);
      } else {
        PM_Message(client, "{ORANGE}Granada no Válida. Tira una Granada Primero");
      }
    } else if (StrEqual(buffer, "updatetrigger")) {
      // edit last trigger
      PM_Message(client, "{LIGHT_RED}main->CrossfireGrenadeSpawnEditorMenu->verticeEditor = null");
    } else if (StrEqual(buffer, "throw")) {
      float grenadeOrigin[3], grenadeVelocity[3];
      char grenadeTypeString[128];
      GetCrossfireSpawnStringKV(g_Crossfire_SelectedId, "grenade", SelectedSpawnInfo[2], "type", grenadeTypeString, sizeof(grenadeTypeString));
      GrenadeType grenadeType = GrenadeTypeFromString(grenadeTypeString);
      if (grenadeType != GrenadeType_None) {
        GetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, "grenade", SelectedSpawnInfo[2], "origin", grenadeOrigin);
        GetCrossfireSpawnVectorKV(g_Crossfire_SelectedId, "grenade", SelectedSpawnInfo[2], "velocity", grenadeVelocity);
        PM_ThrowGrenade(client, grenadeType, grenadeOrigin, grenadeVelocity);
      } else {
        PM_Message(client, "{ORANGE}Granada no Válida. Tira una Granada Primero");
      }
    } else if (StrEqual(buffer, "delete")) {
      PM_Message(client, "{ORANGE}Spawn de Granada {GREEN}%s {ORANGE}eliminado.", SelectedSpawnInfo[2]);
      DeleteCrossfireSpawn(g_Crossfire_SelectedId, "grenade", SelectedSpawnInfo[2]);
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
  char crossfireName[OPTION_NAME_LENGTH];
  GetCrossfireName(g_Crossfire_SelectedId, crossfireName, sizeof(crossfireName));

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
      char crossfireName[OPTION_NAME_LENGTH];
      GetCrossfireName(g_Crossfire_SelectedId, crossfireName, sizeof(crossfireName));
      DeleteCrossfire(g_Crossfire_SelectedId);
      PM_MessageToAll("{ORANGE}Zona {GREEN}%s {ORANGE}eliminada.", crossfireName);
      CrossfiresEditorMenu(client);
    } else {
      SingleCrossfireEditorMenu(client);
    }
  }
  return 0;
}


/*******************************************************************/
/********************* Events, Forwards, Hooks *********************/
/*******************************************************************/

public void Crossfires_MapStart() {
  PrecacheSound("ui/achievement_earned.wav");
  PrecacheSound("ui/armsrace_demoted.wav");
  delete g_CrossfiresKv;
  g_CrossfiresKv = new KeyValues("Crossfires");
  // g_CrossfiresKv.SetEscapeSequences(true); // Avoid fatals from special chars in user data

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  char crossfiresFile[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, crossfiresFile, sizeof(crossfiresFile),
            "data/practicemode/crossfires/%s.cfg", map);
  g_CrossfiresKv.ImportFromFile(crossfiresFile);
}

public void Crossfires_MapEnd() {
  char dir[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, dir, sizeof(dir), "data/practicemode/crossfires");
  if (!DirExists(dir)) {
    if (!CreateDirectory(dir, 511))
      PrintToServer("[Crossfires_MapEnd]Failed to create directory %s", dir);
  }

  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  char path[PLATFORM_MAX_PATH];
  Format(path, sizeof(path), "%s/%s.cfg", dir, mapName);

  DeleteFile(path);
  if (!g_CrossfiresKv.ExportToFile(path)) {
    PrintToServer("[Crossfires_MapEnd]Failed to write spawn names to %s", path);
  }
  RemoveHoloCFireEnts();
}

public void Crossfire_PluginStart() {
  g_Crossfire_HoloEnts = new ArrayList();
  g_Crossfire_Players = new ArrayList();
  g_Crossfire_Bots = new ArrayList();
  g_Crossfire_Arenas = new ArrayList();

  g_Crossfire_MaxBotsCvar = CreateConVar("sm_crossfire_max_bots", "8",
                              "How many crossfire bots spawn at max.", 0, true, 1.0, true, 10.0);
  g_Crossfire_MaxPlayersCvar = CreateConVar("sm_crossfire_max_players", "2",
                              "How many crossfire players spawn at max.", 0, true, 1.0, true, 3.0);
  g_Crossfire_BotAttackTimeCvar = CreateConVar("sm_crossfire_attack_time", "30",
                              "How much ticks until bot stops shooting.", 0, true, 0.0, true, 100.0);
}

public void Crossfire_ClientDisconnect(int client) {
  g_Crossfire_WaitForSave[client] = false;
  g_CrossFire_SpawnOrigin[client] = ZERO_VECTOR;
  g_CrossFire_MaxOrigin[client] = ZERO_VECTOR;
  g_Crossfire_Players_Points[client] = 0;
  g_Crossfire_Players_Room[client] = -1;
  g_Crossfire_PlayerWeapon[client] = "-1";
  g_Crossfire_StartTime[client] = CFOption_BotStartDelayMIN;
  g_Crossfire_Time[client] = 0;
  g_Crossfire_AllowedToAttack[client] = false;
  g_Crossfire_Ducking[client] = false;
  g_Crossfire_Strafe[client] = false;
  g_Crossfire_StrafeHoldTime[client] = 0;
  g_Crossfire_Seen[client] = false;
  g_Crossfire_SeenTime[client] = 0;
  g_Crossfire_SeenTotalTime[client] = 0;
  g_Crossfire_Moving[client] = false;
}

public void CrossfireRoom_OnStartTouch(int entity, int client) {
  if (!IsValidClient(client))
    return;

}

public void CrossfireRoom_OnEndTouch(int entity, int client) {
  if (!IsValidClient(client))
    return;
  float fVel[3];
  Entity_GetAbsVelocity(client, fVel);
  fVel[0] = fVel[0] * -2.0;
  fVel[1] = fVel[1] * -2.0;
  TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
}

// TODO: Use Timer for calculating the closest player, store it in global -> g_crossfireBotTarget[bot] = me
public Action CrossfireBot_PlayerRunCmd(int client, int &buttons, float vel[3], float angles[3], int &weapon) {
  if (!g_InCrossfireMode || !g_Crossfire_PlayersReady) {
    return Plugin_Continue;
  }

  if (!IsPlayerAlive(client)) {
    return Plugin_Continue;
  }

  float m_bData = GetEntPropFloat(client, Prop_Data, "m_flDuckSpeed");
  if (m_bData < 7.0) {
    SetEntPropFloat(client, Prop_Send, "m_flDuckSpeed", 7.0, 0);
  }

  // always look at closest player (otherwise bot overrides its angles(maybe create global variable and update that through timer function?))
  int nearestTarget = -1;
  int nearestNonVisibleTarget = -1;

  float nearestDistance = -1.0;
  float distance;
  for (int i = 0; i < g_Crossfire_Players.Length; i++) {
    int target = g_Crossfire_Players.Get(i);
    if (IsPlayer(target)) {
      if (!IsPlayerAlive(target)) {
        continue;
      }
      distance = Entity_GetDistance(client, target);
      if (distance > nearestDistance && nearestDistance > -1.0) {
        continue;
      }
      if (!IsAbleToSee(client, target, 0.9)) {
        // if (distance < 1000.0) {
        nearestNonVisibleTarget = target;
        // }
        continue;
      }
      nearestDistance = distance;
      nearestTarget = target;
    }
  }

  // Movement And Attack Logic

  // ONLY 2 BOTS EXECUTE THIS LOGIC AT MAX <- set to cvar ? Make this Logic inside player_death event with global true var
  // 1) Bot Wait Random Time
  // 2) Bot moves towards g_CrossFire_MaxOrigin[client]
  // 3) Player can see the bot, g_Crossfire_Strafe[client] = 1(randomInt)
  // 4) Bot moves back to SpawnOrigin, g_Crossfire_StrafeHoldTime[client] = 14(randomInt)
  // 5) Player can't see the bot, 14 ticks has passed
  // 6) Bot moves towards g_CrossFire_MaxOrigin[client]
  // 7) Player can see the bot, g_Crossfire_Strafe[client] = 0(randomInt)
  // 8) Bot gets to g_CrossFire_MaxOrigin[client], g_Crossfire_Ducking[client] = 1(randomInt)
  // 9) Bot crouches and starts shooting

  if (g_Crossfire_Moving[client]) {
    if (g_Crossfire_StartTime[client] > 0) {
      if (g_Crossfire_Time[client] == g_Crossfire_StartTime[client]) {
        g_Crossfire_Time[client] = 0;
        g_Crossfire_StartTime[client] = -1;
      } else {
        // Still havent Waited Random Time (STEP 1)
        g_Crossfire_Time[client]++;
      }
    } else {
      // Officially started, g_Crossfire_Time[client] should be 0
      if (g_Crossfire_Time[client] == 0) {
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR); // dont move him
      } else if (g_Crossfire_Time[client] > 0) {
        float clientOrigin[3];
        GetClientAbsOrigin(client, clientOrigin);
        if (nearestTarget > 0) {
          if (!g_Crossfire_Seen[client]) {
            // Player started to see the bot (STEP 3)
            g_Crossfire_SeenTotalTime[client]++;
            if (g_Crossfire_SeenTotalTime[client] < 10) {
              // PrintToChatAll("[%N]: player started seeing me, ignore!", client);
            } else {
              g_Crossfire_SeenTotalTime[client] = 0;
              g_Crossfire_Seen[client] = true;
              g_Crossfire_SeenTime[client] = g_Crossfire_Time[client];
              g_Crossfire_Strafe[client] = (GetRandomInt(1, 3*(CFOption_BotStrafeChanceMAX+1) + 3) <= (3*g_Crossfire_BotStrafeChance));
              // if (g_Crossfire_Strafe[client]) PrintToChatAll("[%N]: player finished seeing me, coming back to spawn!", client);
              // else PrintToChatAll("[%N]: player finished seeing me, peeking him!", client);
              g_Crossfire_StrafeHoldTime[client] = GetRandomInt(0, 50);
            }
          } else {
            // Player seeing The Bot
            // Move back to SpawnOrigin (STEP 4)
            if (g_Crossfire_Strafe[client]) {
              if (GetVectorDistance(clientOrigin, g_CrossFire_SpawnOrigin[client]) > 5.0) {
                // PrintToChatAll("[%N]: moving back to spawn!", client);
                // Go to Spawn Origin
                SubtractVectors(g_CrossFire_SpawnOrigin[client], clientOrigin, clientOrigin);
                NormalizeVector(clientOrigin, clientOrigin);
                ScaleVector(clientOrigin, 250.0);
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientOrigin);
              } else {
                // PrintToChatAll("[%N]: errorspawn!", client);
                // Bot Reached spawnOrigin while player can see him <- this shouldnt happen?
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
              }
            } else {
              // Player can see bot, but he wont strafe (STEP 7)
              if (GetVectorDistance(clientOrigin, g_CrossFire_MaxOrigin[client]) > 5.0) {
                // PrintToChatAll("[%N]: moving to maxorigin!", client);
                // Go to maxOrigin
                SubtractVectors(g_CrossFire_MaxOrigin[client], clientOrigin, clientOrigin);
                NormalizeVector(clientOrigin, clientOrigin);
                ScaleVector(clientOrigin, 250.0);
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientOrigin);
              } else {
                // Bot gets to maxorigin (STEP 8)
                float playerPos[3];
                GetClientEyePosition(nearestTarget, playerPos);
                float crouchPos[3];
                crouchPos = g_CrossFire_MaxOrigin[client];
                crouchPos[2] += 48.0;
                g_Crossfire_Ducking[client] = !GetRandomInt(0, 1) && IsPointVisible(playerPos, crouchPos);
                // Get To The Next Sequence
                g_Crossfire_Moving[client] = false;
                g_Crossfire_AllowedToAttack[client] = true;
                g_Crossfire_Time[client] = 0;
              }
            }
          }
        } else {
          // Player Saw Bot but now doesnt, He Is Hiding|Holding, dont do anything, let time pass
          if (g_Crossfire_Seen[client] && (g_Crossfire_Time[client] - g_Crossfire_SeenTime[client]) <= g_Crossfire_StrafeHoldTime[client]) {
            // PrintToChatAll("[%N]: Im hiding until time pass!", client);
          } else {
            // If Time passed (STEP 5)
            if (g_Crossfire_Seen[client]) {
              // PrintToChatAll("[%N]: Time passed, I can try peek now!", client);
              g_Crossfire_Seen[client] = false;
            } else {
              // Move towards to maxOrigin (STEP 2 & STEP 6)
              if (GetVectorDistance(clientOrigin, g_CrossFire_MaxOrigin[client]) > 5.0) {
                SubtractVectors(g_CrossFire_MaxOrigin[client], clientOrigin, clientOrigin);
                NormalizeVector(clientOrigin, clientOrigin);
                ScaleVector(clientOrigin, 250.0);
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clientOrigin);
              } else {
                // PrintToChatAll("[%N]: errormaxorigin", client);
                // Bot Reached maxOrigin while player Cant see him <- this shouldnt happen?
                TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, ZERO_VECTOR);
              }
            }
          }
        }
      }
      g_Crossfire_Time[client]++;
    }
  } else if (g_Crossfire_AllowedToAttack[client]) {
    // Should Attack
    if (g_Crossfire_Ducking[client]) buttons |= IN_DUCK;
    if (nearestTarget > 0) {
      if (g_Crossfire_Time[client] >= g_Crossfire_BotReactTime &&
      g_Crossfire_Time[client] <= (g_Crossfire_BotReactTime+g_Crossfire_BotAttackTimeCvar.IntValue)) {
        // Has a Target
        if (g_Crossfire_Time[client] == g_Crossfire_BotReactTime) {
          if (g_Crossfire_BotWeapons == 5 && !GetEntProp(client, Prop_Send, "m_bIsScoped")) {
            // zoom
            buttons |= IN_ATTACK2;
          }
        }
        if (g_Crossfire_BotsAttack) buttons |= IN_ATTACK;
        if (g_Crossfire_Time[client] == (g_Crossfire_BotReactTime+g_Crossfire_BotAttackTimeCvar.IntValue)) {
          // Reset Shooting time
          buttons &= ~IN_ATTACK;
          // g_Crossfire_Ducking[client] = GetRandomInt(0, 1); CROUCH | STAND WHILE SHOOTING
          g_Crossfire_Time[client] = 0;
        } else {
          g_Crossfire_Time[client]++;
        }
      }
      g_Crossfire_Time[client]++;
    } else {
      g_Crossfire_Time[client] = 0;
    }
  }

  if (nearestTarget > 0) {
    float clientEyepos[3], viewTarget[3];
    GetClientEyePosition(client, clientEyepos);
    GetClientEyePosition(nearestTarget, viewTarget);
    viewTarget[2] -= 0.0; // headshot or bodyshot(30.0) ?
    SubtractVectors(viewTarget, clientEyepos, viewTarget);
    GetVectorAngles(viewTarget, viewTarget);
    TeleportEntity(client, NULL_VECTOR, viewTarget, NULL_VECTOR);
  } else if (nearestNonVisibleTarget > 0) {
    float clientEyepos[3], viewTarget[3];
    GetClientEyePosition(client, clientEyepos);
    GetClientEyePosition(nearestNonVisibleTarget, viewTarget);
    SubtractVectors(viewTarget, clientEyepos, viewTarget);
    GetVectorAngles(viewTarget, viewTarget);
    viewTarget[2] -= 3.0; //headshot
    TeleportEntity(client, NULL_VECTOR, viewTarget, NULL_VECTOR);
  }

  return Plugin_Continue;
}

public Action Event_CrossfireBot_Death(int victim, Event event, const char[] name, bool dontBroadcast) {
  // TODO: Respawn in next pos?
  int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
  if (!IsValidClient(killer) || killer == victim) {
    return Plugin_Continue;
  }
  int index = -1;
  if((index = g_Crossfire_Bots.FindValue(victim)) != -1) {
    int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
    CreateTimer(0.5, Timer_RemoveRagdoll, EntIndexToEntRef(ragdoll), TIMER_FLAG_NO_MAPCHANGE);
    g_Crossfire_Time[index] = 0;
    if (g_Crossfire_Players.FindValue(killer) != -1) {
      g_Crossfire_Players_Points[killer] += 5; // 5 points per kill
    }
    g_Crossfire_Bots.Erase(index);
  }
  if (g_Crossfire_Moving[victim] || g_Crossfire_AllowedToAttack[victim]) {
    // he was an active bot, send the next one
    g_Crossfire_Moving[victim] = false;
    g_Crossfire_AllowedToAttack[victim] = false;
    for (int i = 0; i < g_Crossfire_Bots.Length; i++) {
      int bot = g_Crossfire_Bots.Get(i);
      if (!g_Crossfire_Moving[bot] && !g_Crossfire_AllowedToAttack[bot]) {
        g_Crossfire_Moving[bot] = true;
        break;
      }
    }
  }
  if (g_Crossfire_Bots.Length == 0) {
    EndSingleCrossfire(true);
  }
  return Plugin_Continue;
}

/*******************************************************************/
/*******************************************************************/

/****************************** Misc *******************************/
/*******************************************************************/

public void UpdateHoloCFireEnts() {
  RemoveHoloCFireEnts();
  CreateHoloCFireEnts();
}

public void RemoveHoloCFireEnts() {
  int ent;
  for (int i = g_Crossfire_HoloEnts.Length - 1; i >= 0; i--) {
    ent = g_Crossfire_HoloEnts.Get(i);
    if (IsValidEntity(ent)) {
      AcceptEntityInput(ent, "Kill");
    }
  }
  g_Crossfire_HoloEnts.Clear();
}

public void CreateHoloCFireEnts() {
  if (!StrEqual(g_Crossfire_SelectedId, "-1")) {
    // Show Only Selected
    if (g_CrossfiresKv.JumpToKey(g_Crossfire_SelectedId)) {
      if (g_CrossfiresKv.GotoFirstSubKey()) {
          do {
            char spawnType[OPTION_ID_LENGTH];
            g_CrossfiresKv.GetSectionName(spawnType, sizeof(spawnType));
            CreateHoloCrossfireEntity(spawnType, {0, 255, 0, 150});
          } while (g_CrossfiresKv.GotoNextKey());
          g_CrossfiresKv.GoBack();
        }
      g_CrossfiresKv.GoBack();
    }
  } else {
    // Show All Crossfires
    if (g_CrossfiresKv.GotoFirstSubKey()) {
      do {
        char crossfireId[OPTION_ID_LENGTH];
        g_CrossfiresKv.GetSectionName(crossfireId, sizeof(crossfireId));
        // g_CrossfiresKv.GetString("name", crossfirename, sizeof(crossfirename));
        int crossfireColor[4];
        GetRandomColor(crossfireColor, 150);
        if (g_CrossfiresKv.GotoFirstSubKey()) {
          do {
            char spawnType[OPTION_ID_LENGTH];
            g_CrossfiresKv.GetSectionName(spawnType, sizeof(spawnType));
            CreateHoloCrossfireEntity(spawnType, crossfireColor);
          } while (g_CrossfiresKv.GotoNextKey());
          g_CrossfiresKv.GoBack();
        }
      } while (g_CrossfiresKv.GotoNextKey());
      g_CrossfiresKv.GoBack();
    }
  }
}

public void CreateHoloCrossfireEntity(const char[] spawnType, int crossfireColor[4]) {
  if (g_CrossfiresKv.GotoFirstSubKey()) {
    do {
      char spawnid[OPTION_ID_LENGTH];
      g_CrossfiresKv.GetSectionName(spawnid, sizeof(spawnid));
      float origin[3], angles[3];
      g_CrossfiresKv.GetVector("origin", origin);
      g_CrossfiresKv.GetVector("angles", angles);
      CreateCrossfirePlayerEntity(spawnType, spawnid, origin, angles, crossfireColor);
    } while (g_CrossfiresKv.GotoNextKey());
    g_CrossfiresKv.GoBack();
  }
}

public void CreateCrossfirePlayerEntity(const char[] spawnType, const char[] spawnId, float origin[3], float angles[3], int color[4]) {
  //models/player/custom_player/legacy/tm_separatist_variantD.mdl <- tt
  //models/player/custom_player/legacy/ctm_sas.mdl <- ct
  int iEnt = CreateEntityByName("prop_dynamic_override");
  if (iEnt > 0) {
    DispatchKeyValue(iEnt, "classname", "prop_dynamic_override");
    if (StrEqual(spawnType, "bot")) {
      DispatchKeyValue(iEnt, "model", "models/player/custom_player/legacy/tm_separatist_variantD.mdl");
      SetEntityRenderColor(iEnt, color[0], color[1], color[2], color[3]);
      float maxOrigin[3];
      g_CrossfiresKv.GetVector("maxorigin", maxOrigin, origin);
      int beamEnt = CreateBeam(origin, maxOrigin);
      SetEntityRenderColor(beamEnt, color[0], color[1], color[2], color[3]);
      g_Crossfire_HoloEnts.Push(beamEnt);
    } else if (StrEqual(spawnType, "player")) {
      DispatchKeyValue(iEnt, "model", "models/player/custom_player/legacy/ctm_sas.mdl");
      SetEntityRenderColor(iEnt, color[0], color[1], 255, color[3]);
      float fMins[3], fMaxs[3];
      g_CrossfiresKv.GetVector("vecmin", fMins);
      g_CrossfiresKv.GetVector("vecmax", fMaxs);
      DataPack boxPack;
      CreateDataTimer(0.3, Timer_ShowBoxEntity, boxPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT)
      boxPack.WriteCell(iEnt);
      boxPack.WriteFloatArray(fMins, 3);
      boxPack.WriteFloatArray(fMaxs, 3);
    }
    DispatchKeyValue(iEnt, "spawnflags", "1"); 
    DispatchKeyValue(iEnt, "rendermode", "1");
    SetEntProp(iEnt, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(iEnt, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(iEnt, Prop_Send, "m_flGlowMaxDist", 1500.0);
    SetVariantColor(color);
    AcceptEntityInput(iEnt, "SetGlowColor");
    DispatchKeyValue(iEnt, "targetname", spawnId);
    if (DispatchSpawn(iEnt)) {
      angles[0] = 0.0; // look paralel to ground
      TeleportEntity(iEnt, origin, angles, NULL_VECTOR);
    }
    g_Crossfire_HoloEnts.Push(iEnt);
  }
}

public Action Timer_ShowBoxEntity(Handle timer, DataPack pack) {
  pack.Reset();
  int parent = pack.ReadCell();
  if (!IsValidEntity(parent)) {
    return Plugin_Stop;
  }
  float origin[3];
  Entity_GetAbsOrigin(parent, origin);
  float fMins[3], fMaxs[3];
  pack.ReadFloatArray(fMins, 3);
  pack.ReadFloatArray(fMaxs, 3);
  fMins[2] = fMaxs[2] = (origin[2] + 16.0);

  TE_SendBeamSquareToAll(fMins, fMaxs, g_PredictTrail, 0, 0, 0, 0.3, 1.5, 1.5, 0, 0.0, {0, 255, 0, 255}, 0);
  return Plugin_Continue;
}

stock void InitCrossfire(int client) {
  if (g_InCrossfireMode) {
    PM_Message(client, "{ORANGE}Crossfires Ya Activo.");
    return;
  }
  // Get Crossfires
  g_Crossfire_Arenas.Clear();
  int crossfireCount = GetCrossfiresNextId();
  if (crossfireCount > 0) {
    char iStr[OPTION_ID_LENGTH];
    for (int i = 0; i < crossfireCount; i++) {
      IntToString(i, iStr, OPTION_ID_LENGTH);
      g_Crossfire_Arenas.PushString(iStr);
    }
    // Random Crossfires
    SortADTArray(g_Crossfire_Arenas, Sort_Random, Sort_String);
  } else {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Zonas.");
    return;
  }
  // Setup First Crossfire
  g_Crossfire_Players.Clear();
  g_Crossfire_Players.Push(client);
  // Choose N random clients
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
      if (i == client) continue; // Already In ArrayList
      if (g_Crossfire_Players.Length < g_Crossfire_MaxPlayersCvar.IntValue) {
        g_Crossfire_Players.Push(i);
      } else {
        ChangeClientTeam(i, CS_TEAM_SPECTATOR);
      }
    }
  }
  PrintToServer("[RETAKES-LOG]%d jugadores conectados.", g_Crossfire_Players.Length);
  
  CS_TerminateRound(0.0, CSRoundEnd_Draw);
  StartSingleCrossfire(client, 0);
}

stock void StartSingleCrossfire(int client, int crossfirePos = 0) {
  ServerCommand("bot_kick");
  g_Crossfire_Bots.Clear();
  g_Crossfire_DeathPlayersCount = 0;
  g_Crossfire_Arenas.GetString(crossfirePos, g_Crossfire_ActiveId, OPTION_ID_LENGTH);
  char crossfireName[OPTION_NAME_LENGTH];
  GetCrossfireName(g_Crossfire_ActiveId, crossfireName, OPTION_NAME_LENGTH);
  PM_Message(client, "{ORANGE}Empezando Arena: {GREEN}%s", crossfireName);
  PrintToServer("[RETAKES-LOG]Empezando Arena: %s", crossfireName);

  // Spawn Zone Setup vecmins[3], vecmaxs[3]
  // CreateDataTimer(1.0, Timer_ShowCrossfireBoxEntity, pack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
  g_Crossfire_PlayersReady = false;
  CreateTimer(0.2, Timer_StartCrossfire, GetClientSerial(client));
}

public Action Timer_StartCrossfire(Handle timer, int serial) {
  for (int i = 0; i < g_Crossfire_Players.Length; i++) {
    int player = g_Crossfire_Players.Get(i);
    if (IsPlayer(player) && !IsPlayerAlive(player)) {
      CS_RespawnPlayer(player);
    }
  }
  // Get Bots
  char nextSpawn[OPTION_ID_LENGTH];
  GetCrossfireSpawnsNextId(g_Crossfire_ActiveId, "bot", nextSpawn, OPTION_ID_LENGTH);
  PrintToServer("[RETAKES-LOG]Cantidad de Bots: %s", nextSpawn);
  int botCount = StringToInt(nextSpawn);
  ArrayList enabledBots = new ArrayList(OPTION_ID_LENGTH);
  if (botCount > 0) {
    char iStr[OPTION_ID_LENGTH];
    for (int i = 0; i < botCount; i++) {
      IntToString(i, iStr, OPTION_ID_LENGTH);
      enabledBots.PushString(iStr);
    }
    // Random Spawns
    SortADTArray(enabledBots, Sort_Random, Sort_String);
    // Clamp if above max bots
    if (botCount > g_Crossfire_MaxBotsCvar.IntValue) {
      // Take first max bots
      for (int i = enabledBots.Length - 1; i >= g_Crossfire_MaxBotsCvar.IntValue; i--) {
        enabledBots.Erase(i);
      }
      botCount = g_Crossfire_MaxBotsCvar.IntValue;
    }
  } else {
    PrintToServer("[RETAKES-LOG]Error: No Existen Suficientes Spawns de Bots.");
    return Plugin_Handled;
  }

  // Bots Setup
  for (int i = 0; i < botCount; i++) {
    char randomSpawnId[OPTION_ID_LENGTH];
    enabledBots.GetString(i, randomSpawnId, OPTION_ID_LENGTH);
    ServerCommand("bot_quota_mode normal");
    ServerCommand("bot_add");
    DataPack pack;
    CreateDataTimer(0.2, Timer_GetCrossfireBots, pack);
    pack.WriteString(randomSpawnId);
  }

  delete enabledBots;

  // Get Players
  GetCrossfireSpawnsNextId(g_Crossfire_ActiveId, "player", nextSpawn, OPTION_ID_LENGTH);
  int playerCount = StringToInt(nextSpawn);
  ArrayList enabledPlayers = new ArrayList(OPTION_ID_LENGTH);
  if (playerCount > 0) {
    char iStr[OPTION_ID_LENGTH];
    for (int i = 0; i < playerCount; i++) {
      IntToString(i, iStr, OPTION_ID_LENGTH);
      enabledPlayers.PushString(iStr);
    }
    // Random Spawns
    SortADTArray(enabledPlayers, Sort_Random, Sort_String);
    // Clamp if above max players
    if (playerCount >= g_Crossfire_MaxPlayersCvar.IntValue) {
      // Take first max players
      for (int i = enabledPlayers.Length - 1; i >= g_Crossfire_MaxPlayersCvar.IntValue; i--) {
        enabledPlayers.Erase(i);
      }
      playerCount = g_Crossfire_MaxPlayersCvar.IntValue;
    }
  } else {
    PrintToServer("[RETAKES-LOG]Error: No Existen Suficientes Spawns de Jugadores.");
    return Plugin_Handled;
  }

  // More Players Than Available Spawns (I dont need the if but it reads better)
  if (g_Crossfire_Players.Length > enabledPlayers.Length) {
    for (int i = g_Crossfire_Players.Length; i > enabledPlayers.Length; i--) {
      int player = g_Crossfire_Players.Get(i);
      ChangeClientTeam(player, CS_TEAM_SPECTATOR);
      g_Crossfire_Players.Erase(i);
    }
  }
  // Players Setup
  for (int i = 0; i < g_Crossfire_Players.Length; i++) {
    char randomSpawnId[OPTION_ID_LENGTH];
    enabledPlayers.GetString(i, randomSpawnId, OPTION_ID_LENGTH);
    float origin[3], angles[3], vecmin[3], vecmax[3];
    GetCrossfireSpawnVectorKV(g_Crossfire_ActiveId, "player", randomSpawnId, "origin", origin);
    GetCrossfireSpawnVectorKV(g_Crossfire_ActiveId, "player", randomSpawnId, "angles", angles);
    GetCrossfireSpawnVectorKV(g_Crossfire_ActiveId, "player", randomSpawnId, "vecmin", vecmin);
    GetCrossfireSpawnVectorKV(g_Crossfire_ActiveId, "player", randomSpawnId, "vecmax", vecmax);
    PrintToServer("[RETAKES-LOG] Teleporting Client to [%f, %f, %f] with angles: [%f, %f]",
      origin[0], origin[1], origin[2], angles[0], angles[1]);
    int player = g_Crossfire_Players.Get(i);
    g_Crossfire_Players_Room[player] = CreateCrossFireRoomEntity(player, vecmin, vecmax);
    ChangeClientTeam(player, CS_TEAM_CT);
    TeleportEntity(player, origin, angles, ZERO_VECTOR);
    Client_GiveWeapon(player, g_Crossfire_PlayerWeapon[player]);
    // int weaponIndex = Client_GiveWeapon(player, g_Crossfire_PlayerWeapon[player]);
    // if (IsValidEntity(weaponIndex)) {
    //   SetEntPropFloat(weaponIndex, Prop_Send, "m_flNextPrimaryAttack", 9999.0);
    // }
    SetEntityMoveType(player, MOVETYPE_NONE);
  }

  delete enabledPlayers;

  // Success
  SetCvarIntSafe("bot_stop", 1);
  SetCvarIntSafe("mp_radar_showall", 0);
  SetCvarIntSafe("sm_glow_pmbots", 0);
  SetCvarIntSafe("sv_infinite_ammo", 1);
  SetCvarIntSafe("sv_grenade_trajectory", 0);
  SetCvarIntSafe("sm_allow_noclip", 0);
  SetCvarIntSafe("mp_respawn_on_death_ct", 0);
  SetCvarIntSafe("mp_respawn_on_death_t", 0);
  SetCvarIntSafe("sv_showimpacts", 0);
  SetCvarIntSafe("sm_holo_spawns", 0);
  SetCvarIntSafe("sm_bot_collision", 1);

  // wait for setting in true
  g_Crossfire_Countdown = 3;
  g_Crossfire_CountdownHandle = CreateTimer(1.0, Crossfire_CountDown, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
  g_InCrossfireMode = true;
  return Plugin_Handled;
}

public Action Crossfire_CountDown(Handle timer, any data) {
  g_Crossfire_Countdown--;
  if(g_Crossfire_Countdown <= 0) {
    for (int i = 0; i < g_Crossfire_Players.Length; i++) {
      int player = g_Crossfire_Players.Get(i);
      if (IsPlayer(player)) {
        ClearSyncHud(player, HudSync);
        SetEntityMoveType(player, MOVETYPE_WALK);
        
        // char weaponName[128];
        // if (StrEqual(g_Crossfire_PlayerWeapon[player], "weapon_usp_silencer")) {
        //   strcopy(weaponName, sizeof(weaponName), "weapon_hkp2000");
        // } else {
        //   strcopy(weaponName, sizeof(weaponName), g_Crossfire_PlayerWeapon[player]);
        // }
        // int weaponIndex = Client_GetActiveWeapon(player); // Client_GetWeapon(player, weaponName);
        // if (IsValidEntity(weaponIndex)) {
        //   SetEntPropFloat(weaponIndex, Prop_Send, "m_flNextPrimaryAttack", -0.01);
        // }
      }
    }
    g_Crossfire_PlayersReady = true;
    if(g_Crossfire_CountdownHandle != INVALID_HANDLE) {
      KillTimer(g_Crossfire_CountdownHandle);
      g_Crossfire_CountdownHandle = INVALID_HANDLE;
    }
    return Plugin_Stop;
  }
  for (int i = 0; i < g_Crossfire_Players.Length; i++) {
    int player = g_Crossfire_Players.Get(i);
    if (IsPlayer(player)) {
      SetHudTextParams(-1.0, 0.45, 3.5, 64, 255, 64, 0, 1, 1.0, 0.1, 0.1);
      ShowSyncHudText(player, HudSync, "%d", g_Crossfire_Countdown);
    }
  }
  return Plugin_Continue;
}

public int CreateCrossFireRoomEntity(int client, float vecmin[3], float vecmax[3]) {
  int iEnt = CreateEntityByName("trigger_multiple");
  if (iEnt > 0) {
    DispatchKeyValue(iEnt, "spawnflags", "64");
    DispatchKeyValue(iEnt, "wait", "0");
    DispatchSpawn(iEnt);
    ActivateEntity(iEnt);
    float vecmiddle[3];
    SubtractVectors(vecmax, vecmin, vecmiddle);
    ScaleVector(vecmiddle, 0.5);
    AddVectors(vecmin, vecmiddle, vecmiddle);

    TeleportEntity(iEnt, vecmiddle, NULL_VECTOR, NULL_VECTOR);
    SetEntityModel(iEnt, "models/error.mdl");
    // Have the mins always be negative
    vecmin[0] = vecmin[0] - vecmiddle[0];
    if (vecmin[0] > 0.0)
      vecmin[0] *= -1.0;
    vecmin[1] = vecmin[1] - vecmiddle[1];
    if (vecmin[1] > 0.0)
      vecmin[1] *= -1.0;
    vecmin[2] = vecmin[2] - vecmiddle[2];
    if (vecmin[2] > 0.0)
      vecmin[2] *= -1.0;

    // And the maxs always be positive
    vecmax[0] = vecmax[0] - vecmiddle[0];
    if (vecmax[0] < 0.0)
      vecmax[0] *= -1.0;
    vecmax[1] = vecmax[1] - vecmiddle[1];
    if (vecmax[1] < 0.0)
      vecmax[1] *= -1.0;
    vecmax[2] = vecmax[2] - vecmiddle[2];
    if (vecmax[2] < 0.0)
      vecmax[2] *= -1.0;

    // Make it Higher
    vecmax[2] *= 10.0;
    SetEntPropVector(iEnt, Prop_Send, "m_vecMins", vecmin);
    SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", vecmax);
    SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_BBOX);
    Entity_SetCollisionGroup(iEnt, COLLISION_GROUP_DEBRIS);
    // SDKHook(iEnt, SDKHook_StartTouch, CrossfireRoom_OnStartTouch);
    SDKHook(iEnt, SDKHook_EndTouch, CrossfireRoom_OnEndTouch);
    DataPack boxPack;
    CreateDataTimer(0.3, Timer_ShowBoxEntity, boxPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT)
    boxPack.WriteCell(iEnt);
    boxPack.WriteFloatArray(vecmin, 3);
    boxPack.WriteFloatArray(vecmax, 3);
    return iEnt;
  }
  return -1;
}

public Action Timer_GetCrossfireBots(Handle timer, DataPack pack) {
  pack.Reset();
  char spawnId[OPTION_ID_LENGTH];
  pack.ReadString(spawnId, OPTION_ID_LENGTH);
  
  int bot = GetLiveBot(CS_TEAM_T);
  if (bot < 0) {
    return Plugin_Handled;
  }

  char name[MAX_NAME_LENGTH];
  GetClientName(bot, name, MAX_NAME_LENGTH);
  char crossfireName[OPTION_NAME_LENGTH];
  GetCrossfireName(g_Crossfire_ActiveId, crossfireName, OPTION_NAME_LENGTH);
  Format(name, MAX_NAME_LENGTH, "[%s] %s", name, crossfireName);
  SetClientName(bot, name);
  g_Is_CrossfireBot[bot] = true;
  g_Crossfire_Bots.Push(bot);

  // Weapons
  Client_RemoveAllWeapons(bot);
  switch(g_Crossfire_BotWeapons) {
    case 0: {
      GivePlayerItem(bot, "weapon_knife");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), false);
      Client_SetArmor(bot, 100);
    }
    case 1: {
      GivePlayerItem(bot, "weapon_glock");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case 2: {
      GivePlayerItem(bot, "weapon_mp9");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case 3: {
      GivePlayerItem(bot, "weapon_deagle");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case 4: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case 5: {
      GivePlayerItem(bot, "weapon_awp");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
  }

  // Setup Single Bot
  g_Crossfire_StartTime[bot] = g_Crossfire_BotStartDelay;
  g_Crossfire_Time[bot] = 0;
  g_Crossfire_Ducking[bot] = false;
  g_Crossfire_StrafeHoldTime[bot] = 0;
  g_Crossfire_Strafe[bot] = false;
  g_Crossfire_Seen[bot] = false;
  g_Crossfire_SeenTime[bot] = 0;
  g_Crossfire_SeenTotalTime[bot] = 0;
  g_Crossfire_Moving[bot] = false;
  g_Crossfire_AllowedToAttack[bot] = false;
  if (g_Crossfire_Bots.Length <= 2) { // TODO FIX PEDO CACA
    // 1st and 2nd will be able to move
    // PrintToChatAll("[%N]: Moving!", bot);
    g_Crossfire_Moving[bot] = true;
  }


  float botAngles[3];
  GetCrossfireSpawnVectorKV(g_Crossfire_ActiveId, "bot", spawnId, "origin", g_CrossFire_SpawnOrigin[bot]);
  GetCrossfireSpawnVectorKV(g_Crossfire_ActiveId, "bot", spawnId, "angles", botAngles); // not needed
  GetCrossfireSpawnVectorKV(g_Crossfire_ActiveId, "bot", spawnId, "maxorigin", g_CrossFire_MaxOrigin[bot]);
  TeleportEntity(bot, g_CrossFire_SpawnOrigin[bot], botAngles, ZERO_VECTOR);
  // SetEntPropFloat(bot, Prop_Data, "m_flLaggedMovementValue", 0.0);

  return Plugin_Handled;
}

public void EndSingleCrossfire(bool win) {
  char crossfireName[OPTION_NAME_LENGTH];
  GetCrossfireName(g_Crossfire_ActiveId, crossfireName, OPTION_NAME_LENGTH);
  for (int i = 0; i < g_Crossfire_Players.Length; i++) {
    int player = g_Crossfire_Players.Get(i);
    if (IsPlayer(player)) {
      if (IsValidEntity(g_Crossfire_Players_Room[player])) {
        AcceptEntityInput(g_Crossfire_Players_Room[player], "Kill");
        g_Crossfire_Players_Room[player] = -1;
      }
      EmitSoundToClient(player, (win) ? "ui/achievement_earned.wav" : "ui/armsrace_demoted.wav", _, _, SNDLEVEL_ROCKET);
      // PM_Message(player, "{ORANGE}Crossfire {PURPLE}%s {ORANGE} %s", crossfireName, (win) ? "Ganado" : "Perdido.");
    }
  }
  int client = g_Crossfire_Players.Get(0);
  if (IsPlayer(client)) {
    int currentCrossfireIndex = g_Crossfire_Arenas.FindString(g_Crossfire_ActiveId);
    if (win) {
      if (currentCrossfireIndex < g_Crossfire_Arenas.Length - 1) {
        // go to next crossfire
        currentCrossfireIndex++;
        StartSingleCrossfire(client, currentCrossfireIndex);
        return;
      }
    } else {
      StartSingleCrossfire(client, currentCrossfireIndex);
      return;
    }
  }
  // Finished last arena
  if (g_Crossfire_EndlessMode) {
    // Endless
    StartSingleCrossfire(client);
  } else {
    // Stop on Last Arena
    StopCrossfiresMode();
  }
  // ServerCommand("mp_restartgame 1");
}

public void StopCrossfiresMode() {
  ServerCommand("bot_kick");
  for (int i = 0; i < g_Crossfire_Players.Length; i++) {
    int player = g_Crossfire_Players.Get(i);
    if (IsPlayer(player)) {
      if (IsValidEntity(g_Crossfire_Players_Room[player])) {
        AcceptEntityInput(g_Crossfire_Players_Room[player], "Kill");
        g_Crossfire_Players_Room[player] = -1;
      }
      PM_Message(player, "{GREEN}===============================");
      PM_Message(player, "{ORANGE}end");
      PM_Message(player, "{GREEN}===============================");
    }
  }
  g_Crossfire_Players.Clear();
  g_Crossfire_Bots.Clear();
  g_Crossfire_Arenas.Clear();
  g_InCrossfireMode = false;
  
  SetCvarIntSafe("bot_stop", 0);
  SetConVarFloatSafe("mp_roundtime_defuse", 60.0);
  SetCvarIntSafe("mp_radar_showall", 1);
  SetCvarIntSafe("sm_glow_pmbots", 1);
  SetCvarIntSafe("sv_grenade_trajectory", 1);
  SetCvarIntSafe("sm_allow_noclip", 1);
  SetCvarIntSafe("mp_respawn_on_death_ct", 1);
  SetCvarIntSafe("mp_respawn_on_death_t", 1);
  SetCvarIntSafe("sv_showimpacts", 1);
  SetCvarIntSafe("sm_holo_spawns", 1);
  SetCvarIntSafe("sm_bot_collision", 0);
  CS_TerminateRound(0.0, CSRoundEnd_Draw);
}

/*******************************************************************/
/* Helpers */
/*******************************************************************/

public int GetCrossfiresNextId() {
  int largest = -1;
  char id[OPTION_ID_LENGTH];
  if (g_CrossfiresKv.GotoFirstSubKey()) {
    do {
      g_CrossfiresKv.GetSectionName(id, sizeof(id));
      int idvalue = StringToInt(id);
      if (idvalue > largest) {
        largest = idvalue;
      }
    } while (g_CrossfiresKv.GotoNextKey());
    g_CrossfiresKv.GoBack();
  }
  return largest + 1;
}

public void SetCrossfireName(const char[] id, const char[] newName) {
  g_Crossfire_UpdatedKv = true;
  if (g_CrossfiresKv.JumpToKey(id, true)) {
    g_CrossfiresKv.SetString("name", newName);
    g_CrossfiresKv.GoBack();
  }
  MaybeWriteNewCrossfireData();
}

public void GetCrossfireName(const char[] id, char[] buffer, int length) {
  if (g_CrossfiresKv.JumpToKey(id)) {
    g_CrossfiresKv.GetString("name", buffer, length);
    g_CrossfiresKv.GoBack();
  }
}

public void DeleteCrossfire(const char[] id) {
  if (g_CrossfiresKv.JumpToKey(id)) {
    g_Crossfire_UpdatedKv = true;
    g_CrossfiresKv.DeleteThis();
    g_CrossfiresKv.Rewind();
  }
  MaybeWriteNewCrossfireData();
}

public void DeleteCrossfireSpawn(const char[] crossfireid, const char[] spawnType, const char[] spawnid) {
  if (g_CrossfiresKv.JumpToKey(crossfireid)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.JumpToKey(spawnid)) {
        g_Crossfire_UpdatedKv = true;
        g_CrossfiresKv.DeleteThis();
      }
    }
  }
  g_CrossfiresKv.Rewind();
  MaybeWriteNewCrossfireData();
}

public void GetCrossfireSpawnsNextId(const char[] crossfireid, const char[] spawnType, char[] buffer, int size) {
  int largest = -1;
  char id[OPTION_ID_LENGTH];
  if (g_CrossfiresKv.JumpToKey(crossfireid)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.GotoFirstSubKey()) {
        do {
          g_CrossfiresKv.GetSectionName(id, sizeof(id));
          int idvalue = StringToInt(id);
          if (idvalue > largest) {
            largest = idvalue;
          }
        } while (g_CrossfiresKv.GotoNextKey());
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  IntToString(largest + 1, buffer, size);
}

public bool SetCrossfireSpawnVectorKV(const char[] crossfireid, const char[] spawnType, const char[] spawnid, const char[] key, const float value[3]) {
  g_Crossfire_UpdatedKv = true;
  bool ret = false;
  if (g_CrossfiresKv.JumpToKey(crossfireid, true)) {
    if (g_CrossfiresKv.JumpToKey(spawnType, true)) {
      if (g_CrossfiresKv.JumpToKey(spawnid, true)) {
        ret = true;
        g_CrossfiresKv.SetVector(key, value);
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  MaybeWriteNewCrossfireData();
  return ret;
}

public bool GetCrossfireSpawnVectorKV(const char[] crossfireid, const char[] spawnType, const char[] spawnid, const char[] key, float value[3]) {
  bool ret = false;
  if (g_CrossfiresKv.JumpToKey(crossfireid)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.JumpToKey(spawnid)) {
        g_CrossfiresKv.GetVector(key, value);
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  return ret;
}

public bool GetCrossfireSpawnStringKV(const char[] crossfireid, const char[] spawnType, const char[] spawnid, const char[] key, char[] buffer, int size) {
  bool ret = false;
  if (g_CrossfiresKv.JumpToKey(crossfireid)) {
    if (g_CrossfiresKv.JumpToKey(spawnType)) {
      if (g_CrossfiresKv.JumpToKey(spawnid)) {
        g_CrossfiresKv.GetString(key, buffer, size);
        ret = true;
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  return ret;
}

public bool SetCrossfireSpawnStringKV(const char[] crossfireid, const char[] spawnType, const char[] spawnid, const char[] key, const char[] value) {
  g_Crossfire_UpdatedKv = true;
  bool ret = false;
  if (g_CrossfiresKv.JumpToKey(crossfireid, true)) {
    if (g_CrossfiresKv.JumpToKey(spawnType, true)) {
      if (g_CrossfiresKv.JumpToKey(spawnid, true)) {
        g_CrossfiresKv.SetString(key, value);
        ret = true;
        g_CrossfiresKv.GoBack();
      }
      g_CrossfiresKv.GoBack();
    }
    g_CrossfiresKv.GoBack();
  }
  MaybeWriteNewCrossfireData();
  return ret;
}

public void MaybeWriteNewCrossfireData() {
  if (g_Crossfire_UpdatedKv) {
    g_CrossfiresKv.Rewind();
    BackupFiles("crossfires");
    char map[PLATFORM_MAX_PATH];
    GetCleanMapName(map, sizeof(map));
    char crossfireFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, crossfireFile, sizeof(crossfireFile), "data/practicemode/crossfires/%s.cfg", map);
    DeleteFile(crossfireFile);
    if (!g_CrossfiresKv.ExportToFile(crossfireFile)) {
      PrintToServer("[MaybeWriteNewCrossfireData]Failed to write crossfires to %s", crossfireFile);
    }
    g_Crossfire_UpdatedKv = false;
    UpdateHoloCFireEnts();
  }
}


stock TE_SendBeamSquareToAll(
  float bottomcorner[3],
  float uppercorner[3],
  int ModelIndex,
  int HaloIndex,
  int StartFrame,
  int FrameRate,
  float Life,
  float Width,
  float EndWidth,
  int FadeLength,
  float Amplitude,
  const Color[4],
  int Speed
) {
  // Create the additional corners of the square
  float tc1[3];
  tc1 = uppercorner;
  tc1[0] = bottomcorner[0];
  float tc2[3];
  tc2 = uppercorner;
  tc2[1] = bottomcorner[1];
  
  // Draw all the edges
  TE_SetupBeamPoints(uppercorner, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(tc1, bottomcorner, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(bottomcorner, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
  TE_SendToAll();
  TE_SetupBeamPoints(tc2, uppercorner, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
  TE_SendToAll();
}

public bool IsCrossfireBot(int client) {
  return client > 0 && g_Is_CrossfireBot[client] && IsClientInGame(client) && IsFakeClient(client);
}
