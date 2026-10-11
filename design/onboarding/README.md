# Handoff : Guide de premier lancement — Easy Controller - Forever

## Vue d'ensemble
Guide en 6 étapes affiché au premier lancement de l'addon (nouvelles installations seulement), relançable plus tard via **Accueil › Guide** ou **`/ec welcome`**. Il fait choisir au joueur le style d'icônes de boutons, configure palettes arrière / pavés tactiles, la taille et le comportement de la barre manette, le clavier de chat, les roues et le mode Soigneur, puis les options de confort.

Fenêtre **dans le jeu**, 820 × 580 px, même famille visuelle que le panneau de réglages existant (captures dans `reference/`). Navigation **à la manette uniquement**.

## À propos des fichiers de design
`Onboarding.dc.html` est une **référence de design en HTML** (ouvrir dans un navigateur, à côté de `support.js`). Ce n'est pas du code à livrer. La tâche est de **recréer chaque écran dans l'addon** (Lua + XML/FrameXML du client WoW, avec les frames, polices, icônes et templates déjà utilisés par le panneau de réglages), avec des textes localisés et des boutons vivants.

Les PNG de `textures/` **sont**, eux, des livrables : à copier dans `design/textures/` du dépôt ; le script existant les convertit pour le jeu.

## Fidélité
**Haute fidélité.** Couleurs, tailles, positions et textes sont finaux (texte de l'avertissement de l'écran 3 à valider). Substitutions propres à la maquette, à remplacer par celles du jeu :
- Police titres/libellés : maquette en **Marcellus** → jeu : **Friz Quadrata** (`Fonts\FRIZQT__.TTF`, ex. `GameFontNormal`).
- Police d'aide : maquette en **PT Sans Narrow** → jeu : police sans empattement du panneau existant (Arial Narrow, `Fonts\ARIALN.TTF`).
- Pastilles A/B/X/Y/LB/RB/croix : **remplaçants** → utiliser les icônes de boutons fournies par le jeu / l'addon, selon le style choisi à l'écran 1.
- Cases d'icônes de l'écran 6 : vides dans la maquette → icônes du jeu.

## Conventions générales
- Toutes les coordonnées sont en px **depuis le coin haut gauche de la fenêtre** (820 × 580).
- Les textes sont en français dans la maquette ; tout passe par la table de localisation (enUS, frFR, deDE, esES, itIT). **Prévoir +30 % de longueur (allemand)** : les zones de texte multiligne ont une largeur fixe et une hauteur libre ; aucun libellé ne doit être tronqué (préférer le retour à la ligne).
- Aucune illustration ne contient de texte.

### Cadre de fenêtre (commun aux 6 écrans)
- Fond `#16110C` avec léger halo radial `#1E170F` en haut (optionnel). Bord 1 px `#7A6448`, liseré intérieur 1 px `#3A2C1D` à 3 px du bord, coins 4 px, ombre portée sombre.
- **En-tête** (x 24 → 800, y 12 → 56) :
  - Sur-titre « EASY CONTROLLER · GUIDE » : Friz 11 px, `#C9A25A`, interlettrage ~0,14 em.
  - Titre d'étape : Friz 22 px, `#F2C43C`, sous le sur-titre (3 px d'écart).
  - À droite : **indicateur d'étape** — 6 points espacés de 7 px : étape faite = disque 8 px `#C9A25A` ; étape courante = disque 10 px `#FFD24A` avec halo ; à venir = cercle 8 px contour 1,5 px `#5A4630`. Puis texte « n / 6 » (aide 14 px `#B9AB8C`). Puis bouton X 30 × 28 (fond `#0F0B07`, bord 1,5 px `#5A4630`, texte `#D8CCB0`).
  - Filet horizontal 1 px `#3A2C1D` à y 62, de x 16 à x 804.
