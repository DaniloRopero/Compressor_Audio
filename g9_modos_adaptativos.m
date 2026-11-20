% =========================================================
% G9 -- FIGURAS DOS MODOS ADAPTATIVOS (CAPITULO 9)
%
% Le os arquivos de telemetria gravados pelo CompressorOffline
% e produz as cinco figuras do Capitulo 9:
%
%   fig_modo1_limiar.png        nivel medio, limiar e desvio padrao
%   fig_modo2_crista.png        fator de crista e razao
%   fig_modo3_ataque.png        tau_A contra inclinacao, com a lei
%   fig_modo4_makeup.png        nivel de entrada e compensacao
%   fig_modos_simultaneos.png   os quatro parametros em conjunto
%
% Imprime tambem, no console, as tabelas numericas do capitulo.
%
% COMO RODAR
%   Rode nesta pasta, depois de executar os cinco comandos do
%   CompressorOffline. Os arquivos esperados sao:
%
%     saida_modo1_adapt.csv   saida_modo4_adapt.csv
%     saida_modo2_adapt.csv   saida_todos_adapt.csv
%     saida_modo3_adapt.csv
%
% Colunas do CSV (nesta ordem):
%   1 n   2 t_s   3 T_db   4 R   5 tauA_ms   6 M_db
%   7 media_db   8 desvio_db   9 crista_db   10 derivada_db_ms
%   11 aquecido
%
% Depende de virgula.m e numvir.m, na mesma pasta.
%
% TCC -- Danilo Francisco Ropero Sivirino
% =========================================================

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

COL = struct('t',2,'T',3,'R',4,'tauA',5,'M',6, ...
             'media',7,'desvio',8,'crista',9,'deriv',10,'quente',11);

% Constantes do AdaptiveController, para as curvas teoricas.
S_REF   = 10.0;   % dB/ms
ATQ_MIN =  0.5;   % ms
ATQ_MAX = 50.0;   % ms
CF_LO   =  3.0;   % dB
CF_HI   = 15.0;   % dB
R_LO    =  2.0;
R_HI    =  8.0;

T_AQUEC = 1.0;    % s -- fim do aquecimento (Config::warmupMs)

CINZA  = [0.15 0.15 0.15];
AZUL   = [0.00 0.35 0.70];
VERM   = [0.75 0.15 0.15];
PONTIL = [0.45 0.45 0.45];

fprintf('\n=== FIGURAS E TABELAS DOS MODOS ADAPTATIVOS ===\n\n');

% =========================================================
% MODO 1 -- LIMIAR ADAPTATIVO
% =========================================================
d1 = lerCsv('saida_modo1_adapt.csv');

NIVEIS_M1 = [-42 -30 -18 -12 -24 -36];
DUR_M1    = 4.0;

t   = d1(:,COL.t);
T   = d1(:,COL.T);
mu  = d1(:,COL.media);
sig = d1(:,COL.desvio);

fprintf('  Modo 1 -- limiar adaptativo\n');
fprintf('    %-10s %-10s %-10s %-9s %-10s %-8s\n', ...
        'patamar','RMS teor','media','desvio','T medido','erro');
tabela1 = zeros(numel(NIVEIS_M1),5);
for k = 1:numel(NIVEIS_M1)
    jan  = (t >= k*DUR_M1 - 0.5) & (t < k*DUR_M1);
    rms  = NIVEIS_M1(k) - 20*log10(sqrt(2));
    tabela1(k,:) = [NIVEIS_M1(k), rms, mean(mu(jan)), ...
                    mean(sig(jan)), mean(T(jan))];
    fprintf('    %7.1f    %8.2f   %8.3f   %7.3f  %8.3f  %+7.3f\n', ...
            tabela1(k,1), tabela1(k,2), tabela1(k,3), ...
            tabela1(k,4), tabela1(k,5), tabela1(k,5)-tabela1(k,2));
end

