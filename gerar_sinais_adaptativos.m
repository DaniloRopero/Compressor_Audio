% =========================================================
% SINAIS DE ENSAIO DOS MODOS ADAPTATIVOS
%
% Gera os quatro sinais de validacao do Capitulo 9, um por
% modo. Cada sinal exercita a metrica que governa a lei de
% adaptacao correspondente, e so ela -- condicao necessaria
% para validar os modos em isolamento.
%
%   sinal_modo1_limiar.wav      patamares de nivel
%   sinal_modo2_crista.wav      quatro materiais de mesmo RMS
%   sinal_modo3_ataque.wav      rampas de inclinacao crescente
%   sinal_modo4_makeup.wav      degraus atraves do joelho
%
% Formato: 32 bits em ponto flutuante, 44.100 Hz, monofonico.
% O formato de ponto flutuante e obrigatorio pela mesma razao
% exposta no Capitulo 7: tanto o MATLAB quanto o framework
% recuperam os valores sem conversao de escala, o que elimina
% discrepancia atribuivel ao formato de arquivo.
%
% O script imprime, para cada modo, o VALOR PREVISTO da
% grandeza adaptada em regime. A previsao decorre das leis
% implementadas no AdaptiveController e das constantes nele
% fixadas; a comparacao entre previsto e medido e o que
% constitui a validacao, e nao a simples observacao de que o
% mecanismo reage.
%
% Gera tambem a figura de conferencia dos quatro envelopes.
%
% TCC -- Danilo Francisco Ropero Sivirino
% =========================================================

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

fs   = 44100;
BITS = 32;
f0   = 440;

% Constantes do AdaptiveController, replicadas aqui apenas
% para o calculo das previsoes impressas. Se alguma delas for
% alterada no codigo C++, altere-a tambem aqui.
TAU_STATS  = 0.400;    % s   -- janela da estatistica (Modo 1)
K_LIMIAR   = 1.0;      % desvios padrao             (Modo 1)
TAU_CRISTA = 0.200;    % s   -- janela unica da crista (Modo 2)
CRISTA_LO  = 3.0;      % dB                          (Modo 2)
CRISTA_HI  = 15.0;     % dB                          (Modo 2)
RAZAO_LO   = 2.0;                                  % (Modo 2)
RAZAO_HI   = 8.0;                                  % (Modo 2)
S_REF      = 10.0;     % dB/ms                       (Modo 3)
ATQ_MIN    = 0.5;      % ms                          (Modo 3)
ATQ_MAX    = 50.0;     % ms                          (Modo 3)
TAU_MAKEUP = 1.000;    % s   -- suavizacao de M       (Modo 4)
LIMIAR_PAD = -12.0;    % dBFS -- limiar manual
RAZAO_PAD  = 4.0;      % razao manual
JOELHO_PAD = 6.0;      % dB  -- largura do joelho

fprintf('\n=== GERACAO DOS SINAIS DE ENSAIO DOS MODOS ADAPTATIVOS ===\n');
fprintf('    (as previsoes dos Modos 2 e 4 exigem simulacao amostra a\n');
fprintf('     amostra; o script leva algumas dezenas de segundos)\n\n');

% =========================================================
% MODO 1 -- LIMIAR ADAPTATIVO
%
% Seis patamares cobrindo 36 dB. O limiar adaptativo segue
%
%     T[n] = mu[n] + k * sigma[n]
%
% em que mu e sigma sao a media e o desvio padrao do NIVEL DE
% CURTO PRAZO. Para senoide estacionaria o desvio padrao tende
% a zero em regime, de modo que o limiar previsto e o proprio
% nivel eficaz do patamar.
%
% A duracao de 4 s por patamar NAO e arbitraria. A estatistica
% e estimada em janela exponencial de 400 ms, e o desvio
% padrao, por depender do QUADRADO do afastamento, retem a
% memoria do degrau anterior por tempo consideravelmente maior
% que a media. Com 2 s por patamar sigma ainda vale cerca de
% 1,4 dB em regime -- residuo do degrau, nao propriedade do
% sinal -- e o limiar fica 1,5 dB acima do previsto. Com 4 s,
% isto e, dez constantes de tempo, sigma cai abaixo de 0,15 dB
% e o limiar converge para mu com erro inferior a 0,15 dB.
% =========================================================
NIVEIS_M1 = [-42 -30 -18 -12 -24 -36];   % dBFS de pico
DUR_M1    = 4.0;

