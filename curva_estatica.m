% =========================================================
% CURVA ESTATICA DE COMPRESSAO
%
% Compara a relacao entrada-saida medida na implementacao em
% C++ com a curva estatica prevista pelo modelo, em niveis de
% -60 a 0 dBFS.
%
% A medida e feita sob duas condicoes de excitacao:
%
%   onda quadrada — valor absoluto constante; a entrada do
%       computador de ganho e exatamente o nivel nominal, e a
%       medida recupera a curva estatica como definida.
%
%   senoide — valor absoluto oscilante; o detector instantaneo
%       produz tensao de controle pulsante, e a medida registra
%       desvio sistematico acima do limiar.
%
% Requer, na mesma pasta:
%   curva_quadrada.csv
%   curva_senoide.csv    (ambos do CompressorOffline)
%
% Gera: fig_curva_estatica.png
% =========================================================

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

fs     = 44100;
NIVEIS = -60 : 2.5 : 0;
T_SEG  = 0.300;
GUARDA = 0.100;        % s descartados no inicio de cada patamar

% parametros do processamento — devem coincidir com os do C++
T = -12;   R = 4;   W = 6;   M = 6;

C_TEO  = [0.70 0.10 0.10];   % vermelho escuro — curva teorica
C_QUA  = [0.00 0.20 0.50];   % azul-marinho    — onda quadrada
C_SEN  = [0.15 0.45 0.35];   % verde escuro    — senoide
C_REF  = [0.15 0.15 0.15];

nSeg = round(T_SEG*fs);
nGu  = round(GUARDA*fs);

% ---------------------------------------------------------
% MEDIDA
% ---------------------------------------------------------

Lq = medirPatamares('saida_quadrada.csv', NIVEIS, nSeg, nGu);
Ls = medirPatamares('saida_senoide.csv',  NIVEIS, nSeg, nGu);

Lt = arrayfun(@(L) curvaTeorica(L, T, R, W, M), NIVEIS);

dq = Lq - Lt;
ds = Ls - Lt;

% ---------------------------------------------------------
% RELATORIO
% ---------------------------------------------------------

fprintf('\n=== CURVA ESTATICA DE COMPRESSAO ===\n');
fprintf('  T = %.1f dBFS   R = %.1f:1   W = %.1f dB   M = %.1f dB\n', T, R, W, M);
fprintf('  Joelho entre %.1f e %.1f dBFS\n\n', T-W/2, T+W/2);

fprintf('  %8s %10s %10s %10s %10s %10s\n', ...
        'Entrada', 'Teorico', 'Quadrada', 'Desvio', 'Senoide', 'Desvio');
fprintf('  %s\n', repmat('-', 1, 64));
for k = 1:numel(NIVEIS)
    fprintf('  %7.1f  %9.3f  %9.3f  %+9.3f  %9.3f  %+9.3f\n', ...
            NIVEIS(k), Lt(k), Lq(k), dq(k), Ls(k), ds(k));
end

fprintf('\n  Desvio maximo, onda quadrada ... %.4f dB\n', max(abs(dq)));
fprintf('  Desvio maximo, senoide ......... %.4f dB\n', max(abs(ds)));

acima = NIVEIS > T + W/2;
if any(acima)
    fprintf('\n  Acima do joelho, a inclinacao media medida vale:\n');
    pq = polyfit(NIVEIS(acima), Lq(acima), 1);
    ps = polyfit(NIVEIS(acima), Ls(acima), 1);
    fprintf('    onda quadrada ... %.4f   (previsto 1/R = %.4f)\n', pq(1), 1/R);
    fprintf('    senoide ......... %.4f\n', ps(1));
end

fprintf(['\n  A medida com onda quadrada reproduz a curva estatica porque\n' ...
         '  o valor absoluto do sinal e constante: a entrada do computador\n' ...
         '  de ganho coincide com o nivel nominal. Sob senoide, o valor\n' ...
         '  absoluto oscila entre zero e o pico, de modo que o detector\n' ...
         '  instantaneo entrega tensao de controle pulsante e o filtro de\n' ...
         '  suavizacao acomoda em valor inferior ao da curva estatica,\n' ...
         '  resultando em menor reducao de ganho.\n\n']);

% ---------------------------------------------------------
% GRAFICOS
% ---------------------------------------------------------

fig = figure('Name','Curva estatica','NumberTitle','off', ...
             'Color','w','Position',[70 60 900 720]);

ax1 = subplot(2,1,1);
plot(NIVEIS, NIVEIS + M, ':', 'Color', C_REF, 'LineWidth', 1.3); hold on;
plot(NIVEIS, Lt, '-',  'Color', C_TEO, 'LineWidth', 2.0);
plot(NIVEIS, Lq, 'o',  'Color', C_QUA, 'LineWidth', 1.3, ...
     'MarkerSize', 6, 'MarkerFaceColor', 'w');
