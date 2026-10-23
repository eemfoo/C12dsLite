# Lifts

`cos/3.0 - Lifts.cos` installs five lifts and 14 call buttons with the
catalogue's `3 1 6500` and `2 12 6500` classifiers.

| Lift | Stops |
| --- | --- |
| Carrot patch / Favorite Places | 3 |
| Hives and music room | 4 |
| Outside garden to bridge | 3 |
| Room outside garden | 2 |
| Grendel tree | 2: ground and Grendel branch |

The waterfall, sea tower, and both Love Island lifts are omitted, as are the
Grendel tree's dock and underground buttons. All retained installation
coordinates use the Lite offset of -2000 X and +8000 Y. The Grendel tree lift
starts at ground level instead of its excluded underground stop. The Favorite
Places lift also serves Lite's upper section, with its third button at
`1567 18503`: the same X as its lower buttons and the same Y as the top
hives/music room button.

Behavior follows the [new lift tutorial](https://creatures.wiki/New_lift_script):
push travels to the next higher served level, pull to the next lower level,
and buttons support push, pull, and hit with stimuli 89 and 92. Passengers
receive stimulus 94 after travel. Calls made during travel remain pending.
The original C1 artwork, separate cabin buttons, cabin dimensions, and sounds
are retained. Landing aligns the cabin floor (origin +150), rather than the
sprite bottom (origin +164), with the call button's bottom. Buttons settle
under gravity during gameplay; installation aligns cabins with the newly
placed buttons without waiting. All call buttons use
`MVSF` because the source coordinates can overlap the Lite floors; direct
`MVTO` placement can abort installation. Reinjection rebuilds an incomplete
set of lifts and buttons, restoring its CA links before replacing it.
Recovery and removal find passengers using `ENUM` and `CARR`; `EPAS` is only
used in the lift's travel event, where the vehicle is `OWNR`.

Adjacent stops have CA links; removal restores their previous permeability,
releases passengers, clears the Grendel boarding workaround, and removes all
nine event scripts. No map geometry changes are needed.

## Verification

Build with `./compile-pray.sh`, then inject the package in Docking Station.
Syntax/build checks cannot verify movement or creature behavior. In game:

1. Confirm five lifts and 14 buttons, with no agents in the omitted areas.
2. At every stop, check that buttons rest on the floor and cabin floors align
   with the landing. Check all four hives/music room stops and the bridge.
3. Use both cabin buttons and push/pull each call button. At an end stop,
   attempting to travel farther should leave the lift stationary.
4. Check hand-operated collection and individual Norn, Ettin, and adult Grendel
   boarding. Passengers should unload normally and Grendels should resume moving.
5. Call another floor during travel; also call two floors together. Pending
   calls should complete and lights should clear. Hit buttons while calls wait.
6. Remove the package with passengers aboard and during Grendel boarding.
   Confirm passengers remain usable and lift agents/scripts are removed.
