function s = numvir(v, casas)
%NUMVIR  Formata um número com vírgula decimal, para uso em rótulos.
%
%   numvir(0.632, 3)   ->  '0,632'
%   numvir(-6.5, 1)    ->  '-6,5'
%   numvir(2.27)       ->  '2,27'        (padrão: duas casas)
%
% Serve para os textos DENTRO do gráfico -- títulos, anotações, legendas.
% Os rótulos dos EIXOS são tratados pela função virgula.
%
% Por que não converter a string inteira com strrep: abreviações como
% "Incl." e "Fig. 1" também têm ponto, e virariam "Incl," e "Fig, 1".
% Converter número a número evita isso.
%
% NOTA DE IMPLEMENTAÇÃO
%   A precisão é montada no formato ANTES da chamada. O especificador
%   '%.*f', que em C toma a precisão como argumento, não é aceito pelo
%   sprintf do MATLAB.
%
% TCC -- Danilo Francisco Ropero Sivirino

    if nargin < 2 || isempty(casas), casas = 2; end

    fmt = sprintf('%%.%df', round(casas));   % ex.: casas=3  ->  '%.3f'
    s   = strrep(sprintf(fmt, v), '.', ',');
end
