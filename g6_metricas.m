%  G6 — PAINEL DE MÉTRICAS DE VALIDAÇÃO

% ---- BLOCO BASE ----
clear; clc; close all;
fs=44100; dur=3.0; N=round(dur*fs); t=(0:N-1)/fs;
n1=round(N/3); n2=round(2*N/3); x=zeros(1,N);
x(1:n1)    = 0.10*sin(2*pi*440*t(1:n1));
x(n1+1:n2) = 0.80*sin(2*pi*440*t(n1+1:n2));
x(n2+1:N)  = 0.30*sin(2*pi*220*t(n2+1:N));
T=-12; R=4; tA=10; tR=100; W=6; M=6;
alphaA=exp(-1/(fs*tA/1000)); alphaR=exp(-1/(fs*tR/1000));
y=zeros(1,N); gainVec=zeros(1,N); yL=0;
for n=1:N
    xG=20*log10(abs(x(n))+1e-9);
    if W>0&&(2*abs(xG-T)<=W); cG=xG+(1/R-1)*(xG-T+W/2)^2/(2*W);
    elseif xG>T+W/2;           cG=T+(xG-T)/R;
    else;                       cG=xG; end
    gainDB=cG-xG;
    if gainDB<yL; yL=alphaA*yL+(1-alphaA)*gainDB;
    else;         yL=alphaR*yL+(1-alphaR)*gainDB; end
    y(n)=x(n)*10^((yL+M)/20); gainVec(n)=yL;
end
% ---- FIM BLOCO BASE ----

% =========================================================
%  CALCULAR METRICAS
% =========================================================
RMS_in  = 20*log10(sqrt(mean(x.^2))+1e-9);
RMS_out = 20*log10(sqrt(mean(y.^2))+1e-9);
GR_min  = min(gainVec);
GR_med  = mean(gainVec);

% Picos por trecho
pk_t1_in  = 20*log10(max(abs(x(1:n1)))+1e-9);
pk_t2_in  = 20*log10(max(abs(x(n1+1:n2)))+1e-9);
pk_t3_in  = 20*log10(max(abs(x(n2+1:N)))+1e-9);
pk_t1_out = 20*log10(max(abs(y(1:n1)))+1e-9);
pk_t2_out = 20*log10(max(abs(y(n1+1:n2)))+1e-9);
pk_t3_out = 20*log10(max(abs(y(n2+1:N)))+1e-9);

% Excursao dinamica entre trechos
exc_in  = pk_t2_in  - pk_t1_in;
exc_out = pk_t2_out - pk_t1_out;
exc_red = exc_in - exc_out;

% GR teorica no pico do T2 (sem suavizacao temporal)
GR_t2_teo = (T + (pk_t2_in - T)/R) - pk_t2_in;

% Estabilidade
est_A = abs(alphaA) < 1;
est_R = abs(alphaR) < 1;

fprintf('=== METRICAS ===\n');
fprintf('RMS in=%.2f  out=%.2f  delta=%+.2f dBFS\n',RMS_in,RMS_out,RMS_out-RMS_in);
fprintf('GR min=%.2f  med=%.2f dB\n',GR_min,GR_med);
fprintf('Excursao T2-T1: in=%.2f  out=%.2f  red=%.2f dB\n',exc_in,exc_out,exc_red);
fprintf('alphaA=%.6f  alphaR=%.6f\n',alphaA,alphaR);

% =========================================================
%  CORES
% =========================================================
C_BG  = [1.00 1.00 1.00];
C_AX  = [0.97 0.97 0.98];
C_SEP = [0.45 0.50 0.60];
C_TX  = [0.10 0.10 0.12];
C_GR  = [0.18 0.19 0.22];
C_BLU = [0.00 0.35 0.70];
C_GRN = [0.00 0.50 0.20];
C_YEL = [0.60 0.48 0.00];
C_ORA = [0.80 0.38 0.00];
C_RED = [0.80 0.10 0.10];

% =========================================================
%  FIGURA: 3 linhas x 3 colunas de subplots de texto + 1 eixo real
%  Layout:
%    [1,1] Parametros       [1,2] Metricas RMS/GR   [1,3] Plano Z (eixo real)
%    [2,1] Metricas pico    [2,2] Metricas excursao  [2,3] Estab. conclusao
%    [3,:] Estab. teoria    (subplot largo)
% =========================================================
figure('Name','G6 — Metricas de Validacao',...
       'NumberTitle','off',...
       'Position',[40 60 1150 720],...
       'Color',C_BG);

% ---- Funcao auxiliar de subplot de texto ----
% Cria um eixo sem escala, fundo colorido, e coloca texto com text()