x1 = [];
for k = 1:numel(NIVEIS_M1)
    a = 10^(NIVEIS_M1(k)/20);
    t = (0:round(DUR_M1*fs)-1)/fs;
    x1 = [x1, a*sin(2*pi*f0*t)];                              %#ok<AGROW>
end
x1 = x1(:);
audiowrite('sinal_modo1_limiar.wav', x1, fs, 'BitsPerSample', BITS);

fprintf('  Modo 1 -- limiar adaptativo\n');
fprintf('    habilitar APENAS o Modo 1\n');
fprintf('    patamares .... %s dBFS de pico\n', mat2str(NIVEIS_M1));
fprintf('    %-12s %-12s %-12s\n', 'patamar', 'RMS', 'T previsto');
for k = 1:numel(NIVEIS_M1)
    rmsDb = NIVEIS_M1(k) - 20*log10(sqrt(2));
    fprintf('    %7.1f dBFS %8.2f dB %9.2f dBFS\n', ...
            NIVEIS_M1(k), rmsDb, rmsDb);
end
fprintf('    criterio ..... erro inferior a 0,5 dB em regime\n');
fprintf('    duracao ...... %.1f s (%d amostras)\n\n', ...
        numel(x1)/fs, numel(x1));

% =========================================================
% MODO 2 -- RAZAO PELO FATOR DE CRISTA
%
% Quatro materiais de MESMO VALOR EFICAZ e fatores de crista
% crescentes. A igualdade de valor eficaz e deliberada: isola
% o fator de crista como unica variavel. Se a razao responder,
% respondeu a crista, e nao ao nivel.
%
% A versao anterior deste script empregava apenas dois
% materiais -- senoide e percussivo de decaimento curto. O
% arranjo verificava os extremos da lei, mas nao a lei: com
% crista de 16,7 dB, o trecho percussivo satura no limite
% superior da interpolacao e a razao resultante seria 8:1
% qualquer que fosse a inclinacao da reta. Os dois materiais
% intermediarios, obtidos por alongamento do decaimento dos
% golpes, situam-se dentro do intervalo de interpolacao e
% permitem contrapor a lei
%
%     R = R_lo + (CF - CF_lo)/(CF_hi - CF_lo) * (R_hi - R_lo)
%
% a quatro pares medidos, dos quais tres sobre a reta e um em
% saturacao.
%
% O VALOR EFICAZ DE -22 dBFS nao e arbitrario: com crista de
% 19 dB, o material de decaimento mais curto atinge pico de
% -2,9 dBFS, e qualquer nivel acima deste levaria o pico a
% ultrapassar o fundo de escala.
%
% O ENSAIO DO MODO 2 DEVE SER CONDUZIDO COM LIMIAR DE -25 dBFS,
% e nao com o limiar padrao de -12 dBFS. O trecho sustentado
% tem crista de apenas 3 dB e pico de -19 dBFS; sob o limiar
% padrao ele nao comprimiria, e a comparacao entre os quatro
% materiais deixaria de isolar o fator de crista.
% =========================================================
DUR_M2   = 4.0;
RMS_ALVO = 10^(-22/20);        % mesmo valor eficaz nos quatro trechos
PERIODO  = 0.25;               % s -- golpes a 4 Hz
TAUS_M2  = [0.060 0.020 0.010];   % s -- decaimento dos golpes

t2  = (0:round(DUR_M2*fs)-1)/fs;
PER = round(PERIODO*fs);

% sustentado: amplitude de pico = rms * sqrt(2)
sust = (RMS_ALVO*sqrt(2)) * sin(2*pi*f0*t2);

trechos  = {sust};
rotulos  = {'sustentado'};
for k = 1:numel(TAUS_M2)
    env = exp(-mod(0:numel(t2)-1, PER)/(TAUS_M2(k)*fs));
    p   = env .* sin(2*pi*220*t2);
    p   = p * (RMS_ALVO / valorEficaz(p));   % iguala o valor eficaz
    trechos{end+1} = p;                                       %#ok<AGROW>
    rotulos{end+1} = sprintf('percussivo %3.0f ms', TAUS_M2(k)*1000); %#ok<AGROW>
end

x2 = [trechos{1}, trechos{2}, trechos{3}, trechos{4}].';
audiowrite('sinal_modo2_crista.wav', x2, fs, 'BitsPerSample', BITS);

