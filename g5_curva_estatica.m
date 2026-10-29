%  G5 — CURVA ESTÁTICA DE COMPRESSÃO (I/O CURVE)

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

xG_v = linspace(-60, 0, 4000);
nk   = length(xG_v);
cG_sem  = xG_v;
cG_hard = zeros(1,nk);
cG_soft = zeros(1,nk);
cG_lim  = zeros(1,nk);
R_lim   = 20;
for k=1:nk
    xg=xG_v(k);
    if xg>T; cG_hard(k)=T+(xg-T)/R; else; cG_hard(k)=xg; end
    if W>0&&2*abs(xg-T)<=W; cG_soft(k)=xg+(1/R-1)*(xg-T+W/2)^2/(2*W);
    elseif xg>T+W/2;         cG_soft(k)=T+(xg-T)/R;
    else;                     cG_soft(k)=xg; end
    if xg>T; cG_lim(k)=T+(xg-T)/R_lim; else; cG_lim(k)=xg; end
end
xG_t1=20*log10(0.10); xG_t2=20*log10(0.80); xG_t3=20*log10(0.30);
yG_t1=xG_t1;
yG_t2=T+(xG_t2-T)/R;
if W>0&&2*abs(xG_t3-T)<=W; yG_t3=xG_t3+(1/R-1)*(xG_t3-T+W/2)^2/(2*W);
else; yG_t3=T+(xG_t3-T)/R; end

COR_BG_FIG  = [1.00 1.00 1.00];
COR_BG_AX   = [1.00 1.00 1.00];
COR_SEM     = [0.45 0.45 0.45];
COR_HARD    = [0.80 0.25 0.05];
COR_SOFT    = [0.60 0.45 0.00];
COR_LIM     = [0.10 0.50 0.10];
COR_THRESH  = [0.80 0.10 0.10];
COR_KNEE    = [0.65 0.55 0.00];
COR_TEXTO   = [0.10 0.10 0.10];
COR_EIXO    = [0.20 0.20 0.20];
COR_GRID    = [0.75 0.75 0.75];
COR_PT1     = [0.00 0.35 0.75];
COR_PT2     = [0.85 0.30 0.00];
COR_PT3     = [0.00 0.50 0.10];

figure('Name','G5 — Curva Estática [Dourado]',...
       'NumberTitle','off','Position',[60 60 920 520],...
       'Color',COR_BG_FIG);

ax1 = subplot(1,2,1);
plot(xG_v, cG_sem, ':','Color',COR_SEM,'LineWidth',1.0); hold on;
plot(xG_v, cG_hard,'--','Color',COR_HARD,'LineWidth',1.5);
plot(xG_v, cG_soft,'-','Color',COR_SOFT,'LineWidth',2.2);
plot(xG_v, cG_lim, '-.','Color',COR_LIM,'LineWidth',1.3);
xline(T,'--','Color',COR_THRESH,'LineWidth',1.1,...
      'Label',sprintf('T = %d dB',T),'LabelVerticalAlignment','bottom',...
      'LabelHorizontalAlignment','right','FontSize',8.5);
patch([T-W/2 T+W/2 T+W/2 T-W/2],[-60 -60 0 0],...
      COR_KNEE,'FaceAlpha',0.14,'EdgeColor','none');
text(T,-54,sprintf('Joelho\nW = %d dB',W),...
     'Color',COR_KNEE,'FontSize',8,'HorizontalAlignment','center');