- **Barre d'aide** (y 532 → 580, hauteur 48) : fond `#120D08`, filet haut 1 px `#3A2C1D`. À gauche (x 24) : fil d'Ariane « Guide › … », aide 13 px `#9D917A`. À droite (marge 20 px, 18 px entre éléments) : icône de bouton + libellé Friz 15 px `#EFE4C8` (6 px entre icône et libellé).

### États des contrôles
- **Bouton normal** : hauteur 40 (34 dans les cartes de l'écran 5), fond dégradé vertical `#1F1810` → `#0F0B07`, bord 1,5 px `#5A4630`, coins 4, Friz 16 px `#EFE4C8`, padding horizontal 22.
- **Bouton principal non focalisé** (Commencer, Terminer) : bord `#7A6448`, texte `#F2C43C`.
- **Focus manette** (un seul élément à la fois, sur tous les types de contrôle) : fond dégradé `#3A2E12` → `#221A0A`, bord 2 px `#FFD24A`, halo extérieur ~10 px `rgba(255,210,74,.35)`, texte `#FFD24A` (ou `#FFF3D0` pour une ligne de liste).
- **Case à cocher** : 20 × 20, fond `#0F0B07`, bord 1,5 px `#7A6448` (bord `#FFD24A` si la ligne a le focus), coins 3, coche `#FFD24A`.
- **Interrupteur** : 40 × 20, pilule. Activé : fond `#2E2410`, bord `#C9A25A`, pastille 13 px `#FFD24A` à droite. Désactivé : fond `#0F0B07`, bord `#5A4630`, pastille `#6F6452` à gauche.
- **Bouton radio** : cercle 16 px, bord 1,5 px `#7A6448` ; choisi : bord `#FFD24A` + disque 8 px `#FFD24A`.
- **Sélecteur ◀ valeur ▶** : hauteur 32, fond `#0F0B07`, bord 1,5 px `#5A4630`, flèches `#C9A25A`, valeur Friz 15 px centrée. Croix gauche/droite pour changer de valeur.
- **Curseur** : rail 8 px fond `#0F0B07` bord `#5A4630`, partie remplie en dégradé `#7A5D36` → `#F2C43C`, poignée 20 px `#FFD24A` bord 2 px `#FFF3D0` avec halo.
- **Libellé de section** : Friz 16 px `#F2C43C`. **Texte d'aide** : sans 14 px / interligne 18, `#B9AB8C`. Désactivé : `#6F6452`.

## Navigation manette (tous les écrans)
- **Croix** : déplace le focus entre les contrôles (ordre de lecture : haut → bas, gauche → droite). Sur un curseur ou un sélecteur, gauche/droite change la valeur.
- **A** : valide / coche / active le contrôle focalisé.
- **B** : retour à l'étape précédente ; à l'étape 1 = « Plus tard » (ferme le guide, on pourra le relancer).
- **LB / RB** : étape précédente / suivante (pas de LB à l'étape 1, pas de RB à l'étape 6).
- X (bouton de fenêtre) : équivalent à « Plus tard ».
- Les choix s'appliquent **immédiatement** (même enregistrement que le panneau de réglages) ; le guide n'a pas de bouton « annuler tout ».
- La barre d'aide reflète le contexte (par ex. « Ajuster » sur un curseur, « Décocher » sur une case cochée).

## Écrans

### 1 — Bienvenue et ta manette (`1 / 6`, titre « Bienvenue »)
- Illustration `ck_onb_welcome` à **24, 72**, affichée **384 × 192**.
- 3 lignes à **24, 276**, largeur 384, 10 px d'écart ; chacune précédée d'un losange 6 px `#C9A25A`. Sans 16 px / 20, `#EFE4C8` :
  1. « Joue à tout le jeu à la manette : déplacement, ciblage, combat, sacs. »
  2. « Tes sorts sur les boutons ; LT et RT ouvrent deux barres de plus. »
  3. « Roues, clavier de chat et alertes pour tout le reste. »
- Encadré raccourci à **24, 404**, largeur 384 : fond `#0F0B07`, bord 1 px `#3A2C1D`, padding 10 × 14. Ligne 1 : « Ouvrir les réglages à tout moment » (Friz 15 `#D8CCB0`). Ligne 2 : « Maintenir » [RB] + [croix, branche basse en `#FFD24A`] « croix bas ».
- Colonne droite à **x 428**, largeur 368 :
  - y 72 : « Icônes de boutons » + aide « Les aides de l'addon s'affichent dans ce style. »
  - y 122 : 3 options radio, hauteur 48, 8 px d'écart, fond `#0F0B07`, bord `#5A4630` : **Xbox**, **PlayStation**, **Switch**. À droite de chacune, 4 pastilles 24 px (6 px d'écart), dans l'ordre physique bas, droite, gauche, haut :
    - Xbox : lettres colorées A `#8DC63F`, B `#FF5A3C`, X `#3FA9F5`, Y `#F2C43C`.
    - PlayStation : formes ✕ ○ □ △ en `#D8CCB0`.
    - Switch : lettres B A Y X en `#EFE4C8`.
    - Dans le jeu : utiliser les vraies icônes de chaque jeu d'icônes. Choisir une option change en direct les icônes de la barre d'aide.
  - y 304 : encadré **Conseil** : fond `rgba(95,192,208,.06)`, bord 1 px `rgba(159,216,226,.45)`, padding 12 × 14. Titre « Conseil » Friz 15 `#9FD8E2` ; texte sans 14 `#D8CCB0` : « Lance Battle.net depuis Steam, avec Steam Input activé : les palettes arrière et les pavés tactiles de ta manette deviennent utilisables dans le jeu. »
  - y 468 : boutons « Plus tard » (flex 1) et « Commencer » (flex 1,3, style principal), 12 px d'écart.
