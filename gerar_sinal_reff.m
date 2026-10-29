% =========================================================
% SINAL DE ENSAIO DA RAZAO DE COMPRESSAO EFETIVA
%
% Gera o sinal senoidal modulado em amplitude descrito por
% Giannoulis, Massberg e Reiss (2012), Equacao (24):
%
%     x[n] = A (1 + m cos(2*pi*fm*n)) cos(2*pi*fc*n)
%
% O espectro resultante tem uma portadora em fc e duas bandas
% laterais em fc +/- fm. O indice de modulacao recupera-se das
% bandas por  m = 2*|banda| / |portadora|.
%
% Comprimindo o sinal, a modulacao diminui. A razao entre o
% indice de entrada e o de saida define a RAZAO DE COMPRESSAO
% EFETIVA:
%
%     R_eff = m_entrada / m_saida
%
% Varrendo fm, obtem-se a curva R_eff(fm), que caracteriza o
% comportamento DINAMICO do compressor -- algo que a curva
% estatica, por definicao, nao mede.
%
% PARAMETROS DO SINAL
%   portadora .......... 1 kHz
%   amplitude .......... 0,60
%   indice de modulacao  0,25
%
% Com esses valores a envoltoria oscila entre -2,5 e -6,9 dBFS,
% inteiramente acima do joelho (que termina em -9 dBFS). A
% escolha e deliberada: mantem o sinal na Regiao C durante todo
% o ensaio, de modo que a razao medida seja comparavel a razao
% configurada, sem contaminacao pela interpolacao do joelho.
%
% ESTRUTURA TEMPORAL
%   12 trechos de 4,5 s, um por frequencia de modulacao
%   1,5 s de guarda descartados + 3,0 s de analise
%
% A janela de 3,0 s contem numero INTEIRO de ciclos de todas as
% frequencias de modulacao empregadas e tambem da portadora
% (3.000 ciclos). Vale aqui o mesmo argumento de amostragem
% coerente usado no ensaio de distorcao harmonica: sem ciclos
% inteiros haveria vazamento espectral, e as bandas laterais
% seriam medidas com erro.
%
% CONDICAO DE ENSAIO -- IMPORTANTE
%   Rode o CompressorOffline com GANHO DE COMPENSACAO M = 0 dB.
%
%   Justificativa: M e um ganho constante e nao altera a razao
%   entre banda lateral e portadora, de modo que nao afeta a
%   medida. Mantido em +6 dB, porem, o pico da saida alcanca
%   +3,5 dBFS e ultrapassa o fundo de escala -- o mesmo efeito
%   analisado no capitulo de validacao. Zerando M, o pico fica
%   em -2,5 dBFS e o arquivo de saida permanece dentro da faixa.
%
%   Vale aqui a mesma doutrina adotada nos demais ensaios: a
%   condicao de medida deve ser declarada, e nao suposta.
%
% Gera: sinal_reff.wav   (32 bits em ponto flutuante)
%
% TCC -- Danilo Francisco Ropero Sivirino
% =========================================================

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

fs      = 44100;
F_PORT  = 1000;      % Hz  -- portadora
AMP     = 0.60;      % amplitude da portadora
M_IDX   = 0.25;      % indice de modulacao
T_GUARD = 1.5;       % s   -- descartado
T_ANAL  = 3.0;       % s   -- analisado
BITS    = 32;

FM = [1 2 4 6 8 12 16 20 24 28 32 36];   % Hz

T_SEG = T_GUARD + T_ANAL;
nSeg  = round(T_SEG*fs);

fprintf('\n=== SINAL DE ENSAIO DA RAZAO EFETIVA ===\n\n');
fprintf('  portadora .............. %d Hz\n', F_PORT);
fprintf('  amplitude .............. %.2f\n', AMP);
fprintf('  indice de modulacao .... %.2f\n', M_IDX);
fprintf('  nivel de pico .......... %.2f dBFS\n', 20*log10(AMP*(1+M_IDX)));
fprintf('  nivel de vale .......... %.2f dBFS\n', 20*log10(AMP*(1-M_IDX)));
fprintf('  (ambos acima do joelho, que termina em -9 dBFS)\n\n');

% --- conferencia de ciclos inteiros na janela de analise -----
nAnal = round(T_ANAL*fs);
fprintf('  Conferencia de amostragem coerente na janela de %.1f s:\n', T_ANAL);
fprintf('    portadora .......... %.0f ciclos\n', F_PORT*T_ANAL);
ok = true;
for fm = FM
    c = fm*T_ANAL;
    if abs(c - round(c)) > 1e-9
        fprintf('    fm = %2d Hz ......... %.3f ciclos  <-- NAO INTEIRO\n', fm, c);
        ok = false;
    end
end
if ok
    fprintf('    todas as fm ........ numero inteiro de ciclos  [OK]\n\n');
else
    error('Alguma fm nao completa ciclos inteiros na janela.');
end

% --- montagem -----------------------------------------------
x = [];
for k = 1:numel(FM)
    n   = (0:nSeg-1).';
    env = 1 + M_IDX*cos(2*pi*FM(k)*n/fs);
    seg = AMP * env .* cos(2*pi*F_PORT*n/fs);
    x   = [x; seg];                                           %#ok<AGROW>
end

audiowrite('sinal_reff.wav', x, fs, 'BitsPerSample', BITS);

fprintf('  Trechos ................ %d\n', numel(FM));
fprintf('  fm (Hz) ................ %s\n', mat2str(FM));
fprintf('  Duracao total .......... %.1f s (%d amostras)\n', ...
        numel(x)/fs, numel(x));
fprintf('  Pico do arquivo ........ %.3f (%.2f dBFS)\n\n', ...
        max(abs(x)), 20*log10(max(abs(x))));

fprintf('  PROXIMO PASSO\n');
fprintf('    CompressorOffline.exe sinal_reff.wav saida_reff.wav\n');
fprintf('    >>> com M = 0 dB <<<  (ver nota no cabecalho do script)\n');
fprintf('    e depois rode  ratio_efetiva.m\n\n');
fprintf('  ATENCAO: o CSV gerado junto tera cerca de 2,4 milhoes de\n');
fprintf('  linhas. A analise le o WAV, nao o CSV -- pode apagar o CSV\n');
fprintf('  depois, se incomodar no espaco em disco.\n\n');
