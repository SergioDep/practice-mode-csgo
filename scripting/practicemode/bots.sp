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



public Action Command_RemoveAllBots(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  KickAllBotsInServer();
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      PM_MessageToAll("%t", "BotsRemoved", i);
    }
  }
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
        } else if (StrEqual(buffer, "swapteam")) {
          int botTeam = GetClientTeam(bot) == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT;
          ChangeClientTeam(bot, botTeam);
          CS_RespawnPlayer(bot);
        } else if (StrEqual(buffer, "delete")) {
          int owner = GetBotsOwner(bot);
          if (owner > 0){
            g_CurrentBotControl[owner] = -1; // In case another player is using this bot in menu
            ServerCommand("bot_kick \"%s\"", g_BotOriginalName[bot]);
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

stock void GiveBotEditorMenu(int client) {
  int bot = g_CurrentBotControl[client];
  if (IsValidEntity(bot)) {
    Menu menu = new Menu(BotEditorMenuHandler);
    menu.SetTitle("%t", "BotMenu");

    char displayStr[128];
    Format(displayStr, sizeof(displayStr), "%t", "BringBot", client);
    menu.AddItem("bring", displayStr);
    if (g_BotCrouch[bot]) {
      Format(displayStr, sizeof(displayStr), "%t", "StandUp", client);
      menu.AddItem("togglecrouch", displayStr);
    } else {
      Format(displayStr, sizeof(displayStr), "%t", "Crouch", client);
      menu.AddItem("togglecrouch", displayStr);
    }
    Format(displayStr, sizeof(displayStr), "%t", "Boost", client);
    menu.AddItem("boost", displayStr);
    Format(displayStr, sizeof(displayStr), "%t", "Jump", client);
    menu.AddItem("jump", displayStr);
    Format(displayStr, sizeof(displayStr), "%t", "RunBoost", client);
    menu.AddItem("runboost", displayStr);

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
      } else if (StrEqual(buffer, "boost")) {
        //boost teleport
        float origin[3];
        GetClientAbsOrigin(client, origin);
        g_BotSpawnOrigin[bot] = origin;

        g_BotCrouch[bot] = false;
        GetClientEyeAngles(client, g_BotSpawnAngles[bot]);
        GiveBotParams(bot);

        origin[2] += PLAYER_HEIGHT + 4.0;
        TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
      } else if (StrEqual(buffer, "jump")) {
        g_BotJump[bot] = true;
      } else if (StrEqual(buffer, "togglecrouch")) {
        g_BotCrouch[bot] = !g_BotCrouch[bot];
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

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Events, Forwards, Hooks */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

public void Bots_ClientDisconnect(int client) {
  g_ClientBots[client].Clear();
  g_BotPlayerModels[client] = -1;
  g_BotPlayerModelsIndex[client] = -1;
  g_CurrentBotControl[client] = -1;
}

public Action PMBot_PlayerRunCmd(int client, int &buttons, float vel[3], float angles[3], int &weapon) {
  if (!IsPlayerAlive(client)) {
    return Plugin_Continue;
  }

  if (g_BotMindControlOwner[client] > 0) {
    int controller = g_BotMindControlOwner[client];
    if (IsPlayer(controller)) {
      if (IsPlayerAlive(controller) && IsPlayerAlive(client)) {
        int playerButtons = GetClientButtons(controller);

        if (playerButtons & IN_FORWARD) vel[0] = 250.0;
        else if (playerButtons & IN_BACK) vel[0] = -250.0;

        if (playerButtons & IN_MOVERIGHT) vel[1] = 250.0;
        else if (playerButtons & IN_MOVELEFT) vel[1] = -250.0;

        if(playerButtons & IN_JUMP){
          buttons &= ~IN_JUMP;
        }
        if ((playerButtons & IN_ATTACK) || (playerButtons & IN_ATTACK2)) {
          g_BotMindControlOwner[client] = -1;
          return Plugin_Changed;
        }

        float botOrigin[3], contAngles[3];
        GetClientEyeAngles(controller, contAngles);
        GetClientAbsOrigin(client, botOrigin);
        g_BotSpawnAngles[client] = contAngles;
        g_BotSpawnOrigin[client] = botOrigin;
        TeleportEntity(client, NULL_VECTOR, contAngles, NULL_VECTOR);

        return Plugin_Changed;
      }
    }
  }

  vel = ZERO_VECTOR;
  buttons = 0;

  if (g_BotCrouch[client]) {
    buttons |= IN_DUCK;
  }
  if (g_BotJump[client]) {
    buttons |= IN_JUMP;
    g_BotJump[client] = false;
  }
  TeleportEntity(client, NULL_VECTOR, g_BotSpawnAngles[client], NULL_VECTOR);

  return Plugin_Changed;
}

public Action Event_PMBot_Death(int victim, Event event, const char[] name, bool dontBroadcast) {
  RemoveSkin(victim);
  int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
  CreateTimer(0.5, Timer_RemoveRagdoll, EntIndexToEntRef(ragdoll), TIMER_FLAG_NO_MAPCHANGE);
  CreateTimer(g_BotRespawnTimeCvar.FloatValue, Timer_RespawnClient, GetClientSerial(victim), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Continue;
}

public Action OnSetTransmit_All(int entity, int client) {
  if(g_BotPlayerModelsIndex[client] != entity) {
    return Plugin_Continue;
  }
  return Plugin_Handled;
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



stock void CreateBot(int client) {
  if (g_ClientBots[client].Length >= g_MaxPlacedBotsCvar.IntValue) {
    PM_Message(client, "%t", "TooManyBots", client, g_ClientBots[client].Length);
    return;
  }
  char name[MAX_NAME_LENGTH + 1];
  int botNumberTaken = -1;
  GetClientName(client, name, sizeof(name));
  StrCat(name, sizeof(name), " ");
  botNumberTaken = SelectBotNumber(client);
  if (botNumberTaken > 1) {
    char buf[MAX_NAME_LENGTH + 1];
    Format(buf, sizeof(buf), "%d ", botNumberTaken);
    StrCat(name, sizeof(name), buf);
  }
  //actually create bot
  ServerCommand("bot_quota_mode normal");
  ServerCommand("bot_add");
  DataPack botPack;
  
  CreateDataTimer(0.2, Timer_GetPMBots, botPack);

  botPack.WriteCell(client);
  botPack.WriteCell(botNumberTaken);
  botPack.WriteString(name);
}

public Action Timer_GetPMBots(Handle timer, DataPack botPack) {
  botPack.Reset();
  int client = botPack.ReadCell();
  int botNumberTaken = botPack.ReadCell();
  char name[MAX_NAME_LENGTH + 1];
  ReadPackString(botPack, name, sizeof(name));

  if(IsPlayer(client)){
    int bot = GetLiveBot();
    if (bot < 0) {
      return Plugin_Handled;
    }
    GetClientName(bot, g_BotOriginalName[bot], MAX_NAME_LENGTH);
    SetupPMBot(client, bot, name, botNumberTaken);

    GiveBotParams(bot);
    TemporarilyDisableCollisions(client, bot);
  }
  return Plugin_Handled;
}

stock void SetupPMBot(
  int client,
  int bot,
  char[] name,
  int botNumberTaken
) {
  SetClientName(bot, name);
  g_BotNameNumber[bot] = botNumberTaken;
  g_ClientBots[client].Push(bot);
  g_IsPMBot[bot] = true;

  int botTeam = GetClientTeam(client) == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT;

  ChangeClientTeam(bot, botTeam);

  g_BotCrouch[bot] = (GetEntityFlags(client) & FL_DUCKING != 0);

  CS_RespawnPlayer(bot);

  GetClientAbsOrigin(client, g_BotSpawnOrigin[bot]);
  GetClientEyeAngles(client, g_BotSpawnAngles[bot]);
  GetClientWeapon(client, g_BotSpawnWeapon[bot], CLASS_LENGTH);
  Weapons_CopyClientProps(bot, client);
}

public void KickAllClientBots(int client) {
  for (int i = 0; i < g_ClientBots[client].Length; i++) {
    int bot = g_ClientBots[client].Get(i);
    if (IsPMBot(bot)) {
      ServerCommand("bot_kick \"%s\"", g_BotOriginalName[bot]);
      g_IsPMBot[bot] = false;
      g_BotMindControlOwner[bot] = -1;
    }
  }
  g_ClientBots[client].Clear();
}

public void KickAllBotsInServer() {
  for (int client = 0; client <= MaxClients; client++) {
    if (IsPlayer(client)) {
      for (int j = 0; j < g_ClientBots[client].Length; j++) {
        int bot = g_ClientBots[client].Get(j);
        if (IsPMBot(bot)) {
          g_IsPMBot[bot] = false;
          g_BotMindControlOwner[bot] = -1;
          ServerCommand("bot_kick \"%s\"", g_BotOriginalName[bot]);
        }
      }
      g_ClientBots[client].Clear();
    }
  }
}

void GiveBotParams(int bot) {
  // If we were giving a knife, let's give them a gun. We don't want to accidently try to give a
  // knife our beloved bot doesn't own on the steam market!
  // The bayonet knife is appearently called weapon_bayonet as well :(
  // if (StrContains(g_BotSpawnWeapon[bot], "knife", false) >= 0 ||
  //     StrContains(g_BotSpawnWeapon[bot], "bayonet", false) >= 0) {
  //   if (GetClientTeam(bot) == CS_TEAM_CT) {
  //     g_BotSpawnWeapon[bot] = "weapon_m4a1";
  //   } else {
  //     g_BotSpawnWeapon[bot] = "weapon_ak47";
  //   }
  // }

  Client_RemoveAllWeapons(bot);
  GivePlayerItem(bot, g_BotSpawnWeapon[bot]);
  TeleportEntity(bot, g_BotSpawnOrigin[bot], g_BotSpawnAngles[bot], NULL_VECTOR);
  Client_SetArmor(bot, 100);
  SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
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

public bool IsPracticeBot(int client) {
  if (g_IsPMBot[client] || g_IsRetakeBot[client] || g_IsDemoBot[client] || g_IsNadeDemoBot[client] || g_IsCrossfireBot[client]) {
    return true;
  }
  return false;
}

public void SetNotPracticeBot(int bot) {
  g_IsPMBot[bot] = false;
  g_IsRetakeBot[bot] = false;
  g_IsDemoBot[bot] = false;
  g_IsNadeDemoBot[bot] = false;
  g_IsCrossfireBot[bot] = false;
  g_BotMindControlOwner[bot] = -1;
  g_IsDemoVersusBot[bot] = false;
  strcopy(g_BotOriginalName[bot], sizeof(g_BotOriginalName[]), "-1");
}

public int GetLargestBotUserId() {
  int largestUserid = -1;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && IsFakeClient(i) && !IsClientSourceTV(i)) {
      int userid = GetClientUserId(i);
      if (userid > largestUserid && !IsPracticeBot(i)) {
        largestUserid = userid;
      }
    }
  }
  return largestUserid;
}

stock int GetLiveBot(int changeTeam = CS_TEAM_NONE) {
  int largestUserid = GetLargestBotUserId();
  if (largestUserid == -1) {
    return -1;
  }

  int bot = GetClientOfUserId(largestUserid);
  if (!IsValidClient(bot)) {
    return -1;
  }

  if (changeTeam > CS_TEAM_SPECTATOR) {
    ChangeClientTeam(bot, changeTeam);
    ForcePlayerSuicide(bot);
    CS_RespawnPlayer(bot);
  }

  return bot;
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

public Action Timer_RemoveRagdoll(Handle timer, int ref) {
    int ragdoll = EntRefToEntIndex(ref);
    if(ragdoll != INVALID_ENT_REFERENCE)
        AcceptEntityInput(ragdoll, "Kill");
    return Plugin_Handled;
}

public Action Timer_RespawnClient(Handle timer, int serial) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Stop;
  }

  int client = GetClientFromSerial(serial);

  if (g_InBotDemoMode) {
    if (IsPlayer(client) && !IsPlayerAlive(client)) {
      CS_RespawnPlayer(client);
      return Plugin_Stop;
    }
  }

  if (IsValidClient(client) && !IsPlayerAlive(client)) {
    bool respawn = true;
    if (GetClientTeam(client) == CS_TEAM_CT) {
      respawn = !!GetCvarIntSafe("mp_respawn_on_death_ct", true);
    } else if (GetClientTeam(client) == CS_TEAM_T) {
      respawn = !!GetCvarIntSafe("mp_respawn_on_death_t", true);
    }
    if (respawn) {
      CS_RespawnPlayer(client);
      return Plugin_Stop;
    }
    return Plugin_Continue;
  }

  return Plugin_Stop;
}

public int SelectBotNumber(int client) {
  if (g_ClientBots[client].Length == 0) {
    return 1;
  }

  for (int i = 1; i <= MaxClients; i++) {
    bool numberTaken = false;
    for (int j = 0; j < g_ClientBots[client].Length; j++) {
      int bot = g_ClientBots[client].Get(j);
      if (g_BotNameNumber[bot] == i) {
        numberTaken = true;
        break;
      }
    }

    if (!numberTaken) {
      return i;
    }
  }
  return -1;
}

public bool IsPMBot(int client) {
  return client > 0 && g_IsPMBot[client] && IsClientInGame(client) && IsFakeClient(client);
}

public int GetBotsOwner(int bot) {
  if (!IsPMBot(bot)) {
    return -1;
  }
  for (int i = 0; i <= MaxClients; i++) {
    ArrayList list = g_ClientBots[i];
    if (list.FindValue(bot) >= 0) {
      return i;
    }
  }
  return -1;
}

public int FindBotIndex(int client, int bot) {
  for (int i = 0; i < g_ClientBots[client].Length; i++) {
    if (g_ClientBots[client].Get(i) == bot) {
      return i;
    }
  }
  return -1;
}

void TemporarilyDisableCollisions(int client1, int client2) {
  Entity_SetCollisionGroup(client1, COLLISION_GROUP_DEBRIS);
  Entity_SetCollisionGroup(client2, COLLISION_GROUP_DEBRIS);
  DataPack pack;
  CreateDataTimer(0.1, Timer_ResetCollisions, pack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
  pack.WriteCell(GetClientSerial(client1));
  pack.WriteCell(GetClientSerial(client2));
}

public Action Timer_ResetCollisions(Handle timer, DataPack pack) {
  pack.Reset();
  int client1 = GetClientFromSerial(pack.ReadCell());
  int client2 = GetClientFromSerial(pack.ReadCell());
  if (!IsValidClient(client1) || !IsValidClient(client2)) {
    return Plugin_Stop;
  }

  if (DoPlayersCollide(client1, client2)) {
    return Plugin_Continue;
  }

  Entity_SetCollisionGroup(client1, COLLISION_GROUP_PLAYER);
  Entity_SetCollisionGroup(client2, COLLISION_GROUP_PLAYER);
  return Plugin_Stop;
}

public void CreateGlow(int client) {	
  char model[PLATFORM_MAX_PATH];
  int skin = -1;
  GetClientModel(client, model, sizeof(model));
  skin = CreatePlayerModelProp(client, model);
  if(skin > MaxClients) {
    if(SDKHookEx(skin, SDKHook_SetTransmit, OnSetTransmit_All)) {
        SetupGlow(skin, client);
    }
  }
}

public void SetupGlow(int entity, int client) {
  static int offset = -1;
  
  if ((offset = GetEntSendPropOffs(entity, "m_clrGlow")) == -1) {
    PrintToServer("[SetupGlow]Unable to find property offset: \"m_clrGlow\"!");
    return;
  }

  SetEntProp(entity, Prop_Send, "m_bShouldGlow", true, true);
  SetEntProp(entity, Prop_Send, "m_nGlowStyle", 0);
  SetEntPropFloat(entity, Prop_Send, "m_flGlowMaxDist", 10000.0);

  int colors[3];
  int team = GetClientTeam(client);
  if (team == CS_TEAM_T) {
    colors = view_as<int>({237, 163, 56});
  } else if (team == CS_TEAM_CT){
    colors = view_as<int>({16, 152, 86});
  }

  for(int i=0;i<3;i++) {
    SetEntData(entity, offset + i, colors[i], _, true);
  }
}

public int CreatePlayerModelProp(int client, char[] sModel) {
  RemoveSkin(client);
  int skin = CreateEntityByName("prop_dynamic_override");
  DispatchKeyValue(skin, "model", sModel);
  DispatchKeyValue(skin, "disablereceiveshadows", "1");
  DispatchKeyValue(skin, "disableshadows", "1");
  DispatchKeyValue(skin, "solid", "0");
  DispatchKeyValue(skin, "spawnflags", "256");
  SetEntProp(skin, Prop_Send, "m_CollisionGroup", 0);
  DispatchSpawn(skin);
  SetEntityRenderMode(skin, RENDER_TRANSALPHA);
  SetEntityRenderColor(skin, 0, 0, 0, 0);
  SetEntProp(skin, Prop_Send, "m_fEffects", (1 << 0)|(1 << 4)|(1 << 6));
  SetVariantString("!activator");
  AcceptEntityInput(skin, "SetParent", client, skin);
  SetVariantString("primary");
  AcceptEntityInput(skin, "SetParentAttachment", skin, skin, 0);
  g_BotPlayerModels[client] = EntIndexToEntRef(skin);
  g_BotPlayerModelsIndex[client] = skin;
  return skin;
}

public void RemoveSkin(int client) {
  if(IsValidEntity(g_BotPlayerModels[client])) {
    AcceptEntityInput(g_BotPlayerModels[client], "Kill");
  }
  g_BotPlayerModels[client] = INVALID_ENT_REFERENCE;
  g_BotPlayerModelsIndex[client] = -1;
}

/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/* Manico Bots Stuff */
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/
/*******************************************************************/

public void ManicoBots_ClientDisconnect(int client) {
  g_IsDemoVersusBot[client] = false;
  g_manicoZoomed[client] = false;
  g_manicoDontSwitch[client] = false;
  g_manicoUncrouchChance[client] = 0;
  g_manicoTarget[client] = -1;
  g_manicoTargetPos[client] = ZERO_VECTOR;
  g_manicoNadeTarget[client] = ZERO_VECTOR;
  // g_manicoLookAngleMaxAccel[client] = ;
  // g_manicoReactionTime[client] = ;
  g_manicoCurrArea[client] = INVALID_NAV_AREA;
}

public void SetupVersusDemoBot(int client) {
  // remove all grenades
  int g_iaGrenadeOffsets[] = {15, 17, 16, 14, 18, 17};
  bool hasGrenades = true;
  while (hasGrenades) {
    hasGrenades = false;
    int iEnt = GetPlayerWeaponSlot(client, 3);
    if(IsValidEdict(iEnt)) {
        RemovePlayerItem(client, iEnt);
        AcceptEntityInput(iEnt, "Kill");
        hasGrenades = true;
    }
  }
  for(new i = 0; i < 6; i++)
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, g_iaGrenadeOffsets[i]);
  //
  // g_manicoLookAngleMaxAccel[client] = 20000.0;
  // g_manicoReactionTime[client] = 0.0;

  g_manicoLookAngleMaxAccel[client] = Math_GetRandomFloat(4000.0, 7000.0);
  g_manicoReactionTime[client] = Math_GetRandomFloat(0.10, 0.30);
  g_IsDemoVersusBot[client] = true;
  g_manicoCurrArea[client] = INVALID_NAV_AREA;
  SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
  
  Address pLocalProfile = view_as<Address>(GetEntData(client, g_manicoBotProfileOffset));
  //All these offsets are inside BotProfileManager::Init
  StoreToAddress(pLocalProfile + view_as<Address>(104), view_as<int>(g_manicoLookAngleMaxAccel[client]), NumberType_Int32);
  StoreToAddress(pLocalProfile + view_as<Address>(116), view_as<int>(g_manicoLookAngleMaxAccel[client]), NumberType_Int32);
  StoreToAddress(pLocalProfile + view_as<Address>(84), view_as<int>(g_manicoReactionTime[client]), NumberType_Int32);
}

public Action Timer_CheckVersusDemoPlayerFast(Handle hTimer, int client) {
  if (!IsValidClient(client)) {
    return Plugin_Stop;
  }
  if (!g_IsDemoVersusBot[client]) {
    return Plugin_Stop;
  }
  if (!IsPlayerAlive(client)) {
    g_IsDemoVersusBot[client] = false;
    SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
    return Plugin_Stop;
  }

  g_manicoBombPlanted = !!GameRules_GetProp("m_bBombPlanted");
  int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  if (iActiveWeapon == -1) return Plugin_Continue;
  
  float fClientLoc[3], fClientEyes[3];
  GetClientAbsOrigin(client, fClientLoc);
  GetClientEyePosition(client, fClientEyes);
  g_manicoCurrArea[client] = NavMesh_GetNearestArea(fClientLoc);
  
  if ((GetAliveTeamCount(CS_TEAM_T) == 0 || GetAliveTeamCount(CS_TEAM_CT) == 0) && !g_manicoDontSwitch[client]) {
    SDKCall(g_manicoSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_KNIFE), 0);
    g_manicoEveryoneDead = true;
  }
  
  if(g_manicoBombPlanted) {
    int iPlantedC4 = -1;
    iPlantedC4 = FindEntityByClassname(iPlantedC4, "planted_c4");
    
    if (IsValidEntity(iPlantedC4) && GetClientTeam(client) == CS_TEAM_CT)
    {
      float fPlantedC4Location[3];
      GetEntPropVector(iPlantedC4, Prop_Send, "m_vecOrigin", fPlantedC4Location);
      
      float fPlantedC4Distance;
      
      fPlantedC4Distance = GetVectorDistance(fClientLoc, fPlantedC4Location);
      
      if (fPlantedC4Distance > 2000.0 && GetEntData(client, g_manicoBotNearbyEnemiesOffset) == 0 && !g_manicoDontSwitch[client])
      {
        SDKCall(g_manicoSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_KNIFE), 0);
        BotMoveTo(client, fPlantedC4Location, FASTEST_ROUTE);
      }
    }
  }
  
  int iDroppedC4 = GetNearestEntity(client, "weapon_c4", false);
  
  if (!g_manicoBombPlanted && !IsValidEntity(iDroppedC4) && !BotIsHiding(client)) {
    //Rifles
    int iAK47 = GetNearestEntity(client, "weapon_ak47");
    int iM4A1 = GetNearestEntity(client, "weapon_m4a1");
    int iPrimary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    int iPrimaryDefIndex;

    if (IsValidEntity(iAK47))
    {
      float fAK47Location[3];

      iPrimaryDefIndex = IsValidEntity(iPrimary) ? GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex") : 0;

      if ((iPrimaryDefIndex != 7 && iPrimaryDefIndex != 9) || iPrimary == -1)
      {
        GetEntPropVector(iAK47, Prop_Send, "m_vecOrigin", fAK47Location);

        if (GetVectorLength(fAK47Location) > 0.0)
          BotMoveTo(client, fAK47Location, FASTEST_ROUTE);
      }
    }
    else if (IsValidEntity(iM4A1))
    {
      float fM4A1Location[3];

      iPrimaryDefIndex = IsValidEntity(iPrimary) ? GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex") : 0;

      if (iPrimaryDefIndex != 7 && iPrimaryDefIndex != 9 && iPrimaryDefIndex != 16 && iPrimaryDefIndex != 60)
      {
        GetEntPropVector(iM4A1, Prop_Send, "m_vecOrigin", fM4A1Location);

        if (GetVectorLength(fM4A1Location) > 0.0)
        {
          BotMoveTo(client, fM4A1Location, FASTEST_ROUTE);

          if (GetVectorDistance(fClientLoc, fM4A1Location) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
            CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY), false);
        }
      }
      else if (iPrimary == -1)
      {
        GetEntPropVector(iM4A1, Prop_Send, "m_vecOrigin", fM4A1Location);

        if (GetVectorLength(fM4A1Location) > 0.0)
          BotMoveTo(client, fM4A1Location, FASTEST_ROUTE);
      }
    }
    
    //Pistols
    int iUSP = GetNearestEntity(client, "weapon_hkp2000");
    int iP250 = GetNearestEntity(client, "weapon_p250");
    int iFiveSeven = GetNearestEntity(client, "weapon_fiveseven");
    int iTec9 = GetNearestEntity(client, "weapon_tec9");
    int iDeagle = GetNearestEntity(client, "weapon_deagle");
    int iSecondary = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
    int iSecondaryDefIndex;
    
    if (IsValidEntity(iDeagle))
    {
      float fDeagleLocation[3];
      
      iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
      
      if (iSecondaryDefIndex == 4 || iSecondaryDefIndex == 32 || iSecondaryDefIndex == 61 || iSecondaryDefIndex == 36 || iSecondaryDefIndex == 30 || iSecondaryDefIndex == 3 || iSecondaryDefIndex == 63)
      {
        GetEntPropVector(iDeagle, Prop_Send, "m_vecOrigin", fDeagleLocation);
        
        if (GetVectorLength(fDeagleLocation) > 0.0)
        {
          BotMoveTo(client, fDeagleLocation, FASTEST_ROUTE);
          
          if (GetVectorDistance(fClientLoc, fDeagleLocation) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
            CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
        }
      }
    }
    else if (IsValidEntity(iTec9))
    {
      float fTec9Location[3];
      
      iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
      
      if (iSecondaryDefIndex == 4 || iSecondaryDefIndex == 32 || iSecondaryDefIndex == 61 || iSecondaryDefIndex == 36)
      {
        GetEntPropVector(iTec9, Prop_Send, "m_vecOrigin", fTec9Location);
        
        if (GetVectorLength(fTec9Location) > 0.0)
        {
          BotMoveTo(client, fTec9Location, FASTEST_ROUTE);
          
          if (GetVectorDistance(fClientLoc, fTec9Location) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
            CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
        }
      }
    }
    else if (IsValidEntity(iFiveSeven))
    {
      float fFiveSevenLocation[3];
      
      iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
      
      if (iSecondaryDefIndex == 4 || iSecondaryDefIndex == 32 || iSecondaryDefIndex == 61 || iSecondaryDefIndex == 36)
      {
        GetEntPropVector(iFiveSeven, Prop_Send, "m_vecOrigin", fFiveSevenLocation);
        
        if (GetVectorLength(fFiveSevenLocation) > 0.0)
        {
          BotMoveTo(client, fFiveSevenLocation, FASTEST_ROUTE);
          
          if (GetVectorDistance(fClientLoc, fFiveSevenLocation) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
            CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
        }
      }
    }
    else if (IsValidEntity(iP250))
    {
      float fP250Location[3];
      
      iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
      
      if (iSecondaryDefIndex == 4 || iSecondaryDefIndex == 32 || iSecondaryDefIndex == 61)
      {
        GetEntPropVector(iP250, Prop_Send, "m_vecOrigin", fP250Location);
        
        if (GetVectorLength(fP250Location) > 0.0)
        {
          BotMoveTo(client, fP250Location, FASTEST_ROUTE);
          
          if (GetVectorDistance(fClientLoc, fP250Location) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
            CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
        }
      }
    }
    else if (IsValidEntity(iUSP))
    {
      float fUSPLocation[3];
      
      iSecondaryDefIndex = IsValidEntity(iSecondary) ? GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex") : 0;
      
      if (iSecondaryDefIndex == 4)
      {
        GetEntPropVector(iUSP, Prop_Send, "m_vecOrigin", fUSPLocation);
        
        if (GetVectorLength(fUSPLocation) > 0.0)
        {
          BotMoveTo(client, fUSPLocation, FASTEST_ROUTE);
          
          if (GetVectorDistance(fClientLoc, fUSPLocation) < 50.0 && GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
            CS_DropWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY), false);
        }
      }
    }
  }

  return Plugin_Continue;
}

public Action OnTakeDamageAlive(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float fDamageForce[3], float fDamagePosition[3]) {
  if (float(GetClientHealth(iVictim)) - fDamage < 0.0)
    return Plugin_Continue;
  
  if (!(iDamageType & DMG_SLASH) && !(iDamageType & DMG_BULLET) && !(iDamageType & DMG_BURN))
    return Plugin_Continue;
  
  if (iVictim == iAttacker || !IsValidClient(iAttacker) || !IsPlayerAlive(iAttacker))
    return Plugin_Continue;
  
  return Plugin_Continue;
}

public MRESReturn BotCOS(DHookReturn hReturn) {
  hReturn.Value = 0;
  return MRES_Supercede;
}

public MRESReturn BotSIN(DHookReturn hReturn) {
  hReturn.Value = 0;
  return MRES_Supercede;
}

public MRESReturn CCSBot_GetPartPosition(DHookReturn hReturn, DHookParam hParams) {
  int iPlayer = hParams.Get(1);
  int iPart = hParams.Get(2);
  
  if(iPart == 2) {
    int iBone = LookupBone(iPlayer, "head_0");
    if (iBone < 0)
      return MRES_Ignored;
    
    float fHead[3], fBad[3];
    GetBonePosition(iPlayer, iBone, fHead, fBad);
    
    fHead[2] += 4.0;
    
    hReturn.SetVector(fHead);
    
    return MRES_Supercede;
  }
  
  return MRES_Ignored;
}

public MRESReturn CCSBot_SetLookAt(int client, DHookParam hParams) {
  char szDesc[64];
  
  DHookGetParamString(hParams, 1, szDesc, sizeof(szDesc));
  
  if (strcmp(szDesc, "Defuse bomb") == 0 || strcmp(szDesc, "Use entity") == 0 || strcmp(szDesc, "Open door") == 0 || strcmp(szDesc, "Face outward") == 0)
    return MRES_Ignored;
  else if (strcmp(szDesc, "Avoid Flashbang") == 0) {
    DHookSetParam(hParams, 3, PRIORITY_HIGH);
    
    return MRES_ChangedHandled;
  }
  else if (strcmp(szDesc, "Blind") == 0)
    return MRES_Supercede;
  else if (strcmp(szDesc, "Breakable") == 0 || strcmp(szDesc, "Plant bomb on floor") == 0) {
    g_manicoDontSwitch[client] = true;
    CreateTimer(5.0, Timer_EnableSwitch, GetClientUserId(client));
    
    return MRES_Ignored;
  }
  else if(strcmp(szDesc, "GrenadeThrowBend") == 0) {
    float fEyePos[3];
    GetClientEyePosition(client, fEyePos);
    BotBendLineOfSight(client, fEyePos, g_manicoNadeTarget[client], g_manicoNadeTarget[client], 180.0);
    hParams.SetVector(2, g_manicoNadeTarget[client]);
    
    return MRES_ChangedHandled;
  }
  else if(strcmp(szDesc, "Noise") == 0) {
    int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    
    int iDefIndex = 0;
    bool isKnife = false;
    if (IsValidEntity(iActiveWeapon)) {
      iDefIndex = GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
      CSWeaponID pWeaponID = CS_ItemDefIndexToID(iDefIndex);
      if (pWeaponID == CSWeapon_KNIFE)
        isKnife = true;
    }

    if(isKnife) {
      BotEquipBestWeapon(client, true);
      g_manicoDontSwitch[client] = true;
      CreateTimer(2.0, Timer_EnableSwitch, GetClientUserId(client));
    }

    float fNoisePos[3], fClientEyes[3];
    
    DHookGetParamVector(hParams, 2, fNoisePos);
    fNoisePos[2] += 25.0;
    DHookSetParamVector(hParams, 2, fNoisePos);
    
    GetClientEyePosition(client, fClientEyes);
    if(Math_GetRandomInt(1, 100) <= 35 && IsPointVisible2(fClientEyes, fNoisePos) && LineGoesThroughSmoke(fClientEyes, fNoisePos))
      DHookSetParam(hParams, 7, true);
    
    return MRES_ChangedHandled;
  }
  else {
    float fPos[3];
    
    DHookGetParamVector(hParams, 2, fPos);
    fPos[2] += 25.0;
    DHookSetParamVector(hParams, 2, fPos);
    
    return MRES_ChangedHandled;
  }
}

public MRESReturn CCSBot_PickNewAimSpot(int client, DHookParam hParams) {
  if (g_IsDemoVersusBot[client]) {
    SelectBestTargetPos(client, g_manicoTargetPos[client]);
    
    if (!IsValidClient(g_manicoTarget[client]) || !IsPlayerAlive(g_manicoTarget[client]) || g_manicoTargetPos[client][2] == 0)
      return MRES_Ignored;
    
    SetEntDataVector(client, g_manicoBotTargetSpotOffset, g_manicoTargetPos[client]);
  }
  
  return MRES_Ignored;
}

public Action DemoVersusBot_PlayerRunCmd(int client, int& buttons) {

  if (!IsPlayerAlive(client) || !g_IsDemoVersusBot[client]) {
    return Plugin_Continue;
  }

  int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  if (iActiveWeapon == -1) return Plugin_Continue;
  
  int iDefIndex = GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
  
  float fClientLoc[3];
  
  GetClientAbsOrigin(client, fClientLoc);
  
  if(g_manicoCurrArea[client] != INVALID_NAV_AREA) {
    if (g_manicoCurrArea[client].Attributes & NAV_MESH_WALK)
      buttons |= IN_SPEED;
    
    if (g_manicoCurrArea[client].Attributes & NAV_MESH_RUN)
      buttons &= ~IN_SPEED;
  }

  if(g_manicoEveryoneDead)
    buttons &= ~IN_SPEED;

  if(GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") == 1.0)
    SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 260.0);

  g_manicoTarget[client] = BotGetEnemy(client);

  float fTargetDistance;
  int iZoomLevel;
  bool bIsEnemyVisible = !!GetEntData(client, g_manicoEnemyVisibleOffset);
  bool bIsHiding = BotIsHiding(client);
  bool bIsDucking = !!(GetEntityFlags(client) & FL_DUCKING);
  bool bIsReloading = IsPlayerReloading(client);
  
  if(HasEntProp(iActiveWeapon, Prop_Send, "m_zoomLevel"))
    iZoomLevel = GetEntProp(iActiveWeapon, Prop_Send, "m_zoomLevel");
  
  if (!GetEntProp(client, Prop_Send, "m_bIsScoped"))
    g_manicoZoomed[client] = false;
  
  if(bIsHiding && (iDefIndex == 8 || iDefIndex == 39) && iZoomLevel == 0)
    buttons |= IN_ATTACK2;
  else if(!bIsHiding && (iDefIndex == 8 || iDefIndex == 39) && iZoomLevel == 1)
    buttons |= IN_ATTACK2;
  
  if (bIsHiding && g_manicoUncrouchChance[client] <= 50)
    buttons &= ~IN_DUCK;
    
  if (!IsValidClient(g_manicoTarget[client]) || !IsPlayerAlive(g_manicoTarget[client]) || g_manicoTargetPos[client][2] == 0)
    return Plugin_Continue;
  
  if (bIsEnemyVisible && GetEntityMoveType(client) != MOVETYPE_LADDER) {
    bool isKnife = false;
    if (iDefIndex > 0) {
      CSWeaponID pWeaponID = CS_ItemDefIndexToID(iDefIndex);
      if (pWeaponID == CSWeapon_KNIFE)
        isKnife = true;
    }

    if (isKnife)
      BotEquipBestWeapon(client, true);
  
    fTargetDistance = GetVectorDistance(fClientLoc, g_manicoTargetPos[client]);
    
    float fClientEyes[3], fClientAngles[3], fAimPunchAngle[3], fToAimSpot[3], fAimDir[3];
      
    GetClientEyePosition(client, fClientEyes);
    SubtractVectors(g_manicoTargetPos[client], fClientEyes, fToAimSpot);
    GetClientEyeAngles(client, fClientAngles);
    GetEntPropVector(client, Prop_Send, "m_aimPunchAngle", fAimPunchAngle);
    ScaleVector(fAimPunchAngle, (FindConVar("weapon_recoil_scale").FloatValue));
    AddVectors(fClientAngles, fAimPunchAngle, fClientAngles);
    GetViewVector(fClientAngles, fAimDir);
    
    float fRangeToEnemy = NormalizeVector(fToAimSpot, fToAimSpot);
    float fOnTarget = GetVectorDotProduct(fToAimSpot, fAimDir);
    float fAimTolerance = Cosine(ArcTangent(32.0 / fRangeToEnemy));
    
    switch(iDefIndex)
    {
      case 7, 8, 10, 13, 14, 16, 17, 19, 23, 24, 25, 26, 28, 33, 34, 39, 60:
      {
        if (fOnTarget > fAimTolerance && fTargetDistance < 2000.0)
        {
          buttons &= ~IN_ATTACK;
        
          if(!bIsReloading) 
            buttons |= IN_ATTACK;
        }
        
        if (fOnTarget > fAimTolerance && !bIsDucking && fTargetDistance < 2000.0 && iDefIndex != 17 && iDefIndex != 19 && iDefIndex != 23 && iDefIndex != 24 && iDefIndex != 25 && iDefIndex != 26 && iDefIndex != 33 && iDefIndex != 34)
          SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
      }
      case 1:
      {
        if (fOnTarget > fAimTolerance && !bIsDucking && !bIsReloading)
          SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
      }
      case 9, 40:
      {
        if (GetClientAimTarget(client, true) == g_manicoTarget[client] && g_manicoZoomed[client] && !bIsReloading)
        {
          buttons |= IN_ATTACK;
          
          SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
        }
      }
    }
    
    fClientLoc[2] += 35.5;
    
    if (!GetEntProp(iActiveWeapon, Prop_Data, "m_bInReload") && IsPointVisible2(fClientLoc, g_manicoTargetPos[client]) && fOnTarget > fAimTolerance && fTargetDistance < 2000.0 && (iDefIndex == 7 || iDefIndex == 8 || iDefIndex == 10 || iDefIndex == 13 || iDefIndex == 14 || iDefIndex == 16 || iDefIndex == 39 || iDefIndex == 60 || iDefIndex == 28))
      buttons |= IN_DUCK;
    
    if (!(GetEntityFlags(client) & FL_ONGROUND))
      buttons &= ~IN_ATTACK;
  }
  return Plugin_Changed;
}

public void LoadSDK() {
  Handle hGameConfig = LoadGameConfigFile("botstuff.games");
  if (hGameConfig == INVALID_HANDLE)
    SetFailState("Failed to find botstuff.games game config.");
  
  if(!(g_manicoTheBots = GameConfGetAddress(hGameConfig, "TheBots")))
    SetFailState("Failed to get TheBots address.");
  
  if ((g_manicoBotTargetSpotOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_targetSpot")) == -1)
    SetFailState("Failed to get CCSBot::m_targetSpot offset.");
  
  if ((g_manicoBotNearbyEnemiesOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_nearbyEnemyCount")) == -1)
    SetFailState("Failed to get CCSBot::m_nearbyEnemyCount offset.");
  
  if ((g_manicoFireWeaponOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_fireWeaponTimestamp")) == -1)
    SetFailState("Failed to get CCSBot::m_fireWeaponTimestamp offset.");
  
  if ((g_manicoEnemyVisibleOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_isEnemyVisible")) == -1)
    SetFailState("Failed to get CCSBot::m_isEnemyVisible offset.");
  
  if ((g_manicoBotProfileOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_pLocalProfile")) == -1)
    SetFailState("Failed to get CCSBot::m_pLocalProfile offset.");
  
  if ((g_manicoBotEnemyOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_enemy")) == -1)
    SetFailState("Failed to get CCSBot::m_enemy offset.");
  
  if ((g_manicoBotMoraleOffset = GameConfGetOffset(hGameConfig, "CCSBot::m_morale")) == -1)
    SetFailState("Failed to get CCSBot::m_morale offset.");
  
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::MoveTo");
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer); // Move Position As Vector, Pointer
  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // Move Type As Integer
  if ((g_manicoBotMoveTo = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::MoveTo signature!");
  
  StartPrepSDKCall(SDKCall_Entity);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBaseAnimating::LookupBone");
  PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
  PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
  if ((g_manicoLookupBone = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CBaseAnimating::LookupBone signature!");
  
  StartPrepSDKCall(SDKCall_Entity);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBaseAnimating::GetBonePosition");
  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
  PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
  if ((g_manicoGetBonePosition = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CBaseAnimating::GetBonePosition signature!");
  
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::IsVisible");
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
  PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
  PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
  PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
  if ((g_manicoBotIsVisible = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::IsVisible signature!");
  
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::IsAtHidingSpot");
  PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
  if ((g_manicoBotIsHiding = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::IsAtHidingSpot signature!");
  
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::EquipBestWeapon");
  PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
  if ((g_manicoBotEquipBestWeapon = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::EquipBestWeapon signature!");
  
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "Weapon_Switch");
  PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
  PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
  if ((g_manicoSwitchWeaponCall = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for Weapon_Switch offset!");
  
  StartPrepSDKCall(SDKCall_Raw);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBotManager::IsLineBlockedBySmoke");
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
  PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
  if ((g_manicoIsLineBlockedBySmoke = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CBotManager::IsLineBlockedBySmoke offset!");
  
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CCSBot::BendLineOfSight");
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain);
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain);
  PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
  PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
  if ((g_manicoBotBendLineOfSight = EndPrepSDKCall()) == INVALID_HANDLE)SetFailState("Failed to create SDKCall for CCSBot::BendLineOfSight signature!");
  
  delete hGameConfig;
}

public void LoadDetours() {
  GameData hGameData = new GameData("botstuff.games");   
  if (hGameData == null) {
    SetFailState("Failed to load botstuff gamedata.");
    return;
  }
  
  //CCSBot::SetLookAt Detour
  DynamicDetour hBotSetLookAtDetour = DynamicDetour.FromConf(hGameData, "CCSBot::SetLookAt");
  if(!hBotSetLookAtDetour.Enable(Hook_Pre, CCSBot_SetLookAt))
    SetFailState("Failed to setup detour for CCSBot::SetLookAt");
  
  //CCSBot::PickNewAimSpot Detour
  DynamicDetour hBotPickNewAimSpotDetour = DynamicDetour.FromConf(hGameData, "CCSBot::PickNewAimSpot");
  if(!hBotPickNewAimSpotDetour.Enable(Hook_Post, CCSBot_PickNewAimSpot))
    SetFailState("Failed to setup detour for CCSBot::PickNewAimSpot");
  
  //BotCOS Detour
  DynamicDetour hBotCOSDetour = DynamicDetour.FromConf(hGameData, "BotCOS");
  if(!hBotCOSDetour.Enable(Hook_Pre, BotCOS))
    SetFailState("Failed to setup detour for BotCOS");
  
  //BotSIN Detour
  DynamicDetour hBotSINDetour = DynamicDetour.FromConf(hGameData, "BotSIN");
  if(!hBotSINDetour.Enable(Hook_Pre, BotSIN))
    SetFailState("Failed to setup detour for BotSIN");
  
  //CCSBot::GetPartPosition Detour
  DynamicDetour hBotGetPartPosDetour = DynamicDetour.FromConf(hGameData, "CCSBot::GetPartPosition");
  if(!hBotGetPartPosDetour.Enable(Hook_Pre, CCSBot_GetPartPosition))
    SetFailState("Failed to setup detour for CCSBot::GetPartPosition");
  
  delete hGameData;
}

public int LookupBone(int iEntity, const char[] szName) {
  return SDKCall(g_manicoLookupBone, iEntity, szName);
}

public void GetBonePosition(int iEntity, int iBone, float fOrigin[3], float fAngles[3]) {
  SDKCall(g_manicoGetBonePosition, iEntity, iBone, fOrigin, fAngles);
}

public void BotMoveTo(int client, float fOrigin[3], E_Manico_RouteType routeType) {
  SDKCall(g_manicoBotMoveTo, client, fOrigin, routeType);
}

bool BotIsVisible(int client, float fPos[3], bool bTestFOV, int iIgnore = -1) {
  return SDKCall(g_manicoBotIsVisible, client, fPos, bTestFOV, iIgnore);
}

public bool BotIsHiding(int client) {
  return SDKCall(g_manicoBotIsHiding, client);
}

public void BotEquipBestWeapon(int client, bool bMustEquip) {
  SDKCall(g_manicoBotEquipBestWeapon, client, bMustEquip);
}

public void BotBendLineOfSight(int client, const float fEye[3], const float fTarget[3], float fBend[3], float fAngleLimit) {
  SDKCall(g_manicoBotBendLineOfSight, client, fEye, fTarget, fBend, fAngleLimit);
}

public int BotGetEnemy(int client) {
  return GetEntDataEnt2(client, g_manicoBotEnemyOffset);
}

stock int GetNearestEntity(int client, char[] szClassname, bool bCheckVisibility = true) {
  int iNearestEntity = -1;
  float fClientOrigin[3], fClientEyes[3], fEntityOrigin[3];
  
  GetEntPropVector(client, Prop_Data, "m_vecOrigin", fClientOrigin); // Line 2607
  GetClientEyePosition(client, fClientEyes); // Line 2607
  
  //Get the distance between the first entity and client
  float fDistance, fNearestDistance = -1.0;
  
  //Find all the entity and compare the distances
  int iEntity = -1;
  bool bVisible;
  while ((iEntity = FindEntityByClassname(iEntity, szClassname)) != -1) {
    GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", fEntityOrigin); // Line 2610
    fDistance = GetVectorDistance(fClientOrigin, fEntityOrigin);
    bVisible = bCheckVisibility ? IsPointVisible2(fClientEyes, fEntityOrigin) : true;
    
    if ((fDistance < fNearestDistance || fNearestDistance == -1.0) && bVisible) {
      iNearestEntity = iEntity;
      fNearestDistance = fDistance;
    }
  }
  
  return iNearestEntity;
}

bool IsPlayerReloading(int client) {
  int iPlayerWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  
  if(!IsValidEntity(iPlayerWeapon))
    return false;
  
  //Out of ammo? or Reloading? or Finishing Weapon Switch?
  if(GetEntProp(iPlayerWeapon, Prop_Data, "m_bInReload") || GetEntProp(iPlayerWeapon, Prop_Send, "m_iClip1") <= 0 || GetEntProp(iPlayerWeapon, Prop_Send, "m_iIronSightMode") == 2)
    return true;
  
  if(GetEntPropFloat(client, Prop_Send, "m_flNextAttack") > GetGameTime())
    return true;
  
  return GetEntPropFloat(iPlayerWeapon, Prop_Send, "m_flNextPrimaryAttack") >= GetGameTime();
}

public Action Timer_Zoomed(Handle hTimer, any client) {
  client = GetClientOfUserId(client);
  
  if(client != 0 && IsClientInGame(client))
    g_manicoZoomed[client] = true;	
  
  return Plugin_Stop;
}

public Action Timer_DelaySwitch(Handle hTimer, any client) {
  client = GetClientOfUserId(client);
  
  if(client != 0 && IsClientInGame(client)) {
    SDKCall(g_manicoSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_KNIFE), 0);
    SDKCall(g_manicoSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY), 0);
  }
  
  return Plugin_Stop;
}

public Action Timer_EnableSwitch(Handle hTimer, any client) {
  client = GetClientOfUserId(client);
  
  if(client != 0 && IsClientInGame(client))
    g_manicoDontSwitch[client] = false;	
  
  return Plugin_Stop;
}

public void SelectBestTargetPos(int client, float fTargetPos[3]) {
  if(IsValidClient(g_manicoTarget[client]) && IsPlayerAlive(g_manicoTarget[client])) {
    int iBone = LookupBone(g_manicoTarget[client], "head_0");
    int iSpineBone = LookupBone(g_manicoTarget[client], "spine_3");
    if (iBone < 0 || iSpineBone < 0)
      return;
    
    bool bShootSpine;
    float fHead[3], fBody[3], fBad[3];
    GetBonePosition(g_manicoTarget[client], iBone, fHead, fBad);
    GetBonePosition(g_manicoTarget[client], iSpineBone, fBody, fBad);
    
    fHead[2] += 4.0;
    
    if (BotIsVisible(client, fHead, false, -1)) {
      if (BotIsVisible(client, fBody, false, -1)) {
        int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if (iActiveWeapon == -1) return;
        
        int iDefIndex = GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex");
        
        switch(iDefIndex) {
          case 7, 8, 10, 13, 14, 16, 17, 19, 23, 24, 25, 26, 27, 28, 29, 33, 34, 35, 39, 60:
          {
            if (Math_GetRandomInt(1, 100) <= 80)
              bShootSpine = true;
          }
          case 2, 3, 4, 30, 32, 36, 61, 63:
          {
            if (Math_GetRandomInt(1, 100) <= 30)
              bShootSpine = true;
          }
          case 9, 11, 38:
          {
            bShootSpine = true;
          }
        }
      }
    }
    else {
      //Head wasn't visible, check other bones.
      for (int b = 0; b <= sizeof(g_szBoneNames) - 1; b++) {
        iBone = LookupBone(g_manicoTarget[client], g_szBoneNames[b]);
        if (iBone < 0)
          return;
        
        GetBonePosition(g_manicoTarget[client], iBone, fHead, fBad);
        
        if (BotIsVisible(client, fHead, false, -1))
          break;
        else
          fHead[2] = 0.0;
      }
    }
    
    if(bShootSpine)
      fTargetPos = fBody;
    else
      fTargetPos = fHead;
  }
}

stock void GetViewVector(float fVecAngle[3], float fOutPut[3]) {
  fOutPut[0] = Cosine(fVecAngle[1] / (180 / FLOAT_PI));
  fOutPut[1] = Sine(fVecAngle[1] / (180 / FLOAT_PI));
  fOutPut[2] = -Sine(fVecAngle[0] / (180 / FLOAT_PI));
}

stock bool IsPointVisible2(float fStart[3], float fEnd[3]) {
  TR_TraceRayFilter(fStart, fEnd, MASK_VISIBLE_AND_NPCS, RayType_EndPoint, TraceEntityFilterStuff);
  return TR_GetFraction() >= 0.9;
}

public bool TraceEntityFilterStuff(int iEntity, int iMask) {
  return iEntity > MaxClients;
}

stock bool LineGoesThroughSmoke(float fFrom[3], float fTo[3]) {
  return SDKCall(g_manicoIsLineBlockedBySmoke, g_manicoTheBots, fFrom, fTo);
} 

stock int GetAliveTeamCount(int iTeam) {
  int iNumber = 0;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == iTeam)
      iNumber++;
  }
  return iNumber;
}
