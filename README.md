# Idle Dot Shooter

Een complete iOS-remake van de idle-shooter *Idle Dot Shooter*, gebouwd in SwiftUI.
De torentje schiet zichzelf, de drone raapt op, en je bouwt een upgrade-machine die
kleine plopjes verandert in absurde bedragen.

**Het enige verschil met het origineel: niets in de shop kost geld.** Elk pakket,
elke boost en elke cosmetic is gratis. De europrijs die het item in het origineel
draagt staat er doorgestreept bij, zodat meteen duidelijk is wat je *niet* betaalt.
Er zit geen StoreKit, geen betaalscherm en geen advertentie in de app.

## Openen en draaien

```
open IdleDotShooter.xcodeproj
```

Xcode 16 of nieuwer, deployment target iOS 16.0, draait op iPhone en iPad.
Er zijn geen dependencies — geen SPM, geen CocoaPods, geen assets van buitenaf.
Selecteer een simulator of je device, zet je eigen team bij Signing, en run.

Wie liever het projectbestand genereert: er staat een `project.yml` klaar voor
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen generate`).

## Wat er in zit

**Idle gevecht.** Het torentje mikt automatisch op de dichtstbijzijnde dot en
schiet door, ook terwijl je in een ander scherm zit. Kogels hebben snelheid,
pierce, crits en explosieve splash. Dots driften rond, botsen tegen de randen en
laten bij het knappen orbs vallen.

**Zes zeldzaamheden.** Common tot Cosmic, plus gouden dots die 25x waard zijn.
Je Luck-stat verschuift elke spawn-worp richting de bovenkant van de tabel.

**24 upgrades in drie takken.**

| Defence | Drone | Economy |
| --- | --- | --- |
| Damage, Fire Rate, Multishot, Crit Chance, Crit Damage, Bullet Speed, Pierce, Explosive Rounds | Speed, Suction, Agility, Size, Magnet Power, Drone Count, Collector Bonus, Orb Lifetime | Capacity, Dot Value, Spawn Rate, Luck, Combo Window, Idle Income, Golden Dots, Offline Rate |

Kopen kan per 1, 10, 25 of MAX; de MAX-knop rekent uit hoeveel levels je portemonnee aankan.

**Drie abilities.** *Frenzy* (rapid fire), *Dot Rain* (regen van dots over het veld)
en *Black Hole* (zwaartekrachtput die alles opslokt en uitbetaalt). Elk met eigen
unlock, levels, duur en cooldown. Auto-cast is gratis te claimen in de shop.

**50 melkwegstelsels.** Elk met een naam, een modifier (Dense Field, Armoured
Shells, Crushing Gravity, Nebula Drift, …) en oplopende health- en
waardevermenigvuldigers. Reizen kost cash; eenmaal ontgrendeld reis je gratis terug.

**Rebirth.** Vanaf Galaxy 10 kun je je run resetten voor Star Dust. Daarmee koop je
twaalf permanente upgrades die elke reset overleven — van Cosmic Damage tot Warp
Memory (begin je volgende run alvast een paar stelsels verder).

**Command Centre.** Dots vernietigd, schoten, treffers, accuracy, crits, grootste
klap, orbs opgeraapt en verloren, verdiend en uitgegeven, tijd actief en offline,
abilities gecast, rebirths, kills per zeldzaamheid — plus een live-blok met wat je
huidige build op dit moment presteert.

**Leaderboard.** Ranglijst op vernietigde dots, globaal en "friends", met je eigen
rij ertussen. Let op: er zit geen server achter deze build. De rivalen worden
lokaal gegenereerd, opgeslagen en lopen mee met de klok. `LeaderboardService` is
een protocol, dus een echte backend is een kwestie van één implementatie inpluggen.

**Offline verdiensten.** De app meet je werkelijke inkomen per seconde en keert bij
terugkomst een percentage daarvan uit, tot 24 uur. Het welkom-terugscherm laat zien
hoeveel en tegen welk tarief.

**Cosmetics.** 8 turrets, 6 dot-thema's, 5 drones, 6 achtergronden en 5 bullet
trails, allemaal gratis, allemaal zichtbaar in de render.

**Instellingen.** Haptics, geluid, particles, damage numbers, reduced motion,
bevestiging voor rebirth, standaard koophoeveelheid, handmatig opslaan en een
volledige wipe.

## Structuur

```
IdleDotShooter/
  App/       app entry point
  Core/      GameState, GameEngine, GameLoop, entiteiten, opslag, formatting
  Model/     upgrades, galaxies, abilities, rebirth, shop, cosmetics, rarity, stats
  Services/  haptics + geluid, leaderboard
  Views/     SwiftUI-schermen, canvas-renderer, componenten
```

Een paar keuzes die de moeite van het uitleggen waard zijn:

- **`GameState` publiceert handmatig en getemperd.** De loop markeert de state als
  vies; `publishIfNeeded()` flusht op 12 Hz. Alleen `FieldCanvas` observeert de
  engine, die wel elke frame publiceert. Zo hertekent de HUD niet 60 keer per
  seconde mee.
- **Rendering gaat via één SwiftUI `Canvas`.** Geen SpriteKit, geen textures —
  alles is een pad. Dat houdt de app volledig zelfstandig en klein.
- **Botsingen lopen over een uniform grid** (`SpatialGrid`), zodat honderden kogels
  tegen honderden dots niet ontaardt in kwadratisch werk.
- **Opslaan** gebeurt als JSON in Documents, met `UserDefaults` als terugvaloptie,
  elke 15 seconden en bij het naar de achtergrond gaan.

## Balans in het kort

Dots in Galaxy *n* hebben `1.4^n` keer zoveel health en zijn `1.8^n` keer zoveel
waard; reizen naar Galaxy *n* kost `2500 · 3^n`. Upgradekosten groeien
geometrisch per upgrade (1.11 tot 1.78 per level). Star Dust schaalt met de
wortel van wat je deze run verdiende, maal hoe diep je kwam. Alle getallen staan
bij elkaar in `Model/Upgrades.swift`, `Model/Galaxy.swift`, `Model/Rebirth.swift`
en `Core/DerivedStats.swift`, dus bijstellen kan zonder de engine aan te raken.

## Over deze build

Dit is een onafhankelijke, van nul geschreven implementatie van het spelconcept:
eigen code, eigen art (alles wordt getekend), eigen teksten en eigen balans. Er is
geen code, asset of handelsmerk van de originele app overgenomen, en de app doet
zich niet voor als de originele uitgave.
