# Animationen entstehen im Agenten, nicht in Studio

Der Spike aus Issue #7 ist durchgelaufen und hat die Frage mit Ja beantwortet:
eine `KeyframeSequence`, die Lune auf claudebox gebaut hat und die nie in Studio
war, lässt sich über die Open Cloud Assets API hochladen **und im Spiel
abspielen**. Damit gehört die ganze Animationskette dem Agenten — bauen,
hochladen, versionieren, abspielen — und Ben baut keine Basis-Clips.

Der Beleg, am 2026-09-10 in Studio gesehen:

    [AnimationSpike] rig type: R15
    [AnimationSpike] RightUpperArm joint: AnimationConstraint
    [AnimationSpike] animation id: rbxassetid://109551632272102
    [AnimationSpike] track length 1.20s, playing true

Der Arm hat sich bewegt. Die 1.20 s sind genau die Länge, die der Generator
gesetzt hat: der Clip kam vollständig durch, nicht als leere Hülle.

Die Warnung im Assets-Guide — *".rbxm or .rbxmx files edited outside of Roblox
Studio might not upload or function"* — trifft für eine von Lune erzeugte
`KeyframeSequence` also weder beim Upload noch beim Abspielen zu. Das war der
letzte unbelegte Punkt in `docs/research/roblox-animation-without-studio.md`.

## Considered Options

- **Ben baut ein Dutzend Basis-Clips im Animation Editor** und legt sie als
  `.rbxm` ins Repo, der Agent macht den Rest. Das war der Plan für den Fall,
  dass der Spike Nein sagt. Er ist damit hinfällig — nicht weil er schlecht
  wäre, sondern weil er Ben Arbeit gibt, die niemand mehr braucht.
- **Clips aus dem Rojo-Baum abspielen, ohne hochzuladen.** Geht nicht:
  `AnimationClipProvider:RegisterAnimationClip` liefert eine ID, die laut
  Referenz ausserhalb von Studio nicht gilt. Jeder Clip muss durch den Upload.

## Consequences

- **Ben öffnet Studio zum Schauen, nicht zum Bauen.** Sein Beitrag zur Animation
  ist das Urteil "sieht falsch aus", nicht das Posen eines Rigs. Das ist
  dieselbe Schleife wie in ADR 0001 und ADR 0004: der Agent ändert eine Datei,
  Rojo synct, Ben drückt Play und sagt, wie es sich anfühlt.
- **Ein Clip ist ein Build-Artefakt, kein Handwerk.** Er steht als Code im Repo,
  ist diffbar und wird aus einer Beschreibung erzeugt. Was ein Duel braucht —
  Timing, Blending, Gewichte, Prioritäten, Trefferframes — ist damit
  vollständig agentenseitig.
- **Jeder Upload kostet eine neue Asset-ID.** Open Cloud kann den Inhalt eines
  bestehenden Animation-Assets nicht ersetzen (nur `.fbx`). Iteration heisst
  also: neues Asset, neue ID, generiertes ID-Modul neu committen. Alte IDs
  sammeln sich an. Wenn das Iterieren zäh wird, ist das der Grund.
- **Der Agent sieht die Bewegung nie.** Das bleibt die eigentliche Grenze, und
  sie ist nicht technisch. Vorzeichen und Achsen im Rig sind blind nicht zu
  raten: der Spike-Arm schwingt nach *hinten*, obwohl die Rotation nach vorne
  gemeint war. Jede Bewegung, die mehr als "es bewegt sich" sein soll, braucht
  eine Runde durch Bens Augen.
- **Das Avatar Joint Upgrade ist in unserem Place aktiv** — der R15-Rig trägt
  `AnimationConstraint`s, keine `Motor6D`s — und ein hochgeladener Clip spielt
  darauf ohne Zutun. Für *prozedurale* Überlagerung gilt das nicht: dort ist
  `C0`/`C1` schreibgeschützt, und der Weg führt über `.Transform` in
  `PreSimulation`. Wer das anfasst, liest vorher
  `docs/research/roblox-animation-without-studio.md` §3.1.

Details und Quellen: `docs/research/roblox-animation-without-studio.md`.
Die Pipeline: `.lune/spike-animation.luau` und `.lune/lib/openCloud.luau`.
