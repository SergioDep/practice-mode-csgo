# TODO BEFORE

- [ ] Performance and Bugs
    - [ ] fix grenadeprediction
        - [ ] lanza una granada, presiona R y vuelve despues que explote, mal teleport
    - [ ] Fix inactivity kick
    - [x] remove bots
    - [x] fix grenade hologram <!--current->
        - [x] i need to save the floating ent, groupnades only are shown, not saved
        - [x] do i need the button entity? (on_use runcmd)
        - [x] confirm delete in holos
    - [x] Remove .back .forward array and any extra unnecesary high memory usage commands (lagging server)
        - [x] only change cvar g_MaxHistorySizeCvar
    - [x] Round Time infinite (sm plugins unload practicemode waiting time)
    - [x] Fix grenade trail prediction (store for each client)
    - [x] Dont see enemies in radar

- [ ] Enhancements
    - [x] Improve user experience for saving grenades
        - [x] Save run throws
        - [ ] Use Bot Replay and save in the json of each grenade
    - [x] Show trail prediction to all players
        - [ ] See trails through walls
        - [ ] Correct Prediction Algorithm (make 99% effective) [PayXD]
    - [ ] remove default buy weapons UI, replace with actual menu
    - [ ] Add .cleanup command to clean the map of props/entities and respawn breakable entities without having to restart the round
    - [x] update to sourcemod 1.11
    - [x] spawn entities
    - [x] bot control menu (actualizar fakebots a bots)
    - [x] make exploded smoke glow so it can be seen through particles
    - [x] Add commands .restart or .rr to restart the round
        - [x] .restart 10 to restart and set delay to 10 seconds


# Fixes

