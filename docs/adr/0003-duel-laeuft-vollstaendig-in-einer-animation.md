# Ein Duel läuft vollständig in einer Animation

Frei bewegt sich ein Spieler nur in der Welt. Sobald ein Angriff sitzt, schnappt
das Duel zu und läuft von da an bis zum Ende als **eine durchgehende
Animation**: die Figuren stürmen, weichen, kreisen und schlagen zu, aber niemand
steuert seine Bewegung noch selber. Es gibt keine Pause und keinen Reset — ein
Duel ist eine ununterbrochene Kette von Exchanges, bis die HP eines Spielers auf
null sind. Die einzige Eingabe im Duel ist die Wahl im Commit Window.

Die Entscheidung, ob es überhaupt zum Kampf kommt, liegt damit **vor** dem Duel
und nicht darin: Abstand halten oder rangehen ist die Bewegungsentscheidung, der
erste Angriff ist die Verpflichtung.

## Considered Options

- **Freie Bewegung während des Duels**, mit Kampfphasen als Interpunktion
  dazwischen. Verworfen: das Duel lebt von der Zeitlupe im Commit Window, und
  Zeitlupe und freies Laufen beissen sich. Ausserdem verlangt die Lesbarkeit
  einer Ability eine kontrollierte Kamera und eine kontrollierte Distanz —
  beides gibt es nicht, wenn beide Spieler frei stehen können, wo sie wollen.
- **Ein Reset zwischen den Kampfphasen**, in dem beide zurücktaumeln und sich
  umkreisen. Verworfen, weil er das Versprechen der durchgehenden Animation
  bricht. Wir haben dafür einen Begriff (`Clash`) eingeführt und wieder
  gestrichen, als klar wurde, dass er dasselbe benennt wie `Duel`.

## Consequences

- Die Kamera gehört im Duel dem Spiel, nicht dem Spieler. Das ist die
  Voraussetzung dafür, dass die Silhouette einer Ability im Commit Window
  überhaupt lesbar ist (ADR 0001).
- Weil es keinen ruhigen Moment gibt, haben Truce und Flight keinen eigenen
  Zeitpunkt: beide sind zusätzliche Wahlmöglichkeiten **im Commit Window**,
  anstelle einer Answer. Wer eines von beidem wählt, hat nicht geantwortet und
  kassiert den eingehenden Treffer — der Preis steckt damit in der Mechanik
  statt in einer Extraregel.
- Ein Duel braucht viele Animationen. Wie sie entstehen, ist noch offen: laut
  `docs/research/roblox-animation-without-studio.md` lassen sie sich zwar ohne
  Studio hochladen, aber nicht ohne Studio abspielen, solange sie nur im
  Rojo-Baum liegen. Ein Spike klärt als Nächstes, ob der Agent Clips selber
  erzeugen kann oder ob Ben die Basis-Clips im Animation Editor baut.
