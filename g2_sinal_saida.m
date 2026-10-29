%  G2 — SINAL DE SAÍDA NO DOMÍNIO DO TEMPO

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
COR_SAIDA   = [0.00 0.45 0.45];
COR_ENTRADA = [0.45 0.55 0.58];
COR_THRESH  = [0.85 0.35 0.00];
COR_TEXTO   = [0.10 0.10 0.10];
COR_EIXO    = [0.20 0.20 0.20];
COR_GRID    = [0.75 0.75 0.75];
COR_ANOT    = [0.70 0.45 0.00];
COR_DIV     = [0.55 0.55 0.55];

figure('Name','G2 — Sinal de Saída [Ciano]',...
       'NumberTitle','off','Position',[60 60 900 520],...
       'Color',COR_BG_FIG);

ax1 = subplot(2,1,1);
plot(t, x, 'Color',[COR_ENTRADA, 0.45], 'LineWidth', 0.6);
hold on;
area(t, y,'FaceColor',COR_SAIDA,'FaceAlpha',0.10,'EdgeColor','none');
plot(t, y, 'Color',COR_SAIDA,'LineWidth',0.8);
yline( A_T,'--','Color',COR_THRESH,'LineWidth',1.3,...
       'Label',sprintf('T = %d dBFS',T),...
       'LabelHorizontalAlignment','left','FontSize',8.5);
yline(-A_T,'--','Color',COR_THRESH,'LineWidth',1.3);
xline(1,':','Color',COR_DIV,'LineWidth',1.0);
xline(2,':','Color',COR_DIV,'LineWidth',1.0);
text(1.04, 0.80, sprintf('← Ataque\n   τ_A = %d ms',tA),...
     'Color',COR_ANOT,'FontSize',8.5,'FontAngle','italic');
text(2.05, 0.52, sprintf('← Release\n   τ_R = %d ms',tR),...
     'Color',COR_ANOT,'FontSize',8.5,'FontAngle','italic');
text(0.50,-1.10,sprintf('makeup de +%d dB',M),...
     'Color',COR_EIXO,'FontSize',8,'HorizontalAlignment','center');
title('G2 — Saída y[n]  (Visão Geral)  |  Entrada em transparência',...
      'FontSize',11,'FontWeight','bold','Color',COR_TEXTO);
ylabel('Amplitude','FontSize',10,'Color',COR_EIXO);
xlim([0 dur]); ylim([-1.15 1.15]); grid on;
lg=legend({'Entrada x[n]','','Saída y[n]'},'Location','northeast','FontSize',8);
set(lg,'TextColor',COR_TEXTO,'Color',[1.00 1.00 1.00]);
set(ax1,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

ax2 = subplot(2,1,2);
t_zoom = [0.980, 1.060];
mask   = t >= t_zoom(1) & t <= t_zoom(2);
plot(t(mask), x(mask),'Color',[COR_ENTRADA,0.5],'LineWidth',1.0);
hold on;
plot(t(mask), y(mask),'Color',COR_SAIDA,'LineWidth',1.8);
yline( A_T,'--','Color',COR_THRESH,'LineWidth',1.2);
yline(-A_T,'--','Color',COR_THRESH,'LineWidth',1.2);
xline(1.000, '-','Color',[0.80 0.10 0.10],'LineWidth',1.5,...
      'Label','t = 1,000 s (início do Trecho 2)',...
      'LabelHorizontalAlignment','right','FontSize',8.5);
GR_regime = (T + (20*log10(0.80)-T)/R) - 20*log10(0.80);
t_atk  = t(mask & t >= 1.000);
n_atk  = 0:length(t_atk)-1;
env_teo= GR_regime * (1 - alphaA .^ n_atk);
amp_teo = 0.80 * 10.^((env_teo + M)/20);
plot(t_atk, amp_teo,'--','Color',[0.75 0.50 0.00],...
     'LineWidth',1.2,'DisplayName','Resposta teórica s[n]');
t_tau = 1.000 + tA/1000;
xline(t_tau,':','Color',[0.30 0.55 0.00],'LineWidth',1.0,...
      'Label',sprintf('τ_A = %d ms (63,2%%)',tA),...
      'LabelHorizontalAlignment','right','FontSize',8.5);
title(sprintf('Zoom: Transitório de Ataque  |  t = [%s; %s] s  |  τ_A = %d ms',...
      numvir(t_zoom(1),3),numvir(t_zoom(2),3),tA),...
      'FontSize',10,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Tempo (s)','FontSize',10,'Color',COR_EIXO);
ylabel('Amplitude','FontSize',10,'Color',COR_EIXO);
xlim(t_zoom); grid on;
set(ax2,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

sgtitle(sprintf('G2 — Sinal de Saída  |  R = %d:1  |  τ_A = %d ms  |  τ_R = %d ms  |  M = +%d dB',...
        R,tA,tR,M),...
        'FontSize',12,'FontWeight','bold','Color',COR_TEXTO,...
        'BackgroundColor',COR_BG_FIG);

virgula([ax1 ax2]);

fprintf('G2 gerado.\n');

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
exportgraphics(gcf,'fig_g2_sinal_saida.png','Resolution',300,'BackgroundColor','white');
fprintf('  salvo em fig_g2_sinal_saida.png\n');