fprintf('  Modo 2 -- razao pelo fator de crista\n');
fprintf('    habilitar APENAS o Modo 2, COM LIMIAR DE -25 dBFS\n');
fprintf('    %-20s %-10s %-10s %-10s %-10s\n', ...
        'material', 'pico', 'RMS', 'CF prev.', 'R prev.');
for k = 1:numel(trechos)
    v   = trechos{k};
    cfe = cristaEstimada(v, fs, TAU_CRISTA);
    u   = min(max((cfe - CRISTA_LO)/(CRISTA_HI - CRISTA_LO), 0), 1);
    r   = RAZAO_LO + u*(RAZAO_HI - RAZAO_LO);
    fprintf('    %-20s %7.2f dB %7.2f dB %7.2f dB %7.2f:1\n', ...
            rotulos{k}, 20*log10(max(abs(v))), ...
            20*log10(valorEficaz(v)), cfe, r);
end
fprintf('    o ultimo material satura no limite superior da lei\n');
fprintf('    duracao ...... %.1f s\n\n', numel(x2)/fs);

% =========================================================
% MODO 3 -- ATAQUE PELA DERIVADA DO ENVELOPE
%
% Varredura parametrica da inclinacao do envelope. Quatro
% rampas logaritmicas de -60 a -6 dBFS, com inclinacoes
% espacadas por decada: 0,1 / 1 / 10 / 100 dB/ms.
%
% As rampas sao lineares EM DECIBEIS, e nao em amplitude. A
% distincao e essencial: uma rampa linear em amplitude
% concentra quase toda a excursao em decibeis nos primeiros
% instantes, de modo que sua inclinacao em dB/ms nao e
% constante nem controlavel. Sendo a lei de adaptacao do
% Modo 3 funcao justamente da derivada do envelope EM
% DECIBEIS, a rampa logaritmica torna a variavel independente
% do ensaio exatamente igual a grandeza que governa a lei.
%
% CADA RAMPA E PRECEDIDA DE PEDESTAL DE 0,6 s NO NIVEL INICIAL,
% e nao de silencio. A versao anterior deste script empregava
% silencio, e o arranjo invalidava o ensaio: a transicao de
% silencio absoluto para o primeiro ponto da rampa constitui
% degrau, cuja derivada nao depende da inclinacao da rampa que
% a sucede. O detector media, em todas as quatro, a subida do
% proprio degrau. O resultado era nao monotono -- a rampa de
% 0,1 dB/ms chegava a registrar inclinacao superior a de
% 100 dB/ms --, de modo que a varredura nao media o que se
% propunha a medir. Com o pedestal, o detector rapido acomoda-se
% no nivel inicial antes do inicio da rampa e passa a medir a
% inclinacao desta.
%
% A duracao de 0,6 s do pedestal corresponde a doze constantes
% de tempo do detector de pico rapido (50 ms); a sustentacao de
% 0,8 s ao fim de cada rampa, a dez constantes de tempo da
% liberacao da derivada retida (80 ms), de modo que cada rampa
% comece com o estimador zerado.
%
% O SINAL E PRECEDIDO DE ENTRADA DE AQUECIMENTO DE 1,2 s, no
% nivel inicial. O AdaptiveController mantem os parametros
% manuais durante o primeiro segundo de sinal -- intervalo
% fixado em Config::warmupMs --, pois antes disso os
% estimadores ainda nao acumularam historico e as leis
% produziriam valores sem significado. Sem a entrada de
% aquecimento a primeira rampa comecaria em 0,6 s, isto e,
% DENTRO desse intervalo, e o primeiro ponto da varredura se
% perderia: a adaptacao so entraria em vigor depois que a
% derivada ja houvesse decaido. Os demais modos dispensam a
% precaucao porque seu primeiro trecho dura 4 s ou mais.
% =========================================================
DUR_AQUEC  = 1.2;      % s de entrada de aquecimento (warmupMs = 1 s)
DUR_PED    = 0.6;      % s de pedestal no nivel inicial
DUR_SUST   = 0.8;      % s de sustentacao apos cada rampa
NIVEL_INI  = -60;      % dBFS no inicio da rampa
NIVEL_FIM  =  -6;      % dBFS ao fim da rampa
INCLINACOES = [0.1 1 10 100];   % dB/ms -- decadas

faixaDb = NIVEL_FIM - NIVEL_INI;

