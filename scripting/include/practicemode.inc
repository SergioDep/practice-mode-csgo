#if defined _practicemode_included
#endinput
#endif
#define _practicemode_included

// #include "pugsetup.inc"

#define OPTION_ID_LENGTH 16
#define OPTION_NAME_LENGTH 128  // max length of a setting name/id
#define CVAR_NAME_LENGTH 64     // max length of a cvar
#define CVAR_VALUE_LENGTH 128   // max length of a cvar value

enum GrenadeType {
  GrenadeType_None = 0,
  GrenadeType_Smoke = 1,
  GrenadeType_Flash = 2,
  GrenadeType_HE = 3,
  GrenadeType_Molotov = 4,
  GrenadeType_Decoy = 5,
  GrenadeType_Incendiary = 6,
};

/**
 * Called when practice mode is enabled.
 */
forward void PM_OnPracticeModeEnabled();

/**
 * Called when practice mode is disabled.
 */
forward void PM_OnPracticeModeDisabled();

/**
 * Called when a client saves a grenade position.
 *
 * @return Plugin_Handled or a higher action to block the save.
 */
forward Action PM_OnGrenadeSaved(int client, const float origin[3], const float angle[3], const char[] name);

// Called when a client throws a grenade.
// This is *not* called when the grenade came from the PM_ThrowGrenade native.
forward void PM_OnThrowGrenade(int client, int entity, GrenadeType grenadeType, const float origin[3], const float velocity[3]);

// Called when a client's grenade "pops" or explodes.
// This is *not* called when the grenade came from the PM_ThrowGrenade native.
// origin is the position the grenade exploded/popped.
forward void PM_OnGrenadeExplode(int client, int entity, GrenadeType grenade, const float origin[3]);


// Called when a server-thrown grenade "pops" or explodes.
// This is *only* called when the grenade came from the PM_ThrowGrenade native.
// origin is the position the grenade exploded/popped.
forward void PM_OnManagedGrenadeExplode(int client, int entity, GrenadeType grenade, const float origin[3]);

/**
 * Starts practice mode, returning if it was started.
 */
native bool PM_StartPracticeMode();

/**
 * Exits practice mode, returning if it was exited.
 */
native bool PM_ExitPracticeMode();

/**
 * Returns if practice mode is enabled.
 */
native bool PM_IsPracticeModeEnabled();

native void PM_Message(int client, const char[] format, any:...);

native void PM_MessageToAll(const char[] format, any:...);

native void PM_AddChatAlias(const char[] alias, const char[] command);

// Throws a grenade, setting the grenade owner to client.
native int PM_ThrowGrenade(int client, GrenadeType grenadeType, const float origin[3], const float velocity[3]);

stock GrenadeType GrenadeFromProjectileName(const char[] projectileName, int entity = 0) {
  if (StrEqual(projectileName, "smokegrenade_projectile")) {
      return GrenadeType_Smoke;
  } else if (StrEqual(projectileName, "flashbang_projectile")) {
      return GrenadeType_Flash;
  } else if (StrEqual(projectileName, "hegrenade_projectile")) {
      return GrenadeType_HE;
  } else if (StrEqual(projectileName, "decoy_projectile")) {
      return GrenadeType_Decoy;
  } else if (StrEqual(projectileName, "molotov_projectile")) {
      if (IsValidEntity(entity)) {
        int isInc = GetEntData(entity, FindSendPropInfo("CMolotovProjectile", "m_bIsIncGrenade"), 1);
        return isInc ? GrenadeType_Incendiary : GrenadeType_Molotov;
      }
      return GrenadeType_Molotov;
  } else {
      return GrenadeType_None;
  }
}

stock void GetProjectileName(GrenadeType type, char[] buffer, int length) {
  switch (type) {
    case GrenadeType_Smoke:
    Format(buffer, length, "smokegrenade_projectile");
    case GrenadeType_Flash:
    Format(buffer, length, "flashbang_projectile");
    case GrenadeType_HE:
    Format(buffer, length, "hegrenade_projectile");
    case GrenadeType_Molotov:
    Format(buffer, length, "molotov_projectile");
    case GrenadeType_Decoy:
    Format(buffer, length, "decoy_projectile");
    case GrenadeType_Incendiary:
    Format(buffer, length, "molotov_projectile");
    default:
    PrintToServer("[GetProjectileName]Unknown grenade type: %d", type);
  }
}

