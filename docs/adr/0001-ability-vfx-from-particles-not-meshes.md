# Ability-VFX werden aus Partikeln gebaut, nicht aus 3D-Modellen

Eine Ability sieht gut aus, weil sie aus `ParticleEmitter`, `Beam` und `Trail`
zusammengesetzt ist — nicht, weil ein 3D-Modell darin steckt. Der Grund ist
unser Aufbau mit zwei Maschinen: alle Eigenschaften dieser drei Bausteine sind
Text, den Rojo live von der claudebox nach Studio synchronisiert, aber
`MeshPart.MeshId` steht auf Rojos Liste der Eigenschaften, die sich **nicht**
live setzen lassen ([rojo#286](https://github.com/rojo-rbx/rojo/issues/286)).
Eine Ability aus Partikeln kann der Agent hier fertig bauen und Ben schaut nur
zu; eine Ability aus Modellen wäre Handarbeit, die nur Ben in Studio machen
kann und der Agent nie sehen würde. Bei dutzenden Abilities ist das der
Unterschied zwischen Tagen und Monaten.

## Konsequenzen

- Texturen bleiben erlaubt: hochgeladene Bilder werden nur per ID referenziert,
  und diese ID ist wieder Text. Der Upload läuft ohne Studio über die Open
  Cloud Assets API.
- Frisch hochgeladene Bilder sind zuerst `Restricted`. Ohne Freigabe für das
  Universe lädt die Textur stillschweigend nicht — das ist die wahrscheinlichste
  Ursache, wenn ein Effekt unsichtbar bleibt.
- `SurfaceAppearance` und Unions (`PartOperation`) werden beim Veröffentlichen
  von Linux aus nicht aktualisiert und kommen deshalb in Abilities nicht vor.
- Der gewünschte Rivals-Look ist mit diesen drei Bausteinen erreichbar, und die
  Lesbarkeit, die er verlangt — eine klare Silhouette pro Ability — ist ohnehin
  eine Anforderung des Commit Window.
- Einzelne Vorzeigestücke dürfen später Modelle bekommen. Dann gilt für genau
  diese Abilities, dass Ben sie in Studio pflegt.

Details und Quellen: `docs/research/roblox-3d-and-vfx-sources.md`.
