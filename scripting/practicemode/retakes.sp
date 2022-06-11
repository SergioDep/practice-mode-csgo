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
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Commands */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

public Action Command_RetakesSetupMenu(int client, int args) {
  if (!IsPlayer(client)) {
    return Plugin_Handled;
  }
  RetakesSetupMenu(client);
  return Plugin_Handled;
}

public Action Command_RetakesEditorMenu(int client, int args) {
  if (g_InRetakeMode) {
    PM_Message(client, "{ORANGE}Retake Ya Empezado.");
    return Plugin_Continue;
  }
  if (!IsRetakesEditor(client)) {
    PM_Message(client, "{ORANGE}No tienes permisos de editor.");
    return Plugin_Handled;
  }
  PM_Message(client, "{ORANGE}Modo Edición Activado.");
  RetakesEditorMenu(client);
  return Plugin_Handled;
}

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Menus */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

public void RetakesSetupMenu(int client) {
  Menu menu = new Menu(RetakesSetupMenuHandler);

  menu.SetTitle("Opciones De Retake");
  // menu.AddItem("togglerepeat", "Repetir: %");
  // menu.AddItem("togglerandom", "RandomWeapons: %");
  // menu.AddItem("togglezone", "");
  menu.AddItem("start", "Empezar Retakes");
  menu.AddItem("stop", "Salir de Retakes");
  menu.AddItem("edit", "Editar Retakes");
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int RetakesSetupMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if(action == MenuAction_Select) {
    char buffer[128];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "start")) {
      InitRetakes(client);
    } else if (StrEqual(buffer, "stop")) {
      StopRetakesMode();
    } else if (StrEqual(buffer, "edit")) {
      RetakesEditorMenu(client);
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

public void RetakesEditorMenu(int client) {
  if (!IsRetakesEditor(client)) {
    PM_Message(client, "No tienes permisos de editor.");
    return;
  }
  strcopy(g_SelectedRetakeId, OPTION_ID_LENGTH, "-1");
  UpdateHoloRetakeEntities();
  Menu menu = new Menu(RetakesEditorMenuHandler);
  menu.SetTitle("Editar Zonas de Retake: ");
  menu.AddItem("add_new", "Añadir Nueva Zona");
  char id[OPTION_ID_LENGTH];
  char name[OPTION_NAME_LENGTH];
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
    char buffer[OPTION_ID_LENGTH + 1];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "add_new")) {
      g_WaitForRetakeSave[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre del retake a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
    } else if (StrEqual(buffer, "exit_edit")) {
      PM_Message(client, "{ORANGE}Modo Edición Desactivado.");
      RemoveHoloRetakeEntities();
    } else {
      strcopy(g_SelectedRetakeId, OPTION_ID_LENGTH, buffer);
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
  char retakeName[OPTION_NAME_LENGTH];
  GetRetakeName(g_SelectedRetakeId, retakeName, OPTION_NAME_LENGTH);
  menu.SetTitle("Editor de Retake: %s (id %s)", retakeName, g_SelectedRetakeId);
  menu.AddItem("edit_enemies", "Editar Spawns de Bots");
  menu.AddItem("edit_players", "Editar Spawns de Jugadores");
  menu.AddItem("edit_bombs", "Editar Puntos de Plantar Bomba");
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
      RetakeSpawnsEditorMenu(client, "bot");
    } else if (StrEqual(buffer, "edit_players")) {
      RetakeSpawnsEditorMenu(client, "player");
    } else if (StrEqual(buffer, "edit_bombs")) {
      RetakeSpawnsEditorMenu(client, "bomb");
    } else if (StrEqual(buffer, "edit_grenades")) {
      RetakeGrenadesEditorMenu(client);
    } else if (StrEqual(buffer, "delete")) {
      char retakeName[OPTION_NAME_LENGTH];
      GetRetakeName(g_SelectedRetakeId, retakeName, OPTION_NAME_LENGTH);
      RetakeDeleteConfirmationMenu(client);
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    RetakesEditorMenu(client);
  }
  return 0;
}

public void RetakeSpawnsEditorMenu(int client, const char[] spawnType){
  Menu menu = new Menu(RetakeSpawnsEditorMenuHandler);
  menu.SetTitle("Editar Spawns Tipo %s", spawnType); //Bot || Player || Bomb
  menu.AddItem("add_new", "Añadir Nuevo Spawn");

  char spawn_id[OPTION_ID_LENGTH];
  char spawn_display[OPTION_NAME_LENGTH];
  if (g_RetakesKv.JumpToKey(g_SelectedRetakeId)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.GotoFirstSubKey()) {
        do {
          g_RetakesKv.GetSectionName(spawn_id, sizeof(spawn_id));
          Format(spawn_display, OPTION_NAME_LENGTH, "Spawn %s %s", spawnType, spawn_id);
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
    //Editar Spawns Tipo (Bot | Player | Bomb)
    if (StrEqual(buffer, "add_new")) {
      char nextSpawnId[OPTION_ID_LENGTH];
      GetRetakeSpawnsNextId(g_SelectedRetakeId, SelectedRetakeInfo[3], nextSpawnId, OPTION_ID_LENGTH);
      SpawnEditorMenu(client, SelectedRetakeInfo[3], nextSpawnId);
    } else {
      SpawnEditorMenu(client, SelectedRetakeInfo[3], buffer, true);
    }
  } else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) {
    SingleRetakeEditorMenu(client);
  }
  return 0;
}

