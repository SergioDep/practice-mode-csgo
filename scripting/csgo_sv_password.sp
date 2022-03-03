
/*
	[CS:GO] sv_password - bypass players and reserved cookie check
	23.2.2021

	- Works until Valve update breaks signature

	https://forums.alliedmods.net/showthread.php?t=330847
*/

#include <dhooks>


public Plugin myinfo = 
{
	name = "[CS:GO] sv_password - bypass players and reserved cookie check",
	author = "Bacardi",
	description = "Allow set server password even players are in game",
	version = "23.2.2021",
	url = "https://forums.alliedmods.net/showthread.php?t=330847"
};



Handle hSvPasswordChangeCallback;

public void OnPluginStart()
{
	GameData temp = new GameData("csgo_sv_password.games");

	if(temp == null) SetFailState("Why you no has csgo_sv_password.games.txt gamedata?");

	// Function - engine
	// void SvPasswordChangeCallback( IConVar *pConVar, const char *pOldValue, float flOldValue )



	// Build DHooks DHookCallback type (go look under typeset DHookCallback)
	// - Can be Address_Null if you want to load the address from gamedata using DHookSetFromConf.
	hSvPasswordChangeCallback = DHookCreateDetour(Address_Null, CallConv_CDECL, ReturnType_Void, ThisPointer_Ignore);

	if (!hSvPasswordChangeCallback)
		SetFailState("Failed to setup detour for SvPasswordChangeCallback DHookCallback"); // You build Dhook callback wrong! Try fix it.


	if (!DHookSetFromConf(hSvPasswordChangeCallback, temp, SDKConf_Signature, "SvPasswordChangeCallback"))
		SetFailState("Failed to load SvPasswordChangeCallback signature from csgo_sv_password.games.txt gamedata"); // Bad gamedata format ?

	delete temp;

	DHookAddParam(hSvPasswordChangeCallback, HookParamType_ObjectPtr);	// IConVar *pConVar
	DHookAddParam(hSvPasswordChangeCallback, HookParamType_StringPtr);	// const char *pOldValue
	DHookAddParam(hSvPasswordChangeCallback, HookParamType_Float);		// float flOldValue

	if (!DHookEnableDetour(hSvPasswordChangeCallback, false, Detour_OnCSWeaponDrop))
		SetFailState("Failed to detour hSvPasswordChangeCallback.");

	// Post callback
	//	if (!DHookEnableDetour(hSvPasswordChangeCallback, true, Detour_OnCSWeaponDrop_Post))
	//	SetFailState("Failed to detour hSvPasswordChangeCallback post.");

	//PrintToServer("hSvPasswordChangeCallback detoured!");
}

public MRESReturn Detour_OnCSWeaponDrop(DHookParam hParams)
{
	//PrintToServer("hSvPasswordChangeCallback Pre");

	// Skip real function. Bypass player and reserved cookie check.
	return MRES_Supercede;
}

// Not in use
public MRESReturn Detour_OnCSWeaponDrop_Post(DHookParam hParams)
{
	//PrintToServer("hSvPasswordChangeCallback Post");
	return MRES_Supercede;
}

