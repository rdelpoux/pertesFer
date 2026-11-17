function fem = femLire(femFile)
%FEMLIRE Lit un fichier .fem (FEMM 4.2 / xfemm, magnétostatique) en structure.
%   fem = femLire(femFile) renvoie :
%     fem.header     lignes de texte précédant [NumPoints] (problème, frontières,
%                    matériaux, circuits), conservées telles quelles
%     fem.materials  noms des matériaux dans l'ordre du fichier (index 1-based
%                    des labels de bloc)
%     fem.points     n x 4  : x, y, propriété de point, groupe
%     fem.segments   n x 6  : n0, n1 (0-based), taille de maille, frontière,
%                    caché, groupe
%     fem.arcs       n x 8  : n0, n1, angle [deg], segment max [deg], frontière,
%                    caché, groupe, taille de maille retenue
%     fem.holes      n x 3  : x, y, groupe
%     fem.labels     n x 9  : x, y, matériau (1-based), taille de maille, circuit,
%                    direction d'aimantation [deg], groupe, tours, externe
%
%   Le format est celui écrit par FEMM et relu par cfemm (FemmReader.cpp).
%
%   See also femEcrire, femBarrieres, femAjouterAimants.

arguments
    femFile (1,1) string {mustBeFile}
end

lines = splitlines(string(fileread(femFile)));
iP = find(startsWith(lines, "[NumPoints]"), 1);
assert(~isempty(iP), "femLire:format", "Section [NumPoints] absente de %s", femFile);
fem = struct();
fem.file = femFile;
fem.header = lines(1:iP-1);
fem.materials = regexp(strjoin(fem.header, newline), '<BlockName>\s*=\s*"([^"]*)"', "tokens");
fem.materials = string(cellfun(@(c) c{1}, fem.materials, UniformOutput=false));

[fem.points, next] = bloc(lines, iP, 4);
[fem.segments, next] = bloc(lines, next, 6);
[fem.arcs, next] = bloc(lines, next, 8);
[fem.holes, next] = bloc(lines, next, 3);
[fem.labels, ~] = bloc(lines, next, 9);
end

function [M, next] = bloc(lines, iStart, nCols)
%BLOC Lit la section numérique qui commence à la ligne iStart ("[Nom] = n").
n = sscanf(lines(iStart), "[%*[^]]] = %d");
if n == 0
    M = zeros(0, nCols);
else
    txt = strtrim(lines(iStart+1:iStart+n));
    M = str2double(split(txt, char(9)));
    if isvector(M) && n == 1, M = M(:).'; end
    assert(size(M, 2) >= nCols, "femLire:colonnes", "%s : %d colonnes lues, %d attendues.", lines(iStart), size(M, 2), nCols);
    M = M(:, 1:nCols);
end
next = iStart + n + 1;
end
