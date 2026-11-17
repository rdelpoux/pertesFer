%% Figures et tableaux de la note à partir des pertes calculées par calculPertes.m
% Lit resultats/pertes.mat et écrit :
%   ../note/resultats.tex          tableaux LaTeX (inclus par la note)
%   ../note/figures/pertes_vitesse.pdf   pertes fer en fonction de la vitesse
%   ../note/figures/densite_pertes.pdf   pertes par élément, loi P1
%
%   See also calculPertes, pertesFer.

clearvars; clc; close all;
ici = fileparts(mfilename("fullpath"));                 % pertesFer/calculPertes
addpath(fullfile(ici, "..", "lib"));                    % fonctions : pertesFer/lib

%% Réglages
vitRef = 1500;                         % vitesse des tableaux [tr/min]
jeuCarte = coefficientsFer().name;     % jeu de coefficients de la carte de densité et du tableau d'hystérésis
tauConsigne = 2;                       % couple des trajectoires [N.m]
libelleMachine = struct(sans_aimant="sans aimant", B123_f25="avec aimants (B123\_f25)");
dossierNote = fullfile(ici, "..", "note");

%% Données
R = load(fullfile(ici, "resultats", "pertes.mat"));
p = R.p;
nPositions = height(R.courants.(R.machines(1) + "_" + R.lois(1)));
iv = find(R.vitesses == vitRef, 1);
figDir = fullfile(dossierNote, "figures"); if ~isfolder(figDir), mkdir(figDir); end
% Une ligne de tableau par couple (machine, loi)
[mm, ll] = ndgrid(R.machines, R.lois); mm = mm.'; ll = ll.';
cas = table(mm(:), ll(:), VariableNames=["machine", "loi"]);
cas.nom = cas.machine + "_" + cas.loi;
cas.libelle = arrayfun(@(m, l) libelleMachine.(m) + " & " + l, cas.machine, cas.loi);

%% Figure : pertes fer en fonction de la vitesse, un panneau par jeu de coefficients
coul = struct(sans_aimant=[0, 0, 0], B123_f25=[0.85, 0.15, 0.15]);
style = struct(P0="--", P1="-");
f = figure(Visible="off", Theme="light", Color="w", Position=[100, 100, 1000, 330]);
tl = tiledlayout(f, 1, numel(R.jeux), TileSpacing="compact", Padding="compact");
for jeu = R.jeux.'
    ax = nexttile(tl); hold(ax, "on"); grid(ax, "on"); box(ax, "on");
    for m = R.machines
        for loi = R.lois
            L = R.pertes.(m + "_" + loi).(jeu);
            plot(ax, R.vitesses, L.total, style.(loi), Color=coul.(m), Marker="o", MarkerSize=4, ...
                LineWidth=1.1, DisplayName=loi + ", " + libelleMachine.(m));
        end
    end
    xlabel(ax, "vitesse (tr/min)"); ylabel(ax, "pertes fer (W)"); title(ax, "jeu « " + jeu + " »", Interpreter="none");
    if jeu == R.jeux(1), legend(ax, Location="northwest", FontSize=7); end
end
exportgraphics(f, fullfile(figDir, "pertes_vitesse.pdf"), ContentType="vector");
exportgraphics(f, fullfile(figDir, "pertes_vitesse.eps"), ContentType="vector");   % EPS pour la compilation latex + dvips
close(f);

%% Figure : pertes par élément pour la loi P1 à la vitesse de référence
f = figure(Visible="off", Theme="light", Color="w", Position=[100, 100, 1000, 470]);
tl = tiledlayout(f, 1, numel(R.machines), TileSpacing="compact", Padding="compact");
for m = R.machines
    L = pertesFer(R.simu.(m + "_P1"), [], vitRef, Coefficients=jeuCarte, SectorFactor=2 * p, Poles=p);
    dens = zeros(numel(L.x), 1); dens(L.isStator) = L.densityStator; dens(~L.isStator) = L.densityRotor;
    ax = nexttile(tl); hold(ax, "on"); axis(ax, "equal"); axis(ax, "off");
    tracerRotor(femLire(fullfile(ici, "..", "modeles", m + ".fem")), [], Axes=ax, RotorOnly=false);
    scatter(ax, L.x, L.y, 2, dens, "filled");
    colormap(ax, "turbo"); clim(ax, [0, prctile(dens, 99)]); cb = colorbar(ax); cb.Label.String = "W/kg";
    title(ax, sprintf("%s, P1 : %.1f W (stator %.1f, rotor %.1f)", libelleMachine.(m), L.total, L.stator, L.rotor));
end
exportgraphics(f, fullfile(figDir, "densite_pertes.pdf"), ContentType="image", Resolution=200);
exportgraphics(f, fullfile(figDir, "densite_pertes.eps"), ContentType="image", Resolution=200);   % EPS pour la compilation latex + dvips
close(f);