plot(NIVEIS, Ls, 's',  'Color', C_SEN, 'LineWidth', 1.3, ...
     'MarkerSize', 6, 'MarkerFaceColor', 'w');
xline(T,       '--', 'T',            'Color', C_REF, 'LineWidth', 1.3, 'FontSize', 9);
xline(T-W/2,   ':',  'T-W/2',        'Color', C_REF, 'LineWidth', 1.0, 'FontSize', 8);
xline(T+W/2,   ':',  'T+W/2',        'Color', C_REF, 'LineWidth', 1.0, 'FontSize', 8);
title('Curva estatica: relacao entrada-saida');
xlabel('Nivel de entrada (dBFS)'); ylabel('Nivel de saida (dBFS)');
legend({'ganho unitario + M','curva teorica','medido, onda quadrada','medido, senoide'}, ...
       'Location','northwest');
axis([min(NIVEIS) max(NIVEIS) min(Lt)-3 max(NIVEIS)+M+3]);
estiloEixo(ax1);

ax2 = subplot(2,1,2);
plot(NIVEIS, dq, '-o', 'Color', C_QUA, 'LineWidth', 1.5, ...
     'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
plot(NIVEIS, ds, '-s', 'Color', C_SEN, 'LineWidth', 1.5, ...
     'MarkerSize', 5, 'MarkerFaceColor', 'w');
yline(0, '-', 'Color', 'k', 'LineWidth', 1.0);
xline(T+W/2, ':', 'T+W/2', 'Color', C_REF, 'LineWidth', 1.0, 'FontSize', 8);
title('Desvio em relacao a curva teorica');
xlabel('Nivel de entrada (dBFS)'); ylabel('Desvio (dB)');
legend({'onda quadrada','senoide'}, 'Location','northwest');
estiloEixo(ax2);

salvarFigura(fig, 'fig_curva_estatica.png');

fprintf('Figura salva em fig_curva_estatica.png\n\n');

% =========================================================
% FUNCOES AUXILIARES
% =========================================================

function L = medirPatamares(arquivo, niveis, nSeg, nGu)
    if ~isfile(arquivo)
        error(['Arquivo nao encontrado: %s\n' ...
               'Rode o CompressorOffline sobre o WAV correspondente.'], arquivo);
    end

    D = readmatrix(arquivo, 'NumHeaderLines', 1);
    y = D(:,1).';

    esperado = nSeg * numel(niveis);
    if numel(y) < esperado
        error('CSV com %d amostras; esperadas %d.', numel(y), esperado);
    end

    L = zeros(1, numel(niveis));
    for k = 1:numel(niveis)
        w = y((k-1)*nSeg + nGu + 1 : k*nSeg);
        L(k) = 20*log10(max(abs(w)) + 1e-12);
    end
end

function Lout = curvaTeorica(L, T, R, W, M)
    xG = L;
    if W > 0 && 2*abs(xG - T) <= W
        cG = xG + (1/R - 1) * (xG - T + W/2)^2 / (2*W);
    elseif xG > T + W/2
        cG = T + (xG - T) / R;
    else
        cG = xG;
    end
    Lout = cG + M;
end

function estiloEixo(ax)
    set(ax, 'Color', 'w', ...
            'XColor', 'k', 'YColor', 'k', ...
            'GridColor', [0.20 0.20 0.20], 'GridAlpha', 0.28, ...
            'MinorGridColor', [0.30 0.30 0.30], ...
            'FontSize', 10, 'LineWidth', 1.0, 'Box', 'on', ...
            'TickDir', 'out', 'XGrid', 'on', 'YGrid', 'on');

    set(ax.Title,  'Color', 'k', 'FontSize', 11, 'FontWeight', 'bold');
    set(ax.XLabel, 'Color', 'k', 'FontSize', 10);
    set(ax.YLabel, 'Color', 'k', 'FontSize', 10);

    lg = get(ax, 'Legend');
    if ~isempty(lg)
        set(lg, 'TextColor', 'k', 'Color', 'w', ...
                'EdgeColor', [0.20 0.20 0.20], 'FontSize', 9, 'Box', 'on');
    end

    try, ax.Toolbar = []; catch, end
    try, disableDefaultInteractivity(ax); catch, end
end

function salvarFigura(fig, nome)
    try, set(findall(fig,'Type','axes'), 'Toolbar', []); catch, end
    try
        exportgraphics(fig, nome, 'Resolution', 300, 'BackgroundColor', 'white');
    catch
        set(fig, 'InvertHardcopy', 'off', 'PaperPositionMode', 'auto');
        print(fig, nome, '-dpng', '-r300');
    end
end
