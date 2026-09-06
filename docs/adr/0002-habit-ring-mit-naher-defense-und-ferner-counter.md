# Die fünf Habits stehen in einem Ring, nah verteidigt und fern kontert

Jede Attacke soll genau zwei gültige Answers haben — eine Defense und einen
Counter. Statt diese zehn Zuordnungen von Hand zu schreiben, ordnen wir die
fünf Habits in einem Ring an: eine Attacke wird von dem Habit beantwortet, der
im Ring **direkt davor** steht (das ist die Defense), und von dem **zwei
davor** (das ist der Counter). Die Regel aus `CONTEXT.md` fällt damit aus der
Struktur heraus, statt gepflegt werden zu müssen.

Der Ring lautet: **Vine → Bloom → Spore → Root → Thorn → Vine**.

| Attacke | Defense (nah) | Counter (fern) |
| --- | --- | --- |
| Vine | Thorn | Root |
| Bloom | Vine | Thorn |
| Spore | Bloom | Vine |
| Root | Spore | Bloom |
| Thorn | Root | Spore |

## Considered Options

- **Eine handgeschriebene Matchup-Tabelle.** Verworfen: zehn willkürliche
  Fakten, die der Spieler auswendig lernen und wir bei jeder Änderung neu
  ausbalancieren müssten.
- **Eine gerade Anzahl Habits (vier oder sechs).** Verworfen: nur bei einer
  ungeraden Anzahl wird jeder Habit von genau zwei anderen geschlagen. Bei einer
  geraden Anzahl geht die Rechnung nicht auf und es entstehen Sonderfälle.
- **Sieben Habits.** Verworfen: der Verteidiger müsste im Commit Window unter
  sieben Silhouetten unterscheiden. Fünf ist die kleinste Zahl, die funktioniert.
- **Fern verteidigt, nah kontert.** Funktioniert strukturell genauso; wir haben
  uns für nah = Defense entschieden, weil "der direkt davor deckt dich" die
  Regel ist, die man sich leichter merkt.

## Consequences

- Jede Ability hat im Loadout zwei Aufgaben: sie verteidigt gegen genau einen
  Habit und kontert genau einen anderen. Keine Ability ist tot.
- Ob ein Loadout ein **tödliches Loch** hat — einen Habit, auf den es gar keine
  Answer gibt — hängt allein an der Loadout-Grösse. Bei vier von fünf Habits
  gibt es nie eines. Bei drei von fünf entsteht genau dann eines, wenn die zwei
  fehlenden Habits im Ring benachbart sind; dafür beherrscht man dann zwei
  Habits vollständig. Das macht die Loadout-Wahl zur Entscheidung zwischen
  scharf und stumpf.
- Die Ringreihenfolge ist thematisch gebaut (Dornen bestrafen das Heranziehen,
  ein Bloom bläst die Spore-Wolke weg, eine verwurzelte Gegnerin frisst die
  Wolke) und sollte beim Umbenennen eines Habits mitgeprüft werden.
