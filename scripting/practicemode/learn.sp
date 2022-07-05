// #define LEARN_ATTEMPTS 1
// #define LEARN_START_SEC 3.0
// #define LEARN_ADVANCE_DELAY_SEC 1.0
// #define LEARN_BLACKLIST_CATEGORY "Exempt"
// #define LEARN_SOUND_THROW_MISS "ui/armsrace_demoted.wav"
// #define LEARN_SOUND_THROW_CLOSE "ui/item_drop3_rare.wav"
// #define LEARN_SOUND_THROW_GOOD "ui/item_drop4_mythical.wav"
// #define LEARN_SOUND_END_GOOD "ui/item_drop5_legendary.wav"
// #define LEARN_SOUND_END_PERFECT "ui/item_drop6_ancient.wav"
// #define LEARN_SOUND_START "ui/achievement_earned.wav"

// ArrayList g_LearnQueue[MAXPLAYERS + 1];
// int g_LearnAttempts[MAXPLAYERS + 1];
// int g_LearnMissCount[MAXPLAYERS + 1];
// char g_LearnSuccessStrings[][] = {
//   "Bien.", 
//   "Buenardo.", 
//   "Buen trabajo.",  
//   "Bien hecho.",
//   "Buena.",
//   "Sigue asi.",
//   "Aplausos.",
//   "200iq.",
//   "Ez.",
//   "Un God.",
//   "Un S1mple."
// };

// public void Learn_MapStart() {
//   PrecacheSound(LEARN_SOUND_THROW_MISS); 
//   PrecacheSound(LEARN_SOUND_THROW_CLOSE); 
//   PrecacheSound(LEARN_SOUND_THROW_GOOD); 
//   PrecacheSound(LEARN_SOUND_END_GOOD); 
//   PrecacheSound(LEARN_SOUND_END_PERFECT);
//   PrecacheSound(LEARN_SOUND_START);
//   for(int client = 1; client <= MaxClients; client++) {
//     LearnDestroy(client);
//   }
// }

// public void Learn_ClientDisconnect(int client) {
//   LearnDestroy(client);
// }

// public void Learn_OnGrenadeExplode(
//   const int client, 
//   const int entity, 
//   GrenadeType type,
//   const float detonation[3]
// ) {
//   if (!LearnIsActive(client)) {
//     return;
//   }
//   int grenadeID = LearnGetCurrentGrenade(client);
//   if (grenadeID == -1) {
//     return;
//   }
//   LearnEvaluateThrow(client, grenadeID, type, detonation);
// }

// public Action Command_Learn(int client, int args) {
//   if (!g_InPracticeMode) {
//     return Plugin_Handled;
//   }
//   if (!LearnIsActive(client)) {
//     LearnLaunch(client);
//   } else {
//     PM_Message(client, "Modo learning ya activo.");
//     LearnPrintGrenade(client, LearnGetCurrentGrenade(client));
//   }
//   return Plugin_Handled;
// }

// public Action Command_StopLearn(int client, int args) {
//   if (!g_InPracticeMode) {
//     return Plugin_Handled;
//   }
//   if (LearnIsActive(client)) {
//     LearnStop(client, "Cancelando modo learning.");
//   } else {
//     PM_Message(client, "No estas en modo learning.");
//   }
//   return Plugin_Handled;
// }

// public Action Command_Skip(int client, int args) {
//   if (!g_InPracticeMode) {
//     return Plugin_Handled;
//   }
//   if (!LearnIsActive(client)) {
//     PM_Message(client, "No estas en modo learning.");
//     return Plugin_Handled;
//   }

//   int id = LearnGetCurrentGrenade(client);
//   PM_Message(client, "{LIGHT_RED}Saltando{NORMAL} granada %i.", id);
//   g_LearnMissCount[client] += 1;
//   LearnAdvance(client);

//   return Plugin_Handled;
// }

// public Action Command_Show(int client, int args) {
//   if (!g_InPracticeMode) {
//     return Plugin_Handled;
//   }
//   if (!LearnIsActive(client)) {
//     PM_Message(client, "No estas en modo learning.");
//     return Plugin_Handled;
//   }

//   g_LearnAttempts[client] = 0;
//   LearnShowHologram(client, LearnGetCurrentGrenade(client));
  
