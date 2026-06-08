# Analyse experte des FFOR temporels

## 1. Comment lire les figures

Le FFOR représente l'ensemble des couples `(P_pcc, Q_pcc)` que le réseau de
distribution peut présenter au point de couplage commun (PCC), compte tenu des
commandes disponibles et des contraintes du modèle.

La convention de signe du notebook est la suivante :

- `P_pcc > 0` : puissance active importée depuis le réseau amont ;
- aller vers la gauche : diminuer l'import, grâce à plus de production locale
  ou moins de consommation des pompes à chaleur ;
- aller vers la droite : augmenter l'import, en écrêtant le PV ou en conservant
  les pompes à chaleur à leur consommation maximale ;
- aller vers le bas : les onduleurs fournissent du réactif localement
  (`Q_pv > 0`), donc le PCC en importe moins ;
- aller vers le haut : les onduleurs absorbent du réactif (`Q_pv < 0`), donc le
  PCC doit en importer davantage.

### Construction du contour avec 72 directions

Le solveur ne connaît pas directement la forme complète du FFOR. Il sait
seulement chercher le point faisable le plus extrême dans une direction donnée.
Le code définit donc 72 angles régulièrement espacés sur un tour complet :

`phi = 0, 5, 10, ..., 355 degrés`

Pour chaque angle, il construit le vecteur :

`(a, b) = (cos(phi), sin(phi))`

puis Gurobi minimise la fonction :

`a * P_pcc + b * Q_pcc`

sous toutes les contraintes électriques. Cette fonction définit une droite
`a*P + b*Q = constante`, perpendiculaire au vecteur `(a,b)`. En la déplaçant
jusqu'à ce qu'elle touche pour la première fois l'ensemble faisable, on obtient
un point extrême, appelé point de support.

Quelques directions permettent de voir immédiatement le mécanisme :

- `phi = 0 deg` : minimiser `P_pcc`, donc trouver le point le plus à gauche ;
- `phi = 90 deg` : minimiser `Q_pcc`, donc trouver le point le plus bas ;
- `phi = 180 deg` : minimiser `-P_pcc`, donc maximiser `P_pcc` et trouver la
  droite du FFOR ;
- `phi = 270 deg` : minimiser `-Q_pcc`, donc maximiser `Q_pcc` et trouver le
  point le plus haut ;
- les angles intermédiaires recherchent les coins et les côtés obliques.

Les 72 points obtenus sont ensuite classés dans l'ordre des angles. Le code
relie chaque point au suivant et relie le dernier au premier. Le contour affiché
est donc une approximation polygonale de la frontière réelle. Les segments
tracés ne correspondent pas à de nouvelles optimisations : ils sont seulement
les droites dessinées entre deux solutions voisines.

Le nombre 72 n'est ni une propriété physique du réseau ni une contrainte du
FFOR. C'est un choix numérique de résolution :

- `360 / 72 = 5 degrés` entre deux recherches ;
- moins de directions accélère le calcul, mais donne un contour plus grossier
  et peut manquer un petit chanfrein ;
- davantage de directions améliore la description des parties courbes ou des
  changements rapides de contrainte, mais augmente le temps de calcul ;
- passer de 72 à 144 directions donne un pas de `2.5 degrés` et double
  approximativement le nombre d'optimisations.

Pour la figure complète, les huit snapshots, les deux scénarios et les
72 directions représentent `8 * 2 * 72 = 1152` optimisations, chacune suivie
d'une validation AC. Le choix de 72 constitue donc un compromis raisonnable
entre précision visuelle et durée de calcul.

Comme le problème d'optimisation linéarisé est convexe, cette méthode décrit
bien son enveloppe convexe. Une longue face indique généralement qu'une même
contrainte reste dominante sur plusieurs directions. Un coin ou un chanfrein
indique un changement de contrainte active. En revanche, la ligne entre deux
points validés n'est pas elle-même testée point par point par le calcul AC :
elle doit être comprise comme une interpolation graphique du contour.

## 2. Contraintes qui construisent les contours

Pour chaque bus hors PCC, le modèle impose :

`P_bus = P_pv + P_hp + P_load`