scatter(xG_t1,yG_t1,70,COR_PT1,'filled','MarkerEdgeColor','k');
scatter(xG_t2,yG_t2,70,COR_PT2,'filled','MarkerEdgeColor','k');
scatter(xG_t3,yG_t3,70,COR_PT3,'filled','MarkerEdgeColor','k');
text(xG_t1+1.5,yG_t1+1.5,'T1 (Reg.A)','Color',COR_PT1,'FontSize',8.5);
text(xG_t2+1.5,yG_t2-3.0,'T2 (Reg.C)','Color',COR_PT2,'FontSize',8.5);
text(xG_t3+1.5,yG_t3+1.5,'T3 (Reg.B)','Color',COR_PT3,'FontSize',8.5);
text(-52,-53,'Inclinação = 1','Color',COR_SEM,'FontSize',8,'Rotation',42);
text(-8,-22,sprintf('Inclinação = 1/R\n= 1/%d = %s',R,numvir(1/R,2)),'Color',COR_SOFT,'FontSize',8.5);
title(sprintf('Curva entrada-saída  |  T = %d dBFS  |  R = %d:1  |  W = %d dB',T,R,W),...
      'FontSize',11,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Entrada x_G (dBFS)','FontSize',10,'Color',COR_EIXO);
ylabel('Saída y_G (dBFS)','FontSize',10,'Color',COR_EIXO);
xlim([-60 0]); ylim([-60 0]); grid on; axis square;
lg=legend({'Sem compressão','Hard knee','Soft knee — implementado',sprintf('Limitador R = %d:1',R_lim)},...
          'Location','southeast','FontSize',8.5);
set(lg,'TextColor',COR_TEXTO,'Color',[1.00 1.00 1.00]);
set(ax1,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

ax2 = subplot(1,2,2);
xG_zoom = linspace(T-W-4, T+W+4, 1000);
nk2=length(xG_zoom);
cG_h2=zeros(1,nk2); cG_s2=zeros(1,nk2);
for k=1:nk2
    xg=xG_zoom(k);
    if xg>T; cG_h2(k)=T+(xg-T)/R; else; cG_h2(k)=xg; end
    if W>0&&2*abs(xg-T)<=W; cG_s2(k)=xg+(1/R-1)*(xg-T+W/2)^2/(2*W);
    elseif xg>T+W/2;         cG_s2(k)=T+(xg-T)/R;
    else;                     cG_s2(k)=xg; end
end
plot(xG_zoom,xG_zoom,':','Color',COR_SEM,'LineWidth',1.0); hold on;
plot(xG_zoom,cG_h2,'--','Color',COR_HARD,'LineWidth',1.8);
plot(xG_zoom,cG_s2,'-','Color',COR_SOFT,'LineWidth',2.5);
xline(T-W/2,':','Color',COR_KNEE,'LineWidth',1.0,...
      'Label',sprintf('T - W/2 = %d',T-W/2),...
      'LabelHorizontalAlignment','right','FontSize',8.5);
xline(T+W/2,':','Color',COR_KNEE,'LineWidth',1.0,...
      'Label',sprintf('T + W/2 = %d',T+W/2),...
      'LabelHorizontalAlignment','right','FontSize',8.5);
xline(T,'--','Color',COR_THRESH,'LineWidth',1.1,...
      'Label',sprintf('T = %d',T),'LabelVerticalAlignment','bottom',...
      'LabelHorizontalAlignment','right','FontSize',8.5);
patch([T-W/2 T+W/2 T+W/2 T-W/2],...
      [T-W/2-2 T-W/2-2 T+W/2+2 T+W/2+2],...
      COR_KNEE,'FaceAlpha',0.16,'EdgeColor','none');
scatter(xG_t3,yG_t3,80,COR_PT3,'filled','MarkerEdgeColor','k');
text(xG_t3+0.3,yG_t3-0.8,sprintf('T3 = (%s; %s)',numvir(xG_t3,1),numvir(yG_t3,1)),...
     'Color',COR_PT3,'FontSize',8.5);
title(sprintf('Zoom: Zona do Joelho  [%d; %d] dBFS',T-W/2,T+W/2),...
      'FontSize',11,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Entrada x_G (dBFS)','FontSize',10,'Color',COR_EIXO);
ylabel('Saída y_G (dBFS)','FontSize',10,'Color',COR_EIXO);
xlim([T-W-4, T+W+4]); ylim([T-W-4, T+W+4]);
grid on; axis square;
set(ax2,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

sgtitle('G5 — Curva Estática de Compressão  |  Reproduz a Figura 1 de Giannoulis, Massberg e Reiss (2012)',...
        'FontSize',11,'FontWeight','bold','Color',COR_TEXTO,...
        'BackgroundColor',COR_BG_FIG);

virgula([ax1 ax2]);

fprintf('G5 gerado.\n');

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
exportgraphics(gcf,'fig_g5_curva_estatica.png','Resolution',300,'BackgroundColor','white');
fprintf('  salvo em fig_g5_curva_estatica.png\n');