stock void SpawnEditorMenu(int client, const char[] spawnType, char[] spawnId, bool teleport = false) {
  Menu menu = new Menu(SpawnEditorMenuHandler);
  // pass the id through the title, so i dont need more global variables
  menu.SetTitle("Editar %s Spawn %s", spawnType, spawnId);
  menu.AddItem("settomypos", "Mover Punto de Spawn a mi Posición");
  menu.AddItem("delete", "Eliminar Spawn");

  if (teleport) {
    float fOrigin[3], fAngles[3];
    GetRetakeSpawnVectorKV(g_SelectedRetakeId, spawnType, spawnId, "origin", fOrigin);
    GetRetakeSpawnVectorKV(g_SelectedRetakeId, spawnType, spawnId, "angles", fAngles);
    if (!VecEqual(fOrigin, ZERO_VECTOR)) {
      TeleportEntity(client, fOrigin, fAngles, ZERO_VECTOR);
    }
  }

  menu.ExitBackButton = true;
  menu.ExitButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

public int SpawnEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
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
    float fOrigin[3];
    if (StrEqual(buffer, "settomypos")) {
      float fAngles[3];
      GetClientAbsOrigin(client, fOrigin);
      GetClientEyeAngles(client, fAngles);
      SetRetakeSpawnVectorKV(g_SelectedRetakeId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "origin", fOrigin);
      SetRetakeSpawnVectorKV(g_SelectedRetakeId, SelectedSpawnInfo[1], SelectedSpawnInfo[3], "angles", fAngles);
      // PM_Message(client, "{ORANGE}%s Spawn {GREEN}%s {ORANGE}actualizado.", SelectedSpawnInfo[1], SelectedSpawnInfo[3]);
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

  char spawn_id[OPTION_ID_LENGTH];
  char spawn_display[OPTION_NAME_LENGTH];
  if (g_RetakesKv.JumpToKey(g_SelectedRetakeId)) {
    if (g_RetakesKv.JumpToKey("grenade")) {
      if (g_RetakesKv.GotoFirstSubKey()) {
        do {
          g_RetakesKv.GetSectionName(spawn_id, sizeof(spawn_id));
          char grenadeType[OPTION_NAME_LENGTH];
          g_RetakesKv.GetString("type", grenadeType, OPTION_NAME_LENGTH);
          UpperString(grenadeType);
          Format(spawn_display, OPTION_NAME_LENGTH, "Granada %s[%s]", spawn_id, grenadeType);
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
      char nextSpawnId[OPTION_ID_LENGTH];
      GetRetakeSpawnsNextId(g_SelectedRetakeId, "grenade", nextSpawnId, OPTION_ID_LENGTH);
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
    char SelectedSpawnInfo[3][OPTION_ID_LENGTH];
    ExplodeString(title, " ", SelectedSpawnInfo, sizeof(SelectedSpawnInfo), sizeof(SelectedSpawnInfo[]));
    // spawnid = SelectedSpawnInfo[2]
    if (StrEqual(buffer, "updatenade")) {
      if (g_CSUtilsLoaded) {
        if (IsGrenade(g_LastGrenadeType[client])) {
          char grenadeTypeString[128];
          GrenadeTypeString(g_LastGrenadeType[client], grenadeTypeString, sizeof(grenadeTypeString));
          SetRetakeSpawnStringKV(g_SelectedRetakeId, "grenade", SelectedSpawnInfo[2], "type", grenadeTypeString);
          SetRetakeSpawnVectorKV(g_SelectedRetakeId, "grenade", SelectedSpawnInfo[2], "origin", g_LastGrenadeOrigin[client]);
          SetRetakeSpawnVectorKV(g_SelectedRetakeId, "grenade", SelectedSpawnInfo[2], "velocity", g_LastGrenadeVelocity[client]);
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
      GetRetakeSpawnStringKV(g_SelectedRetakeId, "grenade", SelectedSpawnInfo[2], "type", grenadeTypeString, sizeof(grenadeTypeString));
      GrenadeType grenadeType = GrenadeTypeFromString(grenadeTypeString);
      if (IsGrenade(grenadeType)) {
        GetRetakeSpawnVectorKV(g_SelectedRetakeId, "grenade", SelectedSpawnInfo[2], "origin", grenadeOrigin);
        GetRetakeSpawnVectorKV(g_SelectedRetakeId, "grenade", SelectedSpawnInfo[2], "velocity", grenadeVelocity);
        CSU_ThrowGrenade(client, grenadeType, grenadeOrigin, grenadeVelocity);
      } else {
        PM_Message(client, "{ORANGE}Granada no Válida. Tira una Granada Primero");
      }
    } else if (StrEqual(buffer, "delete")) {
      PM_Message(client, "{ORANGE}Spawn de Granada {GREEN}%s {ORANGE}eliminado.", SelectedSpawnInfo[2]);
      DeleteRetakeSpawn(g_SelectedRetakeId, "grenade", SelectedSpawnInfo[2]);
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
  char retakeName[OPTION_NAME_LENGTH];
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
      char retakeName[OPTION_NAME_LENGTH];
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

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Events, Forwards, Hooks */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

public void Retakes_MapStart() {
  PrecacheSound("ui/achievement_earned.wav");
  PrecacheSound("ui/armsrace_demoted.wav");
  delete g_RetakesKv;
  g_RetakesKv = new KeyValues("Retakes");
  // g_RetakesKv.SetEscapeSequences(true); // Avoid fatals from special chars in user data

  char map[PLATFORM_MAX_PATH];
  GetCleanMapName(map, sizeof(map));

  char retakesFile[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, retakesFile, sizeof(retakesFile),
            "data/practicemode/retakes/%s.cfg", map);
  g_RetakesKv.ImportFromFile(retakesFile);
}

public void Retakes_MapEnd() {
  char dir[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, dir, sizeof(dir), "data/practicemode/retakes");
  if (!DirExists(dir)) {
    if (!CreateDirectory(dir, 511))
      PrintToServer("[Retakes]Failed to create directory %s", dir);
  }

  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  char path[PLATFORM_MAX_PATH];
  Format(path, sizeof(path), "%s/%s.cfg", dir, mapName);

  DeleteFile(path);
  if (!g_RetakesKv.ExportToFile(path)) {
    PrintToServer("[Retakes]Failed to write spawn names to %s", path);
  }
  RemoveHoloRetakeEntities();
}

public void Retakes_ClientDisconnect(int client) {
  g_RKBot_Time[client] = 0;
  g_RetakeBotDirection[client] = 0;
  g_RetakeBotDuck[client] = 0;
  // g_RetakeBotWalk[client] = 0;
  g_RetakePlayers_Points[client] = 0;
  g_WaitForRetakeSave[client] = false;
}

public void Retakes_PluginStart() {
  g_HoloRetakeEntities = new ArrayList();
  g_RetakeRetakes = new ArrayList();
  g_RetakePlayers = new ArrayList();
  g_RetakeBots = new ArrayList();

  bombTicking = FindSendPropInfo("CPlantedC4", "m_bBombTicking");

  g_MaxRetakeBotsCvar = CreateConVar("sm_retake_max_bots", "6",
                              "How many retake bots spawn at max.", 0, true, 1.0, true, 10.0);
  g_MaxRetakePlayersCvar = CreateConVar("sm_retake_max_players", "2",
                              "How many retake players spawn at max.", 0, true, 1.0, true, 3.0);
  g_RKBot_SpotMultCvar = CreateConVar("sm_retake_spot_mult", "1.1",
                              "Only for testing purposes.", 0, true, 1.0, true, 2.0);
  g_RKBot_ReactTimeCvar = CreateConVar("sm_retake_react_time", "80",
                              "How much ticks until bot starts shooting.", 0, true, 30.0, true, 150.0);
  g_RKBot_AttackTimeCvar = CreateConVar("sm_retake_attack_time", "30",
                              "How much ticks until bot stops shooting.", 0, true, 0.0, true, 100.0);
  g_RKBot_MoveDistanceCvar = CreateConVar("sm_retake_move_distance", "60",
                              "How much ticks will the bot move before shooting.", 0, true, 0.0, true, 150.0);

  HookEvent("bomb_planted", Event_BombPlant);
  HookEvent("bomb_exploded", Event_BombExplode);
  HookEvent("bomb_defused", Event_BombDefuse);
}

// TODO: Use Timer for calculating the closest player, store it in global -> g_retakeBotTarget[bot] = me
public Action RetakeBot_PlayerRunCmd(int client, int &buttons, float vel[3], float angles[3], int &weapon) {
  if (!g_InRetakeMode) {
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
  for (int i = 0; i < g_RetakePlayers.Length; i++) {
    int target = g_RetakePlayers.Get(i);
    if (IsPlayer(target)) {
      if (!IsPlayerAlive(target)) {
        continue;
      }
      distance = Entity_GetDistance(client, target);
      if (distance > nearestDistance && nearestDistance > -1.0) {
        continue;
      }
      if (!IsAbleToSee(client, target, g_RKBot_SpotMultCvar.FloatValue)) {
        if (distance < 500.0) {
          nearestNonVisibleTarget = -1; //target
        }
        continue;
      }
      // if (!ClientCanSeeClient(client, target)) {
      //   if (distance < 500.0) {
      //     nearestNonVisibleTarget = target;
      //   }
      //   continue;
      // }
      nearestDistance = distance;
      nearestTarget = target;
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
    // Strafe movement perpendicular to player->bot vector
    // bot will stop and attack every g_RKBot_ReactTimeCvar.IntValue frames
    if (g_RKBot_Time[client] >= g_RKBot_ReactTimeCvar.IntValue &&
        g_RKBot_Time[client] <= (g_RKBot_ReactTimeCvar.IntValue+g_RKBot_AttackTimeCvar.IntValue)) { // bot will attack for (2 + 1) frames
      vel[1] = 0.0;
      if (nearestTarget == -1 && nearestNonVisibleTarget > 0) {
        // doesnt see anybody but has a close target
      }
      buttons |= IN_ATTACK;
      // buttons &= ~IN_SPEED;
      if (g_RKBot_Time[client] == (g_RKBot_ReactTimeCvar.IntValue+g_RKBot_AttackTimeCvar.IntValue)) {
        g_RetakeBotDuck[client] = GetRandomInt(0, 1);
        g_RKBot_Time[client] = 0;
      }
      else g_RKBot_Time[client]++;
    } else {
      buttons &= ~IN_ATTACK;
      buttons &= ~IN_DUCK;
      // buttons &= ~IN_SPEED;
      if (g_RKBot_Time[client] == g_RKBot_ReactTimeCvar.IntValue - g_RKBot_MoveDistanceCvar.IntValue) { // the bot will be moving RKBOT_MOVEDISTANCE frames
        g_RetakeBotDirection[client] = GetRandomInt(0, 1);
        g_RetakeBotDuck[client] = GetRandomInt(0, 1);
        // g_RetakeBotWalk[client] = GetRandomInt(0, 1);
      } else {
        if (g_RKBot_Time[client] > g_RKBot_ReactTimeCvar.IntValue - g_RKBot_MoveDistanceCvar.IntValue) { // while the bot is moving
          if (g_RetakeBotDirection[client] == 1) vel[1] = 250.0;
          else vel[1] = -250.0;
          if (g_RetakeBotDuck[client] == 1) buttons |= IN_DUCK;

          // if (g_RetakeBotWalk[client]) buttons |= IN_SPEED;
          if (g_RKBot_Time[client] == g_RKBot_ReactTimeCvar.IntValue - g_RKBot_MoveDistanceCvar.IntValue + 5) { // just after the bot started moving to check if IS STUCK
            float fAbsVel[3];
            Entity_GetAbsVelocity(client, fAbsVel);
            if (GetVectorLength(fAbsVel) < 5.0) {
              // PrintToChatAll("block detected");
              // Jump to Attack Time ?
              // g_RKBot_Time[client] = g_RKBot_ReactTimeCvar.IntValue;
              // PrintToChatAll("direction changed from %d to %d", g_RetakeBotDirection[client], 1 - g_RetakeBotDirection[client]);
              g_RetakeBotDirection[client] = 1 - g_RetakeBotDirection[client];
            }
          }
        } else {
          // unknown status (bot is standing?)
        }
      }
      g_RKBot_Time[client]++;
    }
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

public Action Event_BombPlant(Event event, const char[] name, bool dontBroadcast) {
  // go to next retake

  return Plugin_Continue;
}

public Action Event_BombExplode(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InRetakeMode) {
    return Plugin_Continue;
  }
  EndSingleRetake(false);
  return Plugin_Continue;
}

public Action Event_BombDefuse(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InRetakeMode) {
    return Plugin_Continue;
  }
  EndSingleRetake(true);
  return Plugin_Continue;
}

public Action Event_Retakes_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  return Plugin_Continue;
}

// This Always get Executed when finished a Retake
public Action Event_Retakes_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  // EndSingleRetake();
  return Plugin_Continue;
}

public Action Event_RetakeBot_Death(int victim, Event event, const char[] name, bool dontBroadcast) {
  // TODO: Respawn in next pos?
  int killer = GetClientOfUserId(GetEventInt(event, "attacker"));
  if (!IsValidClient(killer) || killer == victim) {
    return Plugin_Continue;
  }
  int index = -1;
  if((index = g_RetakeBots.FindValue(victim)) != -1) {
    int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
    CreateTimer(0.5, Timer_RemoveRagdoll, EntIndexToEntRef(ragdoll), TIMER_FLAG_NO_MAPCHANGE);
    g_RKBot_Time[index] = 0;
    if (g_RetakePlayers.FindValue(killer) != -1) {
      g_RetakePlayers_Points[killer] += 5; // 5 points per kill
    }
    g_RetakeBots.Erase(index);
  }
  // if (g_RetakeBots.Length == 0) {
  //   // all bots are dead
  // }
  return Plugin_Continue;
}

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Misc */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/



public void UpdateHoloRetakeEntities() {
  RemoveHoloRetakeEntities();
  CreateHoloRetakeEntities();
}

public void RemoveHoloRetakeEntities() {
  int ent;
  for (int i = g_HoloRetakeEntities.Length - 1; i >= 0; i--) {
    ent = g_HoloRetakeEntities.Get(i);
    if (IsValidEntity(ent)) {
      AcceptEntityInput(ent, "Kill");
    }
  }
  g_HoloRetakeEntities.Clear();
}

public void CreateHoloRetakeEntities() {
  if (!StrEqual(g_SelectedRetakeId, "-1")) {
    // Show Only Selected
    if (g_RetakesKv.JumpToKey(g_SelectedRetakeId)) {
      if (g_RetakesKv.GotoFirstSubKey()) {
          do {
            char spawnType[OPTION_ID_LENGTH];
            g_RetakesKv.GetSectionName(spawnType, sizeof(spawnType));
            CreateHoloRetakeEntity(spawnType, {0, 255, 0, 150});
          } while (g_RetakesKv.GotoNextKey());
          g_RetakesKv.GoBack();
        }
      g_RetakesKv.GoBack();
    }
  } else {
    // Show All Retakes
    if (g_RetakesKv.GotoFirstSubKey()) {
      do {
        char retakeid[OPTION_ID_LENGTH];
        g_RetakesKv.GetSectionName(retakeid, sizeof(retakeid));
        // g_RetakesKv.GetString("name", retakename, sizeof(retakename));
        int retakeColor[4];
        GetRandomColor(retakeColor, 150);
        if (g_RetakesKv.GotoFirstSubKey()) {
          do {
            char spawnType[OPTION_ID_LENGTH];
            g_RetakesKv.GetSectionName(spawnType, sizeof(spawnType));
            CreateHoloRetakeEntity(spawnType, retakeColor);
          } while (g_RetakesKv.GotoNextKey());
          g_RetakesKv.GoBack();
        }
      } while (g_RetakesKv.GotoNextKey());
      g_RetakesKv.GoBack();
    }
  }
}

public void CreateHoloRetakeEntity(const char[] spawnType, int retakeColor[4]) {
  if (g_RetakesKv.GotoFirstSubKey()) {
    do {
      char spawnid[OPTION_ID_LENGTH];
      g_RetakesKv.GetSectionName(spawnid, sizeof(spawnid));
      int ent;
      float origin[3], angles[3];
      if (StrEqual(spawnType, "grenade")) {
        if (g_RetakesKv.JumpToKey("trigger_entity")) {
          float vecmins[3], vecmaxs[3];
          g_RetakesKv.GetVector("origin", origin);
          g_RetakesKv.GetVector("angles", angles);
          g_RetakesKv.GetVector("vecmins", vecmins);
          g_RetakesKv.GetVector("vecmaxs", vecmaxs);
          ent = CreateRetakeBoxEntity(spawnid, origin, angles, vecmins, vecmaxs);
          if (ent > 0) {
            g_HoloRetakeEntities.Push(ent);
          }
          g_RetakesKv.GoBack();
        }
      } else {
        g_RetakesKv.GetVector("origin", origin);
        g_RetakesKv.GetVector("angles", angles);
        ent = CreateRetakePlayerEntity(spawnType, spawnid, origin, angles, retakeColor);
        if (ent > 0) {
          g_HoloRetakeEntities.Push(ent);
        }
      }
    } while (g_RetakesKv.GotoNextKey());
    g_RetakesKv.GoBack();
  }
}

public int CreateRetakePlayerEntity(const char[] spawnType, const char[] spawnid, float origin[3], float angles[3], int color[4]) {
  //models/player/custom_player/legacy/tm_separatist_variantD.mdl <- tt
  //models/player/custom_player/legacy/ctm_sas.mdl <- ct
  int iEnt = CreateEntityByName("prop_dynamic_override");
  if (iEnt > 0) {
    DispatchKeyValue(iEnt, "classname", "prop_dynamic_override");
    if (StrEqual(spawnType, "bot")) {
      DispatchKeyValue(iEnt, "model", "models/player/custom_player/legacy/tm_separatist_variantD.mdl");
      SetEntityRenderColor(iEnt, color[0], color[1], color[2], color[3]);
    } else if (StrEqual(spawnType, "player")) {
      DispatchKeyValue(iEnt, "model", "models/player/custom_player/legacy/ctm_sas.mdl");
      SetEntityRenderColor(iEnt, color[0], color[1], 255, color[3]);
    } else if (StrEqual(spawnType, "bomb")) {
      SetEntPropFloat(iEnt, Prop_Send, "m_flModelScale", 3.0);
      DispatchKeyValue(iEnt, "model", "models/weapons/w_ied_dropped.mdl");
      SetEntityRenderColor(iEnt, 255, color[1], color[2], color[3]);
    }
    DispatchKeyValue(iEnt, "spawnflags", "1"); 
    DispatchKeyValue(iEnt, "rendermode", "1");
    SetEntProp(iEnt, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(iEnt, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(iEnt, Prop_Send, "m_flGlowMaxDist", 1500.0);
    SetVariantColor(color);
    AcceptEntityInput(iEnt, "SetGlowColor");
    DispatchKeyValue(iEnt, "targetname", spawnid);
    if (DispatchSpawn(iEnt)) {
      angles[0] = 0.0; // look paralel to ground
      TeleportEntity(iEnt, origin, angles, NULL_VECTOR);
    }
  }
  return iEnt;
}

public int CreateRetakeBoxEntity(const char[] spawnid, float origin[3], float angles[3], float vecmins[3], float vecmaxs[3]) {
  int iEnt;
  iEnt = CreateEntityByName("trigger_multiple");
  if (iEnt > 0) {
    DispatchKeyValue(iEnt, "spawnflags", "64"); // 1 ?
    DispatchKeyValue(iEnt, "wait", "0");
    DispatchKeyValue(iEnt, "targetname", spawnid);
    if (DispatchSpawn(iEnt)) {
      ActivateEntity(iEnt);
      SetEntPropVector(iEnt, Prop_Send, "m_vecMins", vecmins);
      SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", vecmaxs);
      SetEntProp(iEnt, Prop_Send, "m_nSolidType", SOLID_BBOX);
      Entity_SetCollisionGroup(iEnt, COLLISION_GROUP_DEBRIS);
      TeleportEntity(iEnt, origin, angles, NULL_VECTOR);
    }
  }
  return iEnt;
}

stock void InitRetakes(int client) {
  if (g_InRetakeMode) {
    PM_Message(client, "{ORANGE}Retakes Ya Activo.");
    return;
  }
  // Get Retakes
  g_RetakeRetakes.Clear();
  int retakeCount = GetRetakesNextId();
  if (retakeCount > 0) {
    char iStr[OPTION_ID_LENGTH];
    for (int i = 0; i < retakeCount; i++) {
      IntToString(i, iStr, OPTION_ID_LENGTH);
      g_RetakeRetakes.PushString(iStr);
    }
    // Random Retakes
    SortADTArray(g_RetakeRetakes, Sort_Random, Sort_String);
  } else {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Zonas.");
    return;
  }
  // Setup Retake
  StartSingleRetake(client);
}

stock void StartSingleRetake(int client, int retakePos = 0) {
  g_RetakeDeathPlayersCount = 0;
  g_RetakeRetakes.GetString(retakePos, g_RetakePlayId, OPTION_ID_LENGTH);
  char retakeName[OPTION_NAME_LENGTH];
  GetRetakeName(g_RetakePlayId, retakeName, OPTION_NAME_LENGTH);
  PM_Message(client, "{ORANGE}Empezando Retake: {PURPLE}%s", retakeName);

  // Get Bombs
  char nextSpawn[OPTION_ID_LENGTH];
  GetRetakeSpawnsNextId(g_RetakePlayId, "bomb", nextSpawn, OPTION_ID_LENGTH);
  int bombCount = StringToInt(nextSpawn);
  if (bombCount < 0) {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Spawns de Bombas.");
    return;
  }
  // Bomb Setup
  char randomSpawnId[OPTION_ID_LENGTH];
  IntToString(GetRandomInt(0, bombCount-1), randomSpawnId, OPTION_ID_LENGTH);
  float bombPosition[3];
  GetRetakeSpawnVectorKV(g_RetakePlayId, "bomb", randomSpawnId, "origin", bombPosition);
  PlantBomb(client, bombPosition);

  CreateTimer(0.2, Timer_StartRetake, GetClientSerial(client));
}

public Action Timer_StartRetake(Handle timer, int serial) {
  g_RetakePlayers.Clear();
  g_RetakeBots.Clear();

  int client = GetClientFromSerial(serial);
  g_RetakePlayers.Push(client);
  // Choose N random clients
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) > CS_TEAM_SPECTATOR) {
      if (i == client) continue; // Already In ArrayList
      if (g_RetakePlayers.Length < g_MaxRetakePlayersCvar.IntValue) {
        g_RetakePlayers.Push(i);
      } else {
        ChangeClientTeam(i, CS_TEAM_SPECTATOR);
      }
    }
  }
  // PM_Message(client, "{ORANGE}%d jugadores conectados.", g_RetakePlayers.Length);

  // Get Bots
  char nextSpawn[OPTION_ID_LENGTH];
  GetRetakeSpawnsNextId(g_RetakePlayId, "bot", nextSpawn, OPTION_ID_LENGTH);
  // PM_Message(client, "{ORANGE}Cantidad de Bots: %s", nextSpawn);
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
    if (botCount > g_MaxRetakeBotsCvar.IntValue) {
      // Take first max bots
      for (int i = enabledBots.Length - 1; i >= g_MaxRetakeBotsCvar.IntValue; i--) {
        enabledBots.Erase(i);
      }
      botCount = g_MaxRetakeBotsCvar.IntValue;
    }
  } else {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Spawns de Bots.");
    return Plugin_Handled;
  }

  // Bots Setup
  for (int i = 0; i < botCount; i++) {
    char randomSpawnId[OPTION_ID_LENGTH];
    enabledBots.GetString(i, randomSpawnId, OPTION_ID_LENGTH);
    ServerCommand("bot_quota_mode normal");
    ServerCommand("bot_add");
    DataPack pack;
    CreateDataTimer(0.2, Timer_GetRetakeBots, pack);
    pack.WriteString(randomSpawnId);
  }

  delete enabledBots;

  // Get Players
  GetRetakeSpawnsNextId(g_RetakePlayId, "player", nextSpawn, OPTION_ID_LENGTH);
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
    if (playerCount >= g_MaxRetakePlayersCvar.IntValue) {
      // Take first max players
      for (int i = enabledPlayers.Length - 1; i >= g_MaxRetakePlayersCvar.IntValue; i--) {
        PM_Message(client, "{ORANGE}borrando: %d", i);
        enabledPlayers.Erase(i);
      }
      playerCount = g_MaxRetakePlayersCvar.IntValue;
    }
  } else {
    PM_Message(client, "{LIGHT_RED}Error: {ORANGE}No Existen Suficientes Spawns de Jugadores.");
    return Plugin_Handled;
  }

  // Players Setup
  for (int i = 0; i < g_RetakePlayers.Length; i++) {
    char randomSpawnId[OPTION_ID_LENGTH];
    enabledPlayers.GetString(i, randomSpawnId, OPTION_ID_LENGTH);
    float origin[3], angles[3];
    GetRetakeSpawnVectorKV(g_RetakePlayId, "player", randomSpawnId, "origin", origin);
    GetRetakeSpawnVectorKV(g_RetakePlayId, "player", randomSpawnId, "angles", angles);
    int player = g_RetakePlayers.Get(i);
    ChangeClientTeam(player, CS_TEAM_CT);
    SetEntityMoveType(player, MOVETYPE_WALK);
    TeleportEntity(player, origin, angles, ZERO_VECTOR);
  }

  delete enabledPlayers;

  // Success
  SetCvarIntSafe("mp_forcecamera", 0);
  SetCvarIntSafe("mp_radar_showall", 0);
  SetCvarIntSafe("sm_glow_pmbots", 0);
  SetCvarIntSafe("mp_ignore_round_win_conditions", 0);
  SetCvarIntSafe("sv_grenade_trajectory", 0);
  SetCvarIntSafe("sv_infinite_ammo", 2);
  SetCvarIntSafe("sm_allow_noclip", 0);
  SetCvarIntSafe("mp_respawn_on_death_ct", 0);
  SetCvarIntSafe("mp_respawn_on_death_t", 0);
  SetCvarIntSafe("sv_showimpacts", 0);
  SetCvarIntSafe("sm_holo_spawns", 0);
  SetCvarIntSafe("sm_bot_collision", 1);
  g_InRetakeMode = true;
  return Plugin_Handled;
}

public Action Timer_GetRetakeBots(Handle timer, DataPack pack) {
  pack.Reset();
  char spawnId[OPTION_ID_LENGTH];
  pack.ReadString(spawnId, OPTION_ID_LENGTH);
  
  int bot = GetLiveBot(CS_TEAM_T);
  if (bot < 0) {
    return Plugin_Handled;
  }

  char name[MAX_NAME_LENGTH];
  GetClientName(bot, name, MAX_NAME_LENGTH);
  Format(name, MAX_NAME_LENGTH, "[RETAKE]%s", name);
  SetClientName(bot, name);
  g_IsRetakeBot[bot] = true;
  g_RetakeBots.Push(bot);

  // Weapons
  Client_RemoveAllWeapons(bot);
  switch(g_RetakeDifficulty) {
    case RetakeDiff_Easy: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), false);
      Client_SetArmor(bot, 100);
    }
    case RetakeDiff_Medium: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
    case RetakeDiff_Hard: {
      GivePlayerItem(bot, "weapon_ak47");
      SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
      Client_SetArmor(bot, 100);
    }
  }

  float botOrigin[3], botAngles[3];
  GetRetakeSpawnVectorKV(g_RetakePlayId, "bot", spawnId, "origin", botOrigin);
  GetRetakeSpawnVectorKV(g_RetakePlayId, "bot", spawnId, "angles", botAngles);
  TeleportEntity(bot, botOrigin, botAngles, ZERO_VECTOR);
  // SetEntPropFloat(bot, Prop_Data, "m_flLaggedMovementValue", 0.0);

  return Plugin_Handled;
}

public void EndSingleRetake(bool win) {
  ServerCommand("bot_kick");
  g_RetakeBots.Clear();
  char retakeName[OPTION_NAME_LENGTH];
  GetRetakeName(g_RetakePlayId, retakeName, OPTION_NAME_LENGTH);
  for (int i = 0; i < g_RetakePlayers.Length; i++) {
    int player = g_RetakePlayers.Get(i);
    if (win) {
      EmitSoundToClient(player, "ui/achievement_earned.wav", _, _, SNDLEVEL_ROCKET);
      PM_Message(player, "{GREEN}===============================");
      PM_Message(player, "{ORANGE}Retake {PURPLE}%s {ORANGE}Ganado.", retakeName);
      PM_Message(player, "{GREEN}===============================");
      if (i == 0) {
        // go to next retake
        int currentRetakeIndex = g_RetakeRetakes.FindString(g_RetakePlayId);
        if (currentRetakeIndex < g_RetakeRetakes.Length - 1) {
          currentRetakeIndex++;
          StartSingleRetake(i, currentRetakeIndex);
        } else {
          StopRetakesMode();
        }
      }
    } else {
      EmitSoundToClient(player, "ui/armsrace_demoted.wav", _, _, SNDLEVEL_ROCKET);
      PM_Message(player, "{GREEN}===============================");
      PM_Message(player, "{ORANGE}Retake {PURPLE}%s {ORANGE}Perdido.", retakeName);
      PM_Message(player, "{GREEN}===============================");
      if (i == 0) {
        // repeat round
        int currentRetakeIndex = g_RetakeRetakes.FindString(g_RetakePlayId);
        StartSingleRetake(player, currentRetakeIndex);
      }
    }
  }
  g_RetakeDeathPlayersCount = 0;
}

public void StopRetakesMode() {
  GameRules_SetProp("m_bBombPlanted", 0);
  ServerCommand("bot_kick");
  // ServerCommand("mp_restartgame 1"); // test
  g_RetakePlayers.Clear();
  g_RetakeBots.Clear();
  g_RetakeRetakes.Clear();
  g_InRetakeMode = false;
  
  SetConVarFloatSafe("mp_roundtime_defuse", 60.0);
  SetCvarIntSafe("mp_forcecamera", 2);
  SetCvarIntSafe("mp_radar_showall", 1);
  SetCvarIntSafe("sm_glow_pmbots", 1);
  SetCvarIntSafe("mp_ignore_round_win_conditions", 1);
  SetCvarIntSafe("sv_grenade_trajectory", 1);
  SetCvarIntSafe("sv_infinite_ammo", 1);
  SetCvarIntSafe("sm_allow_noclip", 1);
  SetCvarIntSafe("mp_respawn_on_death_ct", 1);
  SetCvarIntSafe("mp_respawn_on_death_t", 1);
  SetCvarIntSafe("sv_showimpacts", 1);
  SetCvarIntSafe("sm_holo_spawns", 1);
  SetCvarIntSafe("sm_bot_collision", 0);
  g_RetakeDeathPlayersCount = 0;
}

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Helpers */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

public int GetRetakesNextId() {
  int largest = -1;
  char id[OPTION_ID_LENGTH];
  if (g_RetakesKv.GotoFirstSubKey()) {
    do {
      g_RetakesKv.GetSectionName(id, sizeof(id));
      int idvalue = StringToInt(id);
      if (idvalue > largest) {
        largest = idvalue;
      }
    } while (g_RetakesKv.GotoNextKey());
    g_RetakesKv.GoBack();
  }
  return largest + 1;
}

public void SetRetakeName(const char[] id, const char[] newName) {
  g_UpdatedRetakeKv = true;
  if (g_RetakesKv.JumpToKey(id, true)) {
    g_RetakesKv.SetString("name", newName);
    g_RetakesKv.GoBack();
  }
  MaybeWriteNewRetakeData();
}

public void GetRetakeName(const char[] id, char[] buffer, int length) {
  if (g_RetakesKv.JumpToKey(id)) {
    g_RetakesKv.GetString("name", buffer, length);
    g_RetakesKv.GoBack();
  }
}

public void DeleteRetake(const char[] id) {
  if (g_RetakesKv.JumpToKey(id)) {
    g_UpdatedRetakeKv = true;
    g_RetakesKv.DeleteThis();
    g_RetakesKv.Rewind();
  }
  MaybeWriteNewRetakeData();
}

public void DeleteRetakeSpawn(const char[] retakeid, const char[] spawnType, const char[] spawnid) {
  if (g_RetakesKv.JumpToKey(retakeid)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.JumpToKey(spawnid)) {
        g_UpdatedRetakeKv = true;
        g_RetakesKv.DeleteThis();
      }
    }
  }
  g_RetakesKv.Rewind();
  MaybeWriteNewRetakeData();
}

public void GetRetakeSpawnsNextId(const char[] retakeid, const char[] spawnType, char[] buffer, int size) {
  int largest = -1;
  char id[OPTION_ID_LENGTH];
  if (g_RetakesKv.JumpToKey(retakeid)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.GotoFirstSubKey()) {
        do {
          g_RetakesKv.GetSectionName(id, sizeof(id));
          int idvalue = StringToInt(id);
          if (idvalue > largest) {
            largest = idvalue;
          }
        } while (g_RetakesKv.GotoNextKey());
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  IntToString(largest + 1, buffer, size);
}

public bool SetRetakeSpawnVectorKV(const char[] retakeid, const char[] spawnType, const char[] spawnid, const char[] key, const float value[3]) {
  g_UpdatedRetakeKv = true;
  bool ret = false;
  if (g_RetakesKv.JumpToKey(retakeid, true)) {
    if (g_RetakesKv.JumpToKey(spawnType, true)) {
      if (g_RetakesKv.JumpToKey(spawnid, true)) {
        ret = true;
        g_RetakesKv.SetVector(key, value);
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  MaybeWriteNewRetakeData();
  return ret;
}

public bool GetRetakeSpawnVectorKV(const char[] retakeid, const char[] spawnType, const char[] spawnid, const char[] key, float value[3]) {
  bool ret = false;
  if (g_RetakesKv.JumpToKey(retakeid)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.JumpToKey(spawnid)) {
        g_RetakesKv.GetVector(key, value);
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  return ret;
}

public bool GetRetakeSpawnStringKV(const char[] retakeid, const char[] spawnType, const char[] spawnid, const char[] key, char[] buffer, int size) {
  bool ret = false;
  if (g_RetakesKv.JumpToKey(retakeid)) {
    if (g_RetakesKv.JumpToKey(spawnType)) {
      if (g_RetakesKv.JumpToKey(spawnid)) {
        g_RetakesKv.GetString(key, buffer, size);
        ret = true;
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  return ret;
}

public bool SetRetakeSpawnStringKV(const char[] retakeid, const char[] spawnType, const char[] spawnid, const char[] key, const char[] value) {
  g_UpdatedRetakeKv = true;
  bool ret = false;
  if (g_RetakesKv.JumpToKey(retakeid, true)) {
    if (g_RetakesKv.JumpToKey(spawnType, true)) {
      if (g_RetakesKv.JumpToKey(spawnid, true)) {
        g_RetakesKv.SetString(key, value);
        ret = true;
        g_RetakesKv.GoBack();
      }
      g_RetakesKv.GoBack();
    }
    g_RetakesKv.GoBack();
  }
  MaybeWriteNewRetakeData();
  return ret;
}

public void MaybeWriteNewRetakeData() {
  if (g_UpdatedRetakeKv) {
    g_RetakesKv.Rewind();
    BackupFiles("retakes");
    char map[PLATFORM_MAX_PATH];
    GetCleanMapName(map, sizeof(map));
    char retakeFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, retakeFile, sizeof(retakeFile), "data/practicemode/retakes/%s.cfg", map);
    DeleteFile(retakeFile);
    if (!g_RetakesKv.ExportToFile(retakeFile)) {
      PrintToServer("[RETAKES]Failed to write retakes to %s", retakeFile);
    }
    g_UpdatedRetakeKv = false;
    UpdateHoloRetakeEntities();
  }
}

public bool IsRetakesEditor(int client) {
  return true;
}

public bool IsRetakeBot(int client) {
  return client > 0 && g_IsRetakeBot[client] && IsClientInGame(client) && IsFakeClient(client);
}

public void PlantBomb(int client, float bombPosition[3]) {
  int bombEntity = CreateEntityByName("planted_c4");
  // TODO: save bombEntity as global ent?
  GameRules_SetProp("m_bBombPlanted", 1);
  SetEntData(bombEntity, bombTicking, 1, 1, true);
  Event event = CreateEvent("bomb_planted");
  if (event != null) {
    event.SetInt("userid", GetClientUserId(client));
    event.SetInt("site", GetNearestBombsite(bombPosition));
    event.Fire();
  }

  if (DispatchSpawn(bombEntity)) {
    ActivateEntity(bombEntity);

    SendVectorToGround(bombPosition);
    TeleportEntity(bombEntity, bombPosition, NULL_VECTOR, NULL_VECTOR)
  }
  else {
    CS_TerminateRound(1.0, CSRoundEnd_Draw);
  }
}

stock int GetNearestBombsite(float start[3]) {
  int playerResource = GetPlayerResourceEntity();
  if (playerResource == -1) {
    return -1;
  }

  float aCenter[3], bCenter[3];
  GetEntPropVector(playerResource, Prop_Send, "m_bombsiteCenterA", aCenter);
  GetEntPropVector(playerResource, Prop_Send, "m_bombsiteCenterB", bCenter);
  float aDist = GetVectorDistance(aCenter, start, true);
  float bDist = GetVectorDistance(bCenter, start, true);
  if (aDist < bDist) {
    return 0; //A
  }
  
  return 1; //B
}

public bool IsAbleToSee(int entity, int client, float spotValue) {
  // Skip all traces if the player isn't within the field of view.
  // - Temporarily disabled until eye angle prediction is added.
  // if (IsInFieldOfView(g_vEyePos[client], g_vEyeAngles[client], g_vAbsCentre[entity]))
  
  float vecOrigin[3], vecEyePos[3];
  GetClientAbsOrigin(entity, vecOrigin);
  GetClientEyePosition(client, vecEyePos);
  
  // Check if centre is visible.
  if (IsPointVisible(vecEyePos, vecOrigin)) {
      return true;
  }
  
  float vecEyePos_ent[3], vecEyeAng[3];
  GetClientEyeAngles(entity, vecEyeAng);
  GetClientEyePosition(entity, vecEyePos_ent);
  
  float mins[3], maxs[3];
  GetClientMins(client, mins);
  GetClientMaxs(client, maxs);
  // Check outer 4 corners of player.
  if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, spotValue)) {
      return true;
  }

  // Check if weapon tip is visible.
  // if (IsFwdVecVisible(vecEyePos, vecEyeAng, vecEyePos_ent)) {
  //     return true;
  // }

  // // Check outer 4 corners of player.
  // if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, 1.30)) {
  //     return true;
  // }
  // // Check inner 4 corners of player.
  // if (IsRectangleVisible(vecEyePos, vecOrigin, mins, maxs, 0.65)) {
  //     return true;
  // }

  return false;
}

/*stock bool IsFwdVecVisible(const float start[3], const float angles[3], const float end[3]) {
  float fwd[3];
  GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
  ScaleVector(fwd, 50.0);
  AddVectors(end, fwd, fwd);

  return IsPointVisible(start, fwd);
}*/

stock bool IsRectangleVisible(const float start[3], const float end[3], const float mins[3], const float maxs[3], float scale=1.0) {
  float ZpozOffset = maxs[2];
  float ZnegOffset = mins[2];
  float WideOffset = ((maxs[0] - mins[0]) + (maxs[1] - mins[1])) / 4.0;

  // This rectangle is just a point!
  if (ZpozOffset == 0.0 && ZnegOffset == 0.0 && WideOffset == 0.0) {
      return IsPointVisible(start, end);
  }

  // Adjust to scale.
  ZpozOffset *= scale;
  ZnegOffset *= scale;
  WideOffset *= scale;
  
  // Prepare rotation matrix.
  float angles[3], fwd[3], right[3];

  SubtractVectors(start, end, fwd);
  NormalizeVector(fwd, fwd);

  GetVectorAngles(fwd, angles);
  GetAngleVectors(angles, fwd, right, NULL_VECTOR);

  float vRectangle[4][3], vTemp[3];

  // If the player is on the same level as us, we can optimize by only rotating on the z-axis.
  if (FloatAbs(fwd[2]) <= 0.7071) {
    ScaleVector(right, WideOffset);
    // Corner 1, 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vRectangle[0]);
    SubtractVectors(vTemp, right, vRectangle[1]);
    // Corner 3, 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vRectangle[2]);
    SubtractVectors(vTemp, right, vRectangle[3]);
  } else if (fwd[2] > 0.0) { // Player is below us.
    fwd[2] = 0.0;
    NormalizeVector(fwd, fwd);
    
    ScaleVector(fwd, scale);
    ScaleVector(fwd, WideOffset);
    ScaleVector(right, WideOffset);
    
    // Corner 1
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[0]);
    
    // Corner 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    SubtractVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[1]);
    
    // Corner 3
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[2]);
    
    // Corner 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    SubtractVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[3]);
  } else { // Player is above us.
    fwd[2] = 0.0;
    NormalizeVector(fwd, fwd);
    
    ScaleVector(fwd, scale);
    ScaleVector(fwd, WideOffset);
    ScaleVector(right, WideOffset);

    // Corner 1
    vTemp = end;
    vTemp[2] += ZpozOffset;
    AddVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[0]);
    
    // Corner 2
    vTemp = end;
    vTemp[2] += ZpozOffset;
    SubtractVectors(vTemp, right, vTemp);
    AddVectors(vTemp, fwd, vRectangle[1]);
    
    // Corner 3
    vTemp = end;
    vTemp[2] += ZnegOffset;
    AddVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[2]);
    
    // Corner 4
    vTemp = end;
    vTemp[2] += ZnegOffset;
    SubtractVectors(vTemp, right, vTemp);
    SubtractVectors(vTemp, fwd, vRectangle[3]);
  }

  // Run traces on all corners.
  for (new i = 0; i < 4; i++) {
    if (IsPointVisible(start, vRectangle[i])) {
        return true;
    }
  }

  return false;
}