% degrau a degrau: tempo de acomodacao do limiar
fprintf('    acomodacao do limiar apos cada degrau (criterio 0,5 dB):\n');
acom1 = zeros(numel(NIVEIS_M1)-1,1);
for k = 2:numel(NIVEIS_M1)
    ini  = (k-1)*DUR_M1;
    jan  = (t >= ini) & (t < ini + DUR_M1);
    Tfim = mean(T((t >= ini + DUR_M1 - 0.5) & (t < ini + DUR_M1)));
    tj   = t(jan);  Tj = T(jan);
    fora = find(abs(Tj - Tfim) >= 0.5, 1, 'last');
    if isempty(fora), acom1(k-1) = 0; else, acom1(k-1) = (tj(fora)-ini)*1000; end
    fprintf('      %+5.1f -> %+5.1f dBFS : %7.1f ms\n', ...
            NIVEIS_M1(k-1), NIVEIS_M1(k), acom1(k-1));
end
fprintf('\n');

degrausTeor = zeros(size(t));
for k = 1:numel(NIVEIS_M1)
    jan = (t >= (k-1)*DUR_M1) & (t < k*DUR_M1);
    degrausTeor(jan) = NIVEIS_M1(k) - 20*log10(sqrt(2));
end

fig = figure('Color','w','Position',[100 100 900 520]);

ax1 = subplot(2,1,1);
plot(ax1, t, degrausTeor, '--', 'Color',PONTIL, 'LineWidth',1.2); hold(ax1,'on');
plot(ax1, t, mu, 'Color',CINZA, 'LineWidth',1.2);
plot(ax1, t, T,  'Color',VERM,  'LineWidth',1.4);
hold(ax1,'off');
xlim(ax1,[0 t(end)]); ylim(ax1,[-50 -10]);
title(ax1,'Nível de curto prazo e limiar adaptativo');
ylabel(ax1,'Nível (dBFS)');
marcaAquecimento(ax1, T_AQUEC);
legend(ax1,{'nível eficaz teórico','média estimada \mu','limiar T', ...
            'fim do aquecimento'}, 'Location','northeast');
estiloEixo(ax1); virgula(ax1);

ax2 = subplot(2,1,2);
plot(ax2, t, sig, 'Color',AZUL, 'LineWidth',1.2);
%  O limite superior acomoda os picos de sigma nas transicoes, de ate
%  5,85 dB; o pico do aquecimento, de 67 dB, fica necessariamente fora,
%  mas ocorre antes de a adaptacao entrar em vigor.
xlim(ax2,[0 t(end)]); ylim(ax2,[0 6.5]);
title(ax2,'Desvio padrão estimado');
xlabel(ax2,'Tempo (s)'); ylabel(ax2,'\sigma (dB)');
marcaAquecimento(ax2, T_AQUEC);
estiloEixo(ax2); virgula(ax2);

exportgraphics(fig,'fig_modo1_limiar.png','Resolution',200);

% =========================================================
% MODO 2 -- RAZAO PELO FATOR DE CRISTA
% =========================================================
d2 = lerCsv('saida_modo2_adapt.csv');

ROT_M2 = {'sustentado','percussivo 60 ms','percussivo 20 ms','percussivo 10 ms'};
DUR_M2 = 4.0;

t  = d2(:,COL.t);
cf = d2(:,COL.crista);
Rz = d2(:,COL.R);

fprintf('  Modo 2 -- razao pelo fator de crista\n');
fprintf('    %-18s %-11s %-9s\n','material','CF medido','R medido');
tabela2 = zeros(numel(ROT_M2),2);
for k = 1:numel(ROT_M2)
    jan = (t >= k*DUR_M2 - 1.0) & (t < k*DUR_M2);
    tabela2(k,:) = [mean(cf(jan)), mean(Rz(jan))];
    fprintf('    %-18s %8.2f dB %8.2f:1\n', ROT_M2{k}, tabela2(k,1), tabela2(k,2));
end
fprintf('\n');

fig = figure('Color','w','Position',[100 100 900 520]);

ax1 = subplot(2,1,1);
plot(ax1, t, cf, 'Color',CINZA, 'LineWidth',1.1); hold(ax1,'on');
%  As duas linhas de referencia em UMA chamada, separadas por NaN, para
%  que constituam um unico objeto grafico e ocupem uma unica entrada na
%  legenda.
plot(ax1, [0 t(end) NaN 0 t(end)], ...
          [CF_LO CF_LO NaN CF_HI CF_HI], ':', 'Color',PONTIL, 'LineWidth',1.1);
hold(ax1,'off');
xlim(ax1,[0 t(end)]); ylim(ax1,[0 20]);
title(ax1,'Fator de crista estimado');
ylabel(ax1,'CF (dB)');
marcaAquecimento(ax1, T_AQUEC);
legend(ax1,{'CF estimado','pontos de referência da lei', ...
            'fim do aquecimento'}, 'Location','southeast');
