%  G3 — ENVELOPE DE GANHO (GAIN REDUCTION)

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

GR_min = min(gainVec);
GR_med = mean(gainVec);

COR_BG_FIG  = [1.00 1.00 1.00];
COR_BG_AX   = [1.00 1.00 1.00];
COR_ENV     = [0.80 0.40 0.00];
COR_AREA    = [0.95 0.60 0.15];
COR_ZERO    = [0.40 0.40 0.40];
COR_MED     = [0.60 0.55 0.00];
COR_TEXTO   = [0.10 0.10 0.10];
COR_EIXO    = [0.20 0.20 0.20];
COR_GRID    = [0.75 0.75 0.75];
COR_ANOT    = [0.00 0.40 0.70];
COR_DIV     = [0.55 0.55 0.55];
COR_REL     = [0.00 0.55 0.25];

figure('Name','G3 — Envelope de Ganho [Laranja]',...
       'NumberTitle','off','Position',[60 60 900 520],...
       'Color',COR_BG_FIG);

ax1 = subplot(2,1,1);
fill([t fliplr(t)],[gainVec zeros(1,N)],COR_AREA,...
     'FaceAlpha',0.18,'EdgeColor','none');
hold on;
plot(t, gainVec,'Color',COR_ENV,'LineWidth',1.2);
yline(0,'--','Color',COR_ZERO,'LineWidth',1.0,...
      'Label','0 dB (sem redução)',...
      'LabelHorizontalAlignment','left','FontSize',8.5);
yline(GR_med,':','Color',COR_MED,'LineWidth',1.0,...
      'Label',sprintf('GR médio = %s dB',numvir(GR_med,1)),...
      'LabelHorizontalAlignment','right','FontSize',8.5);
xline(1,':','Color',COR_DIV,'LineWidth',1.0);
xline(2,':','Color',COR_DIV,'LineWidth',1.0);
text(0.50,GR_min*0.12,'sem compressão',...
     'Color',COR_EIXO,'FontSize',8.5,...
     'HorizontalAlignment','center','FontAngle','italic');
text(1.50,GR_min*0.55,sprintf('ataque + sustentação\nτ_A = %d ms',tA),...
     'Color',COR_ANOT,'FontSize',8.5,'HorizontalAlignment','center');
text(2.50,GR_min*0.40,sprintf('liberação\nτ_R = %d ms',tR),...
     'Color',COR_REL,'FontSize',8.5,'HorizontalAlignment','center');
[~,idx_min]=min(gainVec);
text(t(idx_min)+0.04,GR_min-0.4,...
     sprintf('GR_{máx} = %s dB',numvir(GR_min,1)),...
     'Color',COR_ENV,'FontSize',9,'FontWeight','bold');
title('G3 — Envelope de Ganho  y_L[n]  (Visão Geral)',...
      'FontSize',11,'FontWeight','bold','Color',COR_TEXTO);
ylabel('Redução de Ganho (dB)','FontSize',10,'Color',COR_EIXO);
xlim([0 dur]); ylim([GR_min-1.5, 0.5]); grid on;
set(ax1,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

ax2 = subplot(2,1,2);
t_zoom = [1.990, 2.350];
mask   = t >= t_zoom(1) & t <= t_zoom(2);
fill([t(mask) fliplr(t(mask))],[gainVec(mask) zeros(1,sum(mask))],...
     COR_AREA,'FaceAlpha',0.15,'EdgeColor','none');
hold on;
plot(t(mask),gainVec(mask),'Color',COR_ENV,'LineWidth',1.8);
GR_inicio_rel = gainVec(n2);
t_rel  = t(mask & t >= 2.000);
n_rel  = 0:length(t_rel)-1;
env_teo_rel = GR_inicio_rel * alphaR .^ n_rel;
plot(t_rel, env_teo_rel,'--','Color',[0.65 0.55 0.00],'LineWidth',1.3);
xline(2.000,'-','Color',[0.80 0.10 0.10],'LineWidth',1.5,...
      'Label','t = 2,000 s (início do Trecho 3)',...
      'LabelHorizontalAlignment','right','FontSize',8.5);
yline(0,'--','Color',COR_ZERO,'LineWidth',1.0);
t_tau_R = 2.000 + tR/1000;
xline(t_tau_R,':','Color',COR_REL,'LineWidth',1.0,...
      'Label',sprintf('τ_R = %d ms (36,8%% restante)',tR),...
      'LabelHorizontalAlignment','left','FontSize',8.5);
lg2=legend({'','GR medido','GR teórico (y_L·α_R^n)'},...
           'Location','southeast','FontSize',8.5);
set(lg2,'TextColor',COR_TEXTO,'Color',[1.00 1.00 1.00]);
title(sprintf('Zoom: Transitório de Liberação  |  t = [%s; %s] s  |  τ_R = %d ms',...
      numvir(t_zoom(1),3),numvir(t_zoom(2),3),tR),...
      'FontSize',10,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Tempo (s)','FontSize',10,'Color',COR_EIXO);
ylabel('Redução de Ganho (dB)','FontSize',10,'Color',COR_EIXO);
xlim(t_zoom); grid on;
set(ax2,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

sgtitle('G3 — Envelope de Ganho (Gain Reduction)  |  Detector Ramificado',...
        'FontSize',12,'FontWeight','bold','Color',COR_TEXTO,...
        'BackgroundColor',COR_BG_FIG);

virgula([ax1 ax2]);

fprintf('G3 gerado.\n');

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
exportgraphics(gcf,'fig_g3_envelope_ganho.png','Resolution',300,'BackgroundColor','white');
fprintf('  salvo em fig_g3_envelope_ganho.png\n');
