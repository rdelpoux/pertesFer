%% Trajectoires de courant à couple constant, sans et avec aimants
% Pour chaque machine (modèles de pertesFer/modeles) :
%   1. carto dq xfemm (calculerCarto, reprise des points déjà calculés) ;
%   2. lieu MTPA et trajectoires P0 (MTPA du couple moyen, courant constant)
%      et P1 (MTPA instantané, couple constant à chaque position) au couple
%      tauStar (trajectoiresCouple, solveurs de l'article TIA).
% Sorties : resultats/trajectoires.mat (structure traj, un champ par machine)
% et figures dans ../note/figures.
%
%   See also calculerCarto, trajectoiresCouple.

clearvars; clc; close all;
% Ce script utilise le projet With_Without_Magnet, placé à côté de pertesFer.
projet = fullfile(fileparts(mfilename("fullpath")), "..", "..", "With_Without_Magnet");
addpath(fullfile(projet, "lib"));
P = projetInit();

%% Réglages
machines = ["sans_aimant", "B123_f25"];      % modèles <nom>.fem de pertesFer/modeles
libelles = ["sans aimant", "avec aimants (B123\_f25)"];
tauStar = 2;                                   % [N.m] couple de consigne
thetaCount = 90;                               % positions sur un pas polaire, bornes incluses
grilleDQ = 0:1:20;                             % [A] grille id et iq de la carto

%% Cartos et trajectoires
ici = P.pertesFer.trajectoires;
dossierRes = fullfile(ici, "resultats"); if ~isfolder(dossierRes), mkdir(dossierRes); end
figDir = fullfile(P.pertesFer.note, "figures"); if ~isfolder(figDir), mkdir(figDir); end
traj = struct();
for m = 1:numel(machines)
    femFile = fullfile(P.pertesFer.modeles, machines(m) + ".fem");
    carto = calculerCarto(femFile, fullfile(ici, "cartos", machines(m)), IdVec=grilleDQ, IqVec=grilleDQ, ...
        ThetaCount=thetaCount, Motor=P.motor);
    T = trajectoiresCouple(carto, tauStar, ThetaCount=thetaCount, Motor=P.motor);
    T.machine = machines(m); T.libelle = libelles(m); T.femFile = femFile;
    traj.(machines(m)) = T;
    fprintf("%-12s P0 : id = %.3f A, iq = %.3f A (Is = %.3f A) ; P1 : Is de %.3f à %.3f A\n", machines(m), ...
        T.P0.id(1), T.P0.iq(1), hypot(T.P0.id(1), T.P0.iq(1)), min(hypot(T.P1.id, T.P1.iq)), max(hypot(T.P1.id, T.P1.iq)));
end
save(fullfile(dossierRes, "trajectoires.mat"), "traj", "tauStar", "thetaCount", "machines");

%% Courants pour le calcul des pertes
% Un fichier CSV par machine et par loi dans ../calculPertes/courants : le
% calcul des pertes ne lit que ces fichiers et les modèles .fem, il ne
% dépend ni des cartos ni des solveurs de trajectoires.
dossierCourants = fullfile(P.pertesFer.calculPertes, "courants");
if ~isfolder(dossierCourants), mkdir(dossierCourants); end
for m = machines
    T = traj.(m);
    for loi = ["P0", "P1"]
        C = table(T.thetaDeg, T.(loi).id, T.(loi).iq, T.(loi).iPhase(:, 1), T.(loi).iPhase(:, 2), ...
            VariableNames=["theta_m_deg", "id_A", "iq_A", "i_phase1_A", "i_phase2_A"]);
        writetable(C, fullfile(dossierCourants, m + "_" + loi + ".csv"));
    end
end
fprintf("Courants écrits dans %s\n", dossierCourants);

%% Figures
coul = {[0, 0, 0], [0.85, 0.15, 0.15]};
f = figure(Visible="off", Theme="light", Color="w", Position=[100, 100, 900, 340]);
tl = tiledlayout(f, 1, 2, TileSpacing="compact", Padding="compact");
ax = nexttile(tl); hold(ax, "on"); grid(ax, "on"); box(ax, "on");
for m = 1:numel(machines)
    T = traj.(machines(m));
    plot(ax, T.mtpa.Is, T.mtpa.betaDeg, "-", Color=coul{m}, LineWidth=1.2, DisplayName=T.libelle);
    plot(ax, hypot(T.P0.id(1), T.P0.iq(1)), atan2d(T.P0.iq(1), T.P0.id(1)), "o", Color=coul{m}, MarkerFaceColor=coul{m}, HandleVisibility="off");
end
xlabel(ax, "I_s (A)"); ylabel(ax, "\beta MTPA (deg)"); legend(ax, Location="best");
title(ax, sprintf("Lieu MTPA ; points : P0 à %g N.m", tauStar));
ax = nexttile(tl); hold(ax, "on"); grid(ax, "on"); box(ax, "on");
for m = 1:numel(machines)
    T = traj.(machines(m));
    plot(ax, T.thetaDeg, T.P1.id, "-", Color=coul{m}, LineWidth=1.2, DisplayName="i_d, " + T.libelle);
    plot(ax, T.thetaDeg, T.P1.iq, "--", Color=coul{m}, LineWidth=1.2, DisplayName="i_q, " + T.libelle);
end
xlabel(ax, "\theta_m (deg)"); ylabel(ax, "courant (A)"); xlim(ax, [0, 90]);
legend(ax, Location="eastoutside", FontSize=8); title(ax, sprintf("Trajectoire P1 à %g N.m", tauStar));
exportgraphics(f, fullfile(figDir, "trajectoires.pdf"), ContentType="vector");
exportgraphics(f, fullfile(figDir, "trajectoires.eps"), ContentType="vector");   % EPS pour la compilation latex + dvips
close(f);
fprintf("Trajectoires enregistrées : %s\n", fullfile(dossierRes, "trajectoires.mat"));