estiloEixo(ax1); virgula(ax1);

ax2 = subplot(2,1,2);
plot(ax2, t, Rz, 'Color',VERM, 'LineWidth',1.4); hold(ax2,'on');
plot(ax2, [0 t(end)], [R_HI R_HI], ':', 'Color',PONTIL, 'LineWidth',1.1);
hold(ax2,'off');
xlim(ax2,[0 t(end)]); ylim(ax2,[1 9]);
title(ax2,'Razão de compressão resultante');
xlabel(ax2,'Tempo (s)'); ylabel(ax2,'R');
marcaAquecimento(ax2, T_AQUEC);
legend(ax2,{'R adaptada','saturação superior','fim do aquecimento'}, ...
       'Location','southeast');
estiloEixo(ax2); virgula(ax2);

exportgraphics(fig,'fig_modo2_crista.png','Resolution',200);

% =========================================================
% MODO 3 -- ATAQUE PELA DERIVADA DO ENVELOPE
% =========================================================
d3 = lerCsv('saida_modo3_adapt.csv');

INC   = [0.1 1 10 100];
FAIXA = 54;            % dB percorridos pela rampa
AQUEC = 1.2;  PED = 0.6;  SUST = 0.8;

t  = d3(:,COL.t);
sv = d3(:,COL.deriv);
ta = d3(:,COL.tauA);

fprintf('  Modo 3 -- ataque pela derivada do envelope\n');
fprintf('    %-12s %-12s %-13s %-13s %-12s\n', ...
        's nominal','s medido','tauA medido','tauA(s med)','desvio');
tabela3 = zeros(numel(INC),4);
tIni = AQUEC;
for k = 1:numel(INC)
    durS   = (FAIXA/INC(k))/1000;
    tRampa = tIni + PED;
    jan    = (t >= tRampa) & (t < tRampa + durS + 0.10);
    sMed   = max(sv(jan));
    tauMed = min(ta(jan));
    tauLei = ATQ_MIN + (ATQ_MAX-ATQ_MIN)/(1 + sMed/S_REF);
    tabela3(k,:) = [INC(k), sMed, tauMed, tauLei];
    fprintf('    %9.1f    %9.2f    %9.2f     %9.2f    %+9.3f\n', ...
            INC(k), sMed, tauMed, tauLei, tauMed-tauLei);
    tIni = tRampa + durS + SUST;
end
fprintf('\n');

sCurva   = logspace(-2, 2.6, 400);
tauCurva = ATQ_MIN + (ATQ_MAX-ATQ_MIN)./(1 + sCurva/S_REF);

fig = figure('Color','w','Position',[100 100 760 470]);
ax = axes(fig);
semilogx(ax, sCurva, tauCurva, '-', 'Color',CINZA, 'LineWidth',1.4); hold(ax,'on');
semilogx(ax, tabela3(:,2), tabela3(:,3), 'o', ...
         'MarkerSize',8, 'LineWidth',1.6, 'Color',VERM, 'MarkerFaceColor','w');
hold(ax,'off');
xlim(ax,[0.05 500]); ylim(ax,[0 55]);
title(ax,'Tempo de ataque adaptado em função da inclinação do envelope');
xlabel(ax,'Inclinação estimada v (dB/ms)');
ylabel(ax,'\tau_A (ms)');
%  Cada ponto e rotulado com a inclinacao NOMINAL da rampa que o
%  produziu. A distincao entre nominal e estimada e o proprio objeto da
%  ressalva: na quarta rampa as duas divergem por uma ordem de grandeza,
%  porque o estimador satura.
for k = 1:size(tabela3,1)
    text(ax, tabela3(k,2)*1.25, tabela3(k,3)+1.5, ...
         [numvir(tabela3(k,1),1) ' dB/ms'], ...
         'FontSize',9, 'Color',CINZA, 'HorizontalAlignment','left');
end
legend(ax,{'lei (Eq. da seção 9.4.1)','medido'}, 'Location','southwest');
estiloEixo(ax); virgula(ax);

exportgraphics(fig,'fig_modo3_ataque.png','Resolution',200);

% =========================================================
% MODO 4 -- COMPENSACAO AUTOMATICA DE GANHO
% =========================================================
d4 = lerCsv('saida_modo4_adapt.csv');