`Q_bus = Q_pv + Q_load`

avec :

- `0 <= P_pv <= P_pv_disponible` ;
- `P_hp_min <= P_hp <= 0`, où `P_hp_min` est négatif ;
- `-Q_pv_max <= Q_pv <= Q_pv_max` ;
- `P_pv^2 + Q_pv^2 <= S_inv^2` ;
- `0.90 <= V <= 1.10 p.u.` dans le modèle linéarisé ;
- `P_ligne^2 + Q_ligne^2 <= S_ligne_max^2`.

Le mode de charge actuel est `FFOR_LOAD_MODE = "fixed"`. Les charges actives et
réactives ordinaires ne changent donc pas entre les huit cas. La variation
temporelle vient essentiellement de la disponibilité PV et de la consommation
maximale des pompes à chaleur.

Les diagnostics montrent que :

- sans BelalpSolar, les limites réactives cumulées des PV locaux
  (`+/-0.873 MVAr`) construisent la plupart des faces horizontales ;
- avec BelalpSolar, la tension linéarisée à `0.90` ou `1.10 p.u.` devient souvent
  la contrainte dominante des faces haute et basse ;
- aucune ligne ne dépasse 100 % lors de la validation AC ; le maximum observé
  est environ 76.8 % sur la ligne de raccordement de BelalpSolar ;
- la contrainte circulaire des onduleurs n'est pas active aux quatre points
  cardinaux diagnostiqués. Les bornes explicites de réactif et les tensions sont
  plus restrictives ;
- la validation AC donne des tensions minimales d'environ 0.977 à 0.990 p.u.,
  alors que le modèle linéarisé atteint parfois 0.90 p.u. Le modèle linéarisé
  est donc conservateur et déforme une partie du contour.

## 3. Capacité modélisée de BelalpSolar

BelalpSolar est modélisé avec :

- puissance installée : `8.1 MWp` ;
- facteur de puissance minimal supposé : `cos(phi) = 0.95` ;
- puissance apparente d'onduleur : `8.1 / 0.95 = 8.526 MVA` ;
- capacité réactive fixe :
  `Qmax = 8.1 * tan(arccos(0.95)) = 2.662 MVAr`.

Le modèle autorise donc BelalpSolar entre `-2.662` et `+2.662 MVAr`, sous la
limite circulaire de 8.526 MVA. Cette capacité est aussi disponible lorsque
`P_pv = 0`, ce qui suppose un fonctionnement nocturne de l'onduleur en mode
STATCOM. C'est une hypothèse technique forte, pas une conséquence automatique
de la centrale.

Avec les PV locaux, la borne réactive agrégée théorique devient
`+/-3.535 MVAr`. Cette valeur n'est pas toujours atteignable au PCC à cause des
tensions et de la position électrique des onduleurs.

## 4. Points de départ

Les croix ne sont ni le centre du FFOR ni un optimum. Elles représentent le
calcul AC obtenu avec :

- tout le PV disponible injecté ;
- toutes les pompes à chaleur à leur consommation du snapshot ;
- `Q_pv = 0` pour tous les onduleurs ;
- les charges ordinaires fixes.

| Cas | Sans BelalpSolar `(P,Q)` | Avec BelalpSolar `(P,Q)` | PV avec Belalp | HP |
|---|---:|---:|---:|---:|
| Été 07h | (8.539, 3.745) | (6.333, 3.711) | 2.899 MW | -0.333 MW |
| Été 12h | (7.739, 3.734) | (3.285, 3.753) | 5.962 MW | -0.296 MW |
| Été 18h | (9.209, 3.755) | (9.107, 3.749) | 0.131 MW | -0.318 MW |
| Été 00h | (9.050, 3.752) | (9.050, 3.750) | 0 MW | -0.129 MW |
| Hiver 07h | (12.964, 3.823) | (12.251, 3.792) | 0.756 MW | -4.043 MW |
| Hiver 12h | (10.271, 3.771) | (5.440, 3.764) | 6.325 MW | -2.795 MW |
| Hiver 18h | (12.323, 3.810) | (12.323, 3.807) | 0 MW | -3.350 MW |
| Hiver 00h | (10.754, 3.780) | (10.754, 3.777) | 0 MW | -1.808 MW |

