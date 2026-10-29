%  G4 — NÍVEL (dBFS): ENTRADA vs. SAÍDA

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

xDB_t2 = 20*log10(0.80);
yDB_t2 = T + (xDB_t2-T)/R + M;
xDB_t3 = 20*log10(0.30);
xDB_t1 = 20*log10(0.10);
yDB_t1 = xDB_t1 + M;
if W>0 && 2*abs(xDB_t3-T)<=W
    yDB_t3_pre = xDB_t3 + (1/R-1)*(xDB_t3-T+W/2)^2/(2*W);
else
    yDB_t3_pre = T + (xDB_t3-T)/R;
end
yDB_t3 = yDB_t3_pre + M;

COR_BG_FIG  = [1.00 1.00 1.00];
COR_BG_AX   = [1.00 1.00 1.00];
COR_SAIDA   = [0.00 0.50 0.15];
COR_ENTRADA = [0.55 0.60 0.55];
COR_THRESH  = [0.80 0.10 0.10];
COR_TEXTO   = [0.10 0.10 0.10];
COR_EIXO    = [0.20 0.20 0.20];
COR_GRID    = [0.75 0.75 0.75];
COR_ANOT    = [0.65 0.45 0.00];
COR_DIV     = [0.55 0.55 0.55];
COR_NIVEL   = [0.00 0.45 0.20];

figure('Name','G4 — Nível dBFS [Verde]',...
       'NumberTitle','off','Position',[60 60 900 520],...
       'Color',COR_BG_FIG);

ax1 = subplot(2,1,1);
plot(t, xdB,'Color',[COR_ENTRADA, 0.7],'LineWidth',0.6);
hold on;
plot(t, ydB,'Color',COR_SAIDA,'LineWidth',0.9);
yline(T,'--','Color',COR_THRESH,'LineWidth',1.4,...
      'Label',sprintf('T = %d dBFS',T),...
      'LabelHorizontalAlignment','left','FontSize',8.5);
xline(1,':','Color',COR_DIV,'LineWidth',1.0);
xline(2,':','Color',COR_DIV,'LineWidth',1.0);
text(0.50,yDB_t1+3,sprintf('%s dBFS',numvir(yDB_t1,1)),...
     'Color',COR_NIVEL,'FontSize',8.5,'HorizontalAlignment','center');
text(1.50,yDB_t2+3,sprintf('%s dBFS',numvir(yDB_t2,1)),...
     'Color',COR_NIVEL,'FontSize',8.5,'HorizontalAlignment','center');
text(2.50,yDB_t3+3,sprintf('%s dBFS',numvir(yDB_t3,1)),...
     'Color',COR_NIVEL,'FontSize',8.5,'HorizontalAlignment','center');
title('G4 — Nível (dBFS)  |  Entrada vs. Saída  (Visão Geral)',...
      'FontSize',11,'FontWeight','bold','Color',COR_TEXTO);
ylabel('dBFS','FontSize',10,'Color',COR_EIXO);
xlim([0 dur]); ylim([-80 5]); grid on;
lg=legend({'Entrada x_G[n]','Saída y_{dB}[n]'},'Location','southeast','FontSize',9);
set(lg,'TextColor',COR_TEXTO,'Color',[1.00 1.00 1.00]);
set(ax1,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

ax2 = subplot(2,1,2);
t_zoom = [1.980, 2.200];
mask   = t >= t_zoom(1) & t <= t_zoom(2);
plot(t(mask),xdB(mask),'Color',[COR_ENTRADA,0.8],'LineWidth',1.0);
hold on;
plot(t(mask),ydB(mask),'Color',COR_SAIDA,'LineWidth',1.8);
yline(T,'--','Color',COR_THRESH,'LineWidth',1.3,...
      'Label','T = threshold','LabelHorizontalAlignment','left','FontSize',8.5);
yline(T-W/2,':','Color',[0.55 0.50 0.00],'LineWidth',0.9,...
      'Label',sprintf('T - W/2 = %d dB',T-round(W/2)),...
      'LabelHorizontalAlignment','right','FontSize',8);
yline(T+W/2,':','Color',[0.55 0.50 0.00],'LineWidth',0.9,...
      'Label',sprintf('T + W/2 = %d dB',T+round(W/2)),...
      'LabelHorizontalAlignment','right','FontSize',8);
xline(2.000,'-','Color',[0.80 0.10 0.10],'LineWidth',1.5,...
      'Label','t = 2,000 s','LabelHorizontalAlignment','right','FontSize',8.5);
% Anotacoes na area livre do topo (acima de -2 dBFS), com fundo branco para
% nao se confundirem com as ondas verdes do sinal comprimido.
text(2.190, 3.3, sprintf('Pico de entrada: %s dBFS (Região B)',numvir(xDB_t3,1)),...
     'Color',COR_ANOT,'FontSize',8.5,'HorizontalAlignment','right',...
     'BackgroundColor',[1 1 1],'Margin',1.5,'EdgeColor',[0.85 0.85 0.85]);
text(2.190, 1.0, sprintf('Pico de saída: %s dBFS',numvir(yDB_t3,1)),...
     'Color',COR_NIVEL,'FontSize',8.5,'HorizontalAlignment','right',...
     'BackgroundColor',[1 1 1],'Margin',1.5,'EdgeColor',[0.85 0.85 0.85]);
title(sprintf('Zoom: Trecho 3 — Região B (Soft Knee)  |  W = %d dB  |  [%d; %d] dBFS',...
      W,T-W/2,T+W/2),'FontSize',10,'FontWeight','bold','Color',COR_TEXTO);
xlabel('Tempo (s)','FontSize',10,'Color',COR_EIXO);
ylabel('dBFS','FontSize',10,'Color',COR_EIXO);
xlim(t_zoom); ylim([-20 5]); grid on;
set(ax2,'Color',COR_BG_AX,'XColor',COR_EIXO,'YColor',COR_EIXO,...
        'GridColor',COR_GRID,'GridAlpha',0.6,'FontSize',9,'Box','on');

sgtitle('G4 — Nível (dBFS): Entrada vs. Saída  |  Verificação da Equação 4.23',...
        'FontSize',12,'FontWeight','bold','Color',COR_TEXTO,...
        'BackgroundColor',COR_BG_FIG);

virgula([ax1 ax2]);

fprintf('G4 gerado.\n');

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
exportgraphics(gcf,'fig_g4_nivel_dbfs.png','Resolution',300,'BackgroundColor','white');
fprintf('  salvo em fig_g4_nivel_dbfs.png\n');
