# roblox-game-ben

Ein Roblox-Spiel: du sammelst Plants und Crystals in der Welt, mischst sie bei
dir zu Hause zu Abilities zusammen und duellierst dich damit 1 gegen 1.

Die Begriffe stehen auf Englisch, weil sie genau so im Code vorkommen. Die
Erklärung dazu ist auf Deutsch.

## Language

### Duell

**Duel**:
Ein Kampf zwischen genau zwei Spielern, der läuft, bis die HP eines Spielers auf
null sind. Er läuft von Anfang bis Ende in einer durchgehenden Animation — frei
bewegt man sich nur in der Welt, nie im Duel (ADR 0003).
_Avoid_: Fight, Battle, Match

**Exchange**:
Der kleinste Takt eines Duels: ein Spieler setzt eine Ability ein, der andere
antwortet darauf. Ein Duel ist eine ununterbrochene Kette von Exchanges.
_Avoid_: Turn, Round, Zug

**Initiative**:
Wer im laufenden Duel angreift. Sie wechselt zum Verteidiger, sobald der
richtig geantwortet hat — dann greift er an und der andere muss antworten.
_Avoid_: Turn, am Zug sein

**Attack**:
Die Ability, die der Angreifer in einem Exchange einsetzt. Für das Duel zählt an
ihr nur der Habit — er entscheidet, welche zwei Answers passen. Jeder Exchange
beginnt mit genau einer.
_Avoid_: Angriff, Strike, Offense, Move

**Commit Window**:
Die Zeitspanne in Slow Motion, in der der Verteidiger wählen muss — eine Answer,
einen Truce oder eine Flight. Läuft sie ab, ohne dass er etwas wählt, hat er den
Exchange verloren.
_Avoid_: Countdown, Timer, Reaktionszeit

**Answer**:
Die Ability, die der Verteidiger gegen die eingehende Ability spielt. Ob sie
passt, entscheidet den Exchange — und zwar allein. Wie viel HP der verlorene
Exchange kostet, ist eine getrennte Frage. Jede Attack hat zwei gültige
Answers: eine Defense und einen Counter.
_Avoid_: Response, Konter

**Defense**:
Die sichere Answer. Du nimmst keinen Schaden, aber der Angreifer behält die
Initiative und greift weiter an.
_Avoid_: Block, Guard, Parry

**Counter**:
Die gierige Answer. Du nimmst keinen Schaden, teilst selber Schaden aus und
nimmst dem Angreifer die Initiative ab. Dafür geht er nur im letzten Drittel des
Commit Window, und wer ihn danebensetzt, nimmt doppelten Schaden.
_Avoid_: Riposte, Gegenangriff, Counterattack

**Truce**:
Ein Angebot aus Items und Recipes, das ein Duel sofort beendet, wenn der andere
es annimmt. Du wählst es im Commit Window anstelle einer Answer und kassierst
dafür den eingehenden Treffer. Jeder Spieler darf pro Duel genau eines machen;
ein abgelehntes Angebot verrät, wie verzweifelt der Anbietende ist.
_Avoid_: Peace, Deal, Frieden, Waffenstillstand

### Sammeln und Mischen

**Plant**:
Eine Zutat, die du in der Welt sammelst. Plants bestimmen, welche Abilities du
überhaupt mischen kannst.
_Avoid_: Ingredient, Zutat, Herb

**Crystal**:
Eine Zutat, die den Schaden einer bestehenden Ability erhöht. Ein Crystal kann
nie entscheiden, wer einen Exchange gewinnt — nur, wie teuer er wird.
_Avoid_: Gem, Stone, Upgrade

**Ability**:
Das, was du bei dir zu Hause aus zwei Plants zusammenmischst und im Duel
einsetzt.
_Avoid_: Move, Skill, Spell, Fähigkeit

**Habit**:
Was die Pflanze hinter einer Ability tut — Vine, Thorn, Spore, Root, Bloom.
Der Habit ist das Einzige, was im Duel mechanisch zählt: er entscheidet, welche
Answer gegen die Ability passt. Die fünf stehen in einem Ring, in dem jeder von
genau zwei anderen beantwortet wird (ADR 0002). Zwei Abilities mit demselben
Habit sind im Kampf austauschbar und unterscheiden sich nur im Aussehen. (Der
Begriff ist der botanische Fachausdruck für die Wuchsform einer Pflanze.)
_Avoid_: Element, Type, Verb, Behaviour

**Recipe**:
Ein Paar von Plants und die Ability, die daraus entsteht. Die Reihenfolge zählt
nicht, und dieselbe Plant zweimal ist ein gültiges Paar. Jedes Paar ergibt eine
Ability — es gibt keine Fehlmischung. Seltene Rezepte sind nicht stärker, sie
sehen besser aus. Ein Recipe ist das Einzige, was du weggeben kannst, ohne es zu
verlieren — deshalb taugt es als Einsatz in einem Truce.
_Avoid_: Formula, Combo, Mix

### Welt

**Loadout**:
Die Abilities, die du in ein Duel mitnimmst. Es sind immer weniger, als es
Habits gibt, du lässt also eine selbst gewählte Lücke — gegen mindestens einen
Habit hast du nur die halbe Answer oder gar keine. Das gilt für jeden Spieler
auf jeder Stufe.
_Avoid_: Deck, Build, Set, Slots

**Satchel**:
Was du dabei hast und noch nicht nach Hause gebracht hast. Der Inhalt ist das
Einzige, was du in einem Duel unfreiwillig verlieren kannst.
_Avoid_: Inventory, Bag, Rucksack

**Loot**:
Was aus einem Satchel auf den Boden fällt, wenn du ein Duel verlierst. Wer es
zuerst aufhebt, bekommt es.
_Avoid_: Drop, Beute

**Flight**:
Der Ausstieg aus einem laufenden Duel. Du wählst ihn im Commit Window anstelle
einer Answer und kassierst dafür den eingehenden Treffer; überlebst du ihn, bist
du mit deinem Satchel draussen.
_Avoid_: Flee, Escape, Surrender, Aufgeben

**Power**:
Eine einzelne Zahl, die aus deinen Crystal-Stufen, der Anzahl deiner Habits und
deiner Siegwertung berechnet wird. Sie ist das Einzige, woran das Spiel misst,
wie stark ein Spieler ist. Es zählt der Höchststand, den du je erreicht hast —
nie der aktuelle.
_Avoid_: Level, Rank, Score, Stärke

**Village**:
Der sichere Ort, der alle Zones verbindet. Hier steht dein House, hier wird
nicht gekämpft, und hier zeigen Spieler einander ihre Abilities.
_Avoid_: Hub, Town, Lobby, Dorf

**House**:
Dein Platz im Village. Nur hier wird gemischt, und nur hier ist der Inhalt
deines Satchels endgültig sicher. Vom Village aus betrittst du es mit einem
Klick — aus einer Zone führt kein Weg direkt nach Hause.
_Avoid_: Base, Home, Plot, Haus

**Zone**:
Ein Gebiet der Welt mit einer festen Power-Spanne. Wer zu stark ist, kommt nicht
hinein; wer zu schwach ist, noch nicht hinaus. Dadurch trifft offenes PvP immer
nur ähnlich starke Spieler.
_Avoid_: Area, Region, Level, Biome
