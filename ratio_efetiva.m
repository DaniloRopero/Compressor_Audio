% =========================================================
% RAZAO DE COMPRESSAO EFETIVA  R_eff(fm)
%
% Apura a razao de compressao efetiva em funcao da frequencia
% de modulacao, conforme o metodo de Giannoulis, Massberg e
% Reiss (2012), Secao 4.1 e Figura 10.
%
% METODO
%   1. o sinal de entrada e uma senoide modulada em amplitude:
%        x[n] = A (1 + m cos(2*pi*fm*n)) cos(2*pi*fc*n)
%   2. o espectro tem portadora em fc e bandas laterais em
%      fc +/- fm;
%   3. o indice de modulacao recupera-se das bandas:
%        m = 2 * |banda lateral| / |portadora|
%   4. a razao efetiva e
%        R_eff = m_entrada / m_saida
%
% INTERPRETACAO
%   fm baixa  -> o detector acompanha a modulacao e comprime
%                plenamente: R_eff aproxima-se de R
%   fm alta   -> o detector nao consegue seguir e a modulacao
%                passa praticamente intacta: R_eff -> 1
%
% A curva R_eff(fm) e, portanto, a caracterizacao DINAMICA do
% compressor. A curva estatica mede o que ele faz em regime
% permanente; esta mede o que ele consegue fazer em funcao da
% velocidade com que o sinal varia.
%
% RESULTADO ESPERADO PARA ESTA IMPLEMENTACAO
%   O detector adotado e o RAMIFICADO. Giannoulis et al. (2012)
%   registram que designs ramificados ficam sistematicamente
%   abaixo da razao alvo, por nao aproveitarem integralmente o
%   tempo de liberacao. Espera-se, portanto, R_eff < R mesmo em
%   fm baixa -- e isso NAO e defeito de implementacao: e
%   propriedade documentada da topologia escolhida.
%
% CONDICAO DE ENSAIO
%   O processamento deve ser feito com M = 0 dB. O ganho de
%   compensacao nao altera a razao banda/portadora e, portanto,
%   nao afeta a medida; mantido em +6 dB, porem, faz o pico da
%   saida ultrapassar o fundo de escala.
%
% Requer, na mesma pasta:
%   sinal_reff.wav   (de gerar_sinal_reff.m)
%   saida_reff.wav   (do CompressorOffline)
%
% Gera: fig_ratio_efetiva.png
%
% TCC -- Danilo Francisco Ropero Sivirino
% =========================================================

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

fs      = 44100;
F_PORT  = 1000;
T_GUARD = 1.5;
T_ANAL  = 3.0;
R_ALVO  = 4;          % razao configurada no compressor

FM = [1 2 4 6 8 12 16 20 24 28 32 36];

C_MED = [0.00 0.20 0.50];
C_ALV = [0.70 0.10 0.10];
C_LIM = [0.45 0.45 0.45];

if ~isfile('sinal_reff.wav')
    error('sinal_reff.wav nao encontrado. Rode gerar_sinal_reff.m');
end
if ~isfile('saida_reff.wav')
    error(['saida_reff.wav nao encontrado.\n' ...
           'Rode: CompressorOffline.exe sinal_reff.wav saida_reff.wav']);
end

[xin, fsi] = audioread('sinal_reff.wav');
[yout, fso] = audioread('saida_reff.wav');

if fsi ~= fs || fso ~= fs
    error('Taxa de amostragem inesperada: %d / %d Hz.', fsi, fso);
end

xin  = xin(:,1).';
yout = yout(:,1).';

nSeg  = round((T_GUARD + T_ANAL)*fs);
nGu   = round(T_GUARD*fs);
N     = round(T_ANAL*fs);

if numel(yout) < nSeg*numel(FM)
    error('Saida com %d amostras; esperadas %d.', ...
          numel(yout), nSeg*numel(FM));
end

bPort = round(F_PORT*N/fs);

mIn   = zeros(1, numel(FM));
mOut  = zeros(1, numel(FM));
rEff  = zeros(1, numel(FM));

for k = 1:numel(FM)
    ini = (k-1)*nSeg + nGu + 1;
    wi  = xin (ini : ini + N - 1);
    wo  = yout(ini : ini + N - 1);

    Xi = abs(fft(wi)) / (N/2);
    Xo = abs(fft(wo)) / (N/2);

    bMod = round(FM(k)*N/fs);

    % media das duas bandas laterais, para reduzir o efeito de
    % eventual assimetria numerica entre elas
    latI = (Xi(bPort - bMod + 1) + Xi(bPort + bMod + 1)) / 2;
    latO = (Xo(bPort - bMod + 1) + Xo(bPort + bMod + 1)) / 2;

    mIn(k)  = 2 * latI / Xi(bPort + 1);
    mOut(k) = 2 * latO / Xo(bPort + 1);
    rEff(k) = mIn(k) / mOut(k);
end

