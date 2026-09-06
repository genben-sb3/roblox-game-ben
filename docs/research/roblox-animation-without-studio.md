# Authoring character animation for combat without Roblox Studio

Research note, 2026-09-06. Audience: the agent and Christian. Context:
`roblox-game-ben` is a plant-and-crystal collecting game with 1v1 duels. All
code lives on a headless Linux box and reaches Studio (Ben's Windows PC) over
Rojo live sync. [ADR 0001](../adr/0001-ability-vfx-from-particles-not-meshes.md)
already established that particle/beam/trail VFX is entirely Rojo-syncable text.
This note asks the follow-up question: **can the characters that cast those
abilities be animated from Linux too?**

Companion note: `docs/research/roblox-3d-and-vfx-sources.md` (VFX, meshes,
textures, Open Cloud upload, Rojo sync limits). This one covers only animation
and does not repeat that ground.

## Summary

1. **An `Animation.AnimationId` is always an uploaded Roblox asset.** There is
   no local, file-based animation format the engine will play. Everything else
   in this note is about how that asset gets made and who has to be in front of
   Studio when it does.
2. **The upload no longer needs Studio.** Since 2025-10-23 the Open Cloud Assets
   API accepts `assetType: "Animation"` as an `.rbxm`/`.rbxmx` file containing a
   `KeyframeSequence` or `CurveAnimation`. `asphalt` (the successor to Tarmac)
   already automates exactly this and generates a Luau module of asset IDs. So a
   *pipeline* from Linux exists.
3. **But Roblox warns that files "edited outside of Roblox Studio might not
   upload or function"**, and I could not find a single first-hand report of a
   `.rbxm` *generated* on Linux (Lune, rbx-dom) being uploaded as an Animation
   and playing. This is the one unverified link in the chain, and it needs a
   30-minute spike before anyone plans around it.
4. **Playing a `KeyframeSequence` at runtime without uploading is not possible.**
   `KeyframeSequenceProvider:RegisterKeyframeSequence()` and its modern
   equivalent `AnimationClipProvider:RegisterAnimationClip()` both say, in the
   official reference, that the ID they return "is temporary and cannot be used
   outside of Studio". The Rojo tree syncs a `KeyframeSequence` fine; the engine
   just will not play it.
5. **Procedural animation in pure Luau is fully available and syncs perfectly**
   — and it is the part the agent can genuinely own. The catch is that the rig
   changed underneath us: the **Avatar Joint Upgrade** replaces `Motor6D` with
   `AnimationConstraint` on R15 characters, `C0`/`C1` are now read-only, and the
   supported technique is multiplying into `.Transform` during
   `RunService.PreSimulation` — client-side, with replication done by hand.

---

## 1. How an `AnimationId` is produced

### 1.1 The default path runs through Studio

The [Animation Editor](https://create.roblox.com/docs/animation/editor) is the
first-party authoring tool. Saving an animation "saves it as a KeyframeSequence
object in ServerStorage and adds a reference to your rig object" (the `AnimSaves`
folder); *publishing* is a separate action ("Publish to Roblox" in the media
controls) that produces the asset, after which "you can copy the animation's
asset ID from the Toolbox".

The engine side is deliberately narrow. From the
[`Animation`](https://create.roblox.com/docs/reference/engine/classes/Animation)
reference, `AnimationId` is:

> the asset ID of the animation an `Animation` object is referencing. Once an
> animation has been created and uploaded to Roblox, the ID can be copied from
> the Creator Dashboard.

There is no alternative. `Animator:LoadAnimation()` takes an `Animation`
instance, and that instance carries a `ContentId`
([Use animations](https://create.roblox.com/docs/animation/using)).

### 1.2 A `KeyframeSequence` is just an instance tree

The good news is that the animation *data* is ordinary instances, not an opaque
blob. From the
[`KeyframeSequenceProvider`](https://create.roblox.com/docs/reference/engine/classes/KeyframeSequenceProvider)
reference:

> A `KeyframeSequence` stores a series of `Poses` that encode the hierarchy and
> motion of an animation. […] `KeyframeSequences` are **usually created by the
> Roblox Animation Editor but can be created through other plugins or even
> manually.**

The shape is `KeyframeSequence` → `Keyframe` (with a `Time`) → `Pose` (named
after the rig part, carrying a `CFrame`, `Weight`, `EasingStyle`,
`EasingDirection`) → nested sub-poses. `KeyframeSequence` itself carries `Loop`
and `Priority`, and "the last `Keyframe` in the sequence, meaning the `Keyframe`
with the highest `Time` property, determines the length of an animation"
([`KeyframeSequence`](https://create.roblox.com/docs/reference/engine/classes/KeyframeSequence)).

Every one of those property types (`CFrame`, `float`, `Enum`, `bool`) is a type
Rojo and rbx-dom handle. So the data is expressible as JSON or as an `.rbxmx`,
and it is diffable text.

There is also a newer form: `CurveAnimation`, which like `KeyframeSequence`
inherits from `AnimationClip`
([`CurveAnimation`](https://create.roblox.com/docs/reference/engine/classes/CurveAnimation)).
`AnimationClipProvider` handles both.

### 1.3 Open Cloud accepts Animation uploads — since October 2025

This is the finding that changes the answer. The
[Open Cloud assets guide](https://create.roblox.com/docs/cloud/guides/usage-assets)
now lists **Animation** in its supported-asset-types table:

| Asset type | Format | Content type | Restrictions |
| --- | --- | --- | --- |
| **Animation** | `.rbxm`, `.rbxmx` | `model/x-rbxm` | "`.rbxm` or `.rbxmx` files edited outside of Roblox Studio might not upload or function." |

Same endpoints as for images (`POST https://apis.roblox.com/assets/v1/assets`,
`x-api-key`, 20 MB per request), so the plumbing our VFX note already describes
carries over unchanged.

This was announced on 2025-10-23 in
[Open Cloud Upload Support for More Asset Types](https://devforum.roblox.com/t/open-cloud-upload-support-for-more-asset-types/4022082),
which enables uploads for "`.rbxm` models and animations, as well as Roblox
formatted meshes". The same announcement is explicit about the intended use
case: to "re-upload native data you previously downloaded using Roblox APIs or
Roblox Studio". It also deprecates the legacy
`data.roblox.com/ide/publish/UploadNewAnimation` endpoint that the older
cookie-based uploader tools used.

### 1.4 The tooling already exists

[`asphalt`](https://github.com/jackTabsCode/asphalt) — a Rust CLI, explicitly "a
modern alternative to Tarmac" — lists among its supported asset types:

> - Animations (.rbxm, .rbxmx)
>   - Asphalt detects animations by looking to see if the saved class is a
>     KeyframeSequence or a CurveAnimation. If it isn't, Asphalt will assume it
>     is a Model.

It authenticates with an Open Cloud API key (`asset:read`, `asset:write`), keeps
an `asphalt.lock.toml` you commit, and generates a Luau or TypeScript module of
asset IDs. That is precisely the pattern the VFX note recommends for textures,
extended to animations. It runs on Linux and needs no Studio.

Its predecessor [`bau`](https://github.com/jackTabsCode/bau) did the same job for
Studio-produced `AnimSaves` `.rbxm` files and is archived in favour of asphalt.

To produce the `.rbxm` itself without Studio there is
[Lune](https://lune-org.github.io/docs/api-reference/roblox), whose `roblox`
library offers `Instance.new()` and `serializeModel(instances, xml?)` — i.e. a
standalone Luau runtime on Linux can construct a `KeyframeSequence` tree in
memory and write it out as `.rbxm` or `.rbxmx`.

### 1.5 The caveat that decides this, and what it costs

Two restrictions, both from the Open Cloud assets guide, matter more than
anything else in this section:

- **"`.rbxm` or `.rbxmx` files edited outside of Roblox Studio might not upload
  or function."** Roblox attributes this to "additional processing done by
  Studio". I could not determine what that processing is for animations
  specifically, and no staff reply in the announcement thread clarifies it.
- **"Currently, you can only update the asset content for `.fbx` files."** So
  `PATCH`-ing an existing Animation asset is not possible. **Every iteration on
  an animation produces a brand-new asset ID**, and the generated ID module has
  to be re-committed each time. asphalt's lockfile handles the bookkeeping, but
  the underlying churn is real, and old asset IDs accumulate.

### 1.6 FBX with animation, without Studio: no

Studio's [Importer](https://create.roblox.com/docs/studio/importer) does support
this — "3D model import supports meshes with PBR textures, meshes with rigging,
skinning, and animation data", and `.fbx`/`.gltf` "support […] rigs, avatar
components, animation data".

Open Cloud does not. The `Model` row of the assets table says only that the API
"Imports custom 3D models as a `Model` container containing one or more
`MeshPart` objects", recommends the Studio Importer for anything non-trivial
("The Importer provides a 3D preview, various error-checking, and many
customizable import settings"), and never mentions animation data. **I found no
documented path that turns an FBX animation into an Animation asset without
Studio.**

---

## 2. Can a `KeyframeSequence` be played straight out of the Rojo tree?

Short answer: **no.** The instance syncs; the engine refuses to play it.

### 2.1 What the API actually says

`KeyframeSequenceProvider:RegisterKeyframeSequence(keyframeSequence)` returns a
`ContentId` you can assign to `Animation.AnimationId`. The reference is
unambiguous about its scope:

> Generates a temporary asset ID from a `KeyframeSequence` that can be used for
> **localized testing** of an animation. […] The asset ID generated by this
> function is **temporary and cannot be used outside of Studio**. Developers
> wishing to generate an asset ID that can be used online should upload the
> `KeyframeSequence` to Roblox.

`RegisterActiveKeyframeSequence` is the same function returning an `active://`
URL instead of a hash, with the identical restriction.

The modern replacement is no different.
[`AnimationClipProvider`](https://create.roblox.com/docs/reference/engine/classes/AnimationClipProvider)
"replaces the deprecated `KeyframeSequenceProvider`" and handles both
`KeyframeSequence` and `CurveAnimation`, but `RegisterAnimationClip` and
`RegisterActiveAnimationClip` carry the same sentence verbatim: temporary,
Studio only, upload if you want it online.

Neither method is marked `PluginSecurity` or `RobloxScriptSecurity` — both are
`security: None`, `capabilities: [Animation]`, and callable from ordinary
scripts. The restriction is a runtime one, not a security tag. In practice
developers hit it as an error at play time:

- "RegisterKeyframeSequence can only be called in Studio"
  ([devforum, 2023](https://devforum.roblox.com/t/workaround-for-registerkeyframesequence-only-being-useable-in-studio/2481925))
- "Usage error: RegisterActiveKeyframeSequence can only be used in Solo mode"
  ([devforum, 2024](https://devforum.roblox.com/t/registeractivekeyframesequence-can-only-be-used-in-solo-mode/2852050))
  — and Solo mode no longer exists.

So: `KeyframeSequenceProvider` is *server-and-client callable but Studio-only in
effect*. It is a preview API for animation plugins, not a runtime loader.

### 2.2 What that leaves

`AnimationClipProvider:GetAnimationClipAsync(assetId)` can *download* an
`AnimationClip` from an already-uploaded asset, and a newer
`GetClipEvaluatorAsync(assetId)` returns a `ClipEvaluator` that "samples the clip
at an arbitrary time to produce an animation pose, so you can read animation data
directly instead of playing it back through an `Animator`". Both still start from
an uploaded asset ID, so neither is an escape hatch from the upload — but
`ClipEvaluator` is genuinely interesting for us: it means a small set of
Ben-authored clips can be sampled and recombined by our own Luau code, which is
agent territory. I have not verified `ClipEvaluator`'s availability or behaviour
beyond this reference entry.

The remaining option — reading a `KeyframeSequence` out of the Rojo tree and
applying its poses to the rig ourselves, frame by frame, in Luau — is not
"playing an animation"; it is writing an animation player. That is §3.

---

## 3. Procedural animation: what Luau can do on its own

This is the part that costs nothing in our setup. Luau syncs perfectly, so
anything expressible as code is fully iterable from Linux.

### 3.1 First: the rig changed. `Motor6D` is on the way out

This is the single most important thing to know before writing any procedural
rig code in 2026. Per the
[`Motor6D`](https://create.roblox.com/docs/reference/engine/classes/Motor6D)
reference, Motor6D is now "Superseded by `AnimationConstraint` for
avatar/character rigs" and is "no longer used by default for player characters
when `StarterPlayer.AvatarJointUpgrade` is enabled."

The [Avatar Joint Upgrade](https://devforum.roblox.com/t/avatar-joint-upgrade-for-physically-simulated-character-movement-is-now-live/4298561)
(announced 2026-01-26) replaces R15 joints with `AnimationConstraint` and
`BallSocketConstraint`, enabling ragdoll and force-based movement. The
announcement warns: "Scripts checking `instance:IsA("Motor6D")` will not detect
`AnimationConstraints`. Setting `C0`, `C1`, `Part0`, or `Part1` properties will
error." [Phase 2](https://devforum.roblox.com/t/avatar-joint-upgrade-aju-phase-2-rollout-updated-migration-recommendations/4656414)
(2026-05-27) turns it on for experiences left at `Default`; Phase 3, targeted at
end of 2026, removes the legacy path.

Concretely, from the
[`AnimationConstraint`](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint)
migration notes:

- **Find joints** with `:FindFirstChildWhichIsA("AnimationConstraint")`, not
  `:FindFirstChildOfClass("Motor6D")`.
- **`C0`, `C1`, `Part0`, `Part1` are read-only aliases** mapping to
  `Attachment0.CFrame`, `Attachment1.CFrame` and their parents. "Do not attempt
  to write to them."
- **Do not modify `RigAttachment.CFrame` directly** — "this disrupts animation
  retargeting and causes performance issues."
- **`IsKinematic`** defaults to `true`, which is "equivalent to Motor6D".

**Practical consequence for us: any procedural-animation tutorial or snippet
that sets `Motor6D.C0` is already wrong for a new experience.** Write against
`AnimationConstraint`, with a `Motor6D` fallback only if we ever need it.

### 3.2 The supported technique: multiply into `.Transform` during `PreSimulation`

Both `Motor6D.Transform` and `AnimationConstraint.Transform` are the CFrame "that
is manipulated when [the joint] is being animated. It is recommended to use this
property for custom animations rather than `C0` and `C1`."

The timing matters and the docs spell it out:

> `Motor6D` transforms are not applied immediately, unlike updating `C0` and
> `C1`, but rather as a batch in a parallel job after `RunService.PreSimulation`,
> immediately before physics steps. The deferred batch update is much more
> efficient than many immediate updates.
>
> If the `Motor6D` is part of an animated model with an `Animator`, then
> `Motor6D.Transform` will usually be overwritten every frame by the `Animator`
> after `RunService.PreAnimation` and before `RunService.PreSimulation`.

So the layering pattern, straight from the `AnimationConstraint` docs, is:

```lua
RunService.PreSimulation:Connect(function()
    if not animator.EvaluationThrottled then
        neck.Transform = computeNeckRotation() * neck.Transform
    end
end)
```

Multiplying (rather than assigning) is what makes procedural motion *stack on top
of* whatever animation tracks are playing: "Because `.Transform` is updated
locally by the animation compositor and reset every frame, this approach layers
your procedural math perfectly." This is the single most useful technique in this
whole note for a duelling game — a played clip provides the body, and code adds
aim, lean, recoil and hit reaction on top.

### 3.3 Blending and weights (for the clips that do exist)

`AnimationTrack:Play(fadeTime, weight, speed)` and
`AnimationTrack:AdjustWeight(weight, fadeTime)` let code cross-fade and blend
tracks; `WeightCurrent`/`WeightTarget` expose the fade in progress, `AdjustSpeed`
retimes, `TimePosition` scrubs, `GetMarkerReachedSignal(name)` fires on
[animation events](https://create.roblox.com/docs/animation/events) authored into
the clip, and `Priority` (`Enum.AnimationPriority`) decides which track wins
([`AnimationTrack`](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)).

All of that is code. **Speed, blending, layering, timing, cancel windows and hit
frames are agent-side work even when the clips themselves are not.** For a duel
game where the interesting design question is the Commit Window, that is most of
the actual game feel.

Note the separate, unrelated meaning of "weight" in
[Use animations](https://create.roblox.com/docs/animation/using): the `Animate`
script's `Weight` values are *selection* probabilities among idle variants
("animation weight / total weight of all state animations"), not blend weights.

### 3.4 `IKControl`

[Inverse kinematics](https://create.roblox.com/docs/animation/inverse-kinematics)
is the one first-party procedural-animation feature, and it is pure property
configuration — therefore fully Rojo-syncable and fully agent-authorable. An
`IKControl` parented to the `Humanoid` or `AnimationController` needs four
properties: `Type` (`Enum.IKControlType`; "Common behavior types are `Position`
or `Transform`"), `EndEffector` (a `BasePart` or `Bone`), `Target` ("any object
with a world position") and `ChainRoot`. Everything between `ChainRoot` and
`EndEffector` is solved.

The documented use cases map onto combat directly: "Grab and pose a character's
hand while automatically adjusting the related limbs", "Make a character's feet
interact realistically on different surfaces and slopes". Roblox recommends
adding `Constraints` so elbows and knees bend naturally, and warns that
misconfigured `IKControl`s produce "unexpected and unnatural animation results".

The docs give no explicit performance figures and do not state how `IKControl`
composes with playing animation tracks; I could not confirm either.

### 3.5 `TweenService`

[`TweenService`](https://create.roblox.com/docs/reference/engine/classes/TweenService)
interpolates properties of types including `number`, `boolean`, `CFrame`,
`Color3`, `UDim2`, `Vector3` and `EnumItem`. It is the right tool for *object*
motion — a weapon's `CFrame`, an attachment's position, a UI element, a
telegraph — and for the VFX timing described in the companion note.

It is the wrong tool for a rig. `Transform` is reset by the `Animator` every
frame (§3.2), so a tween writing to it fights the compositor. And "if two tweens
attempt to modify the same property, the initial tween will be cancelled and
overwritten by the most recent tween" — fine for one-shot object motion, bad for
a limb that several systems want to influence.

### 3.6 `AlignPosition` / `AlignOrientation`: wrong layer

These are physics constraints, not animation.
[`AlignPosition`](https://create.roblox.com/docs/reference/engine/classes/AlignPosition)
"applies force to move two attachments together, or to move one attachment to a
goal position"; `AlignOrientation` is its rotational counterpart. They act on the
physics solver via `MaxForce`/`MaxTorque`/`Responsiveness` (or rigidly, with
`RigidityEnabled`).

They are genuinely useful for *whole-body* combat motion — a dash, a pull, a
knockback, a hovering caster, a floating orb that follows the player — and for
ragdoll once `AnimationConstraint.IsKinematic` is `false`. They are not a way to
pose a limb: doing so means fighting the animation compositor with forces, which
is neither precise nor cheap.

### 3.7 The real limits and costs

- **The rig is small, which helps.** A standard R15 character is
  [15 mesh objects](https://create.roblox.com/docs/avatar/character-bodies/specifications)
  plus the `HumanoidRootPart`. Writing a `CFrame` per joint per frame is a
  handful of CFrame multiplications — trivially cheap for one character, and a
  1v1 duel is two.
- **The engine throttles animation, and procedural code must notice.**
  `Animator.PreferLodEnabled` defaults to `true`, meaning "the engine may reduce
  animation evaluation frequency for remotely-simulated characters based on
  distance, screen coverage, and frame budget."
  `Animator.EvaluationThrottled` is the read-only per-frame flag: when `true`,
  "the `Animator` reused the pose from the previous frame instead of evaluating
  fresh animation data", and "applying procedural offsets would fight the stale
  pose and should be skipped". Setting `PreferLodEnabled = false` forces full
  fidelity for important characters — reasonable for the two duellists,
  explicitly discouraged at scale ("disabling LOD for many animators
  simultaneously can impact performance").
  ([`Animator`](https://create.roblox.com/docs/reference/engine/classes/Animator))
- **Procedural motion does not replicate for free.** `Motor6D.Transform` is
  tagged `NotReplicated`, and the AJU migration guidance is explicit: instead of
  driving joints on the server, "replicate a custom Attribute or fire an
  `UnreliableRemoteEvent` to share the target coordinates, then process the
  animation transforms locally." Uploaded animations, by contrast, replicate
  automatically — provided the `Animator` "must be initially created on the
  server and replicated to clients for animation replication to work at all",
  and provided that for player characters the track is started on that player's
  own client ([`Animation`](https://create.roblox.com/docs/reference/engine/classes/Animation)).
  **This is a real architectural cost: every procedural effect we want other
  players to see is a small networking design problem, where a played clip is
  not.**
- **`RigAttachment.CFrame` is off limits** (§3.1) — animation retargeting depends
  on it, and moving it constantly "can cause performance problems".
- **I found no published per-frame cost figures** for driving a Roblox rig
  procedurally. Anything quantitative would have to come from our own
  measurement.

---

## 4. Rojo sync limits specific to animation

I went looking for an animation-shaped equivalent of the `MeshPart.MeshId` wall
and **did not find one.**

[Rojo's sync details](https://rojo.space/docs/v7/sync-details/) still name only
three cases that cannot be synced in real time — binary data (Terrain, CSG
parts), `MeshPart.MeshId`, and `HttpService.HttpEnabled` — and refer out to
rbx-dom's type coverage chart for the rest. No animation class or property
appears. A search of the `rojo-rbx/rojo` issue tracker for `KeyframeSequence`
returns zero results, and for `animation` returns four unrelated issues (init
files, patch parenting, and two settings PRs).

Reasoning from the property types involved:

- `Animation.AnimationId` is a `ContentId` — an ordinary string. It syncs like a
  particle `Texture` does. Setting an animation's ID from a `.model.json` is
  fine.
- `KeyframeSequence` / `Keyframe` / `Pose` are all creatable classes whose
  properties are `CFrame`, `float`, `bool` and `Enum` — types rbx-dom and the
  plugin API handle. A whole `KeyframeSequence` tree should live-sync as a
  normal instance tree. **This is untested by us**, and it is worth noting that
  it buys nothing on its own (§2).
- One property to watch: `KeyframeSequence.AuthoredHipHeight` is `Hidden` with
  `security: {read: PluginSecurity, write: PluginSecurity}`. The Rojo plugin runs
  with plugin permissions so it should be settable, but this is exactly the
  shape of thing that turns into a `MeshId`-style surprise. Default is `1.35`
  for a standard R15 character.
- `Motor6D.Transform` / `AnimationConstraint.Transform` are `Hidden`,
  `NotReplicated` and not serializable (`can_save: false`) — they are runtime
  state, not something to put in a project file at all.

The genuinely Studio-shaped artefacts are conventions, not sync limits: the
`AnimSaves` folder the Animation Editor writes into `ServerStorage`, and the
default `Animate` script inside a character.

---

## 5. What I could not confirm

Stated plainly, because these are the things that would change the conclusion:

1. **Whether a `.rbxm` generated on Linux (Lune / rbx-dom) uploads successfully
   as an Animation and plays in-game.** Roblox's own restriction line says files
   "edited outside of Roblox Studio might not upload or function", and no staff
   post in the announcement thread explains what Studio's "additional
   processing" does for animations. I found no first-hand success or failure
   report either way. **This is a one-afternoon spike, and it is the highest-value
   unknown in this note.**
2. **Whether Open Cloud's `Model` upload extracts animation data from an FBX.**
   The docs describe only a `Model` of `MeshPart`s. Probably not; unverified.
3. **Whether Animation assets are subject to the Restricted/Open Use privacy
   regime** that bites us on images and meshes. The
   [asset privacy](https://create.roblox.com/docs/projects/assets/privacy) docs
   name images, decals and meshes; they do not mention animations. Unknown.
4. **Moderation behaviour and rate limits for Animation uploads.** The assets
   table gives per-month upload caps for audio and video but lists none for
   Animation. Whether an unlisted cap exists, I don't know.
5. **`ClipEvaluator`'s real availability and behaviour** — it appears in the
   `AnimationClipProvider` reference but I found no announcement or usage
   examples.
6. **The exact current default of `StarterPlayer.AvatarJointUpgrade`.** The
   `Motor6D` and `AnimationConstraint` reference pages describe the upgraded
   joints as "the default for new experiences"; the January 2026 announcement
   said the property ships `Disabled`; the May 2026 Phase 2 post says experiences
   left at `Default` now get the new system. Whatever the precise state, code
   should handle both joint types.
7. **Whether Rojo can write `KeyframeSequence.AuthoredHipHeight`** (PluginSecurity).
8. **Any quantitative per-frame cost** of procedural rig animation.

---

## What this means for the two-machine setup

**A fully animated duel is *not* affordable from Linux alone — but it is much
closer than the mesh situation, and the split is small and one-directional.**

The honest reading of §1 is that the *pipeline* is solved and the *authoring* is
not. Open Cloud will take an Animation asset from a `curl` on the claudebox, and
asphalt already automates it end to end. What no tool solves is that a
good-looking combat animation is a human posing a rig against a timeline. Hand-
writing `Pose.CFrame` values for fifteen joints across a dozen keyframes is
technically possible and practically hopeless — the agent has no viewport and
can never see the result, which is exactly the constraint that made ADR 0001
choose particles over meshes. The same logic applies here, and it points the
other way: for *keyframed* animation, Studio is genuinely load-bearing.

The cheapest workable split:

**Ben, in Studio (rare, batched):**
- Author base clips in the Animation Editor: idle, a cast pose per ability
  archetype, a hit reaction, a block, a dodge. A dozen short clips, not a
  library.
- Save each one as `.rbxm` into `art/anim/` in the repo (right-click the
  `KeyframeSequence` → Save to File). **He does not publish them and does not
  paste IDs.** The `.rbxm` is the hand-off artefact; from that point the agent
  owns everything.
- Repeat only when the game needs a genuinely new body pose.

**The agent, on Linux (constant):**
- Upload and version those `.rbxm` files with asphalt via Open Cloud, and commit
  the generated ID module. Note that no in-place update exists — each re-upload
  is a new asset ID, which is exactly why this should be automated and never
  manual.
- Own all of the timing: which track plays, at what `speed`, blended with what
  `fadeTime` and `weight`, at what `Priority`, cancelled on which frame,
  with hit windows driven by `GetMarkerReachedSignal`. This is where duel feel
  actually lives, and it is 100% Luau.
- Own all procedural motion layered on top: aim, lean, recoil, knockback,
  hit reactions, look-at — by multiplying into `AnimationConstraint.Transform`
  during `PreSimulation`, guarded by `EvaluationThrottled`.
- Own `IKControl` configuration (pure properties, pure `.model.json`) for
  hand-to-target and foot-to-ground.
- Own all VFX, per ADR 0001.

**Before committing to that split, run one spike** (§5.1): have Lune build a
trivial two-keyframe `KeyframeSequence`, upload it with asphalt, and have Ben
play it once. If it works, the Studio dependency shrinks to "Ben authors clips
because he can see them", not "Ben is required by the toolchain" — and the door
opens to generating variants (mirrored, retimed, additive offsets) as data from
Linux. If it fails, nothing above changes: Ben's `.rbxm` files came out of
Studio and upload on the supported path.

**And there is a real design option worth naming:** a duel where abilities read
as *poses plus VFX* rather than full-body animation needs very few authored
clips. Given that the defender has to recognise an incoming Ability inside a
Commit Window, a small set of highly readable cast poses is arguably better
design than a large set of elaborate ones — and it happens to be the cheapest
thing to build with a headless agent and a Windows PC in another room.

---

## Sources

**Roblox engine reference**

- [`Animation`](https://create.roblox.com/docs/reference/engine/classes/Animation)
- [`AnimationTrack`](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)
- [`Animator`](https://create.roblox.com/docs/reference/engine/classes/Animator)
- [`KeyframeSequence`](https://create.roblox.com/docs/reference/engine/classes/KeyframeSequence)
- [`KeyframeSequenceProvider`](https://create.roblox.com/docs/reference/engine/classes/KeyframeSequenceProvider)
- [`AnimationClipProvider`](https://create.roblox.com/docs/reference/engine/classes/AnimationClipProvider)
- [`CurveAnimation`](https://create.roblox.com/docs/reference/engine/classes/CurveAnimation)
- [`Motor6D`](https://create.roblox.com/docs/reference/engine/classes/Motor6D)
- [`AnimationConstraint`](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint)
- [`IKControl`](https://create.roblox.com/docs/reference/engine/classes/IKControl)
- [`TweenService`](https://create.roblox.com/docs/reference/engine/classes/TweenService)
- [`AlignPosition`](https://create.roblox.com/docs/reference/engine/classes/AlignPosition)
- [`AlignOrientation`](https://create.roblox.com/docs/reference/engine/classes/AlignOrientation)

**Roblox guides**

- [Animation in Roblox](https://create.roblox.com/docs/animation)
- [Animation Editor](https://create.roblox.com/docs/animation/editor)
- [Use animations](https://create.roblox.com/docs/animation/using)
- [Animation events](https://create.roblox.com/docs/animation/events)
- [Inverse Kinematics](https://create.roblox.com/docs/animation/inverse-kinematics)
- [Importer](https://create.roblox.com/docs/studio/importer)
- [Character body specifications](https://create.roblox.com/docs/avatar/character-bodies/specifications)
- [Open Cloud — usage guide for assets](https://create.roblox.com/docs/cloud/guides/usage-assets)
- [Asset privacy](https://create.roblox.com/docs/projects/assets/privacy)

**DevForum announcements and threads**

- [Open Cloud Upload Support for More Asset Types (2025-10-23)](https://devforum.roblox.com/t/open-cloud-upload-support-for-more-asset-types/4022082)
- [Avatar Joint Upgrade is now live (2026-01-26)](https://devforum.roblox.com/t/avatar-joint-upgrade-for-physically-simulated-character-movement-is-now-live/4298561)
- [Avatar Joint Upgrade Phase 2 — migration recommendations (2026-05-27)](https://devforum.roblox.com/t/avatar-joint-upgrade-aju-phase-2-rollout-updated-migration-recommendations/4656414)
- [Workaround for RegisterKeyframeSequence only being useable in Studio](https://devforum.roblox.com/t/workaround-for-registerkeyframesequence-only-being-useable-in-studio/2481925)
- [RegisterActiveKeyframeSequence can only be used in Solo mode](https://devforum.roblox.com/t/registeractivekeyframesequence-can-only-be-used-in-solo-mode/2852050)
- [KeyframeSequence Uploader](https://devforum.roblox.com/t/keyframesequence-uploader/4675227)

**Tooling**

- [Rojo — sync details](https://rojo.space/docs/v7/sync-details/)
- [Rojo — properties](https://rojo.space/docs/v7/properties/)
- [asphalt](https://github.com/jackTabsCode/asphalt)
- [bau (archived)](https://github.com/jackTabsCode/bau)
- [Lune — roblox library](https://lune-org.github.io/docs/api-reference/roblox)
