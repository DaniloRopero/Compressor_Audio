
%  BLOCO BASE — COMPRESSOR DIGITAL (MODO MANUAL)
%  Este bloco está embutido no topo de cada script de
%  gráfico.
%  Para alterar parâmetros editar a SEÇÃO 3.
clear; clc; close all;

% ---------------------------------------------------------
%  SEÇÃO 1 — PARÂMETROS DE TEMPO E AMOSTRAGEM
% ---------------------------------------------------------
fs  = 44100;
dur = 3.0;
N   = round(dur * fs);
t   = (0:N-1) / fs;

% ---------------------------------------------------------
%  SEÇÃO 2 — SINAL DE TESTE
% ---------------------------------------------------------
n1 = round(N / 3);
n2 = round(2 * N / 3);
x  = zeros(1, N);
x(1    : n1) = 0.10 * sin(2*pi * 440 * t(1    : n1));
x(n1+1 : n2) = 0.80 * sin(2*pi * 440 * t(n1+1 : n2));
x(n2+1 : N)  = 0.30 * sin(2*pi * 220 * t(n2+1 : N));

% ---------------------------------------------------------
%  SEÇÃO 3 — PARÂMETROS DO COMPRESSOR
% ---------------------------------------------------------
T  = -12;
R  =  4;
tA =  10;
tR =  100;
W  =  6;
M  =  6;

% ---------------------------------------------------------
%  SEÇÃO 4 — COEFICIENTES IIR
%  Eq.(6), Cap.4: alpha = exp(-1 / (tau * fs))
% ---------------------------------------------------------
alphaA = exp(-1 / (fs * tA / 1000));
alphaR = exp(-1 / (fs * tR / 1000));

% ---------------------------------------------------------
%  SEÇÃO 5 — LOOP DE COMPRESSÃO AMOSTRA A AMOSTRA
% ---------------------------------------------------------
y       = zeros(1, N);
gainVec = zeros(1, N);
yL      = 0;

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

    y(n)       = x(n) * 10^((yL + M) / 20);
    gainVec(n) = yL;
end

% ---------------------------------------------------------
%  SEÇÃO 6 — CONVERSÕES E MÉTRICAS
% ---------------------------------------------------------
xdB    = 20 * log10(abs(x) + 1e-9);
ydB    = 20 * log10(abs(y) + 1e-9);
DR_in  = 20*log10(max(abs(x)) / (sqrt(mean(x.^2)) + 1e-9));
DR_out = 20*log10(max(abs(y)) / (sqrt(mean(y.^2)) + 1e-9));
DR_red = DR_in - DR_out;
RMS_in  = 20*log10(sqrt(mean(x.^2)) + 1e-9);
RMS_out = 20*log10(sqrt(mean(y.^2)) + 1e-9);
GR_med  = mean(gainVec);
GR_min  = min(gainVec);

fprintf('BLOCO BASE carregado\n');
fprintf('  T=%+d  R=%d:1  tA=%d  tR=%d  W=%d  M=%d\n', T,R,tA,tR,W,M);
fprintf('  alphaA=%.6f  alphaR=%.6f\n', alphaA, alphaR);
fprintf('  DR entrada=%.2f dB  |  DR saida=%.2f dB  |  reducao=%.2f dB\n',...
        DR_in, DR_out, DR_red);
