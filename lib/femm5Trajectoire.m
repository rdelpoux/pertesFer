function r = femm5Trajectoire(femFile, thetaDeg, iPhase, options)
%FEMM5TRAJECTOIRE Résout une trajectoire de courant position par position avec FEMM 5.
%   r = femm5Trajectoire(femFile, thetaDeg, iPhase) résout le modèle
%   femFile (un pôle, rotation par l'élément d'entrefer) aux positions
%   thetaDeg [deg mécaniques] avec les courants de phase iPhase (nth x 2,
%   circuits phase1 et phase2) et renvoie, à chaque position, le couple,
%   les flux de phase et l'induction de chaque élément du maillage situé
%   dans le fer. Le maillage est le même à toutes les positions : seul
%   l'angle de l'élément d'entrefer change.
%
%   Avant la résolution, les groupes des labels de bloc sont réécrits dans
%   une copie du modèle (dossier WorkDir) : 1 pour le fer du rotor, 2 pour
%   le fer du stator, 3 pour les aimants, 0 ailleurs. Cela permet de
%   reconnaître le fer dans mo_getallelements, qui rend le groupe de
%   chaque élément mais pas son matériau.
%
%   r : structure
%     thetaDeg, iPhase   entrées (colonnes)
%     torque             couple machine entière [N.m] (intégrale de l'élément d'entrefer)
%     fluxPhase          flux des circuits du modèle (secteur d'un pôle) [Wb], nth x 2
%     elements           champ par élément dans le fer, au format de pertesFer :
%                        x, y, area [m^2], region ("stator"/"rotor"), depth [m],
%                        bx, by (nElem x nth, simple précision), areaStator,
%                        areaRotor, areaStatorExact, areaRotorExact, elementCount
%     femFile, elapsed
%
%   Reprise : si WorkDir/<Name>.mat existe et a été calculé avec le même
%   modèle (même contenu du .fem), les mêmes positions et les mêmes
%   courants, il est relu.
%
%   Options :
%     Name         nom du modèle sans extension   nom du fichier résultat
%     WorkDir      "."                dossier de travail (copie du modèle, résultat)
%     Port         48015              port TCP de FEMM 5 (instance ouverte si besoin)
%     AirGap       "BandeRoulement1"  élément d'entrefer
%     Circuits     ["phase1" "phase2"]
%     IronName     "M-19 Steel"       matériau du fer
%     MagnetName   "NdFeB"            matériau des aimants
%     StatorGroup  2, RotorGroup 1    groupes d'origine du stator et du rotor
%
%   See also femm5Ouvrir, pertesFer, femLire.

arguments
    femFile (1,1) string {mustBeFile}
    thetaDeg (:,1) double
    iPhase (:,2) double
    options.Name (1,1) string = ""
    options.WorkDir (1,1) string = "."
    options.Port (1,1) double = 48015
    options.AirGap (1,1) string = "BandeRoulement1"
    options.Circuits (1,2) string = ["phase1", "phase2"]
    options.IronName (1,1) string = "M-19 Steel"
    options.MagnetName (1,1) string = "NdFeB"
    options.StatorGroup (1,1) double = 2
    options.RotorGroup (1,1) double = 1
end

nth = numel(thetaDeg);
assert(size(iPhase, 1) == nth, "femm5Trajectoire:taille", "iPhase doit avoir une ligne par position.");
[~, base] = fileparts(femFile);
name = options.Name; if strlength(name) == 0, name = base; end
workDir = options.WorkDir; if ~isfolder(workDir), mkdir(workDir); end
outFile = fullfile(workDir, name + ".mat");
empreinte = empreinteFichier(femFile);
if isfile(outFile)
    old = load(outFile, "thetaDeg", "iPhase", "femEmpreinte");
    if isfield(old, "femEmpreinte") && old.femEmpreinte == empreinte ...
            && isequal(size(old.thetaDeg), size(thetaDeg)) && max(abs(old.thetaDeg - thetaDeg)) < 1e-9 ...
            && max(abs(old.iPhase - iPhase), [], "all") < 1e-9
        r = load(outFile);
        return
    end
end

% Copie du modèle avec les groupes du fer et des aimants
fem = femLire(femFile);
iIron = find(fem.materials == options.IronName, 1);
assert(~isempty(iIron), "femm5Trajectoire:fer", "Matériau %s absent de %s.", options.IronName, femFile);
iMag = find(fem.materials == options.MagnetName, 1);
g = zeros(size(fem.labels, 1), 1);
g(fem.labels(:, 3) == iIron & fem.labels(:, 7) == options.RotorGroup) = 1;
g(fem.labels(:, 3) == iIron & fem.labels(:, 7) == options.StatorGroup) = 2;
if ~isempty(iMag), g(fem.labels(:, 3) == iMag) = 3; end
fem.labels(:, 7) = g;
femTmp = fullfile(workDir, name + "_femm5.fem");
femEcrire(fem, femTmp);

% Résolution position par position
global femmSockets %#ok<GVMIS> connexion de la liaison FEMM 5
ouvert = ~isempty(femmSockets) && isfield(femmSockets, "p" + options.Port);
if ~ouvert, femm5Ouvrir(Port=options.Port); end
c = onCleanup(@() fermer(~ouvert));
t0 = tic;
opendocument(char(femTmp));
torque = zeros(nth, 1); fluxPhase = zeros(nth, 2);
for k = 1:nth
    % (a) Position du rotor : angle intérieur (propriété 10) de l'élément
    %     d'entrefer. Le rotor tourne sans que la géométrie ni le maillage
    %     ne changent.
    mi_modifyboundprop(char(options.AirGap), 10, thetaDeg(k));
    % (b) Courants des deux phases à cette position [A].
    mi_setcurrent(char(options.Circuits(1)), iPhase(k, 1));
    mi_setcurrent(char(options.Circuits(2)), iPhase(k, 2));
    % (c) Résolution magnétostatique, puis ouverture du résultat.
    mi_analyze(1);
    mi_loadsolution;
    % (d) Induction constante par élément : pas de lissage aux noeuds.
    mo_smooth('off');
    % (e) Couple de la machine entière (intégrale sur l'élément d'entrefer)
    %     et flux des deux circuits (secteur modélisé).
    torque(k) = mo_gapintegral(char(options.AirGap), 0);
    for j = 1:2
        cp = mo_getcircuitproperties(char(options.Circuits(j)));   % [courant, tension, flux]
        fluxPhase(k, j) = cp(3);
    end
    % (f) Induction (Bx, By) au centre de tous les éléments, en un appel.
    B = mo_getallb();
    if k == 1
        % Description du maillage, relevée à la première position : noeuds,
        % centre (x, y), aire, groupe de chaque élément.
        E = mo_getallelements();
        info = mo_getprobleminfo();            % [type, fréquence, profondeur, unité de longueur]
        fer = E(:, 7) == 1 | E(:, 7) == 2;     % groupes 1 (rotor) et 2 (stator) : le fer
        bx = zeros(nnz(fer), nth, "single"); by = bx;
        centres = E(:, 4:5);
    else
        % Contrôle : le maillage doit être identique à toutes les positions.
        Ek = mo_getallelements();
        assert(size(Ek, 1) == size(E, 1) && max(abs(Ek(:, 4:5) - centres), [], "all") < 1e-12, ...
            "femm5Trajectoire:maillage", "Le maillage a changé entre deux positions (position %d).", k);
    end
    % (g) On ne garde que les éléments du fer.
    bx(:, k) = B(fer, 1); by(:, k) = B(fer, 2);
    mo_close;
end
mi_close;

unit = info(4);
elements = struct();
elements.x = E(fer, 4) * unit; elements.y = E(fer, 5) * unit;
elements.area = E(fer, 6) * unit^2;
elements.region = repmat("rotor", nnz(fer), 1); elements.region(E(fer, 7) == 2) = "stator";
elements.depth = info(3) * unit;
elements.bx = bx; elements.by = by;
st = elements.region == "stator";
elements.areaStator = sum(elements.area(st)); elements.areaRotor = sum(elements.area(~st));
elements.areaStatorExact = elements.areaStator; elements.areaRotorExact = elements.areaRotor;
elements.elementCount = size(E, 1);

r = struct(thetaDeg=thetaDeg, iPhase=iPhase, torque=torque, fluxPhase=fluxPhase, elements=elements, ...
    femFile=string(femFile), femBase=string(base), femEmpreinte=empreinte, elapsed=toc(t0), solveur="FEMM 5 (femm_headless)");
save(outFile, "-struct", "r");
end

function fermer(doitFermer)
if doitFermer, femm5Fermer(); end
end
