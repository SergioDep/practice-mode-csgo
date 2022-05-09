
int g_CurrentBotControl[MAXPLAYERS + 1] = {-1, ...};

public void GiveBotsMenu(int client) {
  if (!g_InPracticeMode) {
    return;
  }

  Menu menu = new Menu(BotsMenuHandler);
  menu.SetTitle("%t", "BotsMenu");

  char displayStr[128];
  Format(displayStr, sizeof(displayStr), "%t", "AddBot", client);
  menu.AddItem("add", displayStr);
  Format(displayStr, sizeof(displayStr), "%t", "BotOptions", client);
  menu.AddItem("control", displayStr);
  Format(displayStr, sizeof(displayStr), "%t", "SwitchBotTeam", client);
  menu.AddItem("swapteam", displayStr);
  Format(displayStr, sizeof(displayStr), "%t", "DeleteBot", client);
  menu.AddItem("delete", displayStr);

  menu.ExitBackButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
}

public int BotsMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char buffer[OPTION_NAME_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    
    if (StrEqual(buffer, "add")) {
      CreateBot(client);
      GiveBotsMenu(client);
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
            ServerCommand("bot_kick %s", g_BotOriginalName[bot]);
            FindAndErase(g_ClientBots[client], bot);
            GiveBotsMenu(client);
          }
        }
      }
    }
    GiveBotsMenu(client);
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
  PM_Message(client, "%t", "NoBotFound", client);
  return -1;
}

stock void GiveBotEditorMenu(int client) {
  int bot = g_CurrentBotControl[client];
  if (IsValidEntity(bot)) {
    Menu menu = new Menu(BotEditorMenuHandler);
    menu.SetTitle("%t", "BotMenu");

    char displayStr[128];
    Format(displayStr, sizeof(displayStr), "%t", "BringBot", client);
    menu.AddItem("bring", displayStr);
    if (g_BotCrouch[bot]) {
      Format(displayStr, sizeof(displayStr), "%t", "Crouch", client);
      menu.AddItem("togglecrouch", displayStr);
    } else {
      Format(displayStr, sizeof(displayStr), "%t", "StandUp", client);
      menu.AddItem("togglecrouch", displayStr);
    }
    Format(displayStr, sizeof(displayStr), "%t", "Boost", client);
    menu.AddItem("boost", displayStr);
    Format(displayStr, sizeof(displayStr), "%t", "Jump", client);
    menu.AddItem("jump", displayStr);
    Format(displayStr, sizeof(displayStr), "%t", "RunBoost", client);
    menu.AddItem("runboost", displayStr);
    // menu.AddItem("test", "test"); //testtestets

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
      PM_Message(client, "%t", "InvalidBot", client);
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
          PM_Message(client, "%t", "TakenBot", client);
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
      else if (StrEqual(buffer, "test")) {
        float eyepos[3], eyeang[3], endpos[3];
        GetClientEyePosition(client, eyepos);
        GetClientEyeAngles(client, eyeang);
        Handle testTrace = TR_TraceRayFilterEx(eyepos, eyeang, MASK_ALL, RayType_Infinite, Trace_BaseFilter, client);
        TR_GetEndPosition(endpos, testTrace);
        int huevo = CreateInvisibleEnt();
        TeleportEntity(huevo, endpos, NULL_VECTOR, ZERO_VECTOR);
        SetEntityRenderMode(huevo, RENDER_NORMAL);
        SetEntProp(huevo, Prop_Send, "m_bShouldGlow", true, true);
        SetEntProp(huevo, Prop_Send, "m_nGlowStyle", 0);
        SetEntPropFloat(huevo, Prop_Send, "m_flGlowMaxDist", 2500.0);
        CreateTimer(3.0, Timer_DeleteHuevo, huevo);
      }
    }
    GiveBotEditorMenu(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GiveBotsMenu(client);
  } else if (action == MenuAction_End) {
    delete menu;
  }

  return 0;
}

public Action Timer_DeleteHuevo(Handle timer, int huevo) {
  if (IsValidEntity(huevo)) {
    AcceptEntityInput(huevo, "kill");
  }
  return Plugin_Stop;
}
