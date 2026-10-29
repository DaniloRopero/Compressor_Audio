%  G8 — COMPARAÇÃO HARD KNEE vs. SOFT KNEE

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
xdB=20*log10(abs(x)+1e-9); ydB=20*log10(abs(y)+1e-9);
% ---- FIM BLOCO BASE ----

W_vals  = [0, 3, 6, 12, 24];
labels  = {'Hard knee (W = 0)','W = 3 dB','W = 6 dB — atual','W = 12 dB','W = 24 dB'};
cores   = {[0.85 0.10 0.10];   % W=0  - vermelho
           [0.95 0.55 0.00];   % W=3  - laranja/ambar
           [0.00 0.55 0.20];   % W=6  - verde (destaque, atual)
           [0.00 0.45 0.80];   % W=12 - azul
           [0.55 0.10 0.75]};  % W=24 - roxo/magenta
estilos = {'--','-.', '-','-.', ':'};
larguras= [1.5, 1.5, 2.5, 1.5, 1.5];

xG_v = linspace(-40, 0, 3000);
nk   = length(xG_v);
curvas = zeros(length(W_vals), nk);
for wi=1:length(W_vals)
    Ww=W_vals(wi);
    for k=1:nk
        xg=xG_v(k);
        if Ww>0&&2*abs(xg-T)<=Ww; curvas(wi,k)=xg+(1/R-1)*(xg-T+Ww/2)^2/(2*Ww);
        elseif xg>T+Ww/2;          curvas(wi,k)=T+(xg-T)/R;
        else;                       curvas(wi,k)=xg; end
    end
end

y_todos = zeros(length(W_vals), N);
for wi=1:length(W_vals)
    Ww=W_vals(wi); yLl=0;
    for n=1:N
        xG2=20*log10(abs(x(n))+1e-9);
        if Ww>0&&2*abs(xG2-T)<=Ww; cG2=xG2+(1/R-1)*(xG2-T+Ww/2)^2/(2*Ww);
        elseif xG2>T+Ww/2;          cG2=T+(xG2-T)/R;
        else;                         cG2=xG2; end
        gDB2=cG2-xG2;
        if gDB2<yLl; yLl=alphaA*yLl+(1-alphaA)*gDB2;
        else;         yLl=alphaR*yLl+(1-alphaR)*gDB2; end
        y_todos(wi,n)=x(n)*10^((yLl+M)/20);
    end
end

COR_BG_FIG = [1.00 1.00 1.00];
COR_BG_AX  = [1.00 1.00 1.00];
COR_REF    = [0.45 0.45 0.45];
COR_TEXTO  = [0.10 0.10 0.10];
COR_EIXO   = [0.20 0.20 0.20];
COR_GRID   = [0.75 0.75 0.75];
COR_THRESH = [0.80 0.10 0.10];
COR_KNEE_Z = [0.60 0.55 0.00];

figure('Name','G8 — Comparação Knee [Multicolor]',...
       'NumberTitle','off','Position',[50 50 1000 520],...
       'Color',COR_BG_FIG);

ax1 = subplot(1,2,1);
plot(xG_v,xG_v,':','Color',COR_REF,'LineWidth',1.0); hold on;
for wi=1:length(W_vals)
    plot(xG_v, curvas(wi,:), estilos{wi},...
         'Color',cores{wi},'LineWidth',larguras(wi),...
         'DisplayName',labels{wi});
end
xline(T,'--','Color',COR_THRESH,'LineWidth',1.0,...
      'Label',sprintf('T = %d dB',T),'LabelVerticalAlignment','bottom',...
      'LabelHorizontalAlignment','right','FontSize',8.5);
patch([T-W/2 T+W/2 T+W/2 T-W/2],[-40 -40 0 0],...
      COR_KNEE_Z,'FaceAlpha',0.12,'EdgeColor','none');
text(T,-37,sprintf('Zona do joelho\nW = %d dB',W),...
     'Color',COR_KNEE_Z,'FontSize',8,'HorizontalAlignment','center');