La croix est proche du bord droit en hiver sans BelalpSolar parce que les
pompes à chaleur consomment déjà presque au maximum. Elle est proche du bord
gauche à midi avec BelalpSolar parce que toute la production disponible est
déjà injectée.

## 5. Analyse côté par côté

### Été 07h

**Sans BelalpSolar, bleu.** Le départ est `(8.539, 3.745)`. La face gauche,
jusqu'à `P = 8.200 MW`, vient surtout de l'arrêt des HP, tandis que le PV local
reste à `0.709 MW`. La face droite à `P = 9.259 MW` combine PV écrêté à zéro et
HP à `-0.333 MW`. Le bas à `Q = 2.862 MVAr` correspond à la fourniture maximale
des PV locaux, `Q_pv = +0.873 MVAr`. Le haut à `Q = 4.635 MVAr` correspond à
`Q_pv = -0.873 MVAr`. Le contour est presque rectangulaire car ni la tension ni
les lignes ne dominent fortement.

**Avec BelalpSolar, vert.** Le départ se déplace à `(6.333, 3.711)` grâce aux
`2.191 MW` de BelalpSolar. La face gauche à `P = 6.020 MW` est imposée par PV
au maximum et HP arrêtées. La face droite revient à `P = 9.254 MW`, presque
comme sans Belalp, car tous les PV peuvent être écrêtés à zéro. Le bas
`Q = 1.196 MVAr` est limité par la tension haute linéarisée à `1.10 p.u.` avant
que toute la capacité réactive théorique soit utilisée. Le haut
`Q = 6.025 MVAr` touche la tension basse linéarisée à `0.90 p.u.`. Les deux
diagonales traduisent le compromis : forte production active plus fourniture de
réactif élève la tension, tandis que forte absorption de réactif l'abaisse.

### Été 12h

**Sans BelalpSolar, bleu.** Le départ est `(7.739, 3.734)`. La gauche
`P = 7.438 MW` est obtenue avec `1.462 MW` de PV et les HP arrêtées. La droite
`P = 9.221 MW` vient du PV nul et des HP à `-0.296 MW`. Le bas
`Q = 2.852 MVAr` et le haut `Q = 4.634 MVAr` sont presque exactement les bornes
`Q_pv = +/-0.873 MVAr`. Le rectangle est donc principalement un produit des
bornes actives PV/HP et de la borne réactive des PV locaux.

**Avec BelalpSolar, vert.** Le départ devient `(3.285, 3.753)` avec `5.962 MW`
de PV total, dont `4.500 MW` à Belalp. La gauche `P = 3.064 MW` correspond au PV
maximal et aux HP arrêtées ; elle exige déjà de l'absorption réactive pour
éviter la surtension. La droite `P = 9.216 MW` correspond à tous les PV
écrêtés. Le bas `Q = 1.205 MVAr` touche `Vmax = 1.10 p.u.`. Le haut
`Q = 7.394 MVAr` utilise la borne réactive totale
`Q_pv = -3.535 MVAr`, dont Belalp à `-2.662 MVAr`, et touche aussi
`Vmin = 0.90 p.u.`. La grande diagonale supérieure droite signifie qu'en
augmentant l'import actif, la chute de tension augmente et laisse moins de
marge pour absorber du réactif. La diagonale inférieure gauche signifie qu'à
forte production active, il faut réduire l'injection réactive ou absorber du
réactif pour rester sous la tension maximale.

### Été 18h

**Sans BelalpSolar, bleu.** Le départ `(9.209, 3.755)` ne contient que
`0.032 MW` de PV. La largeur active, de `8.886` à `9.242 MW`, provient donc
presque entièrement de la modulation des HP entre zéro et `-0.318 MW`.
Les faces basse et haute restent les bornes locales `Q_pv = +/-0.873 MVAr`,
d'où `Q = 2.872` à `4.635 MVAr`.

