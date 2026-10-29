%  G1 — SINAL DE ENTRADA NO DOMÍNIO DO TEMPO

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

A_T = 10^(T/20);

COR_BG_FIG  = [1.00 1.00 1.00];
COR_BG_AX   = [1.00 1.00 1.00];
COR_SINAL   = [0.35 0.15 0.65];
COR_THRESH  = [0.80 0.10 0.35];
COR_TEXTO   = [0.10 0.10 0.10];
COR_EIXO    = [0.20 0.20 0.20];
COR_GRID    = [0.75 0.75 0.75];
COR_DIV     = [0.55 0.55 0.55];

figure('Name','G1 — Sinal de Entrada [Roxo]',...
       'NumberTitle','off','Position',[60 60 900 520],...
       'Color', COR_BG_FIG);

ax1 = subplot(2,1,1);
area(t, x, 'FaceColor', COR_SINAL, 'FaceAlpha', 0.12, 'EdgeColor','none');
hold on;
plot(t, x, 'Color', COR_SINAL, 'LineWidth', 0.7);
yline( A_T,'--','Color',COR_THRESH,'LineWidth',1.5,...
       'Label',sprintf('T = %d dBFS  (A = %s)',T,numvir(A_T,3)),...
       'LabelHorizontalAlignment','left','FontSize',8.5);
yline(-A_T,'--','Color',COR_THRESH,'LineWidth',1.5);
xline(1,':','Color',COR_DIV,'LineWidth',1.0);
xline(2,':','Color',COR_DIV,'LineWidth',1.0);
text(0.50, 1.06,'Trecho 1','Color',COR_TEXTO,'FontSize',9,...
     'HorizontalAlignment','center','FontWeight','bold');
text(1.50, 1.06,'Trecho 2','Color',COR_TEXTO,'FontSize',9,...
     'HorizontalAlignment','center','FontWeight','bold');
text(2.50, 1.06,'Trecho 3','Color',COR_TEXTO,'FontSize',9,...
     'HorizontalAlignment','center','FontWeight','bold');
text(0.50,-1.10,'A = 0,10  (−20 dBFS)','Color',COR_EIXO,...
     'FontSize',8,'HorizontalAlignment','center');
text(1.50,-1.10,'A = 0,80  (−1,9 dBFS)','Color',COR_EIXO,...
     'FontSize',8,'HorizontalAlignment','center');
text(2.50,-1.10,'A = 0,30  (−10,5 dBFS)','Color',COR_EIXO,...
     'FontSize',8,'HorizontalAlignment','center');
title('G1 — Sinal de Entrada  x[n]  (Visão Geral)',...
      'FontSize',11,'FontWeight','bold','Color',COR_TEXTO);
ylabel('Amplitude','FontSize',10,'Color',COR_EIXO);
xlim([0 dur]); ylim([-1.15 1.15]); grid on;
set(ax1,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

ax2 = subplot(2,1,2);
t_zoom = [1.000, 1.025];
mask   = t >= t_zoom(1) & t <= t_zoom(2);
plot(t(mask), x(mask), 'Color', COR_SINAL, 'LineWidth', 1.6);
hold on;
area(t(mask), x(mask),'FaceColor',COR_SINAL,'FaceAlpha',0.10,'EdgeColor','none');
yline( A_T,'--','Color',COR_THRESH,'LineWidth',1.3);
yline(-A_T,'--','Color',COR_THRESH,'LineWidth',1.3);
yline(0,   ':','Color',COR_DIV,   'LineWidth',0.8);
T_period = 1/440;
xline(1.000 + T_period, ':','Color',[0.45 0.20 0.75],'LineWidth',0.9,...
      'Label',sprintf('T_p = %s ms',numvir(T_period*1000,2)),...
      'LabelHorizontalAlignment','right','FontSize',8);
text(1.012, 0.70, sprintf('440 Hz  |  período T_p \\approx %s ms',numvir(T_period*1000,2)),...
     'Color',[0.45 0.20 0.75],'FontSize',9,...
     'HorizontalAlignment','center');
title(sprintf('Zoom: t = [%s; %s] s  —  Ciclos da Senoide de 440 Hz',...
      numvir(t_zoom(1),3), numvir(t_zoom(2),3)),...
      'FontSize',10,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Tempo (s)','FontSize',10,'Color',COR_EIXO);
ylabel('Amplitude','FontSize',10,'Color',COR_EIXO);
xlim(t_zoom); ylim([-0.95 0.95]); grid on;
set(ax2,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

sgtitle(sprintf('Validação — Sinal de Teste  |  f_s = 44,1 kHz  |  duração = %s s',numvir(dur,1)),...
        'FontSize',12,'FontWeight','bold','Color',COR_TEXTO,...
        'BackgroundColor',COR_BG_FIG);

virgula([ax1 ax2]);

fprintf('G1 gerado.\n');

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
exportgraphics(gcf,'fig_g1_sinal_entrada.png','Resolution',300,'BackgroundColor','white');
fprintf('  salvo em fig_g1_sinal_entrada.png\n');
