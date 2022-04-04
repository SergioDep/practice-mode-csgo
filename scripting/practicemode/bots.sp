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

  if (g_BotCrouch[client]) {
    buttons |= IN_DUCK;
  } else {
    buttons &= ~IN_DUCK;
  }
  if (g_BotJump[client]) {
    buttons |= IN_JUMP;
    g_BotJump[client] = false;
  }
  TeleportEntity(client, NULL_VECTOR, g_BotSpawnAngles[client], NULL_VECTOR);

  return Plugin_Continue;
}

stock void CreateBot(int client) {
  if (g_ClientBots[client].Length >= g_MaxPlacedBotsCvar.IntValue) {
    PM_Message(
        client,
        "Tienes muchos bots (%d) añadidos.",
        g_ClientBots[client].Length);
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
}

public Action Event_PMBot_Death(int victim, Event event, const char[] name, bool dontBroadcast) {
  g_BotDeathTime[victim] = GetGameTime();
  RemoveSkin(victim);
  int ragdoll = GetEntPropEnt(victim, Prop_Send, "m_hRagdoll");
  CreateTimer(0.5, Timer_RemoveRagdoll, EntIndexToEntRef(ragdoll), TIMER_FLAG_NO_MAPCHANGE);
  CreateTimer(g_BotRespawnTimeCvar.FloatValue, Timer_RespawnClient, GetClientSerial(victim), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Continue;
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

public void KickAllClientBots(int client) {
  for (int i = 0; i < g_ClientBots[client].Length; i++) {
    int bot = g_ClientBots[client].Get(i);
    if (IsPMBot(bot)) {
      ServerCommand("bot_kick %s", g_BotOriginalName[bot]);
      g_IsPMBot[bot] = false;
      g_BotMindControlOwner[bot] = -1;
    }
  }
  g_ClientBots[client].Clear();
}

public Action Command_RemoveAllBots(int client, int args) {
  if (!g_InPracticeMode) {
    return Plugin_Handled;
  }

  KickAllBotsInServer();
  PM_MessageToAll("Bots Eliminados del Servidor");
  return Plugin_Handled;
}

public void KickAllBotsInServer() {
  for (int client = 0; client <= MaxClients; client++) {
    for (int j = 0; j < g_ClientBots[client].Length; j++) {
      int bot = g_ClientBots[client].Get(j);
      if (IsPMBot(bot)) {
        g_IsPMBot[bot] = false;
        g_BotMindControlOwner[bot] = -1;
        ServerCommand("bot_kick %s", g_BotOriginalName[bot]);
      }
    }
    g_ClientBots[client].Clear();
  }
}

void GiveBotParams(int bot) {
  // If we were giving a knife, let's give them a gun. We don't want to accidently try to give a
  // knife our beloved bot doesn't own on the steam market!
  // The bayonet knife is appearently called weapon_bayonet as well :(
  if (StrContains(g_BotSpawnWeapon[bot], "knife", false) >= 0 ||
      StrContains(g_BotSpawnWeapon[bot], "bayonet", false) >= 0) {
    if (GetClientTeam(bot) == CS_TEAM_CT) {
      g_BotSpawnWeapon[bot] = "weapon_m4a1";
    } else {
      g_BotSpawnWeapon[bot] = "weapon_ak47";
    }
  }

  Client_RemoveAllWeapons(bot);
  GivePlayerItem(bot, g_BotSpawnWeapon[bot]);
  TeleportEntity(bot, g_BotSpawnOrigin[bot], g_BotSpawnAngles[bot], NULL_VECTOR);
  Client_SetArmor(bot, 100);
  SetEntData(bot, FindSendPropInfo("CCSPlayer", "m_bHasHelmet"), true);
}

// Commands.

public Action Event_BotDamageDealtEvent(Event event, const char[] name, bool dontBroadcast) {
  if (!g_InPracticeMode || g_InRetakeMode) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));

  if (IsPMBot(victim) && IsPlayer(attacker)) {
    int damage = event.GetInt("dmg_health");
    int postDamageHealth = event.GetInt("health");
    PM_Message(attacker, "---> %d de daño a BOT %N(Salud Actual: %d)", damage, victim, postDamageHealth);
  }

  return Plugin_Continue;
}

void TemporarilyDisableCollisions(int client1, int client2) {
  Entity_SetCollisionGroup(client1, COLLISION_GROUP_DEBRIS);
  Entity_SetCollisionGroup(client2, COLLISION_GROUP_DEBRIS);
  DataPack pack;
  CreateDataTimer(0.1, Timer_ResetCollisions, pack, TIMER_REPEAT);
  pack.WriteCell(GetClientSerial(client1));
  pack.WriteCell(GetClientSerial(client2));
}

public Action Timer_ResetCollisions(Handle timer, DataPack pack) {
  pack.Reset();
  int client1 = GetClientFromSerial(pack.ReadCell());
  int client2 = GetClientFromSerial(pack.ReadCell());
  if (!IsValidClient(client1) || !IsValidClient(client2)) {
    return Plugin_Handled;
  }

  if (DoPlayersCollide(client1, client2)) {
    return Plugin_Continue;
  }

  Entity_SetCollisionGroup(client1, COLLISION_GROUP_PLAYER);
  Entity_SetCollisionGroup(client2, COLLISION_GROUP_PLAYER);
  return Plugin_Handled;
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

public Action OnSetTransmit_All(int entity, int client) {
  if(g_BotPlayerModelsIndex[client] != entity) {
    return Plugin_Continue;
  }
  return Plugin_Handled;
}

public void SetupGlow(int entity, int client) {
  static int offset = -1;
  
  if ((offset = GetEntSendPropOffs(entity, "m_clrGlow")) == -1) {
    LogError("Unable to find property offset: \"m_clrGlow\"!");
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
