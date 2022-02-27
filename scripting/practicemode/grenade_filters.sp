public bool FindGrenadeByName(const char[] auth, const char[] lookupName,
                       char grenadeId[GRENADE_ID_LENGTH]) {
  char name[GRENADE_NAME_LENGTH];
  if (g_GrenadeLocationsKv.JumpToKey(auth)) {
    if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
      do {
        g_GrenadeLocationsKv.GetSectionName(grenadeId, sizeof(grenadeId));
        g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
        if (StrEqual(name, lookupName)) {
          g_GrenadeLocationsKv.GoBack();
          g_GrenadeLocationsKv.GoBack();
          return true;
        }
      } while (g_GrenadeLocationsKv.GotoNextKey());

      g_GrenadeLocationsKv.GoBack();
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return false;
}

public bool FindMatchingGrenadesByName(const char[] lookupName, const char[] auth, ArrayList ids) {
  char currentId[GRENADE_ID_LENGTH];
  char name[GRENADE_NAME_LENGTH];
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    if (g_GrenadeLocationsKv.JumpToKey(auth)) {
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          g_GrenadeLocationsKv.GetSectionName(currentId, sizeof(currentId));
          g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
          if (StrContains(name, lookupName, false) >= 0) {
            ids.PushString(currentId);
          }
        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }
    }
    g_GrenadeLocationsKv.GoBack();
  }
  return ids.Length > 0;
}
