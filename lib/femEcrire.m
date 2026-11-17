function femEcrire(fem, femFile)
%FEMECRIRE Écrit une structure femLire dans un fichier .fem.
%   femEcrire(fem, femFile) écrit l'en-tête conservé puis les sections
%   numériques (points, segments, arcs, trous, labels) au format lu par FEMM
%   et cfemm. Les compteurs sont recalculés depuis les tableaux.
%
%   See also femLire.

arguments
    fem (1,1) struct
    femFile (1,1) string
end

fid = fopen(femFile, "w", "n", "UTF-8");
assert(fid > 0, "femEcrire:ouverture", "Impossible d'écrire %s", femFile);
c = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", fem.header);
ecrire(fid, "[NumPoints]", fem.points, "%.17g\t%.17g\t%d\t%d\n");
ecrire(fid, "[NumSegments]", fem.segments, "%d\t%d\t%.17g\t%d\t%d\t%d\n");
ecrire(fid, "[NumArcSegments]", fem.arcs, "%d\t%d\t%.17g\t%.17g\t%d\t%d\t%d\t%.17g\n");
ecrire(fid, "[NumHoles]", fem.holes, "%.17g\t%.17g\t%d\n");
ecrire(fid, "[NumBlockLabels]", fem.labels, "%.17g\t%.17g\t%d\t%.17g\t%d\t%.17g\t%d\t%d\t%d\n");
end

function ecrire(fid, nom, M, fmt)
fprintf(fid, "%s = %d\n", nom, size(M, 1));
if ~isempty(M)
    fprintf(fid, fmt, M.');
end
end
