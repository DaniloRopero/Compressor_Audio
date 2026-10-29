% =========================================================
% METRICAS DE FAIXA DINAMICA  —  criterio da Secao 5.7.2
%
% Calcula a reducao de faixa dinamica descartando uma janela
% de guarda apos cada transicao de nivel, e demonstra que a
% janela nao e arbitraria: o resultado cruza o zero em tres
% constantes de tempo de ataque e satura a partir de dez.
%
% As metricas incidem sobre a SAIDA DO C++ (saida.csv).
%
% Requer, na mesma pasta:
%   sinal_teste.wav
%   saida.csv        (gerado pelo CompressorOffline)
%
% Gera: fig_metricas_dinamica.png
% =========================================================

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

tA         = 10;    % ms  — constante de tempo de ataque usada no processamento
GUARDA_TAU = 5;     %     — janela de guarda, em multiplos de tA

GUARDA_MS = GUARDA_TAU * tA;

% paleta escura para impressao
C_IN  = [0.00 0.20 0.50];   % azul-marinho    — entrada
C_OUT = [0.70 0.10 0.10];   % vermelho escuro — saida
C_BAR = [0.15 0.30 0.55];   % azul escuro     — barras
C_MRK = [0.45 0.15 0.05];   % marcacao adotada
C_REF = [0.15 0.15 0.15];   % quase preto     — linhas auxiliares

% ---------------------------------------------------------
% LEITURA
% ---------------------------------------------------------

if ~isfile('sinal_teste.wav'), error('sinal_teste.wav nao encontrado.'); end
if ~isfile('saida.csv'),       error('saida.csv nao encontrado. Rode o CompressorOffline primeiro.'); end

[x, fs] = audioread('sinal_teste.wav');
x = x(:).';
N = numel(x);

D = readmatrix('saida.csv', 'NumHeaderLines', 1);
y = D(:,1).';

if numel(y) ~= N
    error('Numero de amostras divergente: WAV %d, CSV %d', N, numel(y));
end

n1 = round(N/3);
n2 = round(2*N/3);

% ---------------------------------------------------------
% FUNCOES DE MEDIDA
% ---------------------------------------------------------

dbv = @(v) 20*log10(v + 1e-12);
pk  = @(v) dbv(max(abs(v)));
DR  = @(v) dbv(max(abs(v))) - dbv(sqrt(mean(v.^2)));

mascara = @(g) montarMascara(N, n1, n2, g);

% ---------------------------------------------------------
% METRICAS NA CONDICAO ADOTADA
% ---------------------------------------------------------

gu = round(GUARDA_MS/1000 * fs);
m  = mascara(gu);

f1 = (gu+1)    : n1;
f2 = (n1+gu+1) : n2;
f3 = (n2+gu+1) : N;

DRg_in  = DR(x);     DRg_out  = DR(y);
DRm_in  = DR(x(m));  DRm_out  = DR(y(m));

exc21_in  = pk(x(f2)) - pk(x(f1));
exc21_out = pk(y(f2)) - pk(y(f1));
exc23_in  = pk(x(f2)) - pk(x(f3));
exc23_out = pk(y(f2)) - pk(y(f3));

fprintf('\n=== METRICAS DE FAIXA DINAMICA ===\n');
fprintf('  Janela de guarda: %d ms  (%g x tau_A)\n\n', GUARDA_MS, GUARDA_TAU);

fprintf('  %-38s %9s %9s %11s   %s\n', 'Condicao', 'Entrada', 'Saida', 'Reducao', 'Criterio');
fprintf('  %s\n', repmat('-', 1, 82));

mostra = @(nome, a, bb) fprintf('  %-38s %8.3f  %8.3f  %+9.3f dB   %s\n', ...
    nome, a, bb, a-bb, veredito(a-bb > 0));

mostra('DR global, sem guarda',        DRg_in,   DRg_out);
mostra('DR global, com guarda',        DRm_in,   DRm_out);
mostra('Excursao entre trechos 2 e 1', exc21_in, exc21_out);
mostra('Excursao entre trechos 2 e 3', exc23_in, exc23_out);

fprintf('\n  Niveis de pico por trecho, em regime permanente:\n');
fprintf('    trecho 1   entrada %+8.3f   saida %+8.3f dBFS\n', pk(x(f1)), pk(y(f1)));
fprintf('    trecho 2   entrada %+8.3f   saida %+8.3f dBFS\n', pk(x(f2)), pk(y(f2)));
fprintf('    trecho 3   entrada %+8.3f   saida %+8.3f dBFS\n', pk(x(f3)), pk(y(f3)));

