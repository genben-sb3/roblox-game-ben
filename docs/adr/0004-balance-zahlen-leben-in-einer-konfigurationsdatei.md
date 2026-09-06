# Balance-Zahlen leben in einer Konfigurationsdatei, nicht im Code

Jede Zahl, die das Spielgefühl bestimmt — Länge des Commit Window, Dauer eines
Duels, HP, Schaden pro Ereignis, Loadout-Grösse — steht an einer Stelle in einer
Konfigurationsdatei im Repo und nirgends sonst. Im Code gibt es dafür keine
Konstanten.

Der Grund ist unser Aufbau mit zwei Maschinen. Der Agent sieht das Spiel nie und
kann deshalb keine dieser Zahlen begründen; er kann nur die Ränder abstecken.
Richtig werden sie erst durchs Spielen. Wenn sie alle an einem Ort stehen, ändert
der Agent eine Zahl, Rojo synct sie live nach Studio, Ben drückt Play und spürt
den Unterschied sofort — dieselbe Schleife, die ADR 0001 für die VFX herstellt.
Stünden sie verstreut im Code, wäre jede Feinabstimmung eine Codeänderung mit
Wartezeit, und das Spiel würde nie gut anfühlen.

## Consequences

- Private Server machen einen **Teil** dieser Datei als Menü sichtbar: die
  Kampfzeiten ja, HP und Schaden nein. Sonst sind private Server keine
  Spielwiese mehr, sondern ein anderes Spiel.
- Die Zahlen aus der Design-Grillerei sind ausdrücklich **Startwerte**, keine
  Festlegungen. Wer sie später ändert, widerspricht dieser ADR nicht, sondern
  benutzt sie.
- Wer eine dieser Zahlen als Konstante in ein Modul schreibt, macht es kaputt —
  auch wenn es an Ort und Stelle sauberer aussieht.
