
bool g_ClientInInspect[MAXPLAYERS + 1] = {false, ...};

bool g_NadePredict_HoldingUse[MAXPLAYERS + 1] = {false, ...};
bool g_NadePredict_HoldingInspect[MAXPLAYERS + 1] = {false, ...};
bool g_NadePredict_HoldingReload[MAXPLAYERS + 1] = {false, ...};

/* Functionality

BTN MOUSE1 : {
    WEAPON_GRENADE : {
        BTN E : {
            BTN R : WATCH_VARIABLE_ENDPOINT
            ELSE : NORMAL_PREDICT
        }
        ELSIF BTN F : {
            BTN R : WATCH_VARIABLE_ENDPOINT
            ELSE : JUMPTHROW_PREDICT
        }
        ELSIF BTN R : WATCH_FINAL_ENDPOINT
    }
}
ELSIF BTN R : {
    EXISTS(FLYING_GRENADE) : WATCH_FLYING_GRENADE
    ELSE : WATCH_FINAL_ENDPOINT (LAST_ENDPOINT)  # ALSO TELEPORT PLAYER WHEN RELEASE?
}
 */


enum ReloadAction_Type {
    WATCH_FLYING_GRENADE = 0,
    WATCH_VARIABLE_ENDPOINT,
    WATCH_FINAL_ENDPOINT
}

public Action NadePrediction_PlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
    // Get Client Buttons
    if ((buttons & IN_RELOAD) && !g_NadePredict_HoldingReload[client]) {
        g_NadePredict_HoldingReload[client] = true;
    } else if (!(buttons & IN_RELOAD) && g_NadePredict_HoldingReload[client]) {
        g_NadePredict_HoldingReload[client] = false;
    }
    if((buttons & IN_USE) && !g_NadePredict_HoldingUse[client]) {
        g_NadePredict_HoldingUse[client] = true;
    } else if (!(buttons & IN_USE) && g_NadePredict_HoldingUse[client]) {
        g_NadePredict_HoldingUse[client] = false;
    }
    if(g_ClientInInspect[client] && !g_NadePredict_HoldingInspect[client]) {
        g_NadePredict_HoldingInspect[client] = true;
    } else if (!(buttons & IN_USE) && g_NadePredict_HoldingInspect[client]) {
        g_NadePredict_HoldingInspect[client] = false;
    }

    if ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2)) {
        char weaponName[64];
        GetClientWeapon(client, weaponName, sizeof(weaponName));
        if ((StrContains(nadelist, weaponName, false) != -1)) {
            if ((buttons & IN_USE) && g_NadePredict_HoldingUse[client]) {
                if ((buttons & IN_RELOAD) && g_NadePredict_HoldingReload[client]) {
                    //WATCH_VARIABLE_ENDPOINT
                } else {
                    //NORMAL_PREDICT
                }
            }
            else if (g_ClientInInspect[client] && g_NadePredict_HoldingInspect[client]) {
                if ((buttons & IN_RELOAD) && g_NadePredict_HoldingReload[client]) {
                    //WATCH_VARIABLE_ENDPOINT
                } else {
                    //JUMPTHROW_PREDICT
                }
            }
            else if ((buttons & IN_RELOAD) && g_NadePredict_HoldingReload[client]) {
                //WATCH_FINAL_ENDPOINT
            }
        }
    } else if ((buttons & IN_RELOAD) && g_NadePredict_HoldingReload[client]) {
        // if exists flying grenade
        {
            //WATCH_FLYING_GRENADE
        }
        //else
        {
            //WATCH_FINAL_ENDPOINT (LAST_ENDPOINT)  # ALSO TELEPORT PLAYER WHEN RELEASE?
        }
    }
    return Plugin_Handled;
}
