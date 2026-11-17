function c = coefficientsFer(name)
%COEFFICIENTSFER Jeux de coefficients du modèle de pertes fer de Bertotti.
%   c = coefficientsFer(name) renvoie le jeu de coefficients nommé name pour
%   le modèle à trois termes (pertes massiques, induction sinusoïdale de
%   crête B [T] à la fréquence f [Hz]) :
%       p = kh f B^alpha + kc (f B)^2 + kexc (f B)^1.5        [W/kg]
%   c = coefficientsFer() renvoie le jeu par défaut ("m330_35a").
%   noms = coefficientsFer("liste") renvoie les noms des jeux disponibles.
%
%   c : structure
%     name      nom du jeu
%     kh        hystérésis                      [W/kg/Hz/T^alpha]
%     alpha     exposant de l'induction (hystérésis)
%     kc        pertes classiques (Foucault)    [W/kg/(Hz T)^2]
%     kexc      pertes excédentaires            [W/kg/(Hz T)^1.5]
%     density   masse volumique de la tôle      [kg/m^3]
%     steel     nuance et épaisseur de la tôle caractérisée
%     source    origine des valeurs
%
%   Jeux disponibles :
%     "m330_35a" jeu par défaut. Tôle du prototype, ajusté par
%                pertesFer/lib/ajusterCoefficients.m sur les pertes de la
%                fiche « Typical data for SURA M330-35A » (Surahammars / Tata
%                Steel, 2009) de 50 à 400 Hz et jusqu'à 1,5 T : kh et alpha et
%                kexc ajustés, kc = pi^2 sigma d^2 / (6 rho) calculé (résistivité
%                42 µOhm.cm, 0,35 mm). Écart moyen 5 % sur les points ajustés.
%     "initial"  M330-35A, fiche matériau (EN 10106 : 1,30 W/kg à 1,0 T / 50 Hz
%                et 3,30 W/kg à 1,5 T / 50 Hz), kc = pi^2 sigma d^2 / (6 rho),
%                sans terme excédentaire. Jeu des rapports du 5 nov. 2026.
%     "hugo"     coefficients transmis par Fabien, forme de la thèse de
%                H. Helbling (Lille, 2021, Eq. 13 et 57). La thèse caractérise
%                une tôle M400-65A (0,65 mm) : kc y vaut 2,45e-4, soit la valeur
%                d'une tôle de 0,65 mm (kc varie comme d^2 ; 5,3e-5 pour 0,35 mm).
%
%     "boglietti3335"  tôle de 0,35 mm de même classe que la M330-35A (3,3 W/kg
%                à 1,5 T / 50 Hz), coefficients a, b, x de Boglietti et al. 2003
%                (table III). Le terme excédentaire y est ajusté à zéro : il
%                est inclus dans kc (courants induits globaux).
%
%   Pour ajouter un jeu : ajouter une ligne dans la table ci-dessous.
%
%   See also pertesFer, rendement.

arguments
    name (1,1) string = "m330_35a"
end

% name, kh, alpha, kc, kexc, density, steel, source
jeux = {
    "m330_35a", 0.018162, 1.896, 6.272e-5,  0.0007628,  7650, "M330-35A (0,35 mm)", "ajusté sur la fiche Typical data for SURA M330-35A (Surahammars / Tata Steel, 2009), 50 à 400 Hz, J <= 1,5 T ; kc calculé"
    "initial", 0.02337,  2.33,   5.27e-5,    0,          7650, "M330-35A (0,35 mm)", "fiche matériau EN 10106, sans terme excédentaire"
    "hugo",    0.016164, 1.8471, 0.00024571, 0.00041101, 7650, "M400-65A (0,65 mm) dans la thèse", "coefficients transmis par Fabien, thèse H. Helbling 2021 (2021LILUN026)"
    "boglietti3335", 0.0149, 2.11, 0.000097, 0,          7650, "3335 (0,35 mm, 3,3 W/kg à 1,5 T / 50 Hz)", "Boglietti et al., IEEE Trans. Magn. 39(2), 2003, table III (cadre Epstein, 10 à 150 Hz, 0,6 à 1,7 T ; pertes excédentaires incluses dans kc)"
    };
noms = string(jeux(:, 1));
if name == "liste"
    c = noms;
    return
end
k = find(noms == name, 1);
assert(~isempty(k), "coefficientsFer:nom", "Jeu de coefficients inconnu : %s (disponibles : %s).", name, strjoin(noms, ", "));
c = struct(name=noms(k), kh=jeux{k, 2}, alpha=jeux{k, 3}, kc=jeux{k, 4}, kexc=jeux{k, 5}, ...
    density=jeux{k, 6}, steel=string(jeux{k, 7}), source=string(jeux{k, 8}));
end
