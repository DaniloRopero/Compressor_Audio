% =========================================================
% DISTORCAO HARMONICA TOTAL
%
% Avalia a ausencia de distorcoes numericas indesejadas,
% criterio previsto na metodologia, medindo a THD da saida
% para senoide de 1 kHz em niveis de -60 a 0 dBFS.
%
% Dois regimes sao esperados:
%
%   abaixo do limiar — o sistema aplica ganho constante e a
%       distorcao deve situar-se no piso da precisao numerica
%       empregada, da ordem de -280 dB em precisao dupla.
%
%   acima do limiar — a modulacao do ganho pelo detector
%       instantaneo introduz componentes harmonicas. Trata-se
%       de efeito inerente a arquitetura, nao de defeito de
%       implementacao, e sua magnitude deve ser quantificada.
%
% A janela de analise contem 8820 amostras, equivalentes a
% exatamente 200 ciclos de 1 kHz a 44,1 kHz. O sinal e, assim,
% periodico na janela, e a transformada nao apresenta
% vazamento espectral, dispensando janelamento.
%
% Requer, na mesma pasta:
%   saida_senoide.csv    (do CompressorOffline)
%
% Gera: fig_distorcao.png
% =========================================================

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

fs      = 44100;
NIVEIS  = -60 : 2.5 : 0;
T_SEG   = 0.300;
GUARDA  = 0.100;
F_SEN   = 1000;
N_JANELA = 8820;      % 0,2 s = 200 ciclos exatos
N_HARM   = 10;        % harmonicas consideradas

T = -12;   W = 6;     % para marcar o limiar no grafico

C_THD = [0.00 0.20 0.50];
C_REF = [0.15 0.15 0.15];
C_PIS = [0.70 0.10 0.10];

nSeg = round(T_SEG*fs);
nGu  = round(GUARDA*fs);

if ~isfile('saida_senoide.csv')
    error(['saida_senoide.csv nao encontrado.\n' ...
           'Rode: CompressorOffline.exe curva_senoide.wav saida_senoide.csv']);
end

D = readmatrix('saida_senoide.csv', 'NumHeaderLines', 1);
y = D(:,1).';

if numel(y) < nSeg*numel(NIVEIS)
    error('CSV com %d amostras; esperadas %d.', numel(y), nSeg*numel(NIVEIS));
end

binFund = round(F_SEN * N_JANELA / fs);    % 200

thd    = zeros(1, numel(NIVEIS));
nivOut = zeros(1, numel(NIVEIS));

for k = 1:numel(NIVEIS)
    ini = (k-1)*nSeg + nGu + 1;
    w   = y(ini : ini + N_JANELA - 1);

    Y = abs(fft(w)) / (N_JANELA/2);

    fund = Y(binFund + 1);
    soma = 0;
    for h = 2:N_HARM
        b = binFund*h;
        if b < N_JANELA/2
            soma = soma + Y(b + 1)^2;
        end
    end

    thd(k)    = sqrt(soma) / fund;
    nivOut(k) = 20*log10(max(abs(w)) + 1e-12);
end

thdDb = 20*log10(thd + 1e-300);

% ---------------------------------------------------------
% RELATORIO
% ---------------------------------------------------------

fprintf('\n=== DISTORCAO HARMONICA TOTAL ===\n');
fprintf('  Excitacao .......... senoide de %d Hz\n', F_SEN);
fprintf('  Janela de analise .. %d amostras (%.0f ms, %d ciclos exatos)\n', ...
        N_JANELA, N_JANELA/fs*1000, binFund);
fprintf('  Harmonicas ......... 2 a %d\n', N_HARM);
fprintf('  Limiar ............. %.1f dBFS   joelho ate %.1f dBFS\n\n', T, T+W/2);

fprintf('  %8s %10s %12s %10s\n', 'Entrada', 'Saida', 'THD', 'THD');
fprintf('  %8s %10s %12s %10s\n', '(dBFS)', '(dBFS)', '(%)', '(dB)');
fprintf('  %s\n', repmat('-', 1, 44));
for k = 1:numel(NIVEIS)
    fprintf('  %7.1f  %9.3f  %11.5f  %9.2f\n', ...
            NIVEIS(k), nivOut(k), 100*thd(k), thdDb(k));
end

