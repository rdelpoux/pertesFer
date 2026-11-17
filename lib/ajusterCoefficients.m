%% Coefficients de Bertotti de la M330-35A ajustés sur la fiche du fabricant
% Ajuste kh, alpha et kexc de la formule en régime sinusoïdal
%     p = kh f J^alpha + kc (f J)^2 + kexc (f J)^(3/2)      [W/kg]
% sur les pertes de la fiche « Typical data for SURA M330-35A »
% (materiauM330_35A), à 50, 100, 200 et 400 Hz et pour J <= 1,5 T. Le
% coefficient classique kc n'est pas ajusté : il est calculé à partir de la
% conductivité et de l'épaisseur de la tôle, kc = pi^2 sigma d^2 / (6 rho).
% Les fréquences de 1000 et 2500 Hz sont écartées de l'ajustement (effet de
% peau) mais tracées pour comparaison. Le résultat est à reporter dans
% coefficientsFer.m (jeu "m330_35a").
%
%   See also materiauM330_35A, coefficientsFer.

clearvars; clc;
ici = fileparts(mfilename("fullpath"));
mat = materiauM330_35A();

%% Données utilisées pour l'ajustement
[F, J] = meshgrid(mat.lossFreq, mat.J);            % une ligne par J, une colonne par fréquence
P = mat.loss;
garde = ~isnan(P) & F <= 400 & J <= 1.5;
f = F(garde); j = J(garde); p = P(garde);

%% Ajustement (erreur relative, pour que les faibles pertes comptent autant que les fortes)
kc = pi^2 * mat.sigma * mat.thickness^2 / (6 * mat.density);
modele = @(x, f, j) x(1) * f .* j.^x(2) + kc * (f .* j).^2 + x(3) * (f .* j).^1.5;
critere = @(x) sum(((modele(x, f, j) - p) ./ p).^2);
x = fminsearch(critere, [0.02, 2, 5e-4], optimset(TolX=1e-10, TolFun=1e-12, MaxFunEvals=1e5, MaxIter=1e5));
ecart = (modele(x, f, j) - p) ./ p;
fprintf("kh = %.5g W/kg/Hz/T^alpha, alpha = %.4g, kc = %.4g W/kg/(Hz T)^2 (calculé), kexc = %.4g W/kg/(Hz T)^1.5\n", x(1), x(2), kc, x(3));
fprintf("écart relatif sur les %d points ajustés : moyen %.1f %%, max %.1f %%\n", numel(p), 100 * mean(abs(ecart)), 100 * max(abs(ecart)));
for fr = mat.lossFreq
    g = mat.lossFreq == fr; ok = ~isnan(mat.loss(:, g)) & mat.J <= 1.5;
    e = (modele(x, fr, mat.J(ok)) - mat.loss(ok, g)) ./ mat.loss(ok, g);
    fprintf("  %5d Hz : écart moyen %+.1f %%, max %.1f %%\n", fr, 100 * mean(e), 100 * max(abs(e)));
end