- Focus initial : l'option d'icônes détectée (ou Xbox par défaut).
- Barre d'aide : croix Choisir · A Valider · RB Suivant · B Plus tard. Fil : « Guide › Bienvenue ».

### 2 — Palettes arrière et pavés tactiles (`2 / 6`)
- Gauche : « Palettes arrière » à 24, 72. `ck_onb_paddles` à **24, 100**, affichée **400 × 200**. Superposer `ck_onb_paddles_glow` (même position et taille, mode ADD), en pulsation douce facultative.
- Aide à 24, 308, largeur 400 : « Si ta manette a des palettes (L4, R4, L5, R5), identifie-les une fois : tu pourras ensuite y poser des sorts. »
- Bouton « Identifier mes palettes » à **24, 360** (focus initial) → état 2b.
- Droite : « Pavés tactiles » à 448, 72. `ck_onb_touchpad` à **448, 100**, affichée **160 × 160**. Cases à cocher à x 624, y 112, lignes de 36 px, 10 px d'écart : « Pavé gauche », « Pavé droit ». Aide à 448, 272 (largeur 348) : « Chaque pavé coché devient 4 boutons : haut, bas, gauche, droite. »
  - Cocher un pavé : allumer à tour de rôle `ck_onb_touchpad_up_glow`, `_right_glow`, `_down_glow`, `_left_glow` (ADD, même position), environ 250 ms chacun.
- Filet à y 424 (x 24 → 796). Ligne « RT comme modificateur » à **24, 438** : case + libellé Friz 16 + aide « Maintenu, RT change la fonction des autres boutons, comme LT. La barre de droite ne s'ouvre plus avec RT. »
- Barre d'aide : croix Choisir · A Valider · LB RB Étape · B Retour.