NIVEIS_M4 = [-30 -13 -9 -6 -3];
DUR_M4    = 5.0;
T_PAD = -12; R_PAD = 4; W_PAD = 6;

t  = d4(:,COL.t);
Mg = d4(:,COL.M);
mu = d4(:,COL.media);

fprintf('  Modo 4 -- compensacao automatica de ganho\n');
fprintf('    %-10s %-14s %-12s %-14s %-12s\n', ...
        'degrau','curva estat.','M medido','acomodacao','sobressinal');
tabela4 = zeros(numel(NIVEIS_M4),4);
for k = 1:numel(NIVEIS_M4)
    ini  = (k-1)*DUR_M4;
    jan  = (t >= ini) & (t < ini + DUR_M4);
    Mfim = mean(Mg((t >= ini + DUR_M4 - 0.5) & (t < ini + DUR_M4)));
    tj = t(jan); Mj = Mg(jan);
    tol  = max(0.05*abs(Mfim), 0.02);
    fora = find(abs(Mj - Mfim) >= tol, 1, 'last');
    if isempty(fora) || k == 1
        acom = 0;
    else
        acom = (tj(fora) - ini)*1000;
    end
    over = max(0, max(Mj) - Mfim);
    gEst = reducaoEstatica(NIVEIS_M4(k), T_PAD, R_PAD, W_PAD);
    tabela4(k,:) = [NIVEIS_M4(k), -gEst, Mfim, acom];
    fprintf('    %7.1f  %11.2f dB %9.3f dB %10.1f ms %11.4f dB\n', ...
            NIVEIS_M4(k), -gEst, Mfim, acom, over);
end
fprintf('\n');

fig = figure('Color','w','Position',[100 100 900 520]);

ax1 = subplot(2,1,1);
plot(ax1, t, mu, 'Color',CINZA, 'LineWidth',1.2);
xlim(ax1,[0 t(end)]); ylim(ax1,[-36 -2]);
title(ax1,'Nível de curto prazo da entrada');
ylabel(ax1,'Nível (dBFS)');
marcaAquecimento(ax1, T_AQUEC);
estiloEixo(ax1); virgula(ax1);

ax2 = subplot(2,1,2);
plot(ax2, t, Mg, 'Color',VERM, 'LineWidth',1.4); hold(ax2,'on');
%  Os cinco patamares de regime em UMA chamada, separados por NaN, pela
%  mesma razao exposta na figura do Modo 2.
xReg = []; yReg = [];
for k = 1:numel(NIVEIS_M4)
    xReg = [xReg, (k-1)*DUR_M4, k*DUR_M4, NaN];            %#ok<AGROW>
    yReg = [yReg, tabela4(k,3), tabela4(k,3), NaN];        %#ok<AGROW>
end
plot(ax2, xReg, yReg, ':', 'Color',PONTIL, 'LineWidth',1.1);
hold(ax2,'off');
xlim(ax2,[0 t(end)]); ylim(ax2,[-0.5 7]);
title(ax2,'Ganho de compensação automático');
xlabel(ax2,'Tempo (s)'); ylabel(ax2,'M (dB)');
marcaAquecimento(ax2, T_AQUEC);
legend(ax2,{'M aplicado','valor em regime','fim do aquecimento'}, ...
       'Location','northwest');
estiloEixo(ax2); virgula(ax2);

exportgraphics(fig,'fig_modo4_makeup.png','Resolution',200);

% =========================================================
% OPERACAO SIMULTANEA
% =========================================================
dS = lerCsv('saida_todos_adapt.csv');

t = dS(:,COL.t);

fprintf('  Operacao simultanea dos quatro mecanismos\n');
fprintf('    %-18s %-10s %-8s %-11s %-8s\n', ...
        'trecho','T (dBFS)','R','tauA (ms)','M (dB)');
tabela5 = zeros(numel(ROT_M2),4);
for k = 1:numel(ROT_M2)
    jan = (t >= k*DUR_M2 - 1.0) & (t < k*DUR_M2);
    tabela5(k,:) = [mean(dS(jan,COL.T)),    mean(dS(jan,COL.R)), ...
                    mean(dS(jan,COL.tauA)), mean(dS(jan,COL.M))];
    fprintf('    %-18s %8.2f %7.2f %9.2f %8.2f\n', ROT_M2{k}, ...
            tabela5(k,1), tabela5(k,2), tabela5(k,3), tabela5(k,4));