stock void GetGrenadeWeapon(GrenadeType type, char[] buffer, int length) {
  switch (type) {
    case GrenadeType_Smoke:
    Format(buffer, length, "weapon_smokegrenade");
    case GrenadeType_Flash:
    Format(buffer, length, "weapon_flashbang");
    case GrenadeType_HE:
    Format(buffer, length, "weapon_hegrenade");
    case GrenadeType_Molotov:
    Format(buffer, length, "weapon_molotov");
    case GrenadeType_Decoy:
    Format(buffer, length, "weapon_decoy");
    case GrenadeType_Incendiary:
    Format(buffer, length, "weapon_incgrenade");
    default:
    PrintToServer("[GetGrenadeWeapon]Unknown grenade type: %d", type);
  }
}

stock GrenadeType GrenadeTypeFromString(const char[] name) {
  if (StrEqual(name, "smoke")) {
    return GrenadeType_Smoke;
  } else if (StrEqual(name, "flash")) {
    return GrenadeType_Flash;
  } else if (StrEqual(name, "he")) {
    return GrenadeType_HE;
  } else if (StrEqual(name, "molotov")) {
    return GrenadeType_Molotov;
  } else if (StrEqual(name, "decoy")) {
    return GrenadeType_Decoy;
  } else if (StrEqual(name, "incendiary")) {
    return GrenadeType_Incendiary;
  } else {
    return GrenadeType_None;
  }
}

stock void GrenadeTypeString(GrenadeType type, char[] buffer, int length) {
  switch (type) {
    case GrenadeType_Smoke:
    Format(buffer, length, "smoke");
    case GrenadeType_Flash:
    Format(buffer, length, "flash");
    case GrenadeType_HE:
    Format(buffer, length, "he");
    case GrenadeType_Molotov:
    Format(buffer, length, "molotov");
    case GrenadeType_Decoy:
    Format(buffer, length, "decoy");
    case GrenadeType_Incendiary:
    Format(buffer, length, "incendiary");
    case GrenadeType_None:
    return;
    default:
    PrintToServer("[GrenadeTypeString]Unknown grenade type: %d", type);
  }
}

stock void PM_DelayThrowGrenade(float delay, int client, GrenadeType grenadeType, const float origin[3], const float velocity[3]) {
  DataPack p = new DataPack();
  if (client == 0) {
    p.WriteCell(0);
  } else {
    p.WriteCell(GetClientSerial(client));
  }
  p.WriteCell(grenadeType);
  p.WriteFloat(origin[0]);
  p.WriteFloat(origin[1]);
  p.WriteFloat(origin[2]);
  p.WriteFloat(velocity[0]);
  p.WriteFloat(velocity[1]);
  p.WriteFloat(velocity[2]);
  CreateTimer(delay, _PM_DelayThrowGrenade, p);
}

public Action _PM_DelayThrowGrenade(Handle timer, DataPack data) {
  data.Reset();
  int client = GetClientFromSerial(data.ReadCell());
  GrenadeType type = view_as<GrenadeType>(data.ReadCell());
  float origin[3];
  float velocity[3];
  origin[0] = data.ReadFloat();
  origin[1] = data.ReadFloat();
  origin[2] = data.ReadFloat();
  velocity[0] = data.ReadFloat();
  velocity[1] = data.ReadFloat();
  velocity[2] = data.ReadFloat();
  delete data;
  PM_ThrowGrenade(client, type, origin, velocity);
  return Plugin_Handled;
}

public SharedPlugin __pl_practicemode = {
    name = "practicemode", file = "practicemode.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_practicemode_SetNTVOptional() {
  MarkNativeAsOptional("PM_StartPracticeMode");
  MarkNativeAsOptional("PM_ExitPracticeMode");
  MarkNativeAsOptional("PM_IsPracticeModeEnabled");
  MarkNativeAsOptional("PM_Message");
  MarkNativeAsOptional("PM_MessageToAll");
  MarkNativeAsOptional("PM_AddChatAlias");
  MarkNativeAsOptional("PM_ThrowGrenade");
}
#endif
