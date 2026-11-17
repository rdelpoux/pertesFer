function femm5Fermer()
%FEMM5FERMER Ferme la connexion à FEMM 5 ; le processus femm_headless s'arrête avec elle.
%   femm5Fermer() appelle closefemm de la liaison FEMM 5. Le serveur TCP de
%   femm_headless se termine quand son client se déconnecte.
%
%   See also femm5Ouvrir.

try
    closefemm;
catch
    % connexion déjà fermée
end
end
