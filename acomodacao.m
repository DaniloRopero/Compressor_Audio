% =========================================================
% ACOMODACAO DO ENVELOPE DE GANHO
%
% Extrai do envelope registrado pelo CompressorOffline a
% evolucao do ganho apos a transicao de nivel em t = 1 s.
%
% O ensaio responde a uma pergunta especifica: decorridas
% cinco constantes de tempo de ataque, o envelope ja alcancou
% o regime permanente?
%
% A resposta e negativa, e a razao esta no detector ramificado.
% Sob excitacao senoidal o valor absoluto do sinal cai abaixo
% do limiar durante parte de cada semiciclo; nesses intervalos
% o ramo de LIBERACAO atua, puxando o envelope de volta. A
% convergencia resulta da alternancia entre os dois ramos, e e
% governada por uma combinacao de tau_A e tau_R.
%
% Requer, na mesma pasta:
%   saida.csv   (CompressorOffline sobre sinal_teste.wav)
%
% Preenche a tabela "Evolucao do envelope de ganho apos a
% transicao" do capitulo de resultados.
% =========================================================

clear; clc;
cd(fileparts(mfilename('fullpath')));

fs      = 44100;
T_TRANS = 1.000;    % s  — instante da transicao de nivel
tA      = 10;       % ms — constante de tempo de ataque

INSTANTES = [50 100 200 950];   % ms apos a transicao

if ~isfile('saida.csv')
    error(['saida.csv nao encontrado.\n' ...
           'Rode: CompressorOffline.exe sinal_teste.wav saida.wav']);
end

D = readmatrix('saida.csv', 'NumHeaderLines', 1);
g = D(:, end).';          % ultima coluna: envelope de ganho em dB

n0 = round(T_TRANS*fs);

% regime permanente: media sobre o ultimo terco do trecho
iniRegime = n0 + round(0.80*fs);
fimRegime = n0 + round(0.98*fs);
regime    = mean(g(iniRegime:fimRegime));

fprintf('\n=== ACOMODACAO DO ENVELOPE APOS A TRANSICAO ===\n');
fprintf('  Transicao em t = %.3f s\n', T_TRANS);
fprintf('  Constante de tempo de ataque: %g ms\n\n', tA);

fprintf('  %14s %14s %12s %12s\n', ...
        'Tempo decorrido', 'Em tau_A', 'Envelope', 'Do regime');
fprintf('  %s\n', repmat('-', 1, 56));

for k = 1:numel(INSTANTES)
    ms  = INSTANTES(k);
    idx = n0 + round(ms/1000*fs);
    val = g(idx);
    pct = 100 * val / regime;
    fprintf('  %11.0f ms %13.0f %10.3f dB %10.1f %%\n', ...
            ms, ms/tA, val, pct);
end

fprintf('\n  Regime permanente ....... %.3f dB\n', regime);

idx5 = n0 + round(5*tA/1000*fs);
falta = regime - g(idx5);
fprintf('  Falta em 5 tau_A ........ %.3f dB  (%.1f %% do total)\n', ...
        falta, 100*falta/regime);

% instante em que o envelope atinge 99 % do regime
alvo = 0.99 * regime;
idx99 = find(g(n0:end) <= alvo, 1);
if ~isempty(idx99)
    fprintf('  Atinge 99 %% do regime em  %.0f ms  (%.0f tau_A)\n', ...
            idx99/fs*1000, idx99/fs*1000/tA);
end

fprintf(['\n  Um filtro de primeira ordem isolado atingiria 99,3 %% do valor\n' ...
         '  final em cinco constantes de tempo. A acomodacao observada e\n' ...
         '  mais lenta porque, sob excitacao senoidal, o detector alterna\n' ...
         '  entre os ramos de ataque e de liberacao: nos intervalos em que\n' ...
         '  |x[n]| cai abaixo do limiar, o ramo de liberacao atua e puxa o\n' ...
         '  envelope de volta. A dinamica efetiva e, portanto, governada por\n' ...
         '  uma combinacao de tau_A e tau_R, e nao por tau_A isoladamente.\n\n']);