**Avec BelalpSolar, vert.** Le départ est `(9.107, 3.749)` et Belalp ne fournit
que `0.099 MW`. La largeur active reste faible : `8.783` à `9.239 MW`.
En revanche, le bas descend à `1.199 MVAr` grâce au réactif des onduleurs, avec
la tension haute linéarisée active. Le haut est limité à `3.914 MVAr` par la
tension basse linéarisée. Belalp injecte alors environ `+0.701 MVAr` pour
soutenir son bus éloigné pendant que d'autres PV absorbent du réactif. Cette
répartition géographique explique pourquoi la capacité agrégée ne se traduit
pas par une simple extension symétrique vers le haut.

### Été 00h

**Sans BelalpSolar, bleu.** Le départ est `(9.050, 3.752)`. Sans PV actif, la
largeur `8.918` à `9.053 MW` vient uniquement des HP, limitées à `0.129 MW`.
Les onduleurs PV locaux gardent néanmoins leur capacité réactive dans le
modèle : le contour s'étend de `Q = 2.872` à `4.632 MVAr`.

**Avec BelalpSolar, vert.** Le départ actif ne change pratiquement pas, car
Belalp produit zéro. Le modèle lui laisse cependant fonctionner en compensateur
réactif nocturne. Le bas atteint `1.244 MVAr` et touche `Vmax = 1.10 p.u.`.
Le haut n'atteint que `3.818 MVAr` et touche `Vmin = 0.90 p.u.`. À ce point,
Belalp injecte environ `+0.800 MVAr` pour tenir sa tension, tandis que les PV
locaux absorbent davantage. La forme verte est donc principalement un FFOR
réactif sous hypothèse STATCOM nocturne.

### Hiver 07h

**Sans BelalpSolar, bleu.** Le départ `(12.964, 3.823)` est très proche de la
droite parce que les HP consomment `4.043 MW`. La gauche `P = 8.855 MW` est
obtenue en arrêtant ces HP ; le faible PV de `0.063 MW` joue peu. La droite
`P = 13.028 MW` garde les HP au maximum et écrête le PV. Le bas
`Q = 2.871 MVAr` vient de `Q_pv = +0.873 MVAr`. Au haut
`Q = 4.682 MVAr`, `Q_pv = -0.873 MVAr` et la tension linéarisée atteint
`0.90 p.u.` ; il faut déjà réduire la consommation HP à `3.545 MW`, ce qui
forme le chanfrein supérieur droit.

**Avec BelalpSolar, vert.** Le départ est `(12.251, 3.792)` avec `0.693 MW` de
Belalp. La gauche `P = 8.147 MW` vient des HP arrêtées et de tout le PV injecté.
La droite `P = 13.031 MW` vient du PV nul et des HP au maximum. Le bas
`Q = 0.454 MVAr` exige presque toute la consommation HP afin de compenser
l'effet de hausse de tension de l'injection réactive. Le haut
`Q = 4.476 MVAr` exige au contraire l'arrêt presque complet des HP pour éviter
la sous-tension. Les deux grandes diagonales vertes sont donc un couplage
tension active-réactive, pas une diminution arbitraire de la capacité.

### Hiver 12h

**Sans BelalpSolar, bleu.** Le départ `(10.271, 3.771)` combine `1.462 MW` de PV
et `2.795 MW` de HP. La gauche `P = 7.438 MW` arrête les HP avec PV maximal.
La droite `P = 11.759 MW` écrête le PV et garde les HP au maximum. Le bas
`Q = 2.851 MVAr` est la fourniture réactive locale maximale. Le haut
`Q = 4.677 MVAr` combine la borne d'absorption locale avec la tension
linéarisée basse ; le coin supérieur droit est légèrement coupé.

**Avec BelalpSolar, vert.** Le départ se déplace à `(5.440, 3.764)` avec
`6.325 MW` de PV, dont `4.863 MW` à Belalp. La gauche `P = 2.750 MW` arrête les
HP et conserve presque tout le PV ; Belalp absorbe déjà son maximum de
`2.662 MVAr` pour contrôler la tension. La droite `P = 11.760 MW` écrête tout
le PV et garde les HP à `-2.795 MW`. Le bas `Q = 0.644 MVAr` touche
`Vmax = 1.10 p.u.`. Le haut `Q = 7.420 MVAr` atteint la borne réactive totale
`-3.535 MVAr` et `Vmin = 0.90 p.u.`. La ligne Belalp est la plus chargée, mais
seulement à environ 76.8 % en AC : elle influence la forme sans constituer la
limite thermique. C'est le cas où BelalpSolar agrandit le plus le FFOR.