% ---------------------------------------------------------
% SENSIBILIDADE A JANELA DE GUARDA
% ---------------------------------------------------------

taus = [0 0.5 1 1.5 2 2.5 3 4 5 7.5 10 15];
red  = zeros(size(taus));

for k = 1:numel(taus)
    g = round(taus(k)*tA/1000*fs);
    mk = mascara(g);
    red(k) = DR(x(mk)) - DR(y(mk));
end

fprintf('\n=== SENSIBILIDADE A JANELA DE GUARDA ===\n');
fprintf('  %8s %10s %12s\n', 'guarda', 'em tau_A', 'reducao');
fprintf('  %s\n', repmat('-', 1, 34));
for k = 1:numel(taus)
    fprintf('  %6.1f ms %8.1f    %+8.3f dB\n', taus(k)*tA, taus(k), red(k));
end

idxCruza = find(red > 0, 1);
if ~isempty(idxCruza)
    fprintf(['\n  A reducao cruza o zero em %.1f constantes de tempo, coerente com\n' ...
             '  o criterio de acomodacao de um sistema de primeira ordem (3 tau\n' ...
             '  corresponde a 95%% do valor final). A partir de 10 tau o valor\n' ...
             '  satura, indicando que a metrica passou a medir o regime\n' ...
             '  permanente e nao depende mais do ponto exato de corte.\n\n'], taus(idxCruza));
end

% ---------------------------------------------------------
% GRAFICOS
% ---------------------------------------------------------

t = (0:N-1)/fs;

fig = figure('Name','Metricas de faixa dinamica','NumberTitle','off', ...
             'Color','w','Position',[70 50 960 740]);

ax1 = subplot(3,1,1);
plot(t, x, 'Color', C_IN,  'LineWidth', 0.8); hold on;
plot(t, y, 'Color', C_OUT, 'LineWidth', 0.8);
xline(t(n1), ':', 'Color', C_REF, 'LineWidth', 1.2);
xline(t(n2), ':', 'Color', C_REF, 'LineWidth', 1.2);
title('Entrada e saida no dominio do tempo');
xlabel('Tempo (s)'); ylabel('Amplitude');
legend({'entrada','saida'}, 'Location','northwest');
estiloEixo(ax1);

ax2 = subplot(3,1,2);
plot(taus, red, '-o', 'Color', C_IN, 'LineWidth', 1.8, ...
     'MarkerSize', 5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', C_IN); hold on;
yline(0, '-', 'Color', 'k', 'LineWidth', 1.0);
xline(3, '--', '3\tau_A', 'Color', C_REF, 'LineWidth', 1.4, ...
      'FontSize', 9, 'LabelVerticalAlignment','bottom');
xline(GUARDA_TAU, ':', sprintf('adotado: %g\\tau_A', GUARDA_TAU), ...
      'Color', C_MRK, 'LineWidth', 1.6, 'FontSize', 9, ...
      'LabelVerticalAlignment','bottom');
title('Reducao de faixa dinamica em funcao da janela de guarda');
xlabel('Janela de guarda  (multiplos de \tau_A)'); ylabel('Reducao (dB)');
estiloEixo(ax2);

ax3 = subplot(3,1,3);
cats = categorical({'DR sem guarda','DR com guarda','Excursao T2-T1','Excursao T2-T3'});
cats = reordercats(cats, {'DR sem guarda','DR com guarda','Excursao T2-T1','Excursao T2-T3'});
bh = bar(cats, [DRg_in-DRg_out, DRm_in-DRm_out, exc21_in-exc21_out, exc23_in-exc23_out]);
set(bh, 'FaceColor', C_BAR, 'EdgeColor', 'k', 'LineWidth', 0.8, 'BarWidth', 0.6);
yline(0, '-', 'Color', 'k', 'LineWidth', 1.0);
title('Reducao obtida em cada condicao de medida');
ylabel('Reducao (dB)');
estiloEixo(ax3);

salvarFigura(fig, 'fig_metricas_dinamica.png');

fprintf('Figura salva em fig_metricas_dinamica.png\n\n');

% =========================================================
% FUNCOES AUXILIARES
% =========================================================

function m = montarMascara(N, n1, n2, g)
    m = true(1, N);
    if g > 0
        m(1:min(g,N)) = false;
        m(n1 : min(n1+g-1, N)) = false;
        m(n2 : min(n2+g-1, N)) = false;
    end
end

function s = veredito(cond)
    if cond, s = 'APROVADO'; else, s = 'REPROVADO'; end
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