### 2b — Identification en direct (état de l'écran 2)
- Même en-tête. L'illustration reste ; seul `ck_onb_paddles_<id>_glow` de la palette attendue est allumé (ordre L4, R4, L5, R5 ; pulsation).
- À 24, 308, largeur 400 : encadré au style focus, padding 14 × 16. « Appuie sur L4… » (Friz 22 `#FFD24A`) + 4 points de progression à droite (courant `#FFD24A` 10 px, autres cercles `#7A6448` 8 px). Aide `#D8CCB0` : « La palette extérieure gauche. Pas de palette ici ? Attends 5 secondes, on passe à la suivante. » (adapter : intérieure/extérieure, gauche/droite).
- À 24, 420 : ligne de statut sans 14 `#7AA04A` (palettes reconnues).
- Colonne droite à 35 % d'opacité, inerte. Seul B est actif : « Annuler ».
- Fil : « Guide › Palettes › Identification ».
- Centres des palettes **dans la fenêtre** (pour placer les libellés L4… du jeu) : L4 124,236 · L5 149,247 · R5 299,247 · R4 324,236.

### 3 — La barre manette (`3 / 6`)
- « Taille de la barre » à 24, 72.
- Ligne curseur à **24, 100**, 772 × 64 (focus initial), padding horizontal 18, 16 px d'écart : « 70 % » · rail · « 150 % » · valeur actuelle (Friz 20 `#FFD24A`, largeur min. 72, alignée à droite). Pas de 5 %. Petit repère 1 × 6 `#7A6448` sous le rail à la valeur enregistrée.
- Aide à 24, 174 : « La barre du jeu change de taille en direct. Pendant le réglage, cette fenêtre se réduit en haut de l'écran pour la laisser voir. »
- Filet à y 204.
- Option à **24, 226**, largeur 496 : case « Gâchettes : appuyer pour basculer » + aide « Un appui sur LT garde la barre de gauche active jusqu'au prochain appui (même chose pour RT à droite). Décoché : il faut maintenir la gâchette. »
- `ck_onb_toggle` à **540, 214**, taille native **256 × 128** ; `ck_onb_toggle_glow` par-dessus (ADD) quand la case est cochée.
- Avertissement à **24, 364**, largeur 772 : fond `rgba(240,160,144,.06)`, bord 1 px `rgba(240,160,144,.55)`, padding 14 × 16. Titre « Barre compacte du mode Édition » Friz 16 `#F0A090`. Texte sans 14 / 19 `#D8CCB0` (**à valider**) : « Si la barre d'actions compacte du mode Édition est activée, le jeu peut l'afficher sous la barre manette. Bug actuel du jeu : sa position n'est pas toujours enregistrée. En attendant un correctif, désactive-la dans le mode Édition. »
- Barre d'aide : croix (gauche/droite en `#FFD24A`) Ajuster · A Aperçu · LB RB Étape · B Retour.

### 3b — Aperçu de taille, fenêtre réduite (état de l'écran 3)
- Déclenché au premier changement de valeur du curseur (ou par A sur le curseur).
- La fenêtre passe à **820 × 176**, centrée horizontalement, **à 24 px du haut de l'écran** ; si la barre manette est placée en haut, la caler en bas à la place.
- Contenu : y 14 « Taille de la barre » (Friz 18 `#F2C43C`) + « Guide · 3 / 6 » à droite ; y 46 la même ligne curseur (772 × 64, focus) ; y 128 barre d'aide réduite : « Aperçu en direct » · croix Ajuster · A Garder · B Annuler.
- La vraie barre manette change d'échelle en direct (70 → 150 %).
- **A** : garde la valeur ; **B** : revient à la valeur d'avant l'aperçu. Dans les deux cas la fenêtre reprend 820 × 580 à sa position d'origine, focus sur le curseur.

