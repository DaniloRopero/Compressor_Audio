% =========================================================
% VALIDACAO CRUZADA MATLAB x C++
%
% Processa o mesmo arquivo WAV pelo prototipo MATLAB e
% compara, amostra a amostra, com a saida gravada pelo
% programa CompressorOffline.
%
% Requer, na mesma pasta:
%   sinal_teste.wav
%   saida.csv        (gerado pelo CompressorOffline)
%
% Gera: fig_validacao_cruzada.png
% =========================================================

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

% ---------------------------------------------------------
% 1 — ARQUIVOS E PARAMETROS
% ---------------------------------------------------------

arqWav = 'sinal_teste.wav';
arqCsv = 'saida.csv';

T  = -12;      % limiar   (dBFS)
R  =   4;      % razao
tA =  10;      % ataque   (ms)
tR = 100;      % release  (ms)
W  =   6;      % joelho   (dB)
M  =   6;      % make-up  (dB)

LIMIAR_ACEITACAO = 1e-6;

% ---- paleta ativa -------------------------------------------------
C_MAT = [0.28 0.08 0.42];   % violeta escuro   — prototipo MATLAB
C_CPP = [0.78 0.45 0.00];   % ocre / ambar     — implementacao C++
C_ERR = [0.05 0.33 0.33];   % verde-petroleo   — erro absoluto
C_REF = [0.10 0.10 0.10];   % quase preto      — linhas auxiliares

% ---- alternativas: descomente o bloco desejado --------------------
% Grafite e vinho (sobria, maxima legibilidade em preto e branco)
% C_MAT = [0.12 0.12 0.12];  C_CPP = [0.60 0.00 0.20];
% C_ERR = [0.20 0.35 0.45];  C_REF = [0.10 0.10 0.10];

% Verde-escuro e marrom (sem azul, bom para impressao economica)
% C_MAT = [0.05 0.30 0.20];  C_CPP = [0.50 0.25 0.05];
% C_ERR = [0.35 0.10 0.10];  C_REF = [0.10 0.10 0.10];

% Azul-aco e terracota (tons intermediarios, contraste suave)
% C_MAT = [0.10 0.30 0.45];  C_CPP = [0.65 0.30 0.15];
% C_ERR = [0.25 0.20 0.40];  C_REF = [0.10 0.10 0.10];

% ---------------------------------------------------------
% 2 — LEITURA DO SINAL
% ---------------------------------------------------------

if ~isfile(arqWav), error('Arquivo nao encontrado: %s', arqWav); end
if ~isfile(arqCsv), error('Arquivo nao encontrado: %s', arqCsv); end

[x, fs] = audioread(arqWav);
x = x(:).';
N = numel(x);

fprintf('Sinal: %d amostras a %d Hz (%.3f s)\n', N, fs, N/fs);

% ---------------------------------------------------------
% 3 — PROTOTIPO MATLAB
% ---------------------------------------------------------

alphaA = exp(-1 / (fs * tA / 1000));
alphaR = exp(-1 / (fs * tR / 1000));

y  = zeros(1, N);
g  = zeros(1, N);
yL = 0;

for n = 1:N
    xG = 20 * log10(abs(x(n)) + 1e-9);

    if W > 0 && (2 * abs(xG - T) <= W)
        cG = xG + (1/R - 1) * (xG - T + W/2)^2 / (2*W);
    elseif xG > T + W/2
        cG = T + (xG - T) / R;
    else
        cG = xG;
    end

    gainDB = cG - xG;

    if gainDB < yL
        yL = alphaA * yL + (1 - alphaA) * gainDB;
    else
        yL = alphaR * yL + (1 - alphaR) * gainDB;
    end

    y(n) = x(n) * 10^((yL + M) / 20);
    g(n) = yL;
end

% ---------------------------------------------------------
% 4 — LEITURA DA SAIDA DO C++
% ---------------------------------------------------------

D = readmatrix(arqCsv, 'NumHeaderLines', 1);

if size(D, 2) == 2
    yC = D(:,1).';  gC = D(:,2).';
elseif size(D, 2) == 3
    yC = D(:,1).';  gC = D(:,3).';
else
    error('Formato de CSV inesperado: %d colunas', size(D,2));
end

if numel(yC) ~= N
    error('Numero de amostras divergente: MATLAB %d, C++ %d', N, numel(yC));
end

% ---------------------------------------------------------
% 5 — COMPARACAO
% ---------------------------------------------------------

erroY = abs(y - yC);
erroG = abs(g - gC);

