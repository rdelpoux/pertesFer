function port = femm5Ouvrir(options)
%FEMM5OUVRIR Lance FEMM 5 sans interface (femm_headless) et s'y connecte depuis MATLAB.
%   port = femm5Ouvrir() démarre femm_headless sur le port TCP par défaut,
%   met la liaison MATLAB de FEMM 5 (octavefemm) sur le path et ouvre la
%   connexion : les fonctions mi_* et mo_* s'adressent ensuite à cette
%   instance. Le processus est lancé hors de l'environnement de MATLAB
%   (LD_LIBRARY_PATH, LD_PRELOAD), sans quoi il ne démarre pas : c'est pour
%   cette raison que l'on ne passe pas par openfemm(1) directement.
%
%   Options :
%     Port      48015               port TCP
%     Femm5     dossier P.femm5      exécutables de FEMM 5
%     Matlab    dossier P.femm5Matlab  liaison MATLAB (octavefemm)
%     LogFile   ""                   journal de femm_headless ("" : tempdir)
%
%   Attention : la liaison FEMM 5 définit openfemm, callfemm, mi_*, mo_*,
%   comme la liaison FEMM 4.2 ; ne pas avoir les deux sur le path.
%
%   See also femm5Fermer, femm5Trajectoire, projetInit.

arguments
    options.Port (1,1) double {mustBeInteger, mustBePositive} = 48015
    options.Femm5 (1,1) string = "/home/rdelpoux/opt/femm-qt/build/bin"
    options.Matlab (1,1) string = "/home/rdelpoux/opt/femm-qt/octavefemm"
    options.LogFile (1,1) string = ""
end

exe = fullfile(options.Femm5, "femm_headless");
assert(isfile(exe), "femm5Ouvrir:exe", "femm_headless introuvable : %s", exe);
% La liaison FEMM 5 passe en tête du path : elle a les mêmes noms de
% fonctions que le pont FEMM 4.2 (femmLinux de SyntheseSynRel), qui peut
% déjà être sur le path dans la même session.
addpath(options.Matlab);
assert(startsWith(string(which("openfemm")), options.Matlab), "femm5Ouvrir:path", ...
    "openfemm ne vient pas de la liaison FEMM 5 : %s", which("openfemm"));
setenv("FEMM_DIR", options.Femm5);
logFile = options.LogFile;
if strlength(logFile) == 0, logFile = fullfile(tempdir, sprintf("femm5_%d.log", options.Port)); end
[st, out] = system(sprintf('env -u LD_LIBRARY_PATH -u LD_PRELOAD "%s" --port %d > "%s" 2>&1 &', ...
    exe, options.Port, logFile));
assert(st == 0, "femm5Ouvrir:lancement", "Lancement de femm_headless impossible : %s", out);
% openfemm se connecte à l'instance déjà lancée (il ne relance rien si la
% connexion réussit) ; on lui laisse le temps de démarrer.
for k = 1:40
    pause(0.25);
    try
        openfemm(1, options.Port);
        port = options.Port;
        return
    catch err
        if k == 40
            error("femm5Ouvrir:connexion", "Connexion à FEMM 5 impossible (port %d) : %s\nJournal : %s", ...
                options.Port, err.message, fileread(logFile));
        end
    end
end
end