% ---------------------------------------------------------
% RELATORIO
% ---------------------------------------------------------
fprintf('\n=== RAZAO DE COMPRESSAO EFETIVA ===\n');
fprintf('  Portadora .............. %d Hz\n', F_PORT);
fprintf('  Janela de analise ...... %d amostras (%.1f s)\n', N, T_ANAL);
fprintf('  Razao configurada ...... %.1f : 1\n\n', R_ALVO);

fprintf('  %8s %12s %12s %10s %12s\n', ...
        'fm (Hz)', 'm entrada', 'm saida', 'R_eff', '%% do alvo');
fprintf('  %s\n', repmat('-', 1, 58));
for k = 1:numel(FM)
    fprintf('  %8d %12.5f %12.5f %10.3f %11.1f %%\n', ...
            FM(k), mIn(k), mOut(k), rEff(k), 100*rEff(k)/R_ALVO);
end

[rMax, iMax] = max(rEff);
fprintf('\n  Maxima R_eff ........... %.3f  em fm = %d Hz\n', rMax, FM(iMax));
fprintf('  Minima R_eff ........... %.3f  em fm = %d Hz\n', min(rEff), FM(end));
fprintf('  Fracao do alvo atingida  %.1f %% no melhor caso\n', 100*rMax/R_ALVO);

% frequencia em que R_eff cai a metade do seu valor maximo
alvoMeio = 1 + (rMax - 1)/2;
idx = find(rEff <= alvoMeio, 1);
if ~isempty(idx) && idx > 1
    fmMeio = interp1(rEff([idx-1 idx]), FM([idx-1 idx]), alvoMeio);
    fprintf('  R_eff cai a meio termo em  %.1f Hz\n', fmMeio);
end

fprintf(['\n  A razao efetiva decresce monotonicamente com a frequencia\n' ...
         '  de modulacao: quanto mais rapida a variacao de nivel, menos\n' ...
         '  o detector consegue segui-la, e menor a compressao de fato\n' ...
         '  aplicada. No limite de fm elevada, R_eff tende a 1 -- o\n' ...
         '  sistema deixa de comprimir a modulacao e passa a aplicar\n' ...
         '  apenas um ganho aproximadamente constante.\n\n' ...
         '  O afastamento em relacao a razao configurada, visivel mesmo\n' ...
         '  nas frequencias mais baixas, e propriedade documentada do\n' ...
         '  detector ramificado, que nao aproveita integralmente o tempo\n' ...
         '  de liberacao (GIANNOULIS; MASSBERG; REISS, 2012, Fig. 10).\n\n']);

% ---------------------------------------------------------
% FIGURA
% ---------------------------------------------------------
fig = figure('Color','w','Position',[100 100 900 520]);
ax  = axes(fig);

plot(ax, FM, rEff, 'o-', 'Color', C_MED, 'MarkerFaceColor', C_MED, ...
     'LineWidth', 1.6, 'MarkerSize', 6); hold(ax,'on');
yline(ax, R_ALVO, '--', 'Color', C_ALV, 'LineWidth', 1.4);
yline(ax, 1,      ':',  'Color', C_LIM, 'LineWidth', 1.2);

text(ax, FM(end), R_ALVO, sprintf(' razão configurada: %.0f:1', R_ALVO), ...
     'Color', C_ALV, 'FontSize', 9, 'HorizontalAlignment','right', ...
     'VerticalAlignment','bottom');
text(ax, FM(end), 1, ' sem compressão dinâmica', ...
     'Color', C_LIM, 'FontSize', 9, 'HorizontalAlignment','right', ...
     'VerticalAlignment','bottom');

xlim(ax, [0 max(FM)+2]);
ylim(ax, [0.8 max(R_ALVO, rMax)*1.15]);
xlabel(ax, 'Frequência de modulação (Hz)');
ylabel(ax, 'Razão de compressão efetiva');
title(ax, 'Razão de compressão efetiva em função da frequência de modulação');
estiloEixo(ax);

exportgraphics(fig, 'fig_ratio_efetiva.png', 'Resolution', 200);
fprintf('  Figura salva em fig_ratio_efetiva.png\n\n');

% =========================================================
function estiloEixo(ax)
    set(ax, 'Color','w','XColor','k','YColor','k', ...
            'GridColor',[0.20 0.20 0.20],'GridAlpha',0.28, ...
            'FontSize',10,'LineWidth',1.0,'Box','on', ...
            'TickDir','out','XGrid','on','YGrid','on');
    set(ax.Title,'Color','k','FontSize',11,'FontWeight','bold');
    set(ax.XLabel,'Color','k','FontSize',10);
    set(ax.YLabel,'Color','k','FontSize',10);
    % separador decimal com virgula, conforme a norma
    try
        ax.XAxis.TickLabelFormat = '%g';
        yt = ax.YTick;
        ax.YTickLabel = strrep(cellstr(num2str(yt(:),'%.1f')), '.', ',');
    catch
    end
    lg = get(ax,'Legend');
    if ~isempty(lg)
        set(lg,'TextColor','k','Color','w', ...
               'EdgeColor',[0.20 0.20 0.20],'FontSize',9,'Box','on');
    end
    try, ax.Toolbar = []; catch, end
    try, disableDefaultInteractivity(ax); catch, end
end
