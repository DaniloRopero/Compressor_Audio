% =========================================================
% GERACAO DOS SINAIS DE ENSAIO DA CURVA ESTATICA
%
% Produz dois sinais em escada, com niveis de -60 a 0 dBFS
% em degraus de 2,5 dB e 300 ms por patamar:
%
%   curva_quadrada.wav  — onda quadrada de 100 Hz
%       O valor absoluto do sinal e constante dentro de cada
%       patamar, de modo que a entrada do computador de ganho
%       e exatamente o nivel nominal. E a condicao sob a qual
%       a curva estatica esta definida.
%
%   curva_senoide.wav   — senoide de 1 kHz
%       O valor absoluto oscila, de modo que o detector
%       instantaneo produz tensao de controle pulsante. Serve
%       para quantificar o desvio introduzido por essa condicao
%       e para a medida de distorcao harmonica.
%
% A frequencia de 1 kHz e a janela de analise de 8820 amostras
% contem exatamente 200 ciclos, o que elimina vazamento
% espectral na medida de distorcao sem necessidade de
% janelamento.
%
% Gera: curva_quadrada.wav, curva_senoide.wav
% =========================================================

clear; clc;
cd(fileparts(mfilename('fullpath')));

fs      = 44100;
NIVEIS  = -60 : 2.5 : 0;     % dBFS
T_SEG   = 0.300;             % s por patamar
F_QUAD  = 100;               % Hz
F_SEN   = 1000;              % Hz

nSeg = round(T_SEG * fs);
t    = (0:nSeg-1) / fs;

baseQuad = sign(sin(2*pi*F_QUAD*t));
baseQuad(baseQuad == 0) = 1;
baseSen  = sin(2*pi*F_SEN*t);

xQuad = zeros(1, nSeg*numel(NIVEIS));
xSen  = zeros(1, nSeg*numel(NIVEIS));

for k = 1:numel(NIVEIS)
    A = 10^(NIVEIS(k)/20);
    idx = (k-1)*nSeg + (1:nSeg);
    xQuad(idx) = A * baseQuad;
    xSen(idx)  = A * baseSen;
end

audiowrite('curva_quadrada.wav', xQuad(:), fs, 'BitsPerSample', 32);
audiowrite('curva_senoide.wav',  xSen(:),  fs, 'BitsPerSample', 32);

fprintf('\n=== SINAIS DE ENSAIO GERADOS ===\n');
fprintf('  taxa de amostragem ... %d Hz\n', fs);
fprintf('  patamares ............ %d  (de %.1f a %.1f dBFS, passo %.1f dB)\n', ...
        numel(NIVEIS), NIVEIS(1), NIVEIS(end), NIVEIS(2)-NIVEIS(1));
fprintf('  duracao por patamar .. %.0f ms  (%d amostras)\n', T_SEG*1000, nSeg);
fprintf('  duracao total ........ %.3f s  (%d amostras)\n', ...
        numel(xQuad)/fs, numel(xQuad));
fprintf('\n  curva_quadrada.wav ... onda quadrada de %d Hz\n', F_QUAD);
fprintf('  curva_senoide.wav .... senoide de %d Hz\n\n', F_SEN);

fprintf('  Proximo passo: processar ambos pelo CompressorOffline\n');
fprintf('    CompressorOffline.exe curva_quadrada.wav curva_quadrada.csv\n');
fprintf('    CompressorOffline.exe curva_senoide.wav  curva_senoide.csv\n\n');
