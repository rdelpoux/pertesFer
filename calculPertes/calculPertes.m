%% Pertes fer des deux machines sur les trajectoires P0 et P1, calculées avec FEMM 5
%
% Ce script fonctionne seul. Il lui faut :
%   - FEMM 5 (femm-qt), dont le dossier est donné dans les réglages ;
%   - le dossier ../lib (fonctions femm5*, femLire, femEcrire,
%     pertesFer, coefficientsFer) ;
%   - les modèles des deux machines : ../modeles/<machine>.fem ;
%   - les courants des trajectoires : courants/<machine>_<loi>.csv.
%
% Les fichiers de courants ont été écrits par ../trajectoires/trajectoires.m.
% Une ligne par position du rotor (90 positions sur un pas polaire, la
% dernière répète la première) ; colonnes :
%   theta_m_deg   position mécanique du rotor [deg]
%   id_A, iq_A    courants dans le repère dq [A]
%   i_phase1_A, i_phase2_A   courants imposés aux circuits phase1 et phase2 [A]
% Lois de commande, au couple de 2 N.m :
%   P0 : MTPA du couple moyen, courant (id, iq) constant, le couple ondule ;
%   P1 : MTPA instantané, (id, iq) varie avec la position, couple constant.
%
% Ce que fait le script, dans l'ordre :
%   1. réglages ;
%   2. pour chaque machine et chaque loi, il lit les courants et simule la
%      trajectoire avec FEMM 5 : à chaque position, couple et induction
%      (Bx, By) de chaque élément du fer (fonction femm5Trajectoire) ;
%   3. il calcule les pertes fer avec la formule de la note
%      (../note/main.pdf), pour chaque jeu de coefficients et plusieurs
%      vitesses (fonction pertesFer) ;
%   4. il enregistre resultats/pertes.mat et resultats/pertes.csv.
% Les figures et tableaux de la note sont produits ensuite par resultatsNote.m.
%
% Les deux fonctions à relire pour vérifier le calcul sont dans ../lib :
%   femm5Trajectoire.m   pilotage de FEMM 5 (rotation, courants, lecture de B)
%   pertesFer.m          formule des pertes fer, terme par terme
%
%   See also femm5Trajectoire, pertesFer, coefficientsFer, resultatsNote.

clearvars; clc; close all;
ici = fileparts(mfilename("fullpath"));                 % pertesFer/calculPertes
addpath(fullfile(ici, "..", "lib"));                    % fonctions : pertesFer/lib

%% 1. Réglages
machines = ["sans_aimant", "B123_f25"];                 % modèles ../modeles/<machine>.fem
lois = ["P0", "P1"];                                    % lois de commande
vitesses = [500 1000 1500 2000 2500 3000 3500];         % vitesses mécaniques [tr/min]
jeux = coefficientsFer("liste");                        % jeux de coefficients comparés
p = 2;                                                  % paires de pôles ; le modèle représente un pôle
dossierFemm5 = "/home/rdelpoux/opt/femm-qt";            % installation de FEMM 5 (femm-qt)
materiauFer = "M330-35A";                               % nom du matériau du fer dans les modèles

dossierModeles = fullfile(ici, "..", "modeles");
dossierCourants = fullfile(ici, "courants");
dossierRes = fullfile(ici, "resultats");
if ~isfolder(dossierRes), mkdir(dossierRes); end

%% 2. Simulation FEMM 5 de chaque trajectoire
% femm5Trajectoire résout le modèle d'un pôle à chaque position : elle
% tourne le rotor par l'élément d'entrefer, impose les courants des deux
% phases, lance la résolution et lit le couple et l'induction de tous les
% éléments (mo_getallb). Le maillage ne change pas d'une position à
% l'autre. Un résultat déjà calculé avec les mêmes courants est relu.
femm5Ouvrir(Femm5=fullfile(dossierFemm5, "build", "bin"), Matlab=fullfile(dossierFemm5, "octavefemm"));
courants = struct();
simu = struct();
for m = machines
    for loi = lois
        nom = m + "_" + loi;                            % par exemple "sans_aimant_P1"
        C = readtable(fullfile(dossierCourants, nom + ".csv"));
        courants.(nom) = C;
        simu.(nom) = femm5Trajectoire(fullfile(dossierModeles, m + ".fem"), ...
            C.theta_m_deg, [C.i_phase1_A, C.i_phase2_A], ...
            Name=nom, WorkDir=fullfile(dossierRes, "femm5"), IronName=materiauFer);
        couple = simu.(nom).torque(1:end-1);            % la dernière position répète la première
        fprintf("%-16s couple moyen %.4f N.m, ondulation crête à crête %.4f N.m\n", ...
            nom, mean(couple), max(couple) - min(couple));
    end
end
femm5Fermer();

%% 3. Pertes fer
% pertesFer applique la formule de la note à chaque élément du fer et somme
% sur le maillage ; SectorFactor = 2p ramène le pôle modélisé à la machine
% entière. Le résultat contient, pour chaque vitesse, les pertes du stator
% et du rotor et leurs trois termes (hystérésis, classiques, excédentaires).
pertes = struct();
for m = machines
    for loi = lois
        nom = m + "_" + loi;
        for jeu = jeux.'
            pertes.(nom).(jeu) = pertesFer(simu.(nom), [], vitesses, ...
                Coefficients=jeu, SectorFactor=2 * p, Poles=p);
        end
    end
end

%% 4. Enregistrement
% Tableau à plat : une ligne par machine, loi, jeu de coefficients et vitesse.
lignes = {};
for m = machines
    for loi = lois
        nom = m + "_" + loi;
        for jeu = jeux.'
            L = pertes.(nom).(jeu);
            for v = 1:numel(vitesses)
                lignes{end+1, 1} = table(m, loi, jeu, vitesses(v), ...
                    L.statorParts.h(v), L.statorParts.e(v), L.statorParts.x(v), ...
                    L.rotorParts.h(v), L.rotorParts.e(v), L.rotorParts.x(v), ...
                    L.stator(v), L.rotor(v), L.total(v), ...
                    VariableNames=["machine", "loi", "jeu", "vitesse_rpm", ...
                    "stator_hysteresis_W", "stator_classiques_W", "stator_excedentaires_W", ...
                    "rotor_hysteresis_W", "rotor_classiques_W", "rotor_excedentaires_W", ...
                    "stator_W", "rotor_W", "total_W"]); %#ok<SAGROW>
            end
        end
    end
end
tableau = vertcat(lignes{:});
writetable(tableau, fullfile(dossierRes, "pertes.csv"));
save(fullfile(dossierRes, "pertes.mat"), "courants", "simu", "pertes", "tableau", ...
    "vitesses", "jeux", "lois", "machines", "p");
disp(tableau(tableau.vitesse_rpm == 1500, ["machine", "loi", "jeu", "stator_W", "rotor_W", "total_W"]));
fprintf("Résultats : %s\n", fullfile(dossierRes, "pertes.mat"));