% =========================================================
%  [P1] PARAMETROS CONFIGURADOS  — pos [0.025 0.545 0.295 0.400]
% =========================================================
ax1 = axes('Position',[0.025 0.545 0.295 0.400],...
           'Color',C_AX,'XColor',C_SEP,'YColor',C_SEP,...
           'XTick',[],'YTick',[],'Box','on','LineWidth',1.0);
xlim([0 1]); ylim([0 1]);

text(0.50, 0.94, 'PARÂMETROS CONFIGURADOS',...
     'Color',C_BLU,'FontSize',10.5,'FontWeight','bold',...
     'HorizontalAlignment','center','FontName','Courier New','Parent',ax1);

pLabels = {
    sprintf('Limiar       T  = %+d dBFS', T);
    sprintf('Razão        R  = %d : 1',   R);
    sprintf('Ataque       tA = %d ms',    tA);
    sprintf('Liberação    tR = %d ms',    tR);
    sprintf('Joelho       W  = %d dB',    W);
    sprintf('Compensação  M  = %+d dB',   M);
    sprintf('Amostragem   fs = %d Hz',    fs);
};
ypos1 = linspace(0.82, 0.08, 7);
for k = 1:7
    text(0.08, ypos1(k), pLabels{k},...
         'Color',C_TX,'FontSize',9.5,'FontName','Courier New','Parent',ax1);
end

% =========================================================
%  [P2] METRICAS RMS E GR  — pos [0.345 0.545 0.295 0.400]
% =========================================================
ax2 = axes('Position',[0.345 0.545 0.295 0.400],...
           'Color',C_AX,'XColor',C_SEP,'YColor',C_SEP,...
           'XTick',[],'YTick',[],'Box','on','LineWidth',1.0);
xlim([0 1]); ylim([0 1]);

text(0.50, 0.94, 'MÉTRICAS DE NÍVEL',...
     'Color',C_GRN,'FontSize',10.5,'FontWeight','bold',...
     'HorizontalAlignment','center','FontName','Courier New','Parent',ax2);

% Definicao de cada metrica com cor e comentario
m2_txt = {
    sprintf('RMS entrada  = %s dBFS', numvir(RMS_in,2));
    'Nível médio quadrático de entrada';
    sprintf('RMS saída    = %s dBFS', numvir(RMS_out,2));
    'Nível médio quadrático de saída';
    sprintf('Delta RMS    = %s dBFS', numvir(RMS_out-RMS_in,2));
    sprintf('Ganho líquido pela compensação (+%d dB)', M);
    sprintf('GR máxima    = %s dB', numvir(GR_min,2));
    'Pico de atenuação (Trecho 2)';
    sprintf('GR média     = %s dB', numvir(GR_med,2));
    'Atenuação média em todo o sinal';
};
m2_col = {C_TX;C_GR; C_TX;C_GR; C_YEL;C_GR; C_ORA;C_GR; C_YEL;C_GR};
ypos2 = linspace(0.84, 0.06, 10);
for k = 1:10
    sz = 9.5; if mod(k,2)==0; sz=8.0; end
    text(0.06, ypos2(k), m2_txt{k},...
         'Color',m2_col{k},'FontSize',sz,'FontName','Courier New','Parent',ax2);
end

% =========================================================
%  [P3] PLANO Z  — eixo REAL com grafico
% =========================================================
ax3 = axes('Position',[0.665 0.590 0.310 0.355],...
           'Color',C_AX,'XColor',C_GR,'YColor',C_GR,...
           'GridColor',C_SEP,'GridAlpha',0.5,'Box','on','LineWidth',1.0,...
           'FontSize',9);
hold(ax3,'on'); grid(ax3,'on');

theta = linspace(0,2*pi,400);
plot(ax3, cos(theta),sin(theta),'-','Color',[0.20 0.35 0.60],'LineWidth',1.3);
plot(ax3, [-1.1 1.1],[0 0],':','Color',[0.60 0.65 0.72],'LineWidth',0.8);
plot(ax3, [0 0],[-0.44 0.44],':','Color',[0.60 0.65 0.72],'LineWidth',0.8);

h1 = scatter(ax3, alphaA, 0, 150, C_BLU,'filled','o','MarkerEdgeColor','k','LineWidth',0.8);
h2 = scatter(ax3, alphaR, 0, 150, C_GRN,'filled','s','MarkerEdgeColor','k','LineWidth',0.8);
h3 = scatter(ax3, 0, 0, 100,[0.35 0.35 0.35],'x','LineWidth',2.5);