naq = round(DUR_AQUEC*fs);
taq = (0:naq-1).'/fs;
x3  = 10^(NIVEL_INI/20) * sin(2*pi*f0*taq);

for k = 1:numel(INCLINACOES)
    durSub = (faixaDb / INCLINACOES(k)) / 1000;    % s
    nsub   = max(round(durSub*fs), 1);
    nped   = round(DUR_PED*fs);
    nsus   = round(DUR_SUST*fs);

    rampaDb = linspace(NIVEL_INI, NIVEL_FIM, nsub).';
    envk    = [repmat(10^(NIVEL_INI/20), nped, 1); ...
               10.^(rampaDb/20); ...
               repmat(10^(NIVEL_FIM/20), nsus, 1)];

    tk = (0:numel(envk)-1).'/fs;
    x3 = [x3; envk .* sin(2*pi*f0*tk)];                       %#ok<AGROW>
end
audiowrite('sinal_modo3_ataque.wav', x3, fs, 'BitsPerSample', BITS);

fprintf('  Modo 3 -- ataque pela derivada do envelope\n');
fprintf('    habilitar APENAS o Modo 3\n');
fprintf('    rampas logaritmicas de %d a %d dBFS\n', NIVEL_INI, NIVEL_FIM);
fprintf('    entrada de aquecimento de %.1f s antes da primeira rampa\n', ...
        DUR_AQUEC);
fprintf('    %-14s %-12s %-12s %-14s\n', ...
        'inclinacao', 'inicio', 'duracao', 'tau_A previsto');
tIni = DUR_AQUEC;
for k = 1:numel(INCLINACOES)
    s      = INCLINACOES(k);
    durS   = (faixaDb / s) / 1000;
    tauA   = ATQ_MIN + (ATQ_MAX - ATQ_MIN)/(1 + s/S_REF);
    tRampa = tIni + DUR_PED;
    fprintf('    %7.1f dB/ms %8.3f s %9.1f ms %10.2f ms\n', ...
            s, tRampa, durS*1000, tauA);
    tIni = tRampa + durS + DUR_SUST;
end
fprintf('\n    RESSALVA: o estimador satura em cerca de 25 dB/ms, limite\n');
fprintf('    imposto pela suavizacao de 2 ms do nivel. A rampa de\n');
fprintf('    100 dB/ms sera medida como aproximadamente 24 dB/ms, e o\n');
fprintf('    tau_A resultante sera da ordem de 15 ms, e nao de 5 ms. O\n');
fprintf('    ensaio valida, portanto, a lei no intervalo de 0,1 a\n');
fprintf('    10 dB/ms; acima disso valida a saturacao, nao a lei.\n');
fprintf('    duracao ...... %.1f s\n\n', numel(x3)/fs);

% =========================================================
% MODO 4 -- COMPENSACAO AUTOMATICA DE GANHO
%
% Degraus de nivel atravessando o joelho. Com limiar de
% -12 dBFS, razao de 4:1 e joelho de 6 dB, a compensacao
% prevista e igual a REDUCAO DE GANHO EM REGIME, pois
%
%     M = 10*log10(P_in / P_out)  e  P_out = g^2 * P_in
%
% para ganho g constante, donde M = -20*log10(g).
%
% A versao anterior empregava degraus de -30 a -6 dBFS, dos
% quais um unico comprimia -- o ensaio verificava um ponto da
% lei. A escada atual produz cinco pontos: abaixo do joelho,
% dentro do joelho, na borda superior e duas vezes acima,
% cobrindo o intervalo util de M.
%
% A duracao de 5 s por degrau decorre da constante de tempo de
% 1 s da suavizacao de M: sao cinco constantes, 99,3 % da
% acomodacao. O transitorio observado em cada degrau e o dado
% que demonstra ausencia de oscilacao.
% =========================================================
NIVEIS_M4 = [-30 -13 -9 -6 -3];     % dBFS de pico
DUR_M4    = 5.0;

x4 = [];
for k = 1:numel(NIVEIS_M4)
    a = 10^(NIVEIS_M4(k)/20);
    t = (0:round(DUR_M4*fs)-1)/fs;
    x4 = [x4, a*sin(2*pi*f0*t)];                              %#ok<AGROW>
end
x4 = x4(:);
audiowrite('sinal_modo4_makeup.wav', x4, fs, 'BitsPerSample', BITS);