end

fprintf('\n    teste de oscilacao -- variacao pico a pico no primeiro\n');
fprintf('    e no ultimo segundo de cada trecho:\n');
for k = 1:numel(ROT_M2)
    base = (k-1)*DUR_M2;
    jA = (t >= base+1.0) & (t < base+2.0);
    jB = (t >= base+3.0) & (t < base+4.0);
    pp = @(j,c) max(dS(j,c)) - min(dS(j,c));
    fprintf('      %-18s T %5.3f->%5.3f dB   tauA %6.3f->%6.3f ms   M %5.3f->%5.3f dB\n', ...
            ROT_M2{k}, pp(jA,COL.T), pp(jB,COL.T), ...
            pp(jA,COL.tauA), pp(jB,COL.tauA), pp(jA,COL.M), pp(jB,COL.M));
end
fprintf('\n');

fig = figure('Color','w','Position',[100 100 900 760]);
sinais  = {dS(:,COL.T), dS(:,COL.R), dS(:,COL.tauA), dS(:,COL.M)};
titulos = {'Limiar T', 'Razão R', 'Tempo de ataque \tau_A', 'Compensação M'};
rotulos = {'T (dBFS)', 'R', '\tau_A (ms)', 'M (dB)'};
limites = {[-26 -16], [1 9], [0 55], [-0.5 3]};

for k = 1:4
    ax = subplot(4,1,k);
    plot(ax, t, sinais{k}, 'Color',CINZA, 'LineWidth',1.1);
    xlim(ax,[0 t(end)]); ylim(ax, limites{k});
    title(ax, titulos{k});
    ylabel(ax, rotulos{k});
    if k == 4, xlabel(ax,'Tempo (s)'); end
    marcaAquecimento(ax, T_AQUEC);
    estiloEixo(ax); virgula(ax);
end

exportgraphics(fig,'fig_modos_simultaneos.png','Resolution',200);

fprintf('  Figuras gravadas:\n');
fprintf('    fig_modo1_limiar.png\n');
fprintf('    fig_modo2_crista.png\n');
fprintf('    fig_modo3_ataque.png\n');
fprintf('    fig_modo4_makeup.png\n');
fprintf('    fig_modos_simultaneos.png\n\n');

% =========================================================
% FUNCOES AUXILIARES
% =========================================================
function d = lerCsv(nome)
    if ~isfile(nome)
        error('Arquivo nao encontrado: %s\nRode antes os comandos do CompressorOffline.', nome);
    end
    d = readmatrix(nome, 'NumHeaderLines', 1);
end

function marcaAquecimento(ax, t0)
%MARCAAQUECIMENTO  Linha vertical no fim do periodo de aquecimento.
%  Antes desse instante o controlador mantem os parametros manuais, de
%  modo que o trecho a esquerda da linha nao exprime adaptacao alguma.
    yl = ylim(ax);
    hold(ax,'on');
    plot(ax, [t0 t0], yl, '-.', 'Color',[0.55 0.55 0.55], 'LineWidth',1.1);
    hold(ax,'off');
    ylim(ax, yl);
end

function g = reducaoEstatica(xDb, T, R, W)
    if xDb - T < -W/2
        g = 0;
    elseif abs(xDb - T) <= W/2
        g = (1/R - 1) * (xDb - T + W/2)^2 / (2*W);
    else
        g = (1/R - 1) * (xDb - T);
    end
end

function estiloEixo(ax)
    set(ax, 'Color','w','XColor','k','YColor','k', ...
            'GridColor',[0.20 0.20 0.20],'GridAlpha',0.28, ...
            'FontSize',10,'LineWidth',1.0,'Box','on', ...
            'TickDir','out','XGrid','on','YGrid','on');
    set(ax.Title,'Color','k','FontSize',11,'FontWeight','bold');
    set(ax.XLabel,'Color','k','FontSize',10);
    set(ax.YLabel,'Color','k','FontSize',10);
    lg = get(ax,'Legend');
    if ~isempty(lg)
        set(lg,'TextColor','k','Color','w', ...
               'EdgeColor',[0.20 0.20 0.20],'FontSize',9,'Box','on');
    end
    try, ax.Toolbar = []; catch, end
    try, disableDefaultInteractivity(ax); catch, end
end