//   return Plugin_Handled;
// }

// // Just for resetting our local state. 
// // Not intended for "Stop"-specific game state changes.
// public void LearnDestroy(const int client) {
//   delete g_LearnQueue[client];
//   g_LearnQueue[client] = new ArrayList();
//   g_LearnMissCount[client] = 0;
// }

// public void LearnLaunch(const int client) {
//   LearnDestroy(client);
//   g_HoloNadeClientEnabled[client] = false;
//   g_HoloNadeClientAllowed[client] = false;
//   GrenadeAccuracyDenyReport(client);

//   IterateGrenades(_LearnLaunch_Iterator, g_LearnQueue[client]);
//   SortADTArray(g_LearnQueue[client], Sort_Random, Sort_Integer);

//   CreateTimer(LEARN_START_SEC, _LearnLaunch_DeferredStart, client);
  
//   PM_Message(
//     client, 
//     "Empezando modo learning."
//   );
//   PM_Message(
//     client, 
//     " Hay {ORANGE}%i granadas{NORMAL} en este mapa."
//       ..." Granadas con la categoria \"%s\" no incluidos.",
//     g_LearnQueue[client].Length,
//     LEARN_BLACKLIST_CATEGORY
//   );
//   PM_Message(
//     client,
//       " Si no sabes una granada, escribe {PINK}.skip para saltarla"
//       ..." Para cancelar el modo learning, escribe {PINK}.stop o .stoplearn{NORMAL}."
//   );
// }

// public Action _LearnLaunch_DeferredStart(Handle timer, int client) {
//   EmitSoundToClient(client, LEARN_SOUND_START);
//   LearnActivateGrenade(client, LearnGetCurrentGrenade(client));
//   return Plugin_Handled;
// }

// public Action _LearnLaunch_Iterator(
//   const char[] ownerName, 
//   const char[] ownerAuth, 
//   const char[] name, 
//   const char[] execution, 
//   const char[] grenadeId, 
//   float origin[3], 
//   float angles[3], 
//   const char[] grenadeType, 
//   float grenadeOrigin[3],
//   float grenadeVelocity[3], 
//   float grenadeDetonationOrigin[3], 
//   ArrayList arr
// ) {
//   GrenadeType type = GrenadeTypeFromString(grenadeType);
//   if (type == GrenadeType_None) {
//     return Plugin_Continue;
//   }
//   arr.Push(StringToInt(grenadeId, 10));
//   return Plugin_Continue;
// }

// public void LearnStop(const int client, const char[] message) {
//   LearnDestroy(client);
//   HoloNadeAllow(client);
//   GrenadeAccuracyClearIntent(client);
//   GrenadeAccuracyAllowReport(client);
//   PM_Message(client, message);
// }

// public void LearnEvaluateThrow(
//   const int client, 
//   const int id, 
//   const GrenadeType type, 
//   const float detonation[3]
// ) {  
//   float expectedDetonation[3];
//   GetClientGrenadeVector(id, "grenadeDetonationOrigin", expectedDetonation);
//   GrenadeAccuracyScore score = GetGrenadeAccuracyScore(
//     detonation, 
//     expectedDetonation, 
//     GRENADE_ACCURACY_SCORING_DETONATION
//   );
//   score <= GrenadeAccuracyScore_CLOSE
//     ? LearnHit(client, score)
//     : LearnMiss(client);
//   LearnPlayResultSound(client, score);
// }

// public int LearnGetCurrentGrenade(const int client) {
//   if (LearnIsActive(client)) {
//     return g_LearnQueue[client].Get(0);
//   }
//   return -1;
// }

// public bool LearnIsActive(const int client) {
//   return g_LearnQueue[client].Length != 0;
// }

// public void LearnHit(const int client, const GrenadeAccuracyScore score) {
//   int i = GetRandomInt(0, sizeof(g_LearnSuccessStrings) - 1);
//   PM_Message(
//     client, 
//     score == GrenadeAccuracyScore_GOOD 
//       ? "{GREEN}Lanzado Perfectamente{NORMAL}. %s"
//       : "{GREEN}Lanzado Correctamente{NORMAL}. %s",
//     g_LearnSuccessStrings[i]
//   );
//   CreateTimer(LEARN_ADVANCE_DELAY_SEC, _LearnHit_Delay, client);
// }

