public void DemosEditorMenu(int client) {
  strcopy(g_SelectedDemoId[client], DEMO_ID_LENGTH, "-1");

  Menu menu = new Menu(DemosEditorMenuHandler);
  menu.SetTitle("Lista de Demos");
  menu.AddItem("add_new", "Grabar Nueva Demo");

  char demo_id[REPLAY_ID_LENGTH];
  char demo_name[DEMO_NAME_LENGTH];
  if (g_DemosKv.GotoFirstSubKey()) {
    do {
      g_DemosKv.GetSectionName(demo_id, sizeof(demo_id));
      g_DemosKv.GetString("name", demo_name, sizeof(demo_name));
      char display[128];
      Format(display, sizeof(display), "Demo N-%s: %s", demo_id, demo_name);
      menu.AddItem(demo_id, display);
    } while (g_DemosKv.GotoNextKey());
    g_DemosKv.GoBack();
  }
  menu.AddItem("exit_edit", "Salir de modo Demos");
  menu.ExitButton = true;
  menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}

public int DemosEditorMenuHandler(Menu menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    char buffer[DEMO_ID_LENGTH + 1];
    menu.GetItem(item, buffer, sizeof(buffer));
    if (StrEqual(buffer, "add_new")) {
      g_WaitForDemoSave[client] = true;
      PM_Message(client, "{ORANGE}Ingrese el nombre de la Demo a guardar. (\"{LIGHT_RED}!no{ORANGE}\" para cancelar)");
    } else if (StrEqual(buffer, "exit_edit")) {
      PM_Message(client, "{ORANGE}Modo Demos Descativado.");
    } else {
      strcopy(g_SelectedDemoId[client], DEMO_ID_LENGTH, buffer);
      SingleDemoEditorMenu(client);
    }
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock void SingleDemoEditorMenu(int client, int pos = 0) {
  g_SelectedRoleId[client] = -1;

  Menu menu = new Menu(SingleDemoEditorMenuHandler);
  char demo_name[DEMO_NAME_LENGTH];
  GetDemoName(g_SelectedDemoId[client], demo_name, DEMO_NAME_LENGTH);
  menu.SetTitle("Editor de Demo N-%s: %s", g_SelectedDemoId[client], demo_name);

  for (int i = 0; i < MAX_DEMO_BOTS; i++) {
    bool recordedLastRole = true;
    if (i > 0) recordedLastRole = HasRoleRecorded(g_SelectedDemoId[client], i - 1);
    int style = EnabledIf(recordedLastRole);
    if (HasRoleRecorded(g_SelectedDemoId[client], i)) {
      char roleName[DEMO_NAME_LENGTH];
      if (GetRoleName(g_SelectedDemoId[client], i, roleName, sizeof(roleName))) {
        AddMenuIntStyle(menu, i, style, "Cambiar demo %s de jugador %d", roleName, i + 1);
      } else {
        AddMenuIntStyle(menu, i, style, "Cambiar demo de jugador %d", i + 1);
      }
    } else {
      AddMenuIntStyle(menu, i, style, "Añadir demo de jugador %d", i + 1);
    }
  }

  menu.AddItem("replay", "Reproducir Repetición");

  /* Page 2 */
  menu.AddItem("recordall", "Graba los roles de todos los jugadores a la vez");
  menu.AddItem("stop", "Para la repetición actual");
  // menu.AddItem("rename", "Renombra esta repetición");
  // menu.AddItem("copy", "Copia esta repetición a otra nueva");
  menu.AddItem("delete", "Eliminar Esta Demo");

  char display[128];
  Format(display, sizeof(display), "Muestra temporizador de la ronda: %s",
         g_ReplayPlayRoundTimer[client] ? "si" : "no");
  menu.AddItem("round_timer", display);

  //menu.ExitButton = true;
  menu.ExitBackButton = true;
  menu.DisplayAt(client, pos, MENU_TIME_FOREVER);
}