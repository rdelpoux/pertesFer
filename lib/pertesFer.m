function L = pertesFer(r, S, speedRpm, options)
%PERTESFER Pertes fer (modèle de Bertotti à trois termes) d'une trajectoire simulée.
%   L = pertesFer(r, [], speedRpm) calcule les pertes fer de la machine
%   entière aux vitesses speedRpm [tr/min] à partir de l'induction de chaque
%   élément du fer, r.elements (femm5Trajectoire, ou lancerTrajectoires avec
%   l'option Elements).
%   L = pertesFer(r, S, speedRpm) fait le même calcul en des sondes : grille
%   S de sondesFer et champ r.probes (ancienne méthode, gardée pour l'étude
%   des aimants).
%
%   Formule (note pertesFer/note/main.pdf, « formule retenue »), pour chaque
%   élément et chaque composante j = x, y de l'induction, en W/kg :
%
%     p = kh * f1 * somme_c (dB_c / 2)^alpha           hystérésis
%       + kc / (2 pi^2) * < (dB/dt)^2 >                pertes classiques
%       + kexc / gamma  * < |dB/dt|^(3/2) >            pertes excédentaires
%
%     < . >   moyenne sur une période de la forme d'onde
%     dB_c    excursion crête à crête du cycle c, cycles comptés par la
%             méthode rainflow sur une période ; sans cycle mineur, il n'y a
%             qu'un cycle, dB_c = 2 Bmax, et le terme vaut kh f1 Bmax^alpha
%     gamma   (2 pi)^(3/2) < |cos u|^(3/2) > : avec cette constante (et 2 pi^2
%             pour le terme classique), la formule redonne exactement
%             kh f Bmax^alpha + kc (f Bmax)^2 + kexc (f Bmax)^(3/2) pour une
%             induction sinusoïdale, forme dans laquelle les coefficients
%             sont identifiés.
%
%   Période de la forme d'onde :
%     stator  un tour électrique, f1 = p * vitesse. Le calcul ne couvre
%             qu'un pas polaire ; l'induction change de signe d'un pas
%             polaire au suivant, ce qui donne la seconde moitié.
%     rotor   un pas polaire, f1 = 2p * vitesse. La valeur moyenne (champ
%             continu du fondamental) a une dérivée nulle : elle ne produit
%             ni pertes classiques ni pertes excédentaires.
%
%   Puissance de la machine : somme sur les éléments de p * masse, masse =
%   masse volumique * aire * longueur active, multipliée par SectorFactor
%   (2p) pour passer du pôle modélisé à la machine entière.
%
%   L : structure (champs vecteurs si speedRpm est un vecteur)
%     speedRpm, stator, rotor, total [W]
%     hysteresis, eddy, excess [W]   les trois termes, machine entière
%     statorParts, rotorParts        h, e, x, total [W] par région
%     densityStator, densityRotor    pertes par élément à la première vitesse [W/kg]
%     massStator, massRotor          masses de fer [kg]
%     countStator, countRotor        nombre d'éléments (ou de sondes)
%     x, y, isStator                 positions des éléments (ou des sondes)
%     bPeakStator, bPeakRotor        module crête de B par élément [T]
%
%   Options :
%     Coefficients  coefficientsFer()  jeu de coefficients (structure ou nom)
%     Hysteresis    "cycles"           "cycles" (formule de la note) ou
%                                      "harmoniques" (somme de kh f_n B_n^alpha,
%                                      ancienne écriture, pour comparaison)
%     SectorFactor  4                  facteur secteur -> machine entière (2p)
%     Poles         2                  paires de pôles p
%     Closed        true               la dernière position répète la première
%
%   See also coefficientsFer, femm5Trajectoire, rainflow.

arguments
    r (1,1) struct
    S {mustBeA(S, ["struct", "double"])}
    speedRpm (1,:) double
    options.Coefficients (1,1) {mustBeA(options.Coefficients, ["struct", "string", "char"])} = coefficientsFer()
    options.Hysteresis (1,1) string {mustBeMember(options.Hysteresis, ["cycles", "harmoniques"])} = "cycles"
    options.SectorFactor (1,1) double = 4
    options.Poles (1,1) double = 2
    options.Closed (1,1) logical = true
end

co = options.Coefficients;
if ~isstruct(co), co = coefficientsFer(co); end
p = options.Poles;

% --- 1. Induction par élément (ou par sonde) et masse de chaque élément ----
% bx, by : une ligne par élément, une colonne par position du rotor.
if isempty(S)
    assert(isfield(r, "elements") && ~isempty(r.elements), "pertesFer:elements", ...
        "Le résultat ne contient pas l'induction par élément (femm5Trajectoire).");
    S = r.elements; bx = double(S.bx); by = double(S.by);
else
    assert(~isempty(r.probes), "pertesFer:sondes", "Le résultat ne contient pas de sondes.");
    bx = r.probes.bx; by = r.probes.by;
end
if options.Closed                                  % retirer la position répétée
    bx = bx(:, 1:end-1); by = by(:, 1:end-1);
end
assert(abs(r.thetaDeg(end) - r.thetaDeg(1) - 180 / p) < 1e-6, "pertesFer:balayage", ...
    "Les positions doivent couvrir un pas polaire (180/p degrés).");
isStator = S.region == "stator"; isRotor = ~isStator;
% Pour les sondes, l'aire des cellules est corrigée pour retrouver l'aire
% exacte de chaque région ; pour les éléments, la correction vaut 1.
corr = ones(size(S.area));
corr(isStator) = S.areaStatorExact / S.areaStator;
corr(isRotor) = S.areaRotorExact / S.areaRotor;
masse = corr .* S.area * S.depth * co.density;     % kg par élément, pôle modélisé

% --- 2. Formes d'onde sur une période ---------------------------------------
% Stator : pas polaire suivi de son opposé = un tour électrique.
% Rotor : un pas polaire.
statorBx = [bx(isStator, :), -bx(isStator, :)];
statorBy = [by(isStator, :), -by(isStator, :)];
rotorBx = bx(isRotor, :);
rotorBy = by(isRotor, :);
fMeca = speedRpm / 60;                             % vitesse mécanique [tr/s]
f1Stator = p * fMeca;                              % fréquence fondamentale [Hz]
f1Rotor = 2 * p * fMeca;

% --- 3. Pertes de chaque région ---------------------------------------------
[pS, densS] = pertesRegion(statorBx, statorBy, f1Stator, masse(isStator), co, options.Hysteresis);
[pR, densR] = pertesRegion(rotorBx, rotorBy, f1Rotor, masse(isRotor), co, options.Hysteresis);

% --- 4. Machine entière (facteur secteur) -----------------------------------
k = options.SectorFactor;
L = struct();
L.speedRpm = speedRpm;
L.coefficients = co;
L.hysteresisMethod = options.Hysteresis;
L.statorParts = structfun(@(v) k * v, pS, UniformOutput=false);
L.rotorParts = structfun(@(v) k * v, pR, UniformOutput=false);
L.stator = L.statorParts.total;
L.rotor = L.rotorParts.total;
L.total = L.stator + L.rotor;
L.hysteresis = L.statorParts.h + L.rotorParts.h;
L.eddy = L.statorParts.e + L.rotorParts.e;
L.excess = L.statorParts.x + L.rotorParts.x;
L.densityStator = densS; L.densityRotor = densR;
L.massStator = k * sum(masse(isStator));
L.massRotor = k * sum(masse(isRotor));
L.countStator = nnz(isStator); L.countRotor = nnz(isRotor);
L.x = S.x; L.y = S.y; L.isStator = isStator;
L.bPeakStator = max(hypot(bx(isStator, :), by(isStator, :)), [], 2);
L.bPeakRotor = max(hypot(bx(isRotor, :), by(isRotor, :)), [], 2);
end

function [p, densite] = pertesRegion(Bx, By, f1, masse, co, methode)
%PERTESREGION Pertes d'une région (stator ou rotor) pour chaque vitesse.
%   Bx, By : une ligne par élément, une période de la forme d'onde en
%   colonnes (n échantillons régulièrement espacés). f1 : fréquence
%   fondamentale de la période, une valeur par vitesse [Hz]. masse : masse
%   de chaque élément [kg]. p : pertes de la région [W] par terme (h, e, x)
%   et au total, une valeur par vitesse. densite : pertes par élément à la
%   première vitesse [W/kg].

% Constante gamma = (2 pi)^(3/2) < |cos u|^(3/2) >, calculée par intégration.
gammaExc = (2 * pi)^1.5 * integral(@(u) abs(cos(u)).^1.5, 0, 2 * pi) / (2 * pi);

% Hystérésis : somme sur les cycles de (dB_c/2)^alpha. Ne dépend pas de la
% vitesse ; calculée une fois par élément.
hyst = hysteresisParPeriode(Bx, co.alpha, methode) + hysteresisParPeriode(By, co.alpha, methode);

% Dérivée de B par rapport à la phase u = 2 pi f1 t (une période = 2 pi).
% Elle est calculée dans le domaine fréquentiel : l'harmonique n,
% B_n cos(n u + phi_n), a pour dérivée -n B_n sin(n u + phi_n).
dBxdu = deriveePeriodique(Bx);
dBydu = deriveePeriodique(By);

nV = numel(f1);
p = struct(h=zeros(1, nV), e=zeros(1, nV), x=zeros(1, nV), total=zeros(1, nV));
for v = 1:nV
    w = 2 * pi * f1(v);                            % pulsation fondamentale [rad/s]
    dBxdt = w * dBxdu;                             % dB/dt = (du/dt) dB/du [T/s]
    dBydt = w * dBydu;
    % Les trois termes de la formule, en W/kg, pour chaque élément
    pHyst = co.kh * f1(v) * hyst;
    pClass = co.kc / (2 * pi^2) * (mean(dBxdt.^2, 2) + mean(dBydt.^2, 2));
    pExc = co.kexc / gammaExc * (mean(abs(dBxdt).^1.5, 2) + mean(abs(dBydt).^1.5, 2));
    % Somme sur les éléments, pondérée par leur masse [W]
    p.h(v) = sum(pHyst .* masse);
    p.e(v) = sum(pClass .* masse);
    p.x(v) = sum(pExc .* masse);
    p.total(v) = p.h(v) + p.e(v) + p.x(v);
    if v == 1, densite = pHyst + pClass + pExc; end
end
end

function d = deriveePeriodique(B)
%DERIVEEPERIODIQUE Dérivée par rapport à la phase u (période 2 pi) de chaque ligne de B.
%   Le terme de Nyquist (n = N/2 pour N pair), dont la phase est
%   indéterminée, est écarté.
N = size(B, 2);
nMax = floor((N - 1) / 2);                         % plus haut harmonique conservé
n = [0:nMax, zeros(1, N - 2 * nMax - 1), -nMax:-1];% rang de chaque raie de la FFT
d = real(ifft(1i * n .* fft(B, [], 2), [], 2));
end

function h = hysteresisParPeriode(B, alpha, methode)
%HYSTERESISPARPERIODE Terme d'hystérésis par période, sans le facteur kh f1.
%   "cycles" : somme sur les cycles rainflow de (excursion / 2)^alpha. La
%   forme d'onde est permutée pour commencer à son maximum et refermée sur
%   ce maximum ; tous les cycles comptés sont alors des cycles complets.
%   "harmoniques" : somme sur les harmoniques de n B_n^alpha (ancienne écriture).
nE = size(B, 1);
h = zeros(nE, 1);
if methode == "harmoniques"
    N = size(B, 2); nMax = floor((N - 1) / 2);
    Bn = 2 * abs(fft(B, [], 2)) / N;               % amplitudes crête des harmoniques
    h = sum((1:nMax) .* Bn(:, 2:nMax+1).^alpha, 2);
    return
end
for e = 1:nE
    x = B(e, :);
    if max(x) - min(x) < 1e-6, continue; end       % induction constante : pas de cycle
    [~, iMax] = max(x);
    cycles = rainflow([x(iMax:end), x(1:iMax)]);   % colonnes : nombre, excursion, moyenne, début, fin
    h(e) = sum(cycles(:, 1) .* (cycles(:, 2) / 2).^alpha);
end
end
