function h = empreinteFichier(fichier)
%EMPREINTEFICHIER Empreinte MD5 du contenu d'un fichier (texte hexadécimal).
%   h = empreinteFichier(fichier) sert à vérifier qu'un résultat repris a été
%   calculé avec le même modèle .fem : deux fichiers de contenu différent
%   (un autre matériau par exemple) ont des empreintes différentes.
%
%   See also calculerCarto, femm5Trajectoire.

arguments
    fichier (1,1) string {mustBeFile}
end

fid = fopen(fichier, "r"); c = onCleanup(@() fclose(fid));
octets = fread(fid, Inf, "*uint8");
md = java.security.MessageDigest.getInstance("MD5");
md.update(octets);
h = string(lower(reshape(dec2hex(typecast(md.digest(), "uint8"), 2).', 1, [])));
end
