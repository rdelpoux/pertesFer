function mat = materiauM330_35A()
%MATERIAUM330_35A Tôle M330-35A du prototype : courbe B(H) et pertes mesurées (fiche fabricant).
%   mat = materiauM330_35A() renvoie les données de la fiche « Typical data
%   for SURA® M330-35A » (Surahammars Bruks, aujourd'hui Tata Steel, octobre
%   2009 ; copie dans pertesFer/note/TataSteel_M330-35A.pdf).
%
%   mat : structure
%     name        "M330-35A"
%     J           polarisation crête [T], 0,1 à 1,8 T (colonne)
%     H           champ crête à 50 Hz pour chaque J [A/m] (courbe d'aimantation
%                 alternative mesurée sur Epstein, utilisée comme courbe B(H))
%     loss        pertes massiques [W/kg], une ligne par J, une colonne par
%                 fréquence de lossFreq (NaN : non donné)
%     lossFreq    [50 100 200 400 1000 2500] Hz
%     Bfem, Hfem  courbe B(H) écrite dans le .fem : B = J + mu0 H, point (0, 0)
%                 ajouté, prolongée au-delà de 1,8 T (voir ci-dessous)
%     sigma       conductivité [S/m] (résistivité 42 µOhm.cm)
%     thickness   épaisseur [m]
%     density     masse volumique [kg/m^3] (EN 10106, nuance 0,35 mm)
%     muR15       perméabilité relative à 1,5 T (fiche)
%     source      référence
%
%   Prolongement au-delà de 1,8 T : la fiche s'arrête à 1,8 T (9677 A/m).
%   Au-delà, la polarisation suit une loi d'approche à la saturation
%   J = Js - b/H, ajustée sur les deux derniers points de la fiche (1,7 T à
%   5409 A/m et 1,8 T à 9677 A/m), ce qui donne Js = 1,93 T. Ce prolongement
%   n'est pas une donnée du fabricant ; il ne concerne que les zones très
%   saturées (ponts du rotor).
%
%   See also femChangerFer, coefficientsFer.

J = (0.1:0.1:1.8).';
H = [33.4 43.6 50.8 57.2 63.6 70.4 78.1 87.2 98.7 114 136 172 242 428 1027 2576 5409 9677].';
nan = NaN;
loss = [ ...                % 50 Hz  100 Hz  200 Hz  400 Hz  1000 Hz  2500 Hz
    0.02  0.05  0.12   0.33   1.43   5.95
    0.08  0.20  0.48   1.27   5.40  21.7
    0.17  0.41  1.02   2.69  11.0   45.1
    0.28  0.67  1.68   4.49  18.3   76.2
    0.40  0.97  2.47   6.66  27.2  116
    0.53  1.30  3.37   9.19  38.1  167
    0.68  1.68  4.39  12.11  51.1  230
    0.84  2.10  5.54  15.44  66.4  308
    1.02  2.56  6.82  19.22  84.5  403
    1.22  3.07  8.25  23.54 106    517
    1.44  3.64  9.86  28.48 130    654
    1.69  4.29 11.6   34.12 159    803
    2.00  5.07 13.7   40.62 193    nan
    2.40  6.06 16.3   48.24 233    nan
    2.94  7.40 19.6   57.86 279    nan
    3.67  8.86 23.2   70.24 335    nan
    4.32  nan  nan    nan   nan    nan
    4.73  nan  nan    nan   nan    nan];

mu0 = 4e-7 * pi;
% Loi d'approche J = Js - b/H sur les deux derniers points de la fiche
b = (J(end) - J(end-1)) / (1 / H(end-1) - 1 / H(end));
Js = J(end) + b / H(end);
Hext = [15e3 25e3 50e3 100e3 200e3 300e3].';
Jext = Js - b ./ Hext;
Hfem = [0; H; Hext];
Bfem = [0; J; Jext] + mu0 * Hfem;

mat = struct(name="M330-35A", J=J, H=H, loss=loss, lossFreq=[50 100 200 400 1000 2500], ...
    Bfem=Bfem, Hfem=Hfem, Js=Js, sigma=1 / 42e-8, thickness=0.35e-3, density=7650, muR15=880, ...
    source="Typical data for SURA M330-35A, Surahammars Bruks / Tata Steel, oct. 2009");
end
