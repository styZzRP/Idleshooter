# Idle Dot Shooter

Een complete remake van de idle-shooter *Idle Dot Shooter*, als web-app. Het
torentje schiet zichzelf, de drone raapt op, en je bouwt een upgrade-machine die
kleine plopjes verandert in absurde bedragen.

**Het enige verschil met het origineel: niets in de shop kost geld.** Elk
pakket, elke boost en elke cosmetic is gratis. De europrijs die het item in het
origineel draagt staat er doorgestreept bij, zodat meteen duidelijk is wat je
*niet* betaalt. Er zit geen betaalscherm, geen in-app-aankoop en geen
advertentie in.

## Starten

Je hebt geen Xcode nodig, en ook geen build-stap. Er zijn nul dependencies:
alles is gewone HTML, CSS en JavaScript.

**Simpelste manier** — dubbelklik `index.html`. Werkt in Chrome, Firefox en Edge.
Let op: sommige browsers (met name Safari) blokkeren opslag op `file://`, dan
onthoudt hij je voortgang niet.

**Aanbevolen** — serveer de map even lokaal, dan werkt opslaan overal:

```
python3 -m http.server 8000
# of, met Node:  npx http-server -p 8000
```

Open daarna <http://localhost:8000>.

**Op je telefoon** — zet de map op een willekeurige statische host (GitHub
Pages, Netlify, Vercel, of je eigen server) en open de link. Op iOS kun je hem
via *Deel → Zet op beginscherm* als volledig scherm-app gebruiken; hij is
gebouwd voor staand telefoonformaat.

## Wat er in zit

**Idle gevecht.** Het torentje mikt automatisch op de dichtstbijzijnde dot en
schiet door, ook terwijl je in een ander tabblad van het spel zit. Kogels hebben
snelheid, pierce, crits en explosieve splash. Dots driften rond, botsen tegen de
randen en laten bij het knappen orbs vallen.

**Zes zeldzaamheden.** Common tot Cosmic, plus gouden dots die 25x waard zijn.
Je Luck-stat verschuift elke spawn-worp richting de bovenkant van de tabel.

**24 upgrades in drie takken.**

| Defence | Drone | Economy |
| --- | --- | --- |
| Damage, Fire Rate, Multishot, Crit Chance, Crit Damage, Bullet Speed, Pierce, Explosive Rounds | Speed, Suction, Agility, Size, Magnet Power, Drone Count, Collector Bonus, Orb Lifetime | Capacity, Dot Value, Spawn Rate, Luck, Combo Window, Idle Income, Golden Dots, Offline Rate |

Kopen kan per 1, 10, 25 of MAX; de MAX-knop rekent uit hoeveel levels je
portemonnee aankan. Wie geen zin heeft in de klim: **Full Arsenal** bovenaan de
shop zet in één klik alle 24 upgrades op hun hoogste level (de vier zonder cap
gaan naar level 250). Dat item is herbruikbaar, dus na een rebirth claim je hem
gewoon opnieuw.

**Drie abilities.** *Frenzy* (rapid fire), *Dot Rain* (regen van dots over het
veld) en *Black Hole* (zwaartekrachtput die alles opslokt en uitbetaalt). Elk
met eigen unlock, levels, duur en cooldown. Auto-cast is gratis te claimen in de
shop.

**50 melkwegstelsels.** Elk met een naam, een modifier (Dense Field, Armoured
Shells, Crushing Gravity, Nebula Drift, …) en oplopende health- en
waardevermenigvuldigers. Reizen kost cash; eenmaal ontgrendeld reis je gratis
terug.

**Rebirth.** Vanaf Galaxy 10 kun je je run resetten voor Star Dust. Daarmee koop
je twaalf permanente upgrades die elke reset overleven — van Cosmic Damage tot
Warp Memory (begin je volgende run alvast een paar stelsels verder).

**Command Centre.** Dots vernietigd, schoten, treffers, accuracy, crits,
grootste klap, orbs opgeraapt en verloren, verdiend en uitgegeven, tijd actief
en offline, abilities gecast, rebirths, kills per zeldzaamheid — plus een
live-blok met wat je huidige build op dit moment presteert.