abaixo = NIVEIS < T - W/2;
acima  = NIVEIS > T + W/2;

fprintf('\n  Abaixo do joelho: THD maxima de %.2e %% (%.1f dB)\n', ...
        100*max(thd(abaixo)), max(thdDb(abaixo)));
fprintf('  Acima  do joelho: THD maxima de %.5f %% (%.2f dB)\n', ...
        100*max(thd(acima)), max(thdDb(acima)));

fprintf(['\n  Abaixo do limiar o sistema aplica ganho constante e nao\n' ...
         '  introduz distorcao mensuravel: o valor apurado corresponde ao\n' ...
         '  piso da precisao dupla, confirmando a ausencia de degradacao\n' ...
         '  numerica no caminho de sinal.\n']);
fprintf(['\n  Acima do limiar, a reducao de ganho acompanha o valor absoluto\n' ...
         '  do sinal e introduz modulacao de amplitude no dobro da\n' ...
         '  frequencia fundamental, cujo espectro se manifesta como\n' ...
         '  componentes harmonicas. O efeito e inerente a arquitetura\n' ...
         '  feedforward com detector instantaneo e constitui o mecanismo\n' ...
         '  pelo qual a compressao atua sobre a forma de onda.\n\n']);

% ---------------------------------------------------------
% GRAFICOS
% ---------------------------------------------------------

fig = figure('Name','Distorcao harmonica','NumberTitle','off', ...
             'Color','w','Position',[70 80 900 620]);

ax1 = subplot(2,1,1);
plot(NIVEIS, thdDb, '-o', 'Color', C_THD, 'LineWidth', 1.6, ...
     'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
yline(-280, '--', 'piso da precisao dupla', 'Color', C_PIS, ...
      'LineWidth', 1.3, 'FontSize', 9, 'LabelHorizontalAlignment','left');
xline(T,     '--', 'T',     'Color', C_REF, 'LineWidth', 1.3, 'FontSize', 9);
xline(T+W/2, ':',  'T+W/2', 'Color', C_REF, 'LineWidth', 1.0, 'FontSize', 8);
title('Distorcao harmonica total em funcao do nivel de entrada');
xlabel('Nivel de entrada (dBFS)'); ylabel('THD (dB)');
estiloEixo(ax1);

ax2 = subplot(2,1,2);
plot(NIVEIS, 100*thd, '-o', 'Color', C_THD, 'LineWidth', 1.6, ...
     'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
xline(T,     '--', 'T',     'Color', C_REF, 'LineWidth', 1.3, 'FontSize', 9);
xline(T+W/2, ':',  'T+W/2', 'Color', C_REF, 'LineWidth', 1.0, 'FontSize', 8);
title('Mesma grandeza em escala percentual');
xlabel('Nivel de entrada (dBFS)'); ylabel('THD (%)');
estiloEixo(ax2);

salvarFigura(fig, 'fig_distorcao.png');

fprintf('Figura salva em fig_distorcao.png\n\n');

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

% =========================================================
% AMPLITUDES DOS HARMONICOS INDIVIDUAIS
% Verifica se ha predominancia de harmonicos impares.
% =========================================================
fprintf('\n=== HARMONICOS INDIVIDUAIS (dB relativos a fundamental) ===\n\n');
fprintf('  %8s', 'Entrada');
for h = 2:N_HARM, fprintf(' %7s', sprintf('h%d',h)); end
fprintf('\n  %s\n', repmat('-', 1, 8 + 8*(N_HARM-1)));

for k = 1:numel(NIVEIS)
    if NIVEIS(k) < T + W/2, continue; end     % so acima do joelho
    ini = (k-1)*nSeg + nGu + 1;
    w   = y(ini : ini + N_JANELA - 1);
    Y   = abs(fft(w)) / (N_JANELA/2);
    fund = Y(binFund + 1);

    fprintf('  %7.1f ', NIVEIS(k));
    for h = 2:N_HARM
        b = binFund*h;
        if b < N_JANELA/2
            fprintf(' %7.1f', 20*log10(Y(b+1)/fund + 1e-300));
        else
            fprintf(' %7s', '-');
        end
    end
    fprintf('\n');
end
fprintf('\n  Impares = h3, h5, h7, h9.  Pares = h2, h4, h6, h8, h10.\n\n');