fprintf('  Modo 4 -- compensacao automatica de ganho\n');
fprintf('    habilitar APENAS o Modo 4, COM MAKEUP MANUAL DE 0 dB:\n');
fprintf('      CompressorOffline sinal_modo4_makeup.wav saida_modo4.wav \\\n');
fprintf('                        %.0f %.0f %.0f %.0f %.0f 0 --auto-makeup\n', ...
        LIMIAR_PAD, RAZAO_PAD, 10, 100, JOELHO_PAD);
fprintf('    O makeup manual NAO e indiferente aqui. Durante o\n');
fprintf('    aquecimento o controlador mantem M no valor manual, e ao\n');
fprintf('    assumir o controle M parte desse valor e decai com a\n');
fprintf('    constante de 1 s. Com o padrao de 6 dB, o primeiro degrau\n');
fprintf('    -- cuja previsao e zero -- ainda registraria 0,12 dB ao\n');
fprintf('    fim dos 5 s, residuo da condicao inicial e nao da lei.\n');
fprintf('    Com makeup manual de 0 dB nao ha o que decair.\n');
fprintf('    limiar %.0f dBFS, razao %.0f:1, joelho %.0f dB\n', ...
        LIMIAR_PAD, RAZAO_PAD, JOELHO_PAD);
fprintf('    %-12s %-16s %-14s\n', ...
        'degrau', 'curva estatica', 'M previsto');
for k = 1:numel(NIVEIS_M4)
    g  = reducaoEstatica(NIVEIS_M4(k), LIMIAR_PAD, RAZAO_PAD, JOELHO_PAD);
    Mp = previsaoMakeup(NIVEIS_M4(k), f0, fs, ...
                        LIMIAR_PAD, RAZAO_PAD, JOELHO_PAD);
    fprintf('    %7.1f dBFS %11.2f dB %12.2f dB\n', NIVEIS_M4(k), -g, Mp);
end
fprintf('\n    As duas colunas NAO coincidem, e a diferenca e esperada. A\n');
fprintf('    curva estatica preve a reducao para nivel de entrada\n');
fprintf('    constante; sob excitacao senoidal o detector de valor\n');
fprintf('    absoluto instantaneo produz reducao sistematicamente menor,\n');
fprintf('    pelo mesmo mecanismo quantificado na secao 8.8.4. A segunda\n');
fprintf('    coluna resulta de simulacao do nucleo sobre o proprio sinal\n');
fprintf('    de ensaio e e a previsao a ser confrontada com a medida.\n');
fprintf('    criterio ..... M coincide com a reducao de ganho em regime\n');
fprintf('    duracao ...... %.1f s\n\n', numel(x4)/fs);

% =========================================================
% FIGURA DE CONFERENCIA
% =========================================================
sinais = {x1, x2, x3, x4};
titulos = {'Modo 1 - patamares de nivel', ...
           'Modo 2 - quatro materiais de mesmo valor eficaz', ...
           'Modo 3 - rampas de 0,1 a 100 dB/ms com pedestal', ...
           'Modo 4 - degraus atraves do joelho'};

fig = figure('Color','w','Position',[100 100 900 760]);
for k = 1:4
    ax = subplot(4,1,k);
    v  = sinais{k};
    t  = (0:numel(v)-1)/fs;
    plot(ax, t, v, 'Color',[0.15 0.15 0.15], 'LineWidth',0.5);
    xlim(ax, [0 t(end)]);
    ylim(ax, [-1.05 1.05]);
    title(ax, titulos{k});
    ylabel(ax, 'Amplitude');
    if k == 4, xlabel(ax, 'Tempo (s)'); end
    estiloEixo(ax);
end
exportgraphics(fig, 'fig_sinais_adaptativos.png', 'Resolution', 200);

fprintf('  Figura de conferencia: fig_sinais_adaptativos.png\n');
fprintf('\n  PROXIMO PASSO\n');
fprintf('    Processe cada arquivo com o CompressorOffline, habilitando\n');
fprintf('    APENAS o modo correspondente, e analise o CSV resultante.\n');
fprintf('    Opcoes: --adapt-threshold, --adapt-ratio, --adapt-attack,\n');
fprintf('    --auto-makeup e --adapt-all (ver o README do repositorio).\n');
fprintf('    Compare os valores medidos com as previsoes impressas acima.\n\n');

