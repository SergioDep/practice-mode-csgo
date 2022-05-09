void DB_TeleportToGrenade(
  int client,
  int grenadeid
) {
  char query[1024];
  if (grenadeid < 0) {
    PrintToServer("(DB_TeleportToGrenade)->INVALID GRENADE ID");
    return;
  }
  char steamid[32];
  GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
  SQL_FormatQuery(g_db, query, sizeof(query), 
    "BEGIN TRANSACTION;"...
    "  SELECT playergrenades.execution, grenades.*, grenades.grenadetype FROM playergrenades"...
    "  INNER JOIN grenades ON grenades.id = playergrenades.grenadeid"...
    "  WHERE playergrenades.owner = '%s' AND playergrenades.grenadeid = %d;"...
    "COMMIT;",
    steamid, grenadeid
  );
  g_db.Query(T_TeleportToGrenadeCallback, query, client);
}

public void T_TeleportToGrenadeCallback(Database database, DBResultSet results, const char[] error, int client) {
  if (results == null) {
    PrintToServer("Query T_TeleportToGrenadeCallback failed! %s", error);
  } else {
    if (SQL_FetchRow(results)) {
      float grenadeOrigin[3], grenadeVelocity[3];
      char execution[GRENADE_EXECUTION_LENGTH];
      results.FetchString(0, execution, sizeof(execution));
      if (!StrEqual(execution, " ")) {
        //PM_Message(client, "Ejecución: %s", execution);
        SetHudTextParams(-1.0, 0.67, 3.5, 64, 255, 64, 0, 1, 1.0, 1.0, 1.0);
        ShowSyncHudText(client, HudSync, execution);
      }
      GrenadeType grenadeType = GrenadeTypeFromString(grenadeTypeStr);
      if (grenadeType != GrenadeType_None) {
        grenadeOrigin[0] = results.FetchFloat(7);
        grenadeOrigin[1] = results.FetchFloat(8);
        grenadeOrigin[2] = results.FetchFloat(9);
        grenadeVelocity[0] = results.FetchFloat(10);
        grenadeVelocity[1] = results.FetchFloat(11);
        grenadeVelocity[2] = results.FetchFloat(12);
        CSU_ThrowGrenade(client, grenadeType, grenadeOrigin, grenadeVelocity);
      }
    }
  }
}

void DB_ThrowGrenade(
  int client, 
  int grenadeid
) {
  char query[1024];
  if (grenadeid < 0) {
    PrintToServer("(DB_UpdateGrenade)->INVALID GRENADE ID");
    return;
  }
  SQL_FormatQuery(g_db, query, sizeof(query), 
    "BEGIN TRANSACTION;"...
    " SELECT * FROM grenades"...
    " WHERE id=%d;"...
    " COMMIT;",
    grenadeid
  );
  g_db.Query(T_ThrowGrenadeCallback, query, client);
}

public void T_ThrowGrenadeCallback(Database database, DBResultSet results, const char[] error, int client) {
  if (results == null) {
    PrintToServer("Query T_ThrowGrenadeCallback failed! %s", error);
  } else {
    if (SQL_FetchRow(results)) {
      float grenadeOrigin[3], grenadeVelocity[3];
      char grenadeTypeStr[32];
      results.FetchString(6, grenadeTypeStr, sizeof(grenadeTypeStr));
      GrenadeType grenadeType = GrenadeTypeFromString(grenadeTypeStr);
      if (IsGrenade(grenadeType)) {
        grenadeOrigin[0] = results.FetchFloat(7);
        grenadeOrigin[1] = results.FetchFloat(8);
        grenadeOrigin[2] = results.FetchFloat(9);
        grenadeVelocity[0] = results.FetchFloat(10);
        grenadeVelocity[1] = results.FetchFloat(11);
        grenadeVelocity[2] = results.FetchFloat(12);
        CSU_ThrowGrenade(client, grenadeType, grenadeOrigin, grenadeVelocity);
      }
    }
  }
}

void DB_UpdateGrenade(
  int grenadeid,
  char[] query,
  int client = 0
) {
  if (grenadeid == -1) {
    PrintToServer("(DB_UpdateGrenade)->INVALID GRENADE ID");
    return;
  }
  g_db.Query(T_UpdateGrenadeCallback, query, client);
}

public void T_UpdateGrenadeCallback(Database database, DBResultSet results, const char[] error, int client) {
  if (results == null) {
    PrintToServer("Query T_UpdateGrenadeCallback failed! %s", error);
  } else {
    PM_Message(client, "%t", "Grenade_UpdateSuccess", client);
    if (SQL_FetchRow(results)) {
      OnGrenadeKvMutate();
    }
  }
}

