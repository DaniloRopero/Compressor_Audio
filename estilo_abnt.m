function estilo_abnt(ax, opt)
% ESTILO_ABNT  Padroniza um eixo do MATLAB conforme as normas do trabalho.
%
%   estilo_abnt(ax)                 aplica o padrao completo
%   estilo_abnt(ax, 'semivirgula')  aplica tudo, menos a virgula decimal
%
% O QUE ELA RESOLVE
%   - fundo branco e escrita preta, legiveis na impressao
%   - VIRGULA como separador decimal nos dois eixos, conforme a
%     norma ortografica brasileira (o MATLAB usa ponto por padrao)
%   - remove a barra de ferramentas flutuante, que era impressa
%     dentro do PNG pelo exportgraphics
%   - grade discreta e caixa fechada
%
% COMO USAR NOS SEUS SCRIPTS G1 a G8
%   Coloque este arquivo na mesma pasta dos scripts e chame a
%   funcao DEPOIS de title, xlabel, ylabel e legend -- nunca antes.
%   O MATLAB so cria os objetos de texto no momento em que esses
%   comandos sao executados; chamada antes, a funcao nao encontra
%   nada para formatar. Foi exatamente esse o motivo de os titulos
%   terem saido mais claros que os eixos na primeira versao.
%
%       plot(ax, x, y);
%       title(ax, 'Curva estática de compressão');
%       xlabel(ax, 'Nível de entrada (dBFS)');
%       ylabel(ax, 'Nível de saída (dBFS)');
%       estilo_abnt(ax);              % <-- por ultimo
%
% LEMBRETE SOBRE ACENTUACAO
%   Esta funcao nao conserta os TEXTOS: ela so formata. Os rotulos
%   acentuados precisam ser digitados acentuados no script --
%   PARAMETROS -> PARÂMETROS, METRICAS -> MÉTRICAS, NIVEL -> NÍVEL,
%   atenuacao -> atenuação, relacao -> relação, ESTAVEL -> ESTÁVEL,
%   Regiao -> Região, Saida -> Saída. O MATLAB atual suporta UTF-8
%   sem problema; a ausencia de acento era digitacao, nao limitacao.
%
% TCC -- Danilo Francisco Ropero Sivirino

    if nargin < 2, opt = ''; end

    set(ax, 'Color','w', 'XColor','k', 'YColor','k', ...
            'GridColor',[0.20 0.20 0.20], 'GridAlpha',0.28, ...
            'FontSize',10, 'LineWidth',1.0, 'Box','on', ...
            'TickDir','out', 'XGrid','on', 'YGrid','on');

    set(ax.Title,  'Color','k', 'FontSize',11, 'FontWeight','bold');
    set(ax.XLabel, 'Color','k', 'FontSize',10);
    set(ax.YLabel, 'Color','k', 'FontSize',10);

    lg = get(ax, 'Legend');
    if ~isempty(lg)
        set(lg, 'TextColor','k', 'Color','w', ...
                'EdgeColor',[0.20 0.20 0.20], 'FontSize',9, 'Box','on');
    end

    if ~strcmpi(opt, 'semivirgula')
        virgulaDecimal(ax, 'X');
        virgulaDecimal(ax, 'Y');
    end

    % A barra de ferramentas flutuante era capturada pelo
    % exportgraphics e aparecia impressa no canto do PNG.
    try, ax.Toolbar = []; catch, end
    try, disableDefaultInteractivity(ax); catch, end
end

% -------------------------------------------------------------
function virgulaDecimal(ax, eixo)
% Converte os rotulos numericos do eixo para separador virgula,
% preservando a quantidade de casas que o MATLAB ja escolheu.
    try
        tk = get(ax, [eixo 'Tick']);
        if isempty(tk), return; end

        % numero de casas decimais necessarias
        casas = 0;
        for v = tk(:).'
            for c = 0:4
                if abs(v - round(v, c)) < 1e-9
                    casas = max(casas, c); break;
                end
            end
        end

        fmt = sprintf('%%.%df', casas);
        rot = arrayfun(@(v) strrep(sprintf(fmt, v), '.', ','), ...
                       tk(:), 'UniformOutput', false);
        set(ax, [eixo 'TickLabel'], rot);
        set(ax, [eixo 'TickLabelMode'], 'manual');
    catch
        % se o eixo for categorico ou logaritmico, deixa como esta
    end
end