% =========================================================
% FUNCOES AUXILIARES
%
% Evitam dependencia do Signal Processing Toolbox, que fornece
% rms() e pode nao estar instalado.
% =========================================================
function r = valorEficaz(v)
    r = sqrt(mean(v(:).^2));
end

% Reproduz o estimador de fator de crista do AdaptiveController:
% pico e valor eficaz estimados sobre o QUADRADO do sinal, ambos
% com a MESMA constante de tempo, conforme Giannoulis, Massberg
% e Reiss (2013). Devolve a media sobre o ultimo quarto do
% trecho, ja em regime.
function cfDb = cristaEstimada(v, fs, tau)
    v = v(:);
    a = exp(-1/(tau*fs));
    picoQ = 0; rmsQ = 0;
    cf = zeros(numel(v),1);
    for n = 1:numel(v)
        dQ    = v(n)^2;
        rmsQ  = a*rmsQ + (1-a)*dQ;
        decai = a*picoQ + (1-a)*dQ;
        picoQ = max(dQ, decai);
        if rmsQ > 0
            cf(n) = 10*log10(picoQ/rmsQ);
        end
    end
    cfDb = mean(cf(round(0.75*numel(v)):end));
end

% Reducao de ganho em regime da curva estatica com joelho
% quadratico, em dB (valor negativo). Reproduz o computador de
% ganho do CompressorCore.
function g = reducaoEstatica(xDb, T, R, W)
    if xDb - T < -W/2
        g = 0;
    elseif abs(xDb - T) <= W/2
        g = (1/R - 1) * (xDb - T + W/2)^2 / (2*W);
    else
        g = (1/R - 1) * (xDb - T);
    end
end

% Previsao de M por simulacao do nucleo sobre senoide estacionaria
% no nivel de pico indicado. Reproduz o computador de ganho, a
% suavizacao de ataque e liberacao e os dois estimadores de
% potencia do Modo 4, com a potencia de saida medida ANTES da
% aplicacao de M -- condicao que torna a malha aberta.
function Mdb = previsaoMakeup(nivelDb, f0, fs, T, R, W)
    DUR  = 5.0;
    aA   = exp(-1/(fs*0.010));      % attackMs  padrao
    aR   = exp(-1/(fs*0.100));      % releaseMs padrao
    aP   = exp(-1/(fs*0.500));      % powerTauMs
    aM   = exp(-1/(fs*1.000));      % makeupTauMs
    invR = 1/R;  halfW = W/2;

    t = (0:round(DUR*fs)-1)/fs;
    x = 10^(nivelDb/20) * sin(2*pi*f0*t);

    yL = 0; Pin = 0; Pout = 0; Msm = 0;
    for n = 1:numel(x)
        xG = 20*log10(abs(x(n)) + 1e-9);
        if W > 0 && 2*abs(xG - T) <= W
            d  = xG - T + halfW;
            cG = xG + (invR - 1)*d*d/(2*W);
        elseif xG > T + halfW
            cG = T + (xG - T)*invR;
        else
            cG = xG;
        end
        g = cG - xG;
        if g < yL
            yL = aA*yL + (1-aA)*g;
        else
            yL = aR*yL + (1-aR)*g;
        end
        o    = 10^(yL/20) * x(n);
        Pin  = aP*Pin  + (1-aP)*x(n)^2;
        Pout = aP*Pout + (1-aP)*o^2;
        if Pout > 0
            Mi = min(max(10*log10(Pin/Pout), 0), 24);
        else
            Mi = 0;
        end
        Msm = aM*Msm + (1-aM)*Mi;
    end
    Mdb = Msm;
end

function estiloEixo(ax)
    set(ax, 'Color','w','XColor','k','YColor','k', ...
            'GridColor',[0.20 0.20 0.20],'GridAlpha',0.28, ...
            'FontSize',10,'LineWidth',1.0,'Box','on', ...
            'TickDir','out','XGrid','on','YGrid','on');
    set(ax.Title,'Color','k','FontSize',11,'FontWeight','bold');
    set(ax.XLabel,'Color','k','FontSize',10);
    set(ax.YLabel,'Color','k','FontSize',10);
    lg = get(ax,'Legend');
    if ~isempty(lg)
        set(lg,'TextColor','k','Color','w', ...
               'EdgeColor',[0.20 0.20 0.20],'FontSize',9,'Box','on');
    end
    try, ax.Toolbar = []; catch, end
    try, disableDefaultInteractivity(ax); catch, end
end