void DB_SaveGrenade(
  int client,
  const float origin[3],
  const float angles[3],
  GrenadeType type,
  const float grenadeOrigin[3],
  const float grenadeVelocity[3],
  const float grenadeDetonationOrigin[3],
  const char[] name,
  const char[] execution = " "
) {
  char query[2560];
  char steamid[32];
  char grenadeTypeStr[128];
  GrenadeTypeString(type, grenadeTypeStr, sizeof(grenadeTypeStr));
  GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
  SQL_FormatQuery(g_db, query, sizeof(query), 
    "INSERT INTO grenades("...
    "  origin_x,"...
    "  origin_y,"...
    "  origin_z,"...
    "  angles_x,"...
    "  angles_y,"...
    "  grenadetype,"...
    "  grenadeorigin_x,"...
    "  grenadeorigin_y,"...
    "  grenadeorigin_z,"...
    "  grenadevelocity_x,"...
    "  grenadevelocity_y,"...
    "  grenadevelocity_z,"...
    "  delay"...
    ") VALUES ("...
    "  %f,"...
    "  %f,"...
    "  %f,"...
    "  %f,"...
    "  %f,"...
    "  '%s',"...
    "  %f,"...
    "  %f,"...
    "  %f,"...
    "  %f,"...
    "  %f,"...
    "  %f,"...
    "  %f"...
    ");"...
    "  "...
    "INSERT INTO playergrenades("...
    "  grenadeid,"...
    "  map,"...
    "  owner,"...
    "  name,"...
    "  execution,"...
    "  code,"...
    "  file,"...
    "  grenadedetonation_x,"...
    "  grenadedetonation_y,"...
    "  grenadedetonation_z"...
    ") VALUES ("...
    "  last_insert_rowid(),"...
    "  '%s',"...
    "  '%s',"...
    "  '%s',"...
    "  '%s',"...
    "  '%s',"...
    "  '%s',"...
    "  %f,"...
    "  %f,"...
    "  %f"...
    ");"...
	  "SELECT * FROM playergrenades WHERE rowid = last_insert_rowid();",
    origin[0],
    origin[1],
    origin[2],
    angles[0],
    angles[1],
    grenadeTypeStr,
    grenadeOrigin[0],
    grenadeOrigin[1],
    grenadeOrigin[2],
    grenadeVelocity[0],
    grenadeVelocity[1],
    grenadeVelocity[2],
    0.0,
    g_dbMap,
    steamid,
    name,
    execution,
    " ", // code
    " ", // file
    grenadeDetonationOrigin[0],
    grenadeDetonationOrigin[1],
    grenadeDetonationOrigin[2]
  );
  g_db.Query(T_SaveGrenadeCallback, query, client);
}

public void T_SaveGrenadeCallback(Database database, DBResultSet results, const char[] error, int client) {
  if (results == null) {
    PrintToServer("Query T_SaveGrenadeCallback failed! %s", error);
  } else {
    PM_Message(client, "%t", "Grenade_SaveSuccess", client);
    if (SQL_FetchRow(results)) {
      g_CurrentSavedGrenadeId[client] = results.FetchInt(0); //grenadeid
      char name[GRENADE_NAME_LENGTH];
      results.FetchString(3, name, sizeof(name));
      PM_Message(client, "{ORANGE}Granada {PURPLE}%s {ORANGE}guardada.", name);
      char steamid[AUTH_LENGTH];
      GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
      int authIndex = g_EnabledHoloNadeAuth.FindString(steamid);
      if(authIndex == -1) {
        g_EnabledHoloNadeAuth.PushString(steamid);
      }
      OnGrenadeKvMutate();
    }
  }
}

void DB_CopyGrenadeWithCode(int client, const char[] code) {
  char query[1024];
  char steamid[32];
  GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
  SQL_FormatQuery(g_db, query, sizeof(query), 
    "BEGIN TRANSACTION;"...
    "  INSERT INTO playergrenades("...
    "    grenadeid,"...
    "    map,"...
    "    owner,"...
    "    name,"...
    "    execution,"...
    "    code,"...
    "    file,"...
    "    grenadedetonation_x,"...
    "    grenadedetonation_y,"...
    "    grenadedetonation_z"...
    "  )"...
    "  SELECT"...
    "    grenadeid,"...
    "    map,"...
    "    %s,"...
    "    name,"...
    "    execution,"...
    "    code,"...
    "    file,"...
    "    grenadedetonation_x,"...
    "    grenadedetonation_y,"...
    "    grenadedetonation_z"...
    "  FROM playergrenades WHERE code = %s"...
    "COMMIT;",
    steamid,
    code
  );
  g_db.Query(T_CopyGrenadeWithCodeCallback, query, client);
}