// public Action _LearnHit_Delay(Handle timer, int client) {
//   LearnAdvance(client);
//   return Plugin_Handled;
// }

// // Used with success or skip; agnostic to intent.
// public void LearnAdvance(const int client) {
//   if (g_LearnQueue[client].Length == 0) {
//     LogError("Tried to advance learn queue for %i when it is empty.", client);
//     return;
//   }
//   g_LearnQueue[client].Erase(0);
//   if (g_LearnQueue[client].Length > 0) {    
//     LearnActivateGrenade(client, LearnGetCurrentGrenade(client));
//   } else {
//     if (g_LearnMissCount[client] == 0) {
//       LearnStop(client, "Felicitaciones!!! Terminaste el mapa {GREEN}perfectamente{NORMAL}!");  
//       EmitSoundToClient(client, LEARN_SOUND_END_PERFECT);
//     } else {
//       char buffer[128];
//       Format(
//         buffer, 
//         sizeof(buffer), 
//         "Felicitaciones en esta ronda. Solo fallaste {LIGHT_GREEN}%i granadas{NORMAL}.", 
//         g_LearnMissCount[client]
//       );
//       LearnStop(client, buffer);
//       EmitSoundToClient(client, LEARN_SOUND_END_GOOD);
//     }
//   }
// }

// public void LearnMiss(const int client) {
//   int id = LearnGetCurrentGrenade(client);
//   if (g_LearnAttempts[client] == LEARN_ATTEMPTS) {
//     // This is the first miss, so count it.
//     g_LearnMissCount[client] += 1;
//   }
//   g_LearnAttempts[client] -= 1;
//   LearnMovePlayerToGrenade(client, id);
//   PM_Message(client, "{LIGHT_RED}Fallaste{NORMAL}.");
//   LearnPrintGrenade(client, id);
//   if (g_LearnAttempts[client] == 0) {
//     LearnShowHologram(client, id);
//   } 
// }

// public void LearnShowHologram(const int client, const int id) {
//   g_HoloNadeClientWhitelist[client] = id;
//   PM_Message(
//     client, 
//     "Hologram enabled. To skip this grenade, type {PINK}.skip{NORMAL}. To stop, {PINK}.stop{NORMAL}."
//   );
// }

// public void LearnActivateGrenade(const int client, const int id) {
//   g_LearnAttempts[client] = LEARN_ATTEMPTS;
//   g_HoloNadeClientWhitelist[client] = -1;
//   GrenadeAccuracySetIntent(client, id);
//   LearnMovePlayerToGrenade(client, id);
//   LearnPrintGrenade(client, id);
// }

// public void LearnMovePlayerToGrenade(const int client, const int id) {
//   float origin[3];
//   GetClientGrenadeVector(id, "origin", origin);

//   TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
//   SetEntityMoveType(client, MOVETYPE_WALK);

//   // same global behavior as .goto. enables .rename etc.
//   g_Nade_CurrentSavedId[client] = id;
  
//   // lol. TBD whether we need a more elegant solution for spawning.
//   SlapPlayer(client, .health = 0, .sound = false);
//   SlapPlayer(client, .health = 0, .sound = false);
//   SlapPlayer(client, .health = 0, .sound = false);
// }

// public void LearnPrintGrenade(const int client, const int id) {
//   char name[OPTION_NAME_LENGTH];
//   GetClientGrenadeData(id, "name", name, sizeof(name));
//   PM_Message(client, "Lanza {ORANGE}\%s{NORMAL}.", name);
// }

// public void LearnPlayResultSound(const int client, const GrenadeAccuracyScore score) {
//   switch (score) {
//     case GrenadeAccuracyScore_CLOSE: {
//       EmitSoundToClient(client, LEARN_SOUND_THROW_CLOSE);
//     }
//     case GrenadeAccuracyScore_GOOD: {
//       EmitSoundToClient(client, LEARN_SOUND_THROW_GOOD);
//     }
//     default: {
//       EmitSoundToClient(client, LEARN_SOUND_THROW_MISS);
//     }
//   }
// }