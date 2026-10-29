function virgula(ax)
%VIRGULA  Troca o ponto decimal por vírgula nos rótulos dos eixos.
%
%   virgula(ax)        aplica a um eixo
%   virgula([a1 a2])   aplica a vários
%   virgula()          aplica ao eixo corrente
%
% O MATLAB escreve "0.5"; a norma ortográfica brasileira exige "0,5".
% Esta função converte os rótulos já escolhidos pelo MATLAB, preservando
% a quantidade de casas decimais que ele decidiu usar.
%
% CHAME POR ÚLTIMO, depois de xlim, ylim, title, xlabel e legend. O
% MATLAB só define a posição final dos ticks quando o eixo está pronto;
% chamada antes, a conversão é desfeita no redesenho.
%
% Eixos logarítmicos e categóricos são ignorados sem erro.
%
% NOTA DE IMPLEMENTAÇÃO
%   A precisão é montada no formato ANTES da chamada ao sprintf. O
%   especificador '%.*f', que em C toma a precisão como argumento, não
%   é aceito pelo sprintf do MATLAB.
%
% TCC -- Danilo Francisco Ropero Sivirino

    if nargin < 1 || isempty(ax), ax = gca; end

    for a = reshape(ax, 1, [])
        converte(a, 'X');
        converte(a, 'Y');
    end
end

% -------------------------------------------------------------
function converte(a, eixo)
    try
        if strcmpi(get(a, [eixo 'Scale']), 'log'), return; end

        tk = get(a, [eixo 'Tick']);
        if isempty(tk) || ~isnumeric(tk), return; end

        % quantas casas decimais o conjunto de ticks exige
        casas = 0;
        for v = reshape(tk, 1, [])
            for c = 0:4
                if abs(v - round(v, c)) < 1e-9
                    casas = max(casas, c);
                    break;
                end
            end
        end

        fmt = sprintf('%%.%df', casas);      % ex.: casas=1  ->  '%.1f'
        rot = cell(numel(tk), 1);
        for k = 1:numel(tk)
            rot{k} = strrep(sprintf(fmt, tk(k)), '.', ',');
        end

        set(a, [eixo 'TickLabel'], rot);
        set(a, [eixo 'TickLabelMode'], 'manual');
    catch
        % eixo categórico, datetime ou sem ticks numéricos: deixa como está
    end
end