**Leaderboard.** Ranglijst op vernietigde dots, globaal en "friends", met je
eigen rij ertussen. Let op: er zit geen server achter deze build. De rivalen
worden lokaal gegenereerd, opgeslagen en lopen mee met de klok. Wil je een echte
backend, dan vervang je het object in `js/leaderboard.js` — de rest van de app
verandert niet.

**Offline verdiensten.** De app meet je werkelijke inkomen per seconde en keert
bij terugkomst een percentage daarvan uit, tot 24 uur. Het welkom-terugscherm
laat zien hoeveel en tegen welk tarief.

**Cosmetics.** 8 turrets, 6 dot-thema's, 5 drones, 6 achtergronden en 5 bullet
trails, allemaal gratis, allemaal zichtbaar in de render.

**Instellingen.** Trillen, geluid, particles, damage numbers, reduced motion,
bevestiging voor rebirth, standaard koophoeveelheid, handmatig opslaan en een
volledige wipe.

## Structuur

```
index.html          — de hele app-shell
css/styles.css      — thema en alle schermen
js/format.js        — grote getallen compact weergeven
js/palette.js       — kleuren
js/catalog.js       — upgrades, galaxies, abilities, rebirth, cosmetics, shop
js/feedback.js      — trillen + gesynthetiseerde geluidjes (WebAudio)
js/save.js          — opslag in localStorage, met terugval op geheugen
js/state.js         — portemonnee, levels, afgeleide stats, aankopen, rebirth
js/leaderboard.js   — lokale ranglijst
js/engine.js        — de simulatie: dots, kogels, orbs, drones, abilities
js/render.js        — canvas-renderer
js/ui-components.js — DOM-bouwstenen
js/ui-screens.js    — de zes schermen
js/main.js          — opstarten, animatieloop, tabs, opslaan
```

Een paar keuzes die de moeite van het uitleggen waard zijn:

- **Geen framework en geen build.** Gewone `<script>`-tags in volgorde, alles
  hangt aan `window`. Daardoor werkt het ook rechtstreeks vanaf schijf.
- **Alles wordt getekend.** Eén `<canvas>` met 2D-paden — geen plaatjes, geen
  sprites, geen externe fonts. De hele app is een paar honderd kilobyte tekst.
- **De UI hertekent niet alles.** Elk scherm bouwt zijn DOM één keer en werkt
  daarna alleen de tekst en knopstatus bij, tien keer per seconde. Alleen het
  canvas loopt op volle framerate.
- **Botsingen lopen over een uniform grid** (`SpatialGrid`), zodat honderden
  kogels tegen honderden dots niet ontaardt in kwadratisch werk.
- **Opslaan** gebeurt automatisch elke 15 seconden, bij het wegklikken van het
  tabblad en bij het sluiten van de pagina.

## Balans in het kort

Dots in Galaxy *n* hebben `1.4^n` keer zoveel health en zijn `1.8^n` keer zoveel
waard; reizen naar Galaxy *n* kost `2500 · 3^n`. Upgradekosten groeien
geometrisch per upgrade (1.11 tot 1.78 per level). Star Dust schaalt met de
wortel van wat je deze run verdiende, maal hoe diep je kwam. Alle getallen staan
bij elkaar in `js/catalog.js`, dus bijstellen kan zonder de engine aan te raken.

## Over deze build

Dit is een onafhankelijke, van nul geschreven implementatie van het spelconcept:
eigen code, eigen art (alles wordt getekend), eigen teksten en eigen balans. Er
is geen code, asset of handelsmerk van de originele app overgenomen, en de app
doet zich niet voor als de originele uitgave.

Er bestond eerder een SwiftUI-versie van dit project; die staat nog in de
git-geschiedenis (commit `e776400`) en is met
`git checkout e776400 -- IdleDotShooter IdleDotShooter.xcodeproj` terug te halen.
