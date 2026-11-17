function femChangerFer(femIn, femOut, mat, options)
%FEMCHANGERFER Remplace le matériau du fer d'un .fem par une tôle donnée (courbe B(H)).
%   femChangerFer(femIn, femOut, mat) recopie femIn dans femOut en
%   remplaçant le bloc matériau nommé OldName (par défaut "M-19 Steel") par
%   le matériau mat (materiauM330_35A) : nom, courbe B(H) non linéaire,
%   conductivité, épaisseur de tôle. Le matériau garde sa place dans la
%   liste : les labels de bloc du stator et du rotor qui l'utilisaient
%   utilisent le nouveau, sans autre modification de la géométrie.
%
%   Options :
%     OldName   "M-19 Steel"   matériau à remplacer
%     LamFill   0.98           coefficient de foisonnement (celui du modèle
%                              d'origine ; la fiche du fabricant ne le donne pas)
%
%   See also materiauM330_35A, femLire, femEcrire.

arguments
    femIn (1,1) string {mustBeFile}
    femOut (1,1) string
    mat (1,1) struct
    options.OldName (1,1) string = "M-19 Steel"
    options.LamFill (1,1) double = 0.98
end

fem = femLire(femIn);
h = fem.header;
iNom = find(contains(h, "<BlockName> = """ + options.OldName + """"), 1);
assert(~isempty(iNom), "femChangerFer:materiau", "Matériau %s absent de %s.", options.OldName, femIn);
iDebut = find(contains(h(1:iNom), "<BeginBlock>"), 1, "last");
iFin = iNom - 1 + find(contains(h(iNom:end), "<EndBlock>"), 1);

% Nouveau bloc, au format des matériaux de FEMM (points B(H) : B [T], H [A/m])
bloc = [
    "  <BeginBlock>"
    "    <BlockName> = """ + mat.name + """"
    "    <Mu_x> = " + mat.muR15
    "    <Mu_y> = " + mat.muR15
    "    <H_c> = 0"
    "    <H_cAngle> = 0"
    "    <J_re> = 0"
    "    <J_im> = 0"
    "    <Sigma> = " + sprintf("%.6g", mat.sigma / 1e6)       % MS/m
    "    <d_lam> = " + sprintf("%.6g", mat.thickness * 1e3)   % mm
    "    <Phi_h> = 0"
    "    <Phi_hx> = 0"
    "    <Phi_hy> = 0"
    "    <LamType> = 0"
    "    <LamFill> = " + sprintf("%.6g", options.LamFill)
    "    <NStrands> = 0"
    "    <WireD> = 0"
    "    <BHPoints> = " + numel(mat.Bfem)
    compose("      %.10g\t%.10g", mat.Bfem, mat.Hfem)
    "  <EndBlock>"];
fem.header = [h(1:iDebut-1); bloc; h(iFin+1:end)];
femEcrire(fem, femOut);
end
