function ax = tracerRotor(fem, info, options)
%TRACERROTOR Dessine la géométrie d'un .fem (secteur d'un pôle) avec ses aimants.
%   ax = tracerRotor(fem, info) trace les segments et arcs de la structure
%   femLire et colorie les régions d'aimant décrites par info (sortie de
%   femAjouterAimants). Le secteur modélisé est répliqué sur les 2p pôles si
%   FullMachine est vrai (aimants des pôles alternés dans une autre couleur).
%
%   Options :
%     Axes         []       axes cible (nouvelle figure sinon)
%     FullMachine  false    répliquer le secteur par rotation sur toute la machine
%     Poles        2        nombre de paires de pôles (secteur = pi / p)
%     RotorOnly    true     ne tracer que le rotor (rayon < RotorRadius)
%     RotorRadius  0.0395   rayon extérieur du rotor [m]
%     Title        ""       titre
%
%   See also femLire, femAjouterAimants.

arguments
    fem (1,1) struct
    info struct = struct("layer", {}, "side", {}, "xy", {}, "area", {}, "phiCutDeg", {}, "xyAir", {})
    options.Axes = []
    options.FullMachine (1,1) logical = false
    options.Poles (1,1) double = 2
    options.RotorOnly (1,1) logical = true
    options.RotorRadius (1,1) double = 0.0395
    options.Title (1,1) string = ""
end

if isempty(options.Axes)
    fig = figure(Theme="light", Color="w"); ax = axes(fig);
else
    ax = options.Axes;
end
hold(ax, "on"); axis(ax, "equal"); axis(ax, "off");
pts = fem.points(:, 1:2);
seg = fem.segments(:, 1:2) + 1;
r = hypot(pts(:, 1), pts(:, 2));
if options.RotorOnly
    keep = all(r(seg) <= options.RotorRadius * (1 + 1e-6), 2);
    seg = seg(keep, :);
end
X = [pts(seg(:, 1), 1), pts(seg(:, 2), 1), nan(size(seg, 1), 1)].';
Y = [pts(seg(:, 1), 2), pts(seg(:, 2), 2), nan(size(seg, 1), 1)].';
% Arcs : discrétisés
arcX = []; arcY = [];
for k = 1:size(fem.arcs, 1)
    a = fem.arcs(k, :);
    p0 = pts(a(1) + 1, :); p1 = pts(a(2) + 1, :);
    if options.RotorOnly && (hypot(p0(1), p0(2)) > options.RotorRadius * (1 + 1e-6)), continue; end
    [cx, cy, R, t0, t1] = arcCentre(p0, p1, a(3));
    t = linspace(t0, t1, max(8, ceil(a(3) / 2)));
    arcX = [arcX, cx + R * cos(t), NaN]; arcY = [arcY, cy + R * sin(t), NaN]; %#ok<AGROW>
end
if options.FullMachine
    nSect = 2 * options.Poles; sectDeg = 360 / nSect;
else
    nSect = 1; sectDeg = 0;
end
colMag = [0.85, 0.15, 0.15; 0.15, 0.35, 0.85];
for s = 0:nSect-1
    R = [cosd(s * sectDeg), -sind(s * sectDeg); sind(s * sectDeg), cosd(s * sectDeg)];
    for q = 1:numel(info)
        xy = info(q).xy * R.';
        fill(ax, xy(:, 1), xy(:, 2), colMag(mod(s, 2) + 1, :), EdgeColor="none", FaceAlpha=0.9);
    end
    XY = R * [X(:).'; Y(:).']; plot(ax, XY(1, :), XY(2, :), "-", Color=[0.25, 0.25, 0.25], LineWidth=0.5);
    if ~isempty(arcX)
        XY = R * [arcX; arcY]; plot(ax, XY(1, :), XY(2, :), "-", Color=[0.25, 0.25, 0.25], LineWidth=0.5);
    end
end
if strlength(options.Title) > 0, title(ax, options.Title, Interpreter="none"); end
end

function [cx, cy, R, t0, t1] = arcCentre(p0, p1, angleDeg)
%ARCCENTRE Centre, rayon et angles d'un arc FEMM (de p0 à p1, sens trigo, angle donné).
c = (p0 + p1) / 2; d = p1 - p0; L = norm(d);
R = L / (2 * sind(angleDeg / 2));
h = sqrt(max(R^2 - (L / 2)^2, 0));
n = [-d(2), d(1)] / L;          % normale à gauche (sens trigo)
cen = c + h * n;
cx = cen(1); cy = cen(2);
t0 = atan2(p0(2) - cy, p0(1) - cx);
t1 = t0 + deg2rad(angleDeg);
end
