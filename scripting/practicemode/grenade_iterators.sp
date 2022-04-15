typedef GrenadeIteratorFunction = function Action (
  const char[] ownerName, 
  const char[] ownerAuth, 
  const char[] name, 
  const char[] execution, 
  const char[] grenadeId, 
  float origin[3], 
  float angles[3], 
  const char[] grenadeType, 
  float grenadeOrigin[3],
  float grenadeVelocity[3], 
  float grenadeDetonationOrigin[3], 
  any data
);

// Helper that calls a GrenadeIteratorFunction over all grenades
// for the current map.
// TODO: this should be able to modify the grenade strings as well,
// so name, execution, and grenadeId shouldn't be const.
// For now only 'origin' and 'angles' can be updated.
// TODO: this shoudl also just pass the category string, and a good helper function should be
// available to convert it to an ArrayList.
stock void IterateGrenades(GrenadeIteratorFunction f, any data = 0) {
  char ownerName[MAX_NAME_LENGTH];
  char ownerAuth[AUTH_LENGTH];
  char name[GRENADE_NAME_LENGTH];
  char execution[GRENADE_EXECUTION_LENGTH];
  char grenadeId[GRENADE_ID_LENGTH];
  char grenadeTypeString[32];
  float origin[3];
  float angles[3];
  float grenadeOrigin[3];
  float grenadeVelocity[3];
  float grenadeDetonationOrigin[3];

  // Outer iteration by users.
  if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
    do {
      g_GrenadeLocationsKv.GetSectionName(ownerAuth, sizeof(ownerAuth));
      g_GrenadeLocationsKv.GetString("name", ownerName, sizeof(ownerName));

      // Inner iteration by grenades for a user.
      if (g_GrenadeLocationsKv.GotoFirstSubKey()) {
        do {
          g_GrenadeLocationsKv.GetSectionName(grenadeId, sizeof(grenadeId));
          g_GrenadeLocationsKv.GetString("name", name, sizeof(name));
          g_GrenadeLocationsKv.GetString("execution", execution, sizeof(execution));
          g_GrenadeLocationsKv.GetVector("origin", origin);
          g_GrenadeLocationsKv.GetVector("angles", angles);
          g_GrenadeLocationsKv.GetString("grenadeType", grenadeTypeString, sizeof(grenadeTypeString));
          g_GrenadeLocationsKv.GetVector("grenadeOrigin", grenadeOrigin);
          g_GrenadeLocationsKv.GetVector("grenadeVelocity", grenadeVelocity);
          g_GrenadeLocationsKv.GetVector("grenadeDetonationOrigin", grenadeDetonationOrigin);

          Action ret = Plugin_Continue;
          Call_StartFunction(INVALID_HANDLE, f);
          Call_PushString(ownerName);
          Call_PushString(ownerAuth);
          Call_PushString(name);
          Call_PushString(execution);
          Call_PushString(grenadeId);
          Call_PushArrayEx(origin, sizeof(origin), SM_PARAM_COPYBACK);
          Call_PushArrayEx(angles, sizeof(angles), SM_PARAM_COPYBACK);
          Call_PushString(grenadeTypeString);
          Call_PushArrayEx(grenadeOrigin, sizeof(grenadeOrigin), SM_PARAM_COPYBACK);
          Call_PushArrayEx(grenadeVelocity, sizeof(grenadeVelocity), SM_PARAM_COPYBACK);
          Call_PushArrayEx(grenadeDetonationOrigin, sizeof(grenadeDetonationOrigin), SM_PARAM_COPYBACK);
          Call_PushCell(data);
          Call_Finish(ret);

          g_GrenadeLocationsKv.SetVector("origin", origin);
          g_GrenadeLocationsKv.SetVector("angles", angles);
          g_GrenadeLocationsKv.SetVector("grenadeOrigin", grenadeOrigin);
          g_GrenadeLocationsKv.SetVector("grenadeVelocity", grenadeVelocity);
          g_GrenadeLocationsKv.SetVector("grenadeDetonationOrigin", grenadeDetonationOrigin);

          if (ret >= Plugin_Handled) {
            g_GrenadeLocationsKv.GoBack();
            g_GrenadeLocationsKv.GoBack();
            return;
          }

        } while (g_GrenadeLocationsKv.GotoNextKey());
        g_GrenadeLocationsKv.GoBack();
      }

    } while (g_GrenadeLocationsKv.GotoNextKey());
    g_GrenadeLocationsKv.GoBack();
  }
}