% =========================================================
% MEDICAO DAS CONSTANTES DE TEMPO  —  criterio da Secao 5.7.2
%
% Verifica se os tempos de ataque e de liberacao implementados
% correspondem aos valores nominais, medindo sob tres condicoes
% de excitacao distintas:
%
%   A) degrau aplicado ao filtro de suavizacao isolado
%      — definicao teorica; verifica o filtro fora do sistema
%
%   B) sinal de amplitude absoluta constante (onda quadrada)
%      — a tensao de controle e um degrau verdadeiro;
%        verifica o filtro dentro da cadeia completa
%
%   C) excitacao senoidal
%      — a tensao de controle e pulsante, nao um degrau;
%        demonstra por que essa condicao nao recupera tau
%
% Requer, na mesma pasta:
%   degrau.csv   (CompressorOffline sobre sinal_degrau.wav)
%   saida.csv    (CompressorOffline sobre sinal_teste.wav)
%
% Gera: fig_constantes_tempo.png
% =========================================================

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

fs  = 44100;
tA  = 10;      % ms — nominal
tR  = 100;     % ms — nominal
TOL = 10;      % %  — tolerancia da Secao 5.7.2

% paleta escura para impressao
C_MED = [0.00 0.20 0.50];   % azul-marinho    — curva medida
C_TEO = [0.70 0.10 0.10];   % vermelho escuro — curva teorica
C_REF = [0.15 0.15 0.15];   % quase preto     — linhas auxiliares

alphaA = exp(-1 / (fs * tA / 1000));
alphaR = exp(-1 / (fs * tR / 1000));

% ---------------------------------------------------------
% A — RESPOSTA AO DEGRAU DO FILTRO ISOLADO
% ---------------------------------------------------------

medirDegrau = @(alpha, dur_ms) ...
    find(filtroDegrau(alpha, round(dur_ms/1000*fs)) >= 0.632, 1) / fs * 1000;

tA_A = medirDegrau(alphaA, 5*tA);
tR_A = medirDegrau(alphaR, 5*tR);

% ---------------------------------------------------------
% B e C — ENVELOPE MEDIDO SOBRE A SAIDA DO C++
% ---------------------------------------------------------

[tA_B, tR_B] = medirEnvelopeCsv('degrau.csv', fs, 0.10, 0.40, 1.00);
[tA_C, ~   ] = medirEnvelopeCsv('saida.csv',  fs, 1.00, 2.00, 3.00);

% ---------------------------------------------------------
% RELATORIO
% ---------------------------------------------------------

linha = @(nome, nom, med) fprintf('  %-34s %7.1f %10.3f %+9.2f %%   %s\n', ...
    nome, nom, med, 100*(med-nom)/nom, veredito(100*abs(med-nom)/nom, TOL));

fprintf('\n=== MEDICAO DAS CONSTANTES DE TEMPO ===\n');
fprintf('  %-34s %7s %10s %11s   %s\n', 'Condicao de excitacao', 'Nominal', 'Medido', 'Desvio', 'Criterio');
fprintf('  %s\n', repmat('-', 1, 80));
linha('A) degrau, filtro isolado  tau_A', tA, tA_A);
linha('A) degrau, filtro isolado  tau_R', tR, tR_A);
fprintf('\n');
linha('B) amplitude constante     tau_A', tA, tA_B);
linha('B) amplitude constante     tau_R', tR, tR_B);
fprintf('\n');
linha('C) senoide                 tau_A', tA, tA_C);
fprintf('\n');
fprintf('  Tolerancia adotada: %.0f %% em relacao ao valor nominal.\n', TOL);
fprintf(['\n  A condicao C nao satisfaz o criterio porque a tensao de controle\n' ...
         '  nao e um degrau: com senoide, |x[n]| oscila e so excede o limiar\n' ...
         '  durante parte de cada ciclo. A definicao de constante de tempo\n' ...
         '  pressupoe excitacao em degrau, condicao atendida em A e B.\n\n']);

% ---------------------------------------------------------
% GRAFICOS
% ---------------------------------------------------------

fig = figure('Name','Constantes de tempo','NumberTitle','off', ...
             'Color','w','Position',[70 60 960 660]);