%% Tableaux LaTeX
fid = fopen(fullfile(dossierNote, "resultats.tex"), "w", "n", "UTF-8");
cl = onCleanup(@() fclose(fid));
w = @(varargin) fprintf(fid, varargin{:});
w("%% Généré par pertesFer/calculPertes/resultatsNote.m le %s. Ne pas éditer.\n", string(datetime("now", Format="dd/MM/yyyy HH:mm")));
w("\\newcommand{\\vitRef}{%d}\n\\newcommand{\\tauCons}{%g}\n\\newcommand{\\jeuCarte}{%s}\n\\newcommand{\\nPositions}{%d}\n", ...
    vitRef, tauConsigne, tex(jeuCarte), nPositions);

% Tableau : trajectoires simulées
w("\\begin{table}[H]\n\\centering\n\\caption{Trajectoires simulées avec FEMM~5 (%d positions sur un pas polaire). $I_s$ : amplitude du courant.}\n\\label{tab-simulations}\n", nPositions);
w("\\resizebox{\\textwidth}{!}{%%\n\\begin{tabular}{llS[table-format=2.2]S[table-format=2.2]S[table-format=1.3]S[table-format=1.3]S[table-format=5.0]S[table-format=5.0]}\n\\toprule\n");
w("Machine & Loi & {$I_s$ moyen (A)} & {$I_s$ max (A)} & {Couple moyen (N\\,m)} & {Ondulation c-c (N\\,m)} & {Éléments stator} & {Éléments rotor} \\\\\n\\midrule\n");
for k = 1:height(cas)
    r = R.simu.(cas.nom(k)); tq = r.torque(1:end-1);
    C = R.courants.(cas.nom(k));
    Is = hypot(C.id_A(1:end-1), C.iq_A(1:end-1));
    w("%s & %.2f & %.2f & %.3f & %.3f & %d & %d \\\\\n", cas.libelle(k), mean(Is), max(Is), mean(tq), max(tq) - min(tq), ...
        nnz(r.elements.region == "stator"), nnz(r.elements.region == "rotor"));
end
w("\\bottomrule\n\\end{tabular}}\n\\end{table}\n\n");

% Tableau : décomposition des pertes à la vitesse de référence, par jeu de coefficients
w("\\begin{table}[H]\n\\centering\n\\caption{Pertes fer à \\SI{%d}{tr/min} et \\SI{%g}{\\newton\\metre}, machine entière (W), pour chaque jeu de coefficients.}\n\\label{tab-pertes}\n", vitRef, tauConsigne);
w("\\resizebox{\\textwidth}{!}{%%\n\\begin{tabular}{llS[table-format=2.2]S[table-format=2.2]S[table-format=1.2]S[table-format=2.2]S[table-format=2.2]S[table-format=2.2]}\n\\toprule\n");
w("Machine & Loi & {Hystérésis} & {Classiques} & {Excédentaires} & {Stator} & {Rotor} & {Total} \\\\\n");
for jeu = R.jeux.'
    w("\\midrule\n\\multicolumn{8}{l}{\\emph{Jeu « %s »}} \\\\\n", tex(jeu));
    for k = 1:height(cas)
        L = R.pertes.(cas.nom(k)).(jeu);
        w("%s & %.2f & %.2f & %.2f & %.2f & %.2f & %.2f \\\\\n", cas.libelle(k), L.hysteresis(iv), L.eddy(iv), L.excess(iv), L.stator(iv), L.rotor(iv), L.total(iv));
    end
end
w("\\bottomrule\n\\end{tabular}}\n\\end{table}\n\n");

% Tableau : hystérésis, comptage des cycles (formule retenue) et somme sur les harmoniques
w("\\begin{table}[H]\n\\centering\n\\caption{Pertes par hystérésis à \\SI{%d}{tr/min} (W), jeu « %s » : comptage des cycles (formule retenue) et somme sur les harmoniques (ancienne écriture).}\n\\label{tab-hysteresis}\n", vitRef, tex(jeuCarte));
w("\\resizebox{\\textwidth}{!}{%%\n\\begin{tabular}{llS[table-format=1.2]S[table-format=1.2]S[table-format=1.2]S[table-format=1.2]}\n\\toprule\n");
w("Machine & Loi & {Stator, cycles} & {Stator, harmoniques} & {Rotor, cycles} & {Rotor, harmoniques} \\\\\n\\midrule\n");
for k = 1:height(cas)
    Lc = R.pertes.(cas.nom(k)).(jeuCarte);
    Lh = pertesFer(R.simu.(cas.nom(k)), [], vitRef, Coefficients=jeuCarte, SectorFactor=2 * p, Poles=p, Hysteresis="harmoniques");
    w("%s & %.2f & %.2f & %.2f & %.2f \\\\\n", cas.libelle(k), Lc.statorParts.h(iv), Lh.statorParts.h, Lc.rotorParts.h(iv), Lh.rotorParts.h);
end
w("\\bottomrule\n\\end{tabular}}\n\\end{table}\n");
clear cl
fprintf("Note : %s\n", fullfile(dossierNote, "resultats.tex"));

function t = tex(texte)
%TEX Échappe le tiret bas pour LaTeX (noms des jeux de coefficients).
t = strrep(texte, "_", "\_");
end