% Rotulos ancorados a ESQUERDA do polo (que esta proximo de z=1), alinhados
% a direita, para o texto crescer para dentro do grafico e nao ser cortado
% pela borda direita (xlim ate 1.1).
text(ax3, alphaA-0.04,  0.20, sprintf('\\alpha_A = %s', numvir(alphaA,4)),...
     'Color',C_BLU,'FontSize',8.5,'FontWeight','bold','HorizontalAlignment','right');
text(ax3, alphaR-0.04, -0.20, sprintf('\\alpha_R = %s', numvir(alphaR,4)),...
     'Color',C_GRN,'FontSize',8.5,'FontWeight','bold','HorizontalAlignment','right');
text(ax3, 0.08, -0.10, 'zero', 'Color',[0.35 0.35 0.35],'FontSize',8);
text(ax3, 0.55,  0.37, '|z|=1','Color',[0.20 0.35 0.60],'FontSize',8.5);

title(ax3,'Plano Z  —  Polos de H(z)','FontSize',10,'FontWeight','bold','Color',C_TX);
xlabel(ax3,'Re(z)','FontSize',9,'Color',C_GR);
ylabel(ax3,'Im(z)','FontSize',9,'Color',C_GR);
xlim(ax3,[-1.15 1.25]); ylim(ax3,[-0.44 0.44]);
lg3 = legend(ax3,[h1 h2 h3],...
    {sprintf('\\alpha_A (ataque)    = %s',numvir(alphaA,4)),...
     sprintf('\\alpha_R (liberação) = %s',numvir(alphaR,4)),...
     'Zero  z = 0'},...
    'Location','northwest','FontSize',7.5);
set(lg3,'TextColor',C_TX,'Color',C_AX,'EdgeColor',C_SEP);

% Por ultimo no eixo: xlim e ylim acima redefinem os ticks e desfariam
% a conversao se virgula fosse chamada antes.
virgula(ax3);

% =========================================================
%  [P4] METRICAS DE PICO POR TRECHO
% =========================================================
ax4 = axes('Position',[0.025 0.112 0.295 0.400],...
           'Color',C_AX,'XColor',C_SEP,'YColor',C_SEP,...
           'XTick',[],'YTick',[],'Box','on','LineWidth',1.0);
xlim([0 1]); ylim([0 1]);

text(0.50, 0.94, 'PICOS POR TRECHO (dBFS)',...
     'Color',C_BLU,'FontSize',10.5,'FontWeight','bold',...
     'HorizontalAlignment','center','FontName','Courier New','Parent',ax4);

p4_txt = {
    '         ENTRADA    SAÍDA    GANHO';
    sprintf('Trecho 1: %7s  %7s  %7s', numvir(pk_t1_in,2), numvir(pk_t1_out,2), numvir(pk_t1_out-pk_t1_in,2));
    '  (fraco: A = 0,10 — sem compressão)';
    sprintf('Trecho 2: %7s  %7s  %7s', numvir(pk_t2_in,2), numvir(pk_t2_out,2), numvir(pk_t2_out-pk_t2_in,2));
    '  (forte: A = 0,80 — compressão plena)';
    sprintf('Trecho 3: %7s  %7s  %7s', numvir(pk_t3_in,2), numvir(pk_t3_out,2), numvir(pk_t3_out-pk_t3_in,2));
    '  (médio: A = 0,30 — joelho suave)';
    ' ';
    sprintf('GR teórica no pico do T2 = %s dB', numvir(GR_t2_teo,2));
    '  [T + (xG-T)/R - xG, Equação 4.21]';
};
p4_col = {C_GR;C_TX;C_GR;C_ORA;C_GR;C_YEL;C_GR;C_GR;C_BLU;C_GR};
ypos4  = linspace(0.84, 0.06, 10);
for k = 1:10
    sz = 8.5; if mod(k,2)==0; sz=7.5; end
    text(0.035, ypos4(k), p4_txt{k},...
         'Color',p4_col{k},'FontSize',sz,'FontName','Courier New','Parent',ax4);
end

% =========================================================
%  [P5] METRICAS DE EXCURSAO DINAMICA
% =========================================================
ax5 = axes('Position',[0.345 0.112 0.295 0.400],...
           'Color',C_AX,'XColor',C_SEP,'YColor',C_SEP,...
           'XTick',[],'YTick',[],'Box','on','LineWidth',1.0);
xlim([0 1]); ylim([0 1]);

text(0.50, 0.94, 'EXCURSÃO DINÂMICA',...
     'Color',C_GRN,'FontSize',10.5,'FontWeight','bold',...
     'HorizontalAlignment','center','FontName','Courier New','Parent',ax5);