### 4 — Le clavier de chat (`4 / 6`)
- Ligne à 24, 72, 772 × 52 : « Clavier de chat » (Friz 16) + aide « S'ouvre quand tu écris dans le chat ou dans une zone de texte. » ; interrupteur à droite.
- Deux cartes **378 × 380** à **24, 136** et **418, 136**, coins 6, padding 180 / 18 / 16 (le haut est réservé à l'illustration). Carte non choisie : fond `#0F0B07`, bord 1,5 px `#5A4630`. Carte choisie et focalisée : fond `#2A210E` → `#140F08`, bord 2 px `#FFD24A`, halo. Radio en haut à droite du titre.
  - Illustrations 160 × 160 : `ck_onb_daisywheel` à **133, 150** ; `ck_onb_splitkb` à **527, 150**. Illustration de la carte non choisie à 70 % d'opacité.
  - **Marguerite** (titre Friz 18) : « 8 pétales de 4 caractères autour du stick. Le stick choisit un pétale, A B X Y le caractère. »
  - **Clavier 2 sticks** : « Le clavier coupé en deux moitiés : chaque stick déplace son curseur sur sa moitié. »
  - Sous la description de la **carte choisie** (en bas de la carte) : deux lignes, libellé 96 px (aide 14) + sélecteur : « Disposition » ◀ AZERTY | QWERTY | QWERTZ | Espagnol | Italien ▶ ; « Suggestions » ◀ langue ▶. Par défaut : disposition et langue déduites de la langue du client.
  - Carte non choisie : à la place des options, « Choisis cette carte pour voir ses options. » (sans 13 `#6F6452`).
- Interrupteur coupé : les deux cartes à 35 % d'opacité et exclues du focus.
- Barre d'aide : croix Choisir · A Valider · LB RB Étape · B Retour.

### 5 — Les roues et le mode Soigneur (`5 / 6`)
- Deux cartes **378 × 172** à **24, 72** et **418, 72** : fond `#120D08`, bord 1,5 px `#5A4630`, coins 6, padding 12 / 16 / 12 / **144** (la gauche est réservée à l'illustration).
  - `ck_onb_wheel_consumables` à **40, 88** ; `ck_onb_wheel_usable` à **434, 88** ; **112 × 112**. Roue désactivée : illustration à 60 %.
  - Contenu : titre Friz 16 `#F2C43C` (« Roue des consommables » / « Roue des objets utilisables ») ; aide (« Potions, nourriture, bandages. » / « Sac de couchage, étendard, objets de quête. ») ; ligne « Activée »/« Désactivée » + interrupteur ; en bas, bouton 34 px « Choisir sa touche » + ligne « Touche : [LB] + [Y] » ou « Aucune touche » (`#6F6452`).
  - « Choisir sa touche » : attend la prochaine combinaison pressée (même mécanique que l'identification des palettes), B annule.
- Ligne d'options à y 256, hauteur 44, filet bas `#3A2C1D` : à x 24 (378 de large) case « Maintenir pour afficher » ; à x 418 « Stick pour viser » + sélecteur 140 px ◀ Gauche | Droit ▶.
- **Bloc Soigneur** à **24, 312**, **772 × 204** : fond `#120D08`, bord 1 px `#7A5D36`, coins 6, padding 16 / 18 / 16 / 180. **Affiché seulement pour les classes de soin** (sinon masqué ; descendre alors les cartes du haut de 20 px pour recentrer).
  - `ck_onb_wheel_party` à **40, 328**, **144 × 144**.
  - Titre « Mode Soigneur » Friz 18 `#F2C43C` ; pastille « Classes de soin » à droite (sans 12 `#9D917A`, bord 1 px `#4A3A26`, rayon 10).
  - Texte sans 14 / 19 `#D8CCB0` : « Une petite roue de groupe sur un bouton : vise un membre avec le stick, sa couleur montre sa vie (vert, jaune, rouge). Relâche pour lancer le soin sur lui. »
  - Bouton « Poser un soin sur un bouton » en bas.
  - Si l'on veut des % chiffrés, centres des portraits dans la fenêtre : 112,357 · 155,388 · 138,439 · 86,439 · 69,388.
- Barre d'aide : croix Choisir · A Valider · LB RB Étape · B Retour. Fil : « Guide › Roues ».

### 6 — Confort et c'est parti (`6 / 6`, titre « Confort, et c'est parti »)
- « Confort » à 24, 72. Liste à **24, 100**, largeur 452, 7 lignes de **54 px** séparées par un filet `#3A2C1D` ; padding horizontal 14, 12 px d'écart : icône 32 × 32 (icône du jeu dans un cadre `#5A4630`), libellé Friz 15 + aide sans 13, case à droite. Première ligne focalisée par défaut.
  1. Rouge hors de portée — « Les boutons rougissent si la cible est trop loin. »
  2. Objets de quête — « Signale les objets de quête dans tes sacs. »
  3. Meilleur équipement — « Flèche verte sur un objet meilleur que le tien. »
  4. Suivi des réserves — « Prévient quand munitions ou nourriture baissent. »
  5. Vendre les gris et réparer — « Automatique chez le marchand. »
  6. Vibrations — « La manette vibre aux moments importants. »
  7. Rester assis en mangeant — « Le stick ne te relève pas pendant le repas. »
  - Valeur initiale = valeur actuelle du réglage.
- Filet vertical 1 px `#3A2C1D` à x 492 (y 72 → 516).
- `ck_onb_done` à **584, 72**, **128 × 128**.
- « Récapitulatif » à 508, 212 (Friz 15 `#F2C43C`), puis grille 2 colonnes (clé `#9D917A` / valeur `#D8CCB0`, sans 14 / 18, 4 × 14 px d'écart), construite à partir des choix : Icônes, Palettes, Pavés, Barre, Clavier, Roues.
- Boutons à 508, 388, largeur 288, 10 px d'écart : « Poser mes sorts » (ferme le guide et ouvre l'onglet Manette du panneau) ; « Terminer » (style principal ; ferme le guide et le marque comme vu).
- À 508, 492 : « Relancer ce guide : Accueil › Guide, ou /ec welcome » (sans 13 `#9D917A`).
- Barre d'aide : croix Choisir · A Cocher/Décocher · LB Étape · B Retour. Fil : « Guide › Confort ».

## État à gérer
- `EasyControllerDB.onboarding = { seen = bool, version = n }` : afficher au premier lancement **seulement pour une nouvelle installation** (pas de base de données de réglages existante) ; `Terminer`, `Plus tard` ou X → `seen = true`.
- `currentStep` (1–6), `focusIndex` par écran, `mode` (`normal` | `identifyPaddles` | `bindKey` | `sizePreview`).
- Écran 3 : `previewStartScale` (pour l'annulation par B).
- Écran 2b : `paddleQueue = {l4, r4, l5, r5}`, index courant, minuteur de 5 s.
- Écran 5 : visibilité du bloc Soigneur selon la classe (et la spécialisation si besoin).
- Tous les autres contrôles lisent et écrivent directement les réglages existants de l'addon.
- `/ec welcome` et Accueil › Guide rouvrent à l'étape 1 sans toucher aux réglages.

## Tokens de design
Couleurs (valeurs du panneau existant) :
- Fonds : fenêtre `#16110C`, panneau `#120D08`, contrôle `#0F0B07`.
- Or : titre `#F2C43C`, sélection/focus `#FFD24A`, or atténué `#C9A25A`, texte sélectionné `#FFF3D0`.
- Textes : `#EFE4C8` / `#D8CCB0`, aide `#B9AB8C`, gris `#9D917A`, désactivé `#6F6452`.
- Bronze `#7A5D36` ; filets `#5A4630` / `#4A3A26` / `#3A2C1D` ; bord de cadre `#7A6448`.
- Statut : info `#9FD8E2`, avertissement `#F0A090`, danger `#FF7A5C`, validé `#7AA04A`, « à vous » `#5FC0D0`.
- Fonds de focus : `#3A2E12` → `#221A0A` ; carte choisie `#2A210E` → `#140F08` ; interrupteur actif `#2E2410`.

Typographie : titre d'étape 22 ; sous-titre de carte 18 ; libellé de section et bouton 16 ; libellé de ligne et barre d'aide 15 ; aide 14 (13 pour les petites lignes) ; sur-titre 11.
Espacements : marge latérale 24 ; écart entre colonnes 20–24 ; écart entre lignes 8–10 ; hauteurs de contrôle 20 / 32 / 34 / 40 / 48 / 54 / 64.
Coins : 3 (case), 4 (bouton, champ), 6 (carte), 10 (pilule).

## Textures (livrables)
20 PNG RGBA, fond transparent, tailles en puissances de 2, à copier dans `design/textures/`. Les `_glow` ont la même taille et la même position que leur texture de base : `SetBlendMode("ADD")`, puis on joue sur l'alpha pour allumer, éteindre ou faire pulser. Les tailles d'affichage sont des réductions exactes (`SetSize`), jamais des agrandissements.

| Fichier | Taille | Écran | Position x, y | Affichage | Rôle |
|---|---|---|---|---|---|
| ck_onb_welcome | 512×256 | 1 | 24, 72 | 384×192 | Manette de face, bouton du bas allumé |
| ck_onb_paddles | 512×256 | 2, 2b | 24, 100 | 400×200 | Manette de dos, 4 palettes dorées |
| ck_onb_paddles_glow | 512×256 | 2 | 24, 100 | 400×200 | Les 4 palettes allumées |
| ck_onb_paddles_l4_glow / _r4_ / _l5_ / _r5_glow | 512×256 | 2b | 24, 100 | 400×200 | Une palette allumée |
| ck_onb_touchpad | 256×256 | 2 | 448, 100 | 160×160 | Pavé en 4 zones (diagonales) |
| ck_onb_touchpad_up / _right / _down / _left_glow | 256×256 | 2 | 448, 100 | 160×160 | Une zone allumée |
| ck_onb_toggle | 256×128 | 3 | 540, 214 | 256×128 | LT pressé → barre gauche maintenue |
| ck_onb_toggle_glow | 256×128 | 3 | 540, 214 | 256×128 | LT + barre gauche allumés |
| ck_onb_daisywheel | 256×256 | 4 | 133, 150 | 160×160 | Marguerite 8 pétales × 4 |
| ck_onb_splitkb | 256×256 | 4 | 527, 150 | 160×160 | Clavier en 2 moitiés + 2 sticks |
| ck_onb_wheel_consumables | 256×256 | 5 | 40, 88 | 112×112 | Roue 8 cases : potions, nourriture |
| ck_onb_wheel_usable | 256×256 | 5 | 434, 88 | 112×112 | Roue 6 cases : sac de couchage, étendard, parchemin, clé, bourse |
| ck_onb_wheel_party | 256×256 | 5 | 40, 328 | 144×144 | 5 portraits en pentagone, anneaux de vie |
| ck_onb_done | 256×256 | 6 | 584, 72 | 128×128 | Médaille avec coche |

Centres utiles dans les textures : palettes L4 128,174 · L5 160,188 · R5 352,188 · R4 384,174 (dans `ck_onb_paddles`, 512×256) ; portraits 128,52 · 204,107 · 175,197 · 81,197 · 52,107 (dans `ck_onb_wheel_party`, 256×256).

Aucune texture ne reprend de logo ni d'art du jeu ; les manettes sont génériques.

## Fichiers
- `Onboarding.dc.html` (+ `support.js`) — maquettes de référence : écrans 1, 2, 2b, 3, 4, 5, 6, 3b, galerie des textures et tableau. À ouvrir dans un navigateur ; il charge les PNG depuis `textures/`.
- `textures/` — les 20 PNG à copier dans `design/textures/`.
- `tools/draw_textures.js` — source de dessin des textures (Canvas 2D, fonction `drawAll(createCanvas)` qui renvoie `{ out: { nom: canvas }, meta }`). Permet de regénérer ou retoucher une texture.
- `reference/` — captures du panneau de réglages existant (style à suivre).
