# cnballpit-vrc

## Tools

Process:
 * Open Project, BUT NOT SCENE.

Impor the following, in order:
 * World SDK
 * Udon Sharp
 * AudioLink v0.2.5
 * CyanEmu
 
Close Project (and don't save).

 * Open Project
 * Open Scene

Haven't gotten NeoFlight working yet.

## TODO
 * Figure out why shadow edge length too short.
 * Make water use tanoise.
 * Add toggles for quality, i.e. alpha to coverage balls.
 * Add shadows to the balls.
 * Make ball pit use SDF for boundary.

 * Change bounding box for points two different sizes.
 * Use shader override on other two depth cameras.
 * Use override on AudioLink.
 * Try unique tag names.
 * Make both cameras for combine pass be at the same position, only one piece of geometry.
 * Test out explicit CRT Rendering Orders https://docs.unity3d.com/Manual/class-CustomRenderTexture.html#custom-render-texture



## 2.0 Release Notes (Morning of July 6)
 * Make balls look really beautiful, try to use D4rk's thing.
 * Added Yeeters
 * Added pickuppable bricks
 * Moved text monolith locations.
 * Reduced impact of palm trees.
 
## 3.0 Release Notes
 * Reduced Yeeter Delay
 * Removed a few blocks
 * Added a few yeeters.
 * Make the text fake-AA'd
 * Tried switching to Walkthrough layer
 * Put everything in map in object to cull.
 * Switched back to an explicit render.
 * Switched away from an explicit render to SetReplacementShader.  I promise. It's better.
 * Mention Patreon Notice
 
 
## Interesting
 * shader_billboardout modes.
 * Ben Code Catch.
```glsl
 
for( j = 0; j < 4; j++ )
{
	uint obid;
	if( j == 0 )      obid = _Adjacency0[hashed];
	else if( j == 0 ) obid = _Adjacency1[hashed];
	else if( j == 0 ) obid = _Adjacency2[hashed];
	else              obid = _Adjacency3[hashed];
```
 * Back and forth about rendering technique.

## Special Thanks
 * D4rkPl4y3r for the idea, and several pointers!  Also, the binning principle.
 * ERROR.mdl for the `SV_DepthLessEqual` trick to make unsorted high performance balls.
 * TCL for the multiple render texture trick + the explicit camera order trick.
 * Everyone on the VRC Shader Discord for the 50+ questions I had to ask to write this.

VR Computer RTX 2070, Ryzen 3900X; Index at 144 Hz, 122%. Numbers are minimum times, peak up to about .3ms higher... So, signal in data is pretty good, probably around +/- .2ms. 

Conclusion when doing camera shimshammery: ~~Put cameras and objects on `PickupNoEnvironment`.  Cull for all objects not on `PickupNoEnvironment`~~ Your layers don't matter. 

Numbers with quick menu closed / open / With AudioLink and basic video player
Same layers, PickupNoEnvironment: 7.6ms / 9.3ms
Camera on default, looking at PickupNoEnvironment: 8.2ms / 10.0ms
Camera on UiMenu, looking at UiMenu: 8.1ms / 10.1ms
Camera on default, looking at UiMenu: 8.1 / 10.1 ms
(repeat) Camera on PickupNoEnvironment, looking at PickupNoEnvironment: 7.6ms / 9.4ms
Control: Everything off:  7ms / 7ms (framecap) (1.6ms / 2.5ms)
Control: Only AudioLink: 7ms / 7ms (framecap) (1.8ms / 2.7ms)
(repeat) Camera on PickupNoEnvironment, looking at PickupNoEnvironment: 8.1ms / 9.4ms
Camera on UiMenu, looking at UiMenu: 7.6ms / 9.3ms