public void T_CopyGrenadeWithCodeCallback(Database database, DBResultSet results, const char[] error, int client) {
  if (results == null) {
    PrintToServer("Query T_CopyGrenadeWithCodeCallback failed! %s", error);
  } else if (results.RowCount == 0) {
    PM_Message(client, "%t", "Grenade_CodeNotFound", client);
  } else {
    PM_Message(client, "%t", "Grenade_SaveSuccess", client);
    OnGrenadeKvMutate();
  }
}

void DB_UpdateHoloNadeEnts() {
  char enabledids[512];
  for (int i = 0; i < g_EnabledHoloNadeAuth.Length; i++) {
    char enabledsteamid[32];
    g_EnabledHoloNadeAuth.GetString(i, enabledsteamid, sizeof(enabledsteamid));
    Format(enabledsteamid, sizeof(enabledsteamid), "'%s'", enabledsteamid);
    if (i > 0) {
      Format(enabledsteamid, sizeof(enabledsteamid), ", %s", enabledsteamid);
    }
    StrCat(enabledids, sizeof(enabledids), enabledsteamid);
  }
  char query[512];
  SQL_FormatQuery(g_db, query, sizeof(query),
    "BEGIN TRANSACTION;"...
    "  SELECT playergrenades.*, grenades.grenadetype FROM playergrenades"...
    "  INNER JOIN grenades ON grenades.id = playergrenades.grenadeid"...
    "  WHERE playergrenades.map = '%s' AND playergrenades.owner IN (%s);"...
    "COMMIT;",
    g_dbMap, enabledids);
  PrintToServer("DB_UpdateHoloNadeEnts -> Query:");
  PrintToServer("%s", query);
  PrintToServer("DB_UpdateHoloNadeEnts -> Query:");
  g_db.Query(T_UpdateHoloNadeEntsCallback, query);
}

public void T_UpdateHoloNadeEntsCallback(Database database, DBResultSet results, const char[] error, any data) {
  if (results == null) {
    PrintToServer("Query T_UpdateHoloNadeEntsCallback failed! %s", error);
  } else {
    while (SQL_FetchRow(results)) {
      int grenadeId = results.FetchInt(0);
      float grenadeDetonationOrigin[3];
      grenadeDetonationOrigin[0] = results.FetchFloat(6);
      grenadeDetonationOrigin[1] = results.FetchFloat(7);
      grenadeDetonationOrigin[2] = results.FetchFloat(8);
      char grenadeTypeStr[32];
      results.FetchString(9, grenadeTypeStr, sizeof(grenadeTypeStr));
      GrenadeType type = GrenadeTypeFromString(grenadeTypeStr);

      grenadeDetonationOrigin[2] += 32.0;

      if (type == GrenadeType_Molotov || type == GrenadeType_Incendiary) {
        SendVectorToGround(grenadeDetonationOrigin);
        grenadeDetonationOrigin[2] += GRENADEMODEL_HEIGHT;
      } else if (type == GrenadeType_Flash)
        grenadeDetonationOrigin[2] -= GRENADEMODEL_SCALE*5.5; //set to middle
      CreateHoloNadeGroup2(grenadeDetonationOrigin, type, grenadeId);
    }
  }
}

void DB_GetPlayerData(int client) {
  char steamid[32];
  if(GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid))) {
    char query[255];
    SQL_FormatQuery(g_db, query, sizeof(query),
      "BEGIN TRANSACTION;"...
      "  SELECT * FROM players WHERE players.steamid = '%s'"...
      "COMMIT;"
      , steamid);
    g_db.Query(T_GetPlayerDataCallback, query, GetClientUserId(client));
  }
}

public void T_GetPlayerDataCallback(Database database, DBResultSet results, const char[] error, int userid) {
  int client = GetClientOfUserId(userid);
  if(IsPlayer(client)) {
    if (results == null) {
      LogError("Query T_GetPlayerDataCallback failed! %s", error);
    } else if (results.RowCount == 0) {
      CreatePlayerData(client);
    } else {
      char steamid[32];
      if(GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid))) {
        char query[255];
        char playerName[128];
        GetClientName(client, playerName, sizeof(playerName));
        SQL_FormatQuery(g_db, query, sizeof(query), 
          "BEGIN TRANSACTION;" ...
          "  UPDATE players SET name = '%s', last_seen = %d WHERE steamid = '%s';" ...
          "COMMIT;"
          , playerName, GetTime(), steamid);
        DataPack pack = new DataPack();
        pack.WriteString(query);
        g_db.Query(T_ErrorQueryCallback, query, pack);
      }
    }
  }
}

