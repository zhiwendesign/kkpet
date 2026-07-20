# 卡卡 look mechanics

## Natural motion

卡卡 is a compact humanoid 3D-toy construction kid. His shoes, hips, and lower torso stay registered to the same baseline while the eyes lead the gaze. The eyelids and brows reshape subtly, then the head and neck turn or pitch, with only restrained shoulder and upper-torso follow-through. Preserve the skull, round cheeks, smile, blue hard hat, blue hair, yellow overalls, hands, and shoes as rigid or near-rigid toy parts; do not stretch or warp them.

The blue hard hat is worn and rigidly follows the head. Its brim changes perspective with the head pitch and yaw, and the hair remains attached beneath it with mild occlusion changes. No new tool or prop is introduced. Arms remain relaxed and attached, shifting only enough to balance the restrained upper-body turn.

## Cardinal pose families

- `000 up`: eyes and whole eyeball surfaces rotate upward, upper eyelids lift, chin rises slightly, and the face pitches up so more lower face and underside of the hat brim are visible. Feet and lower body remain centered.
- `090 screen-right`: pupils, nose tip, face center, and chin shift unmistakably to screen-right; the head yaws right so the character's left cheek becomes more visible and the opposite cheek/hair edge is partly occluded. The right shoulder follows slightly.
- `180 down`: eyes rotate downward, upper eyelids lower slightly, chin tucks, and the face pitches down so more top of the hard hat and brim are visible. Feet and lower body remain centered.
- `270 screen-left`: pupils, nose tip, face center, and chin shift unmistakably to screen-left; the head yaws left so the character's right cheek becomes more visible and the opposite cheek/hair edge is partly occluded. The left shoulder follows slightly.

## Interpolation and motion budget

Each 22.5-degree step moves the eyes, eyelids, head yaw/pitch, brim perspective, cheek occlusion, and shoulders by roughly one even increment. The lower body and baseline do not slide. Diagonals combine the neighboring cardinal families without snapping, reversing, changing scale, changing expression, flipping overalls details, or moving the hat independently. `157.5 -> 180` and `337.5 -> 000` must each be one ordinary step. Every direction must remain visibly distinct from the neutral idle frame at normal pet size.
