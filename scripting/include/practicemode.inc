#if defined _practicemode_included
#endinput
#endif
#define _practicemode_included

// #include "pugsetup.inc"

#define OPTION_ID_LENGTH 16
#define OPTION_NAME_LENGTH 128  // max length of a setting name/id
#define CVAR_NAME_LENGTH 64     // max length of a cvar
#define CVAR_VALUE_LENGTH 128   // max length of a cvar value

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
forward Action PM_OnGrenadeSaved(int client, const float origin[3], const float angle[3],
                                 const char[] name);

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
}
#endif