void CreatePlayerData(int client) {
  char steamid[32];
  if(GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid))) {
    char query[255];
    char playerName[128];
    GetClientName(client, playerName, sizeof(playerName));
    SQL_FormatQuery(g_db, query, sizeof(query), "INSERT INTO players (steamid, name, last_seen) VALUES ('%s', '%s', %d)", steamid, playerName, GetTime());
    DataPack pack = new DataPack();
    pack.WriteString(query);
    g_db.Query(T_ErrorQueryCallback, query, pack);
  }
}

public void SQLConnectCallback(Database database, const char[] error, any data) {
  if (database == null) {
    LogError("Database failure: %s", error);
  } else {
    g_db = database;
    char dbIdentifier[10];
  
    g_db.Driver.GetIdentifier(dbIdentifier, sizeof(dbIdentifier));
    
    CreateMainTable();
  }
}

void CreateMainTable() {
  char createQuery[2560];
  Format(createQuery, sizeof(createQuery),
    "CREATE TABLE IF NOT EXISTS players ("
    ..."  steamid VARCHAR(32) NOT NULL PRIMARY KEY,"
    ..."  name VARCHAR(128),"
    ..."  last_seen INTEGER(11) NOT NULL"
    ...");"

    ..."CREATE TABLE IF NOT EXISTS grenades ("
    ..."  id INTEGER PRIMARY KEY AUTOINCREMENT,"
    ..."  origin_x decimal(4,2),"
    ..."  origin_y decimal(4,2),"
    ..."  origin_z decimal(4,2),"
    ..."  angles_x decimal(4,2),"
    ..."  angles_y decimal(4,2),"
    ..."  grenadetype CHECK(grenadetype in ('he', 'smoke', 'flash', 'incendiary', 'molotov')),"
    ..."  grenadeorigin_x decimal(4,2),"
    ..."  grenadeorigin_y decimal(4,2),"
    ..."  grenadeorigin_z decimal(4,2),"
    ..."  grenadevelocity_x decimal(4,2),"
    ..."  grenadevelocity_y decimal(4,2),"
    ..."  grenadevelocity_z decimal(4,2),"
    ..."  delay decimal(4,2)"
    ...");"

    ..."CREATE TABLE IF NOT EXISTS playergrenades ("
    ..."  grenadeid INTEGER(4),"
    ..."  map VARCHAR(64),"
    ..."  owner VARCHAR(32),"
    ..."  name VARCHAR(128),"
    ..."  execution VARCHAR(128),"
    ..."  code VARCHAR(64),"
    ..."  file VARCHAR(256),"
    ..."  grenadedetonation_x decimal(4,2),"
    ..."  grenadedetonation_y decimal(4,2),"
    ..."  grenadedetonation_z decimal(4,2),"
    ..."  UNIQUE(grenadeid, owner),"
    ..."  FOREIGN KEY (grenadeid) REFERENCES grenades(id),"
    ..."  FOREIGN KEY (owner) REFERENCES players(steamid)"
    ...");"

    ..."CREATE TABLE IF NOT EXISTS playerdemos ("
    ..."  id INTEGER PRIMARY KEY AUTOINCREMENT,"
    ..."  owner VARCHAR(32),"
    ..."  map VARCHAR(64),"
    ..."  name VARCHAR(128),"
    ..."  UNIQUE(owner, name),"
    ..."  FOREIGN KEY (owner) REFERENCES players(steamid)"
    ...");"

    ..."CREATE TABLE IF NOT EXISTS demoroles ("
    ..."  demoid INTEGER(4),"
    ..."  roleid INTEGER(4),"
    ..."  name VARCHAR(128),"
    ..."  file VARCHAR(256),"
    ..."  team CHECK(team in ('T', 'CT')),"
    ..."  UNIQUE(demoid, roleid),"
    ..."  FOREIGN KEY (demoid) REFERENCES playerdemos(id)"
    ...");"

    ..."CREATE TABLE IF NOT EXISTS demogrenades ("
    ..."  grenadeid INTEGER(4) UNIQUE,"
    ..."  demoid INTEGER(4),"
    ..."  roleid INTEGER(4),"
    ..."  FOREIGN KEY (grenadeid) REFERENCES grenades(id),"
    ..."  FOREIGN KEY (demoid, roleid) REFERENCES demoroles(demoid, roleid)"
    ...");"
  );
  g_db.Query(T_ErrorCheckCallback, createQuery, _, DBPrio_High);
}

public void T_ErrorQueryCallback(Database database, DBResultSet results, const char[] error, DataPack pack) {
  if (results == null) {
    pack.Reset();
    char buffer[1024];
    pack.ReadString(buffer, 1024);
    LogError("Query failed! query: \"%s\" error: \"%s\"", buffer, error);
  }
}

public void T_ErrorCheckCallback(Database database, DBResultSet results, const char[] error, any data) {
  if (results == null) {
    LogError("SQLite Creating the main table has failed! %s", error);
  }
}