title(sprintf('Curva entrada-saída  |  R = %d:1  |  T = %d dBFS  |  cinco valores de W',R,T),...
      'FontSize',10,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Entrada x_G (dBFS)','FontSize',10,'Color',COR_EIXO);
ylabel('Saída y_G (dBFS)','FontSize',10,'Color',COR_EIXO);
% Zoom centrado na zona do knee: [T-W-8, T+W+8] = [-26, -2] dBFS
% Mostra com detalhe a transicao entre as 5 curvas de W
xlim([T-W-8, T+W+8]); ylim([T-W-8, T+W+8]); grid on; axis square;
lg1=legend([{'Sem compressão'}, labels],'Location','northwest','FontSize',8.5);
set(lg1,'TextColor',COR_TEXTO,'Color',[1.00 1.00 1.00]);
set(ax1,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

ax2 = subplot(1,2,2);
% ---------------------------------------------------------------------
% JANELA DE ANALISE -- ATENCAO
%
% A janela anterior, t = [2,100  2,130] s, NAO estava em regime. O
% Trecho 3 comeca em t = 2,0 s, e o envelope vem descendo do patamar de
% compressao do Trecho 2 com tau_R = 100 ms: em 2,10 s ainda vale
% -2,58 dB e so estabiliza em -0,778 dB por volta de 2,3 s. Medir ali
% misturava o efeito de W com o transitorio de liberacao.
%
% A janela abaixo, 30 ms a partir de 2,800 s, esta a oito constantes de
% tempo da transicao -- regime permanente verificado.
%
% As linhas de referencia tambem eram constantes fixas no codigo
% (0.52494 e 0.45097) que nao correspondiam as curvas plotadas. Agora
% sao apuradas dos proprios dados, logo abaixo.
% ---------------------------------------------------------------------
t_zoom = [2.800, 2.830];
mask   = t >= t_zoom(1) & t <= t_zoom(2);

pico_W = zeros(1, length(W_vals));
for wi = 1:length(W_vals)
    pico_W(wi) = max(abs(y_todos(wi, mask)));
end
dif_dB = 20*log10(pico_W(1) / pico_W(end));
plot(t(mask),x(mask),':','Color',COR_REF,'LineWidth',1.2,...
     'DisplayName','Entrada'); hold on;
for wi=1:length(W_vals)
    plot(t(mask), y_todos(wi,mask),...
         'Color',cores{wi},'LineWidth',larguras(wi),...
         'LineStyle',estilos{wi},'DisplayName',labels{wi});
end
% Linhas de referencia de amplitude (picos teoricos para W=0 e W=24)
yline( pico_W(1),':', 'Color',cores{1},'LineWidth',1.0,...
       'Label','W = 0','LabelHorizontalAlignment','left','FontSize',8);
yline(-pico_W(1),':', 'Color',cores{1},'LineWidth',1.0);
yline( pico_W(end),':', 'Color',cores{end},'LineWidth',1.0,...
       'Label','W = 24 dB','LabelHorizontalAlignment','left','FontSize',8);
yline(-pico_W(end),':', 'Color',cores{end},'LineWidth',1.0);
title(sprintf('Zoom: Trecho 3 em regime  |  t = [%s; %s] s  |  220 Hz',...
      numvir(t_zoom(1),3),numvir(t_zoom(2),3)),...
      'FontSize',10,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Tempo (s)','FontSize',10,'Color',COR_EIXO);
ylabel('Amplitude','FontSize',10,'Color',COR_EIXO);
xlim(t_zoom); grid on;
% Anotacao explicando o que se ve
text(mean(t_zoom), max(pico_W)*1.14,...
     sprintf('pico: W = 0 \\rightarrow %s   |   W = 24 dB \\rightarrow %s   |   diferença %s dB',...
             numvir(pico_W(1),3), numvir(pico_W(end),3), numvir(dif_dB,2)),...
     'Color',[0.40 0.34 0.00],'FontSize',8.5,...
     'HorizontalAlignment','center');
ylim([-max(pico_W)*1.25, max(pico_W)*1.25]);
lg2=legend([{'Entrada'}, labels],'Location','northeast','FontSize',8);
set(lg2,'TextColor',COR_TEXTO,'Color',[1.00 1.00 1.00]);
set(ax2,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

sgtitle(sprintf('G8 — Impacto da Largura do Joelho  |  Esquerda: curva entrada-saída  |  Direita: Trecho 3 em regime (220 Hz, Região B)  |  R = %d:1  |  T = %d dBFS',R,T),...
        'FontSize',11,'FontWeight','bold','Color',COR_TEXTO,...
        'BackgroundColor',COR_BG_FIG);

virgula([ax1 ax2]);

fprintf('G8 gerado.\n');
fprintf('  Janela de regime: t = [%.3f, %.3f] s\n', t_zoom(1), t_zoom(2));
ref_sem_compr = 20*log10(0.30) + M;
for wi=1:length(W_vals)
    fprintf('  W=%2d dB | pico=%.4f (%+7.3f dBFS) | atenuacao=%+6.3f dB | RMS saida=%.2f dBFS\n',...
            W_vals(wi), pico_W(wi), 20*log10(pico_W(wi)),...
            20*log10(pico_W(wi)) - ref_sem_compr,...
            20*log10(sqrt(mean(y_todos(wi,:).^2))+1e-9));
end
fprintf('  Diferenca W=0 -> W=24: %.3f dB\n', dif_dB);

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
exportgraphics(gcf,'fig_g8_comparacao_knee.png','Resolution',300,'BackgroundColor','white');
fprintf('  salvo em fig_g8_comparacao_knee.png\n');