Ns = round(5*tA/1000*fs);
ts = (0:Ns-1)/fs*1000;
ax1 = subplot(2,2,1);
plot(ts, filtroDegrau(alphaA, Ns), 'Color', C_MED, 'LineWidth', 1.8); hold on;
plot(ts, 1 - alphaA.^(0:Ns-1), '--', 'Color', C_TEO, 'LineWidth', 1.3);
yline(0.632, ':', '63,2 %', 'Color', C_REF, 'LineWidth', 1.2, ...
      'FontSize', 9, 'LabelHorizontalAlignment','right');
xline(tA, ':', sprintf('\\tau_A = %d ms', tA), 'Color', C_REF, ...
      'LineWidth', 1.2, 'FontSize', 9, 'LabelVerticalAlignment','bottom');
title('A — degrau, filtro de ataque');
xlabel('Tempo (ms)'); ylabel('s[n]');
legend({'medida','teorica  1-\alpha^n'}, 'Location','southeast');
estiloEixo(ax1);

Nr = round(3*tR/1000*fs);
tr = (0:Nr-1)/fs*1000;
ax2 = subplot(2,2,2);
plot(tr, filtroDegrau(alphaR, Nr), 'Color', C_MED, 'LineWidth', 1.8); hold on;
plot(tr, 1 - alphaR.^(0:Nr-1), '--', 'Color', C_TEO, 'LineWidth', 1.3);
yline(0.632, ':', '63,2 %', 'Color', C_REF, 'LineWidth', 1.2, ...
      'FontSize', 9, 'LabelHorizontalAlignment','right');
xline(tR, ':', sprintf('\\tau_R = %d ms', tR), 'Color', C_REF, ...
      'LineWidth', 1.2, 'FontSize', 9, 'LabelVerticalAlignment','bottom');
title('A — degrau, filtro de liberacao');
xlabel('Tempo (ms)'); ylabel('s[n]');
estiloEixo(ax2);

if isfile('degrau.csv')
    D = readmatrix('degrau.csv', 'NumHeaderLines', 1);
    g = D(:, end).';
    ax3 = subplot(2,1,2);
    plot((0:numel(g)-1)/fs, g, 'Color', C_MED, 'LineWidth', 1.6); hold on;
    xline(0.10, ':', 'inicio do ataque', 'Color', C_REF, ...
          'LineWidth', 1.2, 'FontSize', 9, 'LabelVerticalAlignment','bottom');
    xline(0.40, ':', 'inicio da liberacao', 'Color', C_REF, ...
          'LineWidth', 1.2, 'FontSize', 9, 'LabelVerticalAlignment','bottom');
    title('B — envelope de ganho sobre sinal de amplitude constante');
    xlabel('Tempo (s)'); ylabel('g_{dB}[n]  (dB)');
    estiloEixo(ax3);
end

salvarFigura(fig, 'fig_constantes_tempo.png');

fprintf('Figura salva em fig_constantes_tempo.png\n\n');

% =========================================================
% FUNCOES AUXILIARES
% =========================================================

function s = filtroDegrau(alpha, N)
    s = zeros(1, N);
    for n = 2:N
        s(n) = alpha*s(n-1) + (1-alpha)*1.0;
    end
end

function v = veredito(desvio, tol)
    if desvio <= tol, v = 'APROVADO'; else, v = 'REPROVADO'; end
end

function [tauA, tauR] = medirEnvelopeCsv(arquivo, fs, t0, t1, t2)
    tauA = NaN; tauR = NaN;
    if ~isfile(arquivo)
        warning('Arquivo nao encontrado: %s', arquivo); return;
    end

    D = readmatrix(arquivo, 'NumHeaderLines', 1);
    g = D(:, end).';

    n0 = round(t0*fs) + 1;
    n1 = round(t1*fs) + 1;
    n2 = min(round(t2*fs), numel(g));

    ini = n0 + round(0.7*(n1-n0));
    regimeA = mean(g(ini:n1-1));

    idx = find(g(n0:n1-1) <= 0.632*regimeA, 1);
    if ~isempty(idx), tauA = idx/fs*1000; end

    if n2 > n1 + round(0.1*fs)
        ini2 = n1 + round(0.7*(n2-n1));
        regimeR = mean(g(ini2:n2));
        alvo = regimeA + 0.632*(regimeR - regimeA);
        idx2 = find(g(n1:n2) >= alvo, 1);
        if ~isempty(idx2), tauR = idx2/fs*1000; end
    end
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

    % remove a barra de ferramentas do eixo para que ela nao
    % seja capturada dentro do PNG exportado
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
