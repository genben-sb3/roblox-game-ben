# Sourcing 3D models and ability VFX for a Roblox game

Research note, 2026-09-06. Audience: the agent and Christian. Context:
`roblox-game-ben` is a plant-and-crystal collecting game with 1v1 duels where
Abilities have to look as good as possible. Code lives on a headless Linux box
and reaches Studio (Ben's Windows PC) over Rojo live sync.

## Summary

1. **Good Roblox ability VFX is not bought, it is assembled in-engine.** The
   visual quality comes from `ParticleEmitter`, `Beam`, `Trail` and `Attachment`
   objects tuned against a handful of small textures, plus Luau code that emits
   and tweens them. Asset packs sell you the *textures*; the *effect* is
   properties. This is very good news for us.
2. **Almost all of that is plain text we can commit to git.** Every
   `ParticleEmitter`/`Beam`/`Trail` property — including `ColorSequence`,
   `NumberSequence`, `NumberRange`, `Enum` and the texture *reference* — is
   expressible in a Rojo `.model.json` file and live-syncs into Studio.
3. **What cannot live in git is the pixel data.** A particle texture, a flipbook
   sheet and a mesh must be uploaded to Roblox and referred to by
   `rbxassetid://…`. That upload does **not** need Studio: the Open Cloud Assets
   API takes a PNG over `curl` from the Linux box.
4. **The one hard wall in our setup is meshes.** `MeshPart.MeshId` is on Rojo's
   list of properties that cannot be set over live sync. Particle-, beam- and
   trail-based VFX live-sync perfectly; mesh-based VFX does not. So: build
   Abilities out of particles/beams/trails first.
5. **Fastest path to a good-looking ability for a beginner:** open a free
   open-source VFX pack in Studio, look at how its emitters are configured,
   then rebuild that configuration as a `.model.json` in the repo. Copying
   numbers is a legitimate and fast way to learn VFX.

---

## 1. Where 3D models and VFX actually come from

### 1.1 Roblox Creator Store (the primary source)

The [Creator Store](https://create.roblox.com/docs/production/creator-store) is
Roblox's own marketplace, reachable both on the web and from the Toolbox inside
Studio. It carries Models, Plugins, Meshes, Decals/Images, Audio, Fonts, Video
and — relevant to us — a dedicated
[Visual Effects](https://create.roblox.com/store/category/visual-effects)
category with a
[Particle Effects](https://create.roblox.com/store/category/visual-effects/particle-effects)
subcategory.

- Free and paid coexist. Paid models are priced 2.99–49.99 USD, paid plugins
  4.99–249.99 USD, and sellers keep 100% of net proceeds.
- It is the only source where an asset already *is* a Roblox asset ID — nothing
  to upload, nothing to moderate, it just works.

### 1.2 Roblox's own first-party content

Roblox itself publishes free assets into the Creator Store (material packs,
sample environments, the Studio starter templates). These are the safest
possible option licensing-wise and are worth checking first.

### 1.3 External marketplaces

Sketchfab, itch.io, Gumroad, BuiltByBit, Quixel-style libraries and Blender
assets all work *as source files* — you export FBX/glTF/OBJ and import. Two
things to keep in mind:

- **They are not Roblox assets until you upload them.** Everything from outside
  has to pass through the importer or the Open Cloud API, and then through
  moderation (see §5).
- **The licence has to survive the trip.** See §5.

Named examples that come up repeatedly for VFX:

- [Brackeys' VFX Bundle](https://brackeysgames.itch.io/brackeys-vfx-bundle) —
  particle textures, flipbooks and pre-drawn spritesheets, pay-what-you-want.
  Engine-agnostic PNGs, so they import into Roblox fine.
- [itch.io VFX category](https://itch.io/c/6795196/vfx).

### 1.4 Format and budget constraints

From
[Roblox's mesh specifications](https://create.roblox.com/docs/art/modeling/specifications):

| Constraint | Value |
| --- | --- |
| Triangles per mesh | **max 20,000** ("Individual meshes can not exceed 20,000 triangles") |
| Bone influences per vertex | max 4 |
| Animation tracks per exported mesh | 1 |
| Export transform | scale `1,1,1`, rotation `0,0,0`, root at origin |

From
[texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications):

| Constraint | Value |
| --- | --- |
| Max texture resolution | **4096 × 4096** |
| Recommended | 256² for a 5×5-stud object, 512² for 10×10, 1024² for 20×20 |
| Formats | `.png`, `.jpg`, `.tga`, `.bmp` |
| Materials per mesh object | 1 |
| UV space | single UV set, 1024×1024 |
| PBR maps (`SurfaceAppearance`) | Albedo RGB 24-bit, Normal RGB 24-bit OpenGL tangent space, Roughness/Metalness/Emissive single-channel 8-bit |

Import formats accepted by the Open Cloud Assets API for the `Model` type:
`.fbx`, `.gltf`, `.glb`, `.rbxm`, `.rbxmx`. Images: `.png`, `.jpeg`, `.bmp`,
`.tga`, under 8000×8000 px. Max 20 MB per upload request.
([Open Cloud assets](https://create.roblox.com/docs/cloud/guides/usage-assets))

---

## 2. How good Roblox ability VFX is actually made

**It is built in-engine, not bought.** The tutorials and the plugin ecosystem
both point the same way: the artistry is in property tuning, layering and
timing, and the purchased/downloaded part is a small library of grayscale or
coloured PNGs.

### 2.1 The four building blocks

**`ParticleEmitter`** —
[docs](https://create.roblox.com/docs/effects/particle-emitters). Emits 2D
images. The properties that carry the look:

- `Texture` — a `Content` string; ".png format with a transparent background"
  works best.
- `Color` (`ColorSequence`) and `Transparency` (`NumberSequence`) — the gradient
  over the particle's life. Fading out at both ends is what stops particles
  "popping".
- `Size` (`NumberSequence`), `Squash` (`NumberSequence`).
- `LightEmission` (0 = normal blending, 1 = additive) and `Brightness` — this
  pair is what makes an effect look *glowing* rather than *pasted on*. Additive
  blending is most of the "punchy" look.
- `Rate` (max 400 desktop / 100 mobile), `Lifetime` (capped at 20 s), `Speed`,
  `SpreadAngle`, `EmissionDirection`, `Acceleration`, `Drag`, `Rotation`.
- `Shape` (Box/Sphere/Cylinder/Disc), `ShapeStyle` (Volume/Surface),
  `ShapeInOut` (Inward/Outward/InAndOut) — emit from a sphere surface outward
  and you have a shockwave without writing any code.
- `Orientation` — `FacingCamera`, `FacingCameraWorldUp`, `VelocityParallel`,
  `VelocityPerpendicular`. `VelocityParallel` is what makes sparks streak.
- **Flipbooks**: `FlipbookLayout` (2×2, 4×4, 8×8 or custom grid),
  `FlipbookFramerate` (max 30 fps), `FlipbookMode`, `FlipbookStartRandom`. One
  texture atlas animates over the particle lifetime. This is how explosions and
  smoke puffs stop looking like static blobs. See the
  [flipbook release announcement](https://devforum.roblox.com/t/particles-flipbook-release/2029388).

**`Beam`** —
[docs](https://create.roblox.com/docs/effects/beams). Renders a texture between
two `Attachment`s, along a cubic Bézier controlled by `CurveSize0`/`CurveSize1`.
Key properties: `Texture`, `TextureMode` (Wrap/Static/Stretch), `TextureSpeed`,
`Width0`/`Width1`, `Color` (`ColorSequence`), `Transparency` (`NumberSequence`),
`LightEmission`, `FaceCamera`, `Segments`. Beams are how you get beam attacks,
lightning arcs, tether/link effects and energy ribbons.

**`Trail`** — a ribbon following two attachments as they move. This is the
sword-swing / projectile-tail effect.

**`Attachment`** — the mount point. Everything above lives on an attachment, and
moving the attachment (by tween or by welding it to a limb) is how an effect
follows a cast.

**Luau code** — spawning the effect, `:Emit(n)` bursts, tweening attachment
positions, timing the layers, cleaning up. This is where a "cast" becomes a
sequence rather than a loop.

### 2.2 What the community resources actually are

Nearly all the well-regarded free VFX resources are **libraries of textures and
pre-configured emitters you learn from**, not black boxes:

| Resource | What it is | Cost |
| --- | --- | --- |
| [Yuruzuu's Open Source VFX](https://devforum.roblox.com/t/yuruzuus-open-source-vfx/1840021) | Customisable open-source effects, explicitly meant for learning ParticleEmitters | Free |
| [CIX Library](https://devforum.roblox.com/t/over-600-free-particle-with-cix-library-a-particle-library-plugin/2864815) | Studio plugin, 600+ particles, open-source textures, dockable browser | Free |
| [VFX Texture Share](https://create.roblox.com/store/asset/72922819641120/VFX-Texture-Share) | Plugin collecting ~445 flipbook/particle textures, GitHub-backed | Free |
| [Open-Source Mesh Flipbook Pack](https://devforum.roblox.com/t/open-source-mesh-flipbook-pack/3635032) | Mesh flipbooks by the VFX artist "Pew" | Free |
| [2 Free Realistic Flipbook Particle Explosions](https://devforum.roblox.com/t/2-free-realistic-flipbook-particle-explosions/3035597) | Explosion flipbooks, no credit required | Free |
| [VFX Suite](https://devforum.roblox.com/t/introducing-the-vfx-suite-plugin/2545686) | Better `Emit`, sequence copier, Bézier graph editor for particles/beams/trails | Plugin |
| [VFX Forge](https://devforum.roblox.com/t/plugin-vfx-forge-an-advanced-custom-vfx-system/3867553) | Particles, beams, trails, mesh VFX, decal/beam flipbooks, 3D Béziers, lightning | Plugin |
| [Beziers](https://devforum.roblox.com/t/beziers-advanced-modular-vfx-plugin-10000-assets-add-ons/4180222) | Paid plugin, ~10,000 open-source assets (8,336 particles, 925 beams, 77 meshes, 39 mesh flipbooks) | Paid |
| [Brackeys' VFX Bundle](https://brackeysgames.itch.io/brackeys-vfx-bundle) | Engine-agnostic particle textures and spritesheets | Pay-what-you-want |

Tutorials worth reading:
[Introduction to VFX: Particles](https://devforum.roblox.com/t/introduction-to-vfx-particles/2068650)
and
[Full Beginner's Guide on scripting Anime/Fighting VFX](https://devforum.roblox.com/t/full-beginners-guide-on-scripting-animefighting-vfxvisual-effects-part-1/1610853).
The first is honest that "VFX takes years to learn and master" — but it also
shows that a *decent* effect is roughly a dozen property values.

### 2.3 About the "Rivals" look specifically

Rivals is by Nosniy Games (also Treasure Quest, Super Golf), released
2024-06-28 ([wiki](https://robloxrivals.fandom.com/wiki/Roblox_Rivals_Wiki)).
There is no published breakdown of its VFX pipeline. What the look consists of,
mechanically, is reproducible with the primitives above:

- **Flat, saturated colour ramps** — short `ColorSequence`s with 2–3 keypoints,
  not photographic gradients.
- **High `LightEmission`** (near 1) so effects read as light, not as decals.
- **Hard silhouettes** — crisp-edged textures rather than soft smoke blurs.
- **Short lifetimes with strong `Size` curves** — grow fast, shrink out. Punch
  comes from the *speed of the size curve*, not from particle count.
- **Readability first** — one dominant shape per ability so a duelling opponent
  can identify the incoming Ability in a Commit Window. For our game this is not
  just aesthetic: the defender has to recognise the Ability to pick an Answer.
- **Layering** — a core flash + a ring/shockwave + streaking sparks + a light
  source, each its own emitter, offset in time.

There is also a community asset dump for Rivals GFX at
[squidward5/Roblox-Rivals-Assets](https://github.com/squidward5/Roblox-Rivals-Assets)
— useful as reference imagery, **not** as assets to ship (see §5).

---

## 3. Difficulty for a beginner

Ranked by time-to-first-good-looking-ability:

**1. Configure a `ParticleEmitter` from an existing free pack — hours, not days.**
Insert one of the open-source packs in Studio, find an effect that is close,
read off its property values, and rebuild it in the repo. Realistically Ben can
have something that genuinely looks good the same afternoon. There is no
modelling, no texturing, no external software.

**2. Layer 2–4 emitters plus a `Beam`, driven by a Luau cast sequence — days.**
This is where the jump from "a particle effect" to "an ability" happens, and it
is mostly *timing*, which is code — Christian's half of the work.

**3. Author your own particle textures — a weekend of Photoshop/Krita/GIMP.**
A soft radial glow, a ring, a spark streak and a 4×4 smoke flipbook cover most
needs. Grayscale PNGs tinted by `ColorSequence` are more flexible than coloured
ones.

**4. Buy or download 3D models for the world (plants, crystals) — easy, but blocked
by the mesh live-sync wall (see §4).**

**5. Model your own meshes in Blender — weeks.** Not the place to start.

**Recommendation:** start at 1, move to 2. Treat 3 as an upgrade path once an
ability's *shape* is settled. Ability visual quality is our core reward, and
tuning numbers on an existing emitter is by far the highest quality-per-hour
lever available.

---

## 4. What can live in git, and what must live on Roblox

This is the decisive question for our two-machine setup. The dividing line is
sharp:

> **Structure and properties are source code. Pixel and vertex data are assets.**

### 4.1 Rojo-syncable — commit this to the repo

Everything here is text, diffable, reviewable and reaches Studio over
`rojo serve` without anyone touching a menu.

| Thing | How it lives in git |
| --- | --- |
| Luau code that plays effects | `src/**/*.luau` |
| The whole instance tree of an effect (`Attachment` → `ParticleEmitter` + `Beam` + `Trail`) | a `.model.json` file |
| Every scalar property (`Rate`, `Lifetime`, `Speed`, `SpreadAngle`, `LightEmission`, `Brightness`, `Drag`) | `$properties` in the `.model.json` |
| `ColorSequence`, `NumberSequence`, `NumberRange`, `Color3`, `Vector3`, `CFrame`, `Enum` values | native JSON forms — see below |
| The **reference** to a texture (`Texture = "rbxassetid://12345"`) | a `Content` string, i.e. just text |
| Whole models exported from Studio | `.rbxmx` (XML — text, diffable) or `.rbxm` (binary) |

Rojo's [property format](https://rojo.space/docs/v7/properties/) supports
`ColorSequence`, `NumberSequence`, `NumberRange`, `Color3`, `Content`, `Enum`,
`CFrame`, `Vector3`, `Font`, `Tags`, `Attributes` and more. The two that matter
most for VFX:

```json
{
  "ClassName": "ParticleEmitter",
  "Properties": {
    "Texture": "rbxassetid://12345678",
    "LightEmission": 1,
    "Rate": 0,
    "Lifetime": { "NumberRange": [0.35, 0.6] },
    "Color": {
      "ColorSequence": {
        "keypoints": [
          { "time": 0.0, "color": [1.0, 0.95, 0.6] },
          { "time": 1.0, "color": [0.9, 0.2, 0.05] }
        ]
      }
    },
    "Size": {
      "NumberSequence": {
        "keypoints": [
          { "time": 0.0, "value": 0.5, "envelope": 0.0 },
          { "time": 0.3, "value": 4.0, "envelope": 0.5 },
          { "time": 1.0, "value": 0.0, "envelope": 0.0 }
        ]
      }
    }
  }
}
```

(Root keys are PascalCase: `ClassName`, `Name`, `Properties`, `Children`. A
real Ability would be a `Folder` or `Attachment` with a `Children` array holding
several emitters plus a `Beam`.)

That means **an entire Ability's visual definition can be a reviewed, versioned
file in this repo**, and the agent can iterate on it without ever opening
Studio. Ben hits play and sees the change.

### 4.2 Roblox-hosted — must be uploaded and referenced by asset ID

| Thing | Why | What ends up in git |
| --- | --- | --- |
| Particle texture PNG | image bytes are not a property | the ID string only |
| Flipbook sprite sheet PNG | same | the ID string only |
| Beam / Trail texture PNG | same | the ID string only |
| Mesh geometry (FBX/OBJ/glTF) | `MeshPart.MeshId` points at a Roblox mesh asset | the ID string only |
| `SurfaceAppearance` maps | same | the ID strings only |
| Audio | same | the ID string only |

There is no way around this: at runtime the Roblox client fetches these from
Roblox's CDN. A local `.png` in the repo is invisible to a running game.

### 4.3 But uploading does **not** require Studio

This is the part that unblocks us. The
[Open Cloud Assets API](https://create.roblox.com/docs/cloud/guides/usage-assets)
takes uploads over plain HTTP from any Linux box:

- `POST https://apis.roblox.com/assets/v1/assets` — create
- `PATCH https://apis.roblox.com/assets/v1/assets/{assetId}` — update
- `GET https://apis.roblox.com/assets/v1/operations/{operationId}` — poll result

Auth is an API key in an `x-api-key` header, created on the Creator Dashboard
with the `assets` permission set to Read *and* Write for our universe (OAuth
with `asset:read` / `asset:write` also works). Max 20 MB per request.

```bash
curl --location 'https://apis.roblox.com/assets/v1/assets' \
  --header "x-api-key: ${ROBLOX_API_KEY}" \
  --form 'request="{
    \"assetType\": \"Decal\",
    \"displayName\": \"fx_spark_core\",
    \"description\": \"Particle texture\",
    \"creationContext\": { \"creator\": { \"userId\": \"'"${USER_ID}"'\" } }
  }"' \
  --form 'fileContent=@"./art/fx_spark_core.png";type=image/png'
```

The response is a long-running operation; poll it, and the result carries the
asset ID **and** a `moderationResult` field.

Two caveats worth knowing:

- `assetType: "Mesh"` accepts *Roblox-format* mesh data only. To get geometry in
  from Blender you upload `assetType: "Model"` with an `.fbx`/`.glb`, which
  creates a Model containing `MeshPart`s.
- The upload is attributed to a user or group; the resulting image/mesh asset
  defaults to **Restricted** privacy (see §5.2), so the experience needs
  permission granted before it will load.

[Tarmac](https://github.com/rojo-rbx/tarmac) automates the whole image side:
it watches a directory of PNGs, uploads changed ones, and **generates a Luau
module mapping paths to asset IDs** (`return { fx = { spark = "rbxassetid://238549023" } }`)
which is then a normal committed file that Rojo syncs. It authenticates with a
`.ROBLOSECURITY` cookie via `--auth`, which is the older mechanism — an Open
Cloud API key script is the more durable choice today, but Tarmac's *shape*
(local file → upload → generated ID module in git) is exactly the pattern we
want.

### 4.4 The one wall in our exact setup: MeshPart live sync

[Rojo's sync details](https://rojo.space/docs/v7/sync-details/) state that "not
all property types can be synced by Rojo in real-time due to limitations of the
Roblox Studio plugin API", and name three cases:

- binary data (Terrain, CSG parts)
- **`MeshPart.MeshId`**
- `HttpService.HttpEnabled`

`MeshId` is not writable from a plugin, so `rojo serve` cannot create a
`MeshPart` with its mesh attached. See
[rojo#286](https://github.com/rojo-rbx/rojo/issues/286),
[rojo#410](https://github.com/rojo-rbx/rojo/issues/410) and
[rojo#1182](https://github.com/rojo-rbx/rojo/issues/1182) (MeshParts arriving
with empty mesh data on reconnect).

Consequences for us:

- **Particle / Beam / Trail VFX live-syncs fully.** Every property involved is
  scriptable. This is the strongest possible argument for building Abilities out
  of these three and not out of mesh VFX.
- **Mesh-based content does not live-sync.** For world props (plants, crystals)
  the workaround is to keep them in Studio's own place file rather than in the
  Rojo tree, or to have Ben insert them once in Studio and save the model as
  `.rbxmx` into the repo — the built place file gets the `MeshId` correctly even
  though live sync does not.

### 4.5 Headless publishing

`rojo build` writes an `.rbxl`/`.rbxlx`, and Open Cloud can publish it without
Studio:

```
POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published
```

with `x-api-key`, the `universe-places` permission with Write, and
`Content-Type: application/octet-stream` for `.rbxl` (or `application/xml` for
`.rbxlx`).
([place publishing docs](https://create.roblox.com/docs/cloud/guides/usage-place-publishing))

**Important limitation:** the place publishing API "doesn't update certain
instance types" — `EditableImage`, `EditableMesh`, `PartOperation`,
`SurfaceAppearance` and `BaseWrap` must be published from Studio. Practical
reading for us: **avoid `SurfaceAppearance` and unions (CSG) in anything we
intend to ship from the Linux box.** Plain `Texture`/`Decal` on MeshParts, and
plain Parts instead of unions.

### 4.6 The workflow this implies

1. Art (PNG textures, FBX meshes) lives in `art/` in the repo as *build inputs*,
   not as runtime assets.
2. An upload step (Open Cloud API key from CI or from claudebox) pushes changed
   art to Roblox and writes the resulting IDs into a committed Luau module.
3. VFX definitions are `.model.json` files referencing those IDs.
4. `rojo serve` gives Ben the whole thing live in Studio; `rojo build` +
   Open Cloud publishes.

Step 2 is the only step that needs a secret, and it is Christian's to set up.

---

## 5. Licensing and moderation gotchas

### 5.1 Creator Store assets

- Assets you take from the Creator Store are covered by Roblox's
  [limited use license](https://create.roblox.com/docs/resources/limited-use-license):
  use is "solely … for the purpose of internally incorporating the Licensed
  Software into your larger applications for deployment through the Roblox
  platform". In plain terms: **use it in your Roblox game, do not take it
  elsewhere, do not resell it, do not strip attribution.**
- You can distribute copies to collaborating developers who accept the same
  license. You cannot sublicense independently.
- If you publish an asset yourself, everything you distribute must comply with
  the Community Rules, Terms of Use and the DMCA.
- Composite models: you may not distribute a model that contains **Restricted**
  assets you did not create.

### 5.2 Asset privacy (this will bite us)

[Asset privacy docs](https://create.roblox.com/docs/projects/assets/privacy):

- Images, Decals and Meshes have a privacy state: **Restricted** (only creators
  or games with explicit permission may use them) or **Open Use** (anyone).
- Roblox checks permissions on Restricted assets every time they load — "if a
  creator or game doesn't have your explicit permission to use an asset, it
  cannot load in Studio or at runtime". A texture that silently fails to appear
  is usually this.
- Newly created images/meshes/decals now default to Restricted, so **after every
  Open Cloud upload we must grant our universe access** (Creator Dashboard, or
  the Asset Manager for bulk grants).
- **Open Use is one-way**: once set, it cannot be reverted to Restricted. And a
  permission granted to a game cannot be revoked.

### 5.3 Externally-sourced models

- Roblox's position is unambiguous: do not upload content you do not own or do
  not have permission to use; infringement violates the Terms of Use and the
  law. Roblox removes infringing content and can suspend or terminate repeat
  infringers' accounts.
  ([Roblox Terms of Use](https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use),
  [IP guidance](https://create.roblox.com/docs/marketplace/intellectual-property))
- **Attribution is not a licence.** Crediting the author does not grant rights
  you were not given.
- Practical licence triage for anything from Sketchfab / itch.io / Gumroad:
  - **CC0 / public domain** — safe.
  - **CC-BY** — permitted, but you must actually satisfy the attribution term,
    and there is nowhere natural in a Roblox game to put credits other than a
    UI panel. Build one if you use CC-BY.
  - **CC-BY-NC / NC-ND** — avoid. A Roblox experience with Robux monetisation is
    commercial, and Roblox's own terms require you to grant Roblox a broad
    licence over what you upload, which an ND term cannot support.
  - **"Roblox-ready" packs sold on BuiltByBit/Gumroad** — read the seller's
    terms; most permit use in one game but not redistribution.
- Fan content (anything recognisably from an existing game, anime or brand) is
  a takedown risk regardless of who modelled it. That includes the Rivals asset
  dump linked in §2.3 — reference only.

### 5.4 Moderation of uploaded textures and meshes

- Images, meshes, audio and video uploaded to Roblox go through an **automatic
  multi-step review before appearing on the platform**; audio is additionally
  scanned for IP infringement, images for CSAM and other prohibited content.
  Unflagged content can still be reviewed by humans if reported.
  ([Content Moderation on Roblox](https://en.help.roblox.com/hc/en-us/articles/21416271342868-Content-Moderation-on-Roblox))
- Extra rules apply to uploaded assets specifically: "realistic or excessive
  depictions of violence, blood, crude humor, or romantic themes may be
  moderated regardless of your experience's content maturity label."
  ([content maturity](https://create.roblox.com/docs/production/promotion/content-maturity))
  For an ability-based duelling game this is worth internalising: **stylised
  energy effects pass; realistic blood and gore do not.** Our chosen art
  direction is also the safe one.
- Uploads via Open Cloud return a `moderationResult` in the operation response,
  so an upload script can detect rejection automatically.
- Decisions can be appealed.

---

## Sources

- [Creator Store](https://create.roblox.com/docs/production/creator-store)
- [Creator Store — Visual Effects](https://create.roblox.com/store/category/visual-effects)
- [Limited use license](https://create.roblox.com/docs/resources/limited-use-license)
- [Asset privacy](https://create.roblox.com/docs/projects/assets/privacy)
- [Mesh specifications](https://create.roblox.com/docs/art/modeling/specifications)
- [Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications)
- [ParticleEmitter](https://create.roblox.com/docs/effects/particle-emitters)
- [Beams](https://create.roblox.com/docs/effects/beams)
- [Particles' Flipbook Release](https://devforum.roblox.com/t/particles-flipbook-release/2029388)
- [Open Cloud — assets](https://create.roblox.com/docs/cloud/guides/usage-assets)
- [Open Cloud — place publishing](https://create.roblox.com/docs/cloud/guides/usage-place-publishing)
- [Rojo — sync details](https://rojo.space/docs/v7/sync-details/)
- [Rojo — properties](https://rojo.space/docs/v7/properties/)
- [Tarmac](https://github.com/rojo-rbx/tarmac)
- [rojo#286 — MeshPart sync](https://github.com/rojo-rbx/rojo/issues/286)
- [rojo#1182 — MeshPart empty mesh data on reconnect](https://github.com/rojo-rbx/rojo/issues/1182)
- [Introduction to VFX: Particles](https://devforum.roblox.com/t/introduction-to-vfx-particles/2068650)
- [Beginner's Guide to Anime/Fighting VFX](https://devforum.roblox.com/t/full-beginners-guide-on-scripting-animefighting-vfxvisual-effects-part-1/1610853)
- [Yuruzuu's Open Source VFX](https://devforum.roblox.com/t/yuruzuus-open-source-vfx/1840021)
- [CIX Library](https://devforum.roblox.com/t/over-600-free-particle-with-cix-library-a-particle-library-plugin/2864815)
- [VFX Suite plugin](https://devforum.roblox.com/t/introducing-the-vfx-suite-plugin/2545686)
- [VFX Forge plugin](https://devforum.roblox.com/t/plugin-vfx-forge-an-advanced-custom-vfx-system/3867553)
- [Beziers VFX plugin](https://devforum.roblox.com/t/beziers-advanced-modular-vfx-plugin-10000-assets-add-ons/4180222)
- [Open-Source Mesh Flipbook Pack](https://devforum.roblox.com/t/open-source-mesh-flipbook-pack/3635032)
- [Brackeys' VFX Bundle](https://brackeysgames.itch.io/brackeys-vfx-bundle)
- [Content Moderation on Roblox](https://en.help.roblox.com/hc/en-us/articles/21416271342868-Content-Moderation-on-Roblox)
- [Content maturity and compliance](https://create.roblox.com/docs/production/promotion/content-maturity)
- [Roblox Terms of Use](https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use)
- [Intellectual property](https://create.roblox.com/docs/marketplace/intellectual-property)
