# TODO
- [ ] include pugsetup and server configuration
- [ ] demo record (32, 64, 128)(no es el tickrate del server que siempre será 128, solo la fluidez al momento de ver la demo) when +1$ ?

- [ ] (ruby on rails)
- [ ] yape webhook, recibe x -> timer delay for check -> start server (pm || scrim) -> min 3h?
- [ ] plugin html request every 10min (or same as AFK)

- [ ] use edited version of unkowncheats predictor in an alt steam acc and save data from there, 
- [x] check why botmimic needs teleport everytime, (check all velocity vectors and compare?)
- [x] fix teleport while not seen <- (attack mode)

<!-- memory leak somewhere-->
- [ ] get position, get predicted initial grenade velocity, spawn 10000, dont let them detonate or server will explode

<!-- too much time-->
- [ ] using the grenade predictor 99.9% accuracy

## Performance and Bugs


## Enhancements
- [ ] I dont need to Update All Grenades, just the new ones
- [ ] Retakes
      - [x] bot logic [**--**]
        - [x] ONLY MOVE PERPENDICULAR TO THE PLAYER (LEFT AND RIGHT)
      - [ ] teleport players -> let them buy weapons? -> set timer
  - [ ] mirage -> playerspawns(jungle,ladder), enemylocations(marketdoor, apartments, bench, etc...), objective(kill, defuse)
    - [ ] move when player close?, (strafe run shoot || walking strafe shoot || run crouch shoot || shoulder peeking N times) [**--**]
    - [x] bots dont throw  nades, save grenades for each map and location
    system so each player can create their own setups?
- [ ] Entries
  - [ ] mirage -> playerspawns(before t ramp), objectives(ramp entry frags), enemylocations(normal)
    - [ ] early smoke/molly/flash ramp?, enemies(shotgun close?, awp ct, (ecoround 5 players rush with he's))