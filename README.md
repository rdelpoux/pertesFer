# Pertes fer de la machine synchro-réluctante LAPLACE, sans et avec aimants

Calcul des pertes fer de deux machines (sans aimant, et avec aimants
`B123_f25`) sur des trajectoires de courant à couple constant de 2 N·m, avec
FEMM 5. La méthode, les références et les résultats sont dans
`note/main.pdf`.

## Contenu

| dossier | contenu |
|---|---|
| `note/` | note LaTeX (`main.tex`, `main.pdf`), tableaux générés (`resultats.tex`), figures (PDF et EPS), fiche de la tôle M330-35A (`TataSteel_M330-35A.pdf`) |
| `modeles/` | `sans_aimant.fem`, `B123_f25.fem` : un pôle, fer en M330-35A |
| `calculPertes/` | `calculPertes.m` (simulation FEMM 5 et pertes fer), `resultatsNote.m` (figures et tableaux de la note), `courants/*.csv` (courants des trajectoires), `resultats/` (résultats) |
| `lib/` | fonctions : `femm5Trajectoire` (pilotage de FEMM 5), `pertesFer` (formule de la note), `coefficientsFer` (jeux de coefficients), `materiauM330_35A` (fiche de la tôle), `ajusterCoefficients` (ajustement du jeu `m330_35a` sur la fiche), lecture et écriture des `.fem` |
| `trajectoires/` | `trajectoires.m` : cartographies et trajectoires P0, P1 ; ses résultats sont déjà dans `calculPertes/courants` |

## Refaire le calcul des pertes

Il faut MATLAB (R2023b ou plus récent pour la syntaxe nom=valeur), la
Signal Processing Toolbox (fonction `rainflow`) et FEMM 5 (femm-qt,
https://www.femm.info) avec sa liaison MATLAB `octavefemm`.

1. Indiquer le dossier d'installation de FEMM 5 dans `calculPertes/calculPertes.m`
   (réglage `dossierFemm5`).
2. Lancer `calculPertes/calculPertes.m` (quelques minutes : 4 trajectoires de
   90 positions).
3. Lancer `calculPertes/resultatsNote.m`, puis compiler `note/main.tex`
   (`pdflatex`, ou `latex` + `dvips` + `ps2pdf`).

Les deux fonctions à relire pour vérifier le calcul sont
`lib/femm5Trajectoire.m` et `lib/pertesFer.m`.

`trajectoires/trajectoires.m` n'est pas autonome : il demande le projet
`With_Without_Magnet` placé à côté de ce dossier, le runner xfemm et les
classes de cartographie du dépôt SyntheseSynRel, et les solveurs de
trajectoires de l'article TIA de M. Grosso. Il n'est utile que
pour recalculer les courants.