if exc_red >= 0; c_exc = C_GRN; else; c_exc = C_RED; end

p5_txt = {
    'Diferença de pico, Trecho 2 - Trecho 1:';
    sprintf('  Entrada: %s - %s = %s dB', numvir(pk_t2_in,2),  numvir(pk_t1_in,2),  numvir(exc_in,2));
    sprintf('  Saída  : %s - %s = %s dB', numvir(pk_t2_out,2), numvir(pk_t1_out,2), numvir(exc_out,2));
    sprintf('  Redução: %s - %s = %s dB', numvir(exc_in,2), numvir(exc_out,2), numvir(exc_red,2));
    ' ';
    'Interpretação:';
    '  O compressor atenuou o Trecho 2 em';
    sprintf('  relação ao Trecho 1 em %s dB.',numvir(exc_red,2));
    '  A redução é pequena porque a';
    sprintf('  compensação (+%d dB) reequilibra',M);
    '  os níveis.';
    'Evidência principal:';
    sprintf('  GR máxima = %s dB (Trecho 2)',numvir(GR_min,2));
};
p5_col = {C_TX;C_GR;C_GR;c_exc;C_GR;C_TX;C_GR;C_GR;C_GR;C_GR;C_GR;C_TX;C_ORA};
ypos5  = linspace(0.86, 0.06, 13);
for k = 1:13
    sz = 9.5; if k==4; sz=10; end
    text(0.04, ypos5(k), p5_txt{k},...
         'Color',p5_col{k},'FontSize',sz,'FontName','Courier New','Parent',ax5);
end

% =========================================================
%  [P6] ESTABILIDADE BIBO
% =========================================================
ax6 = axes('Position',[0.665 0.112 0.310 0.400],...
           'Color',C_AX,'XColor',C_SEP,'YColor',C_SEP,...
           'XTick',[],'YTick',[],'Box','on','LineWidth',1.0);
xlim([0 1]); ylim([0 1]);

text(0.50, 0.94, 'ESTABILIDADE BIBO',...
     'Color',C_YEL,'FontSize',10.5,'FontWeight','bold',...
     'HorizontalAlignment','center','FontName','Courier New','Parent',ax6);

if est_A; stA='ESTAVEL'; cA=C_GRN; else; stA='INSTAVEL'; cA=C_RED; end
if est_R; stR='ESTAVEL'; cR=C_GRN; else; stR='INSTAVEL'; cR=C_RED; end

% Painel em Courier New: a fonte nao possui alfa, seta nem o sinal de
% multiplicacao. Os rotulos ficam em ASCII de proposito -- caracteres
% ausentes saem como retangulos vazios na exportacao.
p6_txt = {
    'H(z) = (1-a)z / (z-a)   [Equacao 4.27]';
    'Condicao: |polo| < 1    [Equacao 4.28]';
    ' ';
    'Filtro de ATAQUE:';
    sprintf('  aA = exp(-1/(%de-3 * %d))', tA, fs);
    sprintf('  aA = %s', numvir(alphaA,8));
    sprintf('  |aA| < 1  ->  %s', stA);
    ' ';
    'Filtro de LIBERACAO:';
    sprintf('  aR = exp(-1/(%de-3 * %d))', tR, fs);
    sprintf('  aR = %s', numvir(alphaR,8));
    sprintf('  |aR| < 1  ->  %s', stR);
};
c6 = {C_TX;C_TX;C_GR;C_BLU;C_GR;C_GR;cA;C_GR;C_GRN;C_GR;C_GR;cR};
ypos6 = linspace(0.86, 0.10, 12);
for k = 1:12
    bld = 'normal';
    if k==7||k==12; bld='bold'; end
    text(0.05, ypos6(k), p6_txt{k},...
         'Color',c6{k},'FontSize',9.5,'FontName','Courier New',...
         'FontWeight',bld,'Parent',ax6);
end

% =========================================================
%  TITULO GERAL
% =========================================================

fprintf('\nG6 gerado com sucesso.\n');

% A barra de ferramentas flutuante dos eixos era capturada pelo
% exportgraphics e impressa dentro do PNG (aviso "Exported image
% displays axes toolbar"). Desligada em TODOS os eixos da figura,
% inclusive nos paineis de texto, logo antes da exportacao.
try
    for a_ = findall(gcf,'Type','axes').'
        a_.Toolbar = [];
        disableDefaultInteractivity(a_);
    end
catch
end

set(gcf,'Color','w','InvertHardcopy','off');
exportgraphics(gcf,'fig_g6_metricas.png','Resolution',300,'BackgroundColor','white');
fprintf('  salvo em fig_g6_metricas.png\n');