erroYmax = max(erroY);
erroGmax = max(erroG);
erroYrms = sqrt(mean(erroY.^2));

[~, idxPior] = max(erroY);

fprintf('\n=== COMPARACAO AMOSTRA A AMOSTRA ===\n');
fprintf('  erro maximo   (saida)   = %.3e\n', erroYmax);
fprintf('  erro RMS      (saida)   = %.3e\n', erroYrms);
fprintf('  erro maximo   (ganho)   = %.3e dB\n', erroGmax);
fprintf('  pior amostra            = %d  (t = %.4f s)\n', idxPior, idxPior/fs);
fprintf('  limiar de aceitacao     = %.1e\n', LIMIAR_ACEITACAO);

if erroYmax <= LIMIAR_ACEITACAO
    fprintf('\n  RESULTADO: APROVADO\n\n');
else
    fprintf('\n  RESULTADO: REPROVADO — investigar divergencia\n\n');
end

% ---------------------------------------------------------
% 6 — METRICAS POR TRECHO
% ---------------------------------------------------------

n1 = round(N/3);
n2 = round(2*N/3);
guarda = round(0.050 * fs);

faixa1 = (guarda + 1)      : n1;
faixa2 = (n1 + guarda + 1) : n2;
faixa3 = (n2 + guarda + 1) : N;

pk = @(v) 20*log10(max(abs(v)) + 1e-9);

exc_in  = pk(x(faixa2)) - pk(x(faixa1));
exc_out = pk(y(faixa2)) - pk(y(faixa1));

fprintf('=== REGIME PERMANENTE (50 ms de guarda) ===\n');
fprintf('  trecho 1  entrada %+7.3f dBFS   saida %+7.3f dBFS\n', pk(x(faixa1)), pk(y(faixa1)));
fprintf('  trecho 2  entrada %+7.3f dBFS   saida %+7.3f dBFS\n', pk(x(faixa2)), pk(y(faixa2)));
fprintf('  trecho 3  entrada %+7.3f dBFS   saida %+7.3f dBFS\n', pk(x(faixa3)), pk(y(faixa3)));
fprintf('  excursao T2-T1  entrada %+7.3f dB   saida %+7.3f dB\n', exc_in, exc_out);
fprintf('  reducao de excursao     %+7.3f dB\n\n', exc_in - exc_out);

% ---------------------------------------------------------
% 7 — GRAFICOS
% ---------------------------------------------------------

t = (0:N-1) / fs;

fig = figure('Name','Validacao cruzada','NumberTitle','off', ...
             'Color','w','Position',[80 60 940 720]);

ax1 = subplot(3,1,1);
plot(t, y,  'Color', C_MAT, 'LineWidth', 1.3); hold on;
plot(t, yC, '--', 'Color', C_CPP, 'LineWidth', 1.1);
title('Sinal de saida: MATLAB e C++ sobrepostos');
xlabel('Tempo (s)'); ylabel('Amplitude');
legend({'MATLAB','C++'}, 'Location','northwest');
estiloEixo(ax1);

ax2 = subplot(3,1,2);
plot(t, g,  'Color', C_MAT, 'LineWidth', 1.6); hold on;
plot(t, gC, '--', 'Color', C_CPP, 'LineWidth', 1.3);
title('Envelope de ganho');
xlabel('Tempo (s)'); ylabel('g_{dB}[n]  (dB)');
legend({'MATLAB','C++'}, 'Location','southeast');
estiloEixo(ax2);

ax3 = subplot(3,1,3);
semilogy(t, erroY + eps, 'Color', C_ERR, 'LineWidth', 1.0); hold on;
yline(LIMIAR_ACEITACAO, '--', 'Limiar de aceitacao', ...
      'Color', C_REF, 'LineWidth', 1.4, 'FontSize', 9, ...
      'LabelHorizontalAlignment','left');
title(sprintf('Erro absoluto por amostra   (maximo = %.3e)', erroYmax));
xlabel('Tempo (s)'); ylabel('|y_{MATLAB} - y_{C++}|');
estiloEixo(ax3);

salvarFigura(fig, 'fig_validacao_cruzada.png');

fprintf('Validacao concluida. Figura salva em fig_validacao_cruzada.png\n\n');

% =========================================================
% FUNCOES AUXILIARES
% =========================================================

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
end

function salvarFigura(fig, nome)
    try
        exportgraphics(fig, nome, 'Resolution', 300, 'BackgroundColor', 'white');
    catch
        set(fig, 'InvertHardcopy', 'off', 'PaperPositionMode', 'auto');
        print(fig, nome, '-dpng', '-r300');
    end
end