### Hiver 18h

**Sans BelalpSolar, bleu.** Le départ `(12.323, 3.810)` ne contient aucun PV
actif. La largeur `8.917` à `12.322 MW` vient presque entièrement des HP
(`3.350 MW`). Le bas `Q = 2.872 MVAr` est la fourniture maximale des onduleurs
locaux. Le haut `Q = 4.679 MVAr` touche la borne d'absorption locale et la
tension basse ; les HP doivent être légèrement réduites, d'où le coin coupé.

**Avec BelalpSolar, vert.** Belalp ne produit pas d'actif, mais conserve sa
fonction réactive supposée. La gauche `P = 8.916 MW` correspond aux HP arrêtées,
la droite `P = 12.334 MW` aux HP au maximum. Le bas `Q = 0.560 MVAr` se trouve
près de la droite car la consommation HP aide à contenir la hausse de tension
causée par l'injection réactive. Le haut `Q = 3.818 MVAr` se trouve près de la
gauche car l'absorption réactive et la consommation HP provoqueraient ensemble
une sous-tension. La pente du contour exprime directement ce couplage.

### Hiver 00h

**Sans BelalpSolar, bleu.** Le départ est `(10.754, 3.780)`. La largeur
`8.919` à `10.753 MW` correspond à la modulation de `1.808 MW` de HP. Les faces
réactives restent proches de `Q = 2.872` et `4.660 MVAr`, avec un léger
chanfrein de sous-tension en haut à droite.

**Avec BelalpSolar, vert.** Le départ actif est identique, car le PV est nul.
La gauche `P = 8.916 MW` arrête les HP ; la droite `P = 10.759 MW` les maintient
au maximum. Le bas `Q = 0.852 MVAr` nécessite presque toute la consommation HP
pour permettre l'injection réactive sans surtension. Le haut
`Q = 3.818 MVAr` nécessite au contraire presque l'arrêt des HP pour éviter la
sous-tension. Comme à 18h, la diagonale verte est la signature de la contrainte
de tension et de l'hypothèse de réactif nocturne de BelalpSolar.

## 6. Conclusions physiques

1. Les faces verticales sont principalement des saturations de puissance
   active : PV maximal plus HP arrêtées à gauche, PV écrêté plus HP au maximum
   à droite.
2. Sans BelalpSolar, les faces horizontales sont surtout les bornes réactives
   cumulées des PV locaux, `+/-0.873 MVAr`.
3. Avec BelalpSolar, les faces obliques sont principalement créées par les
   limites de tension linéarisées. Fournir du réactif et produire beaucoup de
   puissance active augmente la tension ; absorber du réactif et consommer
   beaucoup d'actif la diminue.
4. Le point de départ est asymétrique par construction : PV au maximum, HP à
   leur consommation du snapshot et réactif nul. Il ne doit pas être interprété
   comme le centre du FFOR.
5. Les résultats nocturnes avec BelalpSolar dépendent entièrement de
   l'hypothèse que l'onduleur peut fonctionner en STATCOM sans production
   solaire. Si cette fonction n'existe pas contractuellement ou techniquement,
   il faut imposer `Q_pv = 0` lorsque `P_pv_disponible = 0`.
6. Le décalage entre la tension linéarisée active à 0.90/1.10 p.u. et les
   tensions AC réelles proches de 0.98/0.99 p.u. indique que les bords verts
   sont conservateurs. Pour une interprétation opérationnelle, il faudrait
   construire le contour avec une boucle AC ou recalibrer les sensibilités
   autour de chaque snapshot.

Les valeurs détaillées utilisées dans cette analyse sont enregistrées dans
`FFOR_temporal_constraint_diagnostics.csv`.
