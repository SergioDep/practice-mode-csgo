public Action Command_BotsMenu(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  Menu menu = new Menu(BotsMenuHandler);
  menu.SetTitle("Menu de Bots");

  menu.AddItem("add", "Agregar Bot");
  menu.AddItem("control", "Controlar Bot");
  menu.AddItem("swapteam", "Cambiar Equipo de Bot");
  menu.AddItem("delete", "Eliminar Bot");

  menu.ExitBackButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
  return Plugin_Handled;
}

public int BotsMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    
    if (StrEqual(buffer, "add")) {
      CreateBot(client);
      Command_BotsMenu(client, 0);
    } else {
      int bot = IsAimingAtBot(client);
      if (bot >= 0) {
        g_CurrentBotControl[client] = bot;
        if (StrEqual(buffer, "control")) {
          GiveBotEditorMenu(client);
          return 0;
        }
        else if (StrEqual(buffer, "swapteam")) {
          int botTeam = GetClientTeam(bot) == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT;
          ChangeClientTeam(bot, botTeam);
          CS_RespawnPlayer(bot);
        }
        else if (StrEqual(buffer, "delete")) {
          int owner = GetBotsOwner(bot);
          if (owner > 0){
            g_CurrentBotControl[owner] = -1; // In case another player is using this bot in menu
            ServerCommand("bot_kick %s", g_PMBotStartName[bot]);
            FindAndErase(g_ClientBots[client], bot);
            Command_BotsMenu(client, 0);
          }
        }
      }
    }
    Command_BotsMenu(client, 0);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GivePracticeMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

stock int IsAimingAtBot(int client, bool print = true){
  int target = GetClientAimTarget(client, true);
  if (IsPMBot(target)) {
    return target;
    // int botIndex = FindBotIndex(client, target); // remove ownership?
    // if (botIndex >= 0){
    //   return target; //returns entity
    // } else {
    //   PM_Message(client, "Solo puedes controlar a tus bots.");
    //   return -2;
    // }
  }
  PM_Message(client, "No Se encontro un bot. Apunta al bot que quieres controlar.");
  return -1;
}

stock void GiveBotEditorMenu(int client) {
  int bot = g_CurrentBotControl[client];
  if (IsValidEntity(bot)) {
    Menu menu = new Menu(BotEditorMenuHandler);
    menu.SetTitle("Bots Menu");

    menu.AddItem("bring", "Mover Bot");
    if (g_BotCrouch[bot]) {
      menu.AddItem("togglecrouch", "Levantarse");
    } else {
      menu.AddItem("togglecrouch", "Agacharse");
    }
    menu.AddItem("boost", "Boost");
    menu.AddItem("jump", "Saltar");
    menu.AddItem("runboost", "Run Boost");

    menu.ExitBackButton = true;

    menu.DisplayAt(client, 0, MENU_TIME_FOREVER);
  }
}

public int BotEditorMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));

    int bot = g_CurrentBotControl[client];
    if(bot < 0){
      PM_Message(client, "Bot No Válido");
      delete menu;
      return 0;
    }

    if (StrEqual(buffer, "runboost")) {
      float origin[3];
      GetClientAbsOrigin(client, origin);
      g_BotSpawnOrigin[bot] = origin;

      GetClientEyeAngles(client, g_BotSpawnAngles[bot]);
      GiveBotParams(bot);

      origin[2] += PLAYER_HEIGHT + 4.0;
      
      TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
      if (g_BotMindControlOwner[bot] > 0) {
        //is being controlled by another player
        if (g_BotMindControlOwner[bot] != client) {
          PM_Message(client, "Bot Ocupado por otro jugador.");
        }
      } else {
        g_BotMindControlOwner[bot] = client;
      }
    } else {
      g_BotMindControlOwner[bot] = -1; //for reset

      if (StrEqual(buffer, "bring")) {
        GetClientAbsOrigin(client, g_BotSpawnOrigin[bot]);
        GetClientEyeAngles(client, g_BotSpawnAngles[bot]);
        GiveBotParams(bot);
        TemporarilyDisableCollisions(client, bot);
      }
      else if (StrEqual(buffer, "boost")) {
        //boost teleport
        float origin[3];
        GetClientAbsOrigin(client, origin);
        g_BotSpawnOrigin[bot] = origin;

        g_BotCrouch[bot] = false;
        GetClientEyeAngles(client, g_BotSpawnAngles[bot]);
        GiveBotParams(bot);

        origin[2] += PLAYER_HEIGHT + 4.0;
        TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
      }
      else if (StrEqual(buffer, "jump")) {
        g_BotJump[bot] = true;
      }
      else if (StrEqual(buffer, "togglecrouch")) {
        g_BotCrouch[bot] = !g_BotCrouch[bot];
      }
    }
    
    GiveBotEditorMenu(client);

  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    Command_BotsMenu(client, 0);
  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}
