%  G7 — RESPOSTA AO DEGRAU DO FILTRO IIR

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

dur_step = 0.200;
Ns  = round(dur_step*fs);
ts  = (0:Ns-1)/fs * 1000;
s_A_med = zeros(1,Ns);
s_A_med(1) = (1-alphaA)*1;
for n=2:Ns
    s_A_med(n) = alphaA*s_A_med(n-1) + (1-alphaA)*1;
end
s_A_teo = 1 - alphaA .^ (0:Ns-1);

dur_step_R = 0.600;
Ns_R   = round(dur_step_R*fs);
ts_R   = (0:Ns_R-1)/fs * 1000;
s_R_med = zeros(1,Ns_R);
s_R_med(1) = (1-alphaR)*1;
for n=2:Ns_R
    s_R_med(n) = alphaR*s_R_med(n-1) + (1-alphaR)*1;
end
s_R_teo = 1 - alphaR .^ (0:Ns_R-1);

nivel_1tau = 1 - exp(-1);
nivel_2tau = 1 - exp(-2);
nivel_3tau = 1 - exp(-3);

COR_BG_FIG  = [1.00 1.00 1.00];
COR_BG_AX   = [1.00 1.00 1.00];
COR_MED_A   = [0.75 0.05 0.25];
COR_TEO_A   = [0.60 0.45 0.00];
COR_MED_R   = [0.60 0.00 0.55];
COR_TEO_R   = [0.00 0.40 0.65];
COR_NIVEL   = [0.40 0.40 0.40];
COR_TAU     = [0.00 0.50 0.10];
COR_TEXTO   = [0.10 0.10 0.10];
COR_EIXO    = [0.20 0.20 0.20];
COR_GRID    = [0.75 0.75 0.75];

figure('Name','G7 — Resposta ao Degrau [Vermelho]',...
       'NumberTitle','off','Position',[60 60 900 520],...
       'Color',COR_BG_FIG);

ax1 = subplot(1,2,1);
plot(ts, s_A_teo,'--','Color',COR_TEO_A,'LineWidth',1.3); hold on;
plot(ts, s_A_med,'-', 'Color',COR_MED_A,'LineWidth',2.0);
yline(nivel_1tau,':','Color',COR_TAU,'LineWidth',1.0,...
      'Label','63,2% (1τ)','LabelHorizontalAlignment','right','FontSize',8.5);
yline(nivel_2tau,':','Color',[0.35 0.50 0.10],'LineWidth',0.9,...
      'Label','86,5% (2τ)','LabelHorizontalAlignment','right','FontSize',8);
yline(nivel_3tau,':','Color',[0.45 0.45 0.05],'LineWidth',0.9,...
      'Label','95,0% (3τ)','LabelHorizontalAlignment','right','FontSize',8);
xline(tA,'-','Color',COR_TAU,'LineWidth',1.4,...
      'Label',sprintf('τ_A = %d ms',tA),...
      'LabelHorizontalAlignment','right','LabelVerticalAlignment','bottom',...
      'FontSize',9,'FontWeight','bold');
[~,idx_tau] = min(abs(s_A_med - nivel_1tau));
scatter(ts(idx_tau), s_A_med(idx_tau), 80, COR_TAU,'filled');
text(ts(idx_tau)+1, s_A_med(idx_tau)-0.06,...
     sprintf('(%s ms; %s)', numvir(ts(idx_tau),1), numvir(s_A_med(idx_tau),3)),...
     'Color',COR_TAU,'FontSize',8);
title(sprintf('Filtro de ATAQUE  |  τ_A = %d ms  |  α_A = %s',tA,numvir(alphaA,5)),...
      'FontSize',10,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Tempo (ms)','FontSize',10,'Color',COR_EIXO);
ylabel('s[n]  (resposta normalizada)','FontSize',10,'Color',COR_EIXO);
xlim([0, min(ts(end), 5*tA)]); ylim([0, 1.05]); grid on;
lg1=legend({'Teórica: 1-α_A^n','Medida: dif. iterada'},'Location','southeast','FontSize',8.5);
set(lg1,'TextColor',COR_TEXTO,'Color',[1.00 1.00 1.00]);
set(ax1,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

ax2 = subplot(1,2,2);
plot(ts_R, s_R_teo,'--','Color',COR_TEO_R,'LineWidth',1.3); hold on;
plot(ts_R, s_R_med,'-', 'Color',COR_MED_R,'LineWidth',2.0);
yline(nivel_1tau,':','Color',COR_TAU,'LineWidth',1.0,...
      'Label','63,2% (1τ)','LabelHorizontalAlignment','right','FontSize',8.5);
yline(nivel_2tau,':','Color',[0.35 0.50 0.10],'LineWidth',0.9,...
      'Label','86,5% (2τ)','LabelHorizontalAlignment','right','FontSize',8);
yline(nivel_3tau,':','Color',[0.45 0.45 0.05],'LineWidth',0.9,...
      'Label','95,0% (3τ)','LabelHorizontalAlignment','right','FontSize',8);
xline(tR,'-','Color',COR_TAU,'LineWidth',1.4,...
      'Label',sprintf('τ_R = %d ms',tR),...
      'LabelHorizontalAlignment','right','LabelVerticalAlignment','bottom',...
      'FontSize',9,'FontWeight','bold');
[~,idx_tauR] = min(abs(s_R_med - nivel_1tau));
scatter(ts_R(idx_tauR), s_R_med(idx_tauR), 80, COR_TAU,'filled');
text(ts_R(idx_tauR)+3, s_R_med(idx_tauR)-0.06,...
     sprintf('(%s ms; %s)', numvir(ts_R(idx_tauR),1), numvir(s_R_med(idx_tauR),3)),...
     'Color',COR_TAU,'FontSize',8);
title(sprintf('Filtro de LIBERAÇÃO  |  τ_R = %d ms  |  α_R = %s',tR,numvir(alphaR,5)),...
      'FontSize',10,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Tempo (ms)','FontSize',10,'Color',COR_EIXO);
ylabel('s[n]  (resposta normalizada)','FontSize',10,'Color',COR_EIXO);
xlim([0, min(ts_R(end), 4*tR)]); ylim([0, 1.05]); grid on;
lg2=legend({'Teórica: 1-α_R^n','Medida: dif. iterada'},'Location','southeast','FontSize',8.5);
set(lg2,'TextColor',COR_TEXTO,'Color',[1.00 1.00 1.00]);
set(ax2,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

sgtitle('G7 — Resposta ao Degrau  |  Verificação das Constantes de Tempo τ_A e τ_R',...
        'FontSize',12,'FontWeight','bold','Color',COR_TEXTO,...
        'BackgroundColor',COR_BG_FIG);

virgula([ax1 ax2]);

fprintf('G7 gerado.\n');
fprintf('  tau_A configurado=%dms | tau_A medido=%.1fms\n', tA, ts(idx_tau));
fprintf('  tau_R configurado=%dms | tau_R medido=%.1fms\n', tR, ts_R(idx_tauR));

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
exportgraphics(gcf,'fig_g7_resposta_degrau.png','Resolution',300,'BackgroundColor','white');
fprintf('  salvo em fig_g7_resposta_degrau.png\n');
