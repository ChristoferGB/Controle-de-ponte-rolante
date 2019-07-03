function varargout = Ponte_Rolante(varargin)
% ========================================================================
% Descrição: Código para a Ponte_Rolante.fig
%
% Autor: Christofer Galdino Bernardo
% Instituição: Instituto Federal do Espírito Santo
% Data: 03/07/2019
%
% Em caso de dúvidas, consultar o documento "CONTROLE ANTIBALANÇO DA CARGA 
% PARA UMA PONTE ROLANTE DIDÁTICA ACIONADA COM USO DE COMANDOS DE VOZ.pdf"
%
% Este código pode ser utilizado livremente conquanto que se faça 
% referência ao autor
% ========================================================================

% PONTE_ROLANTE MATLAB code for Ponte_Rolante.fig
%      PONTE_ROLANTE, by itself, creates a new PONTE_ROLANTE or raises the existing
%      singleton*.
%
%      H = PONTE_ROLANTE returns the handle to a new PONTE_ROLANTE or the handle to
%      the existing singleton*.
%
%      PONTE_ROLANTE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in PONTE_ROLANTE.M with the given input arguments.
%
%      PONTE_ROLANTE('Property','Value',...) creates a new PONTE_ROLANTE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Ponte_Rolante_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Ponte_Rolante_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Ponte_Rolante

% Last Modified by GUIDE v2.5 15-May-2019 10:47:16

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Ponte_Rolante_OpeningFcn, ...
                   'gui_OutputFcn',  @Ponte_Rolante_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Ponte_Rolante is made visible.
function Ponte_Rolante_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Ponte_Rolante (see VARARGIN)

% Choose default command line output for Ponte_Rolante
handles.output = hObject;

%Inicialização do objeto serial
global serial_port 
serial_port = serial('COM4'); %Cria um objeto de nome ComTest para configura e utilizar a comunicação serial
  
set(serial_port,'BaudRate',9600);
set(serial_port,'DataBits',8);
set(serial_port,'Parity','none');
set(serial_port,'StopBits',1);
set(serial_port,'FlowControl','none');
 
% Tamanho do Buffer de entrada
set(serial_port,'InputBufferSize',512);
 
% Tempo para receber algum dado (ms)
set(serial_port,'Timeout',5000);
% O programa aguarda este tempo para receber um dado, caso o dado não chegue, o programa segue adiante

%Configuração do timer do Plotter do gráfico
fopen(serial_port);

%Criação do objeto para gravação de áudio
global recObj
recObj = audiorecorder();

%Configuração do timer do plotter do gráfico da carga
handles.plotterTimer = timer('Name','plotterTimer',               ...
                      'Period',0.005,                    ... 
                      'StartDelay',0,                 ... 
                      'TasksToExecute',inf,           ... 
                      'ExecutionMode','fixedSpacing', ...
                      'TimerFcn',{@plotterTimerCallback,handles.figure1});

%Configuração do timer do modo Temporizado 
handles.temporizacaoTimer = timer('Name','temporizacaoTimer', ...
                                  'Period',0.001, ... 
                                  'StartDelay',str2double(get(handles.valorTemporizacao,'String')),                 ... 
                                  'TasksToExecute',inf,           ... 
                                  'ExecutionMode','fixedSpacing', ...
                                  'TimerFcn',{@temporizacaoTimerCallback,handles.figure1}); 

handles.graficoCarga = plot(0,0); ylim([300 600]);
xlabel('Tempo(s)');
ylabel('Carga');
handles.reenviosDePacote = 0;
handles.posicaoTemporizacao = 4; 
handles.distanciaPacote = str2double(get(handles.distanciaPos1,'String'));
handles.parado = true;
handles.enableTemporizacao = 0;
handles.sequenciaTemporizacao = zeros(1,4);

guidata(hObject,handles);

flushinput(serial_port);
start(handles.plotterTimer);

function [] = plotterTimerCallback(~,~,guiHandle)
     
global serial_port;

if ~isempty(guiHandle)
    
    handles = guidata(guiHandle);
    if ~isempty(handles)
        
        dado = fscanf(serial_port,'%d');
        receivedErrorCheck = dado/1000;
        if (~isempty(dado) && receivedErrorCheck > 1)   %Filtrar erros de leitura serial                            
                                                        %(vetor vazio e leitura errada)
            if dado == 1111     %Caso o microcontrolador tenha identificado erro no recebimento do pacote
                
                if handles.reenviosDePacote == 3        %Estourou o número de erros
                    uiwait(msgbox({'Erro no envio/recebimento do pacote de comunicação de dados!'...
                        'O número máximo de tentativas de reenvio foi alcançado.'...
                        'A comunicação com o microcontrolador será encerrada e o programa será fechado.'},...,
                        'Erro de Comunicação Serial','modal'));
                    btnSair_Callback(0, 0, handles);    %Encerra o programa
                else                                    %Se não estourou o número de erros, reenvia o pacote
                    handles.reenviosDePacote = handles.reenviosDePacote + 1;
                    envioDoPacote(handles);                
                end
                
            else
                
                handles.reenviosDePacote = 0;
                
                if (mod(dado,2) == 0)   %Verifica se a ponte está em movimento
                    handles.parado = true;
                    set(handles.isLigado,'Value',false);
                else
                    handles.parado = false;
                    set(handles.isLigado,'Value',true);
                end
                
                dado = floor(dado/10);  %Deixando apenas os 3 primeiros dígitos referentes à carga
                
                xOld = get(handles.graficoCarga,'XData');  
                xOldMax = xOld(end);
                yOld = get(handles.graficoCarga,'YData');

                if (xOldMax >= 50.0)    %Limpando o gráfico e iniciando novamente
                    xOld = 0;
                    xOldMax = 0;
                    yOld = 0;
                end

                xdata = [xOld (xOldMax+0.1)];
                ydata = [yOld dado];
                set(handles.graficoCarga,'XData',xdata,'YData',ydata);
                
                guidata(handles.output,handles);
                ligarTemporizacao(handles);
            end
            
        end
        
    end
    
end

flushinput(serial_port);

function habilitaLigarManual = ligarTemporizacao(handles)

habilitaLigarManual = false;

isTemporizado = get(handles.btnTemporizacao,'Value');
parado = handles.parado;
enabled = handles.enableTemporizacao;

if(isTemporizado)       %Se estiver com temporização acionada, não pode haver interferência manual
    if(parado && enabled)
        running = handles.temporizacaoTimer.Running;
        if(strcmp(running,'off'))
            handles.temporizacaoTimer.StartDelay = str2double(get(handles.valorTemporizacao,'String'));
            start(handles.temporizacaoTimer);
        end  
    else
        stop(handles.temporizacaoTimer);
    end
else                   %Se não estiver, o usuário pode acionar pelo botão manual de ligar
    habilitaLigarManual = true;
end

% UIWAIT makes Ponte_Rolante wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = Ponte_Rolante_OutputFcn(~, ~, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function Kpl_Callback(~, ~, handles)

kplString = get(handles.Kpl,'String');
kplString(kplString == ',') = '.';

kplMinimo = 1;
kplMaximo = 99;
kpl = str2double(kplString);

if kpl<kplMinimo 
    kpl = kplMinimo;
elseif kpl>kplMaximo
        kpl = kplMaximo;
end

set(handles.Kpl,'String',kpl);


% --- Executes during object creation, after setting all properties.
function Kpl_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Kpc_Callback(~,~, handles)

kpcString = get(handles.Kpc,'String');
kpcString(kpcString == ',') = '.';

kpcMinimo = 0;
kpcMaximo = 99;
kpc = str2double(kpcString);

if kpc<kpcMinimo 
    kpc = kpcMinimo;
elseif kpc>kpcMaximo
        kpc = kpcMaximo;
end

set(handles.Kpc,'String',kpc);


% --- Executes during object creation, after setting all properties.
function Kpc_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Kdc_Callback(~, ~, handles)

kdcString = get(handles.Kdc,'String');
kdcString(kdcString == ',') = '.';

kdcMinimo = 0;
kdcMaximo = 99;
kdc = str2double(kdcString);

if kdc<kdcMinimo 
    kdc = kdcMinimo;
elseif kdc>kdcMaximo
        kdc = kdcMaximo;
end

set(handles.Kdc,'String',kdc);


% --- Executes during object creation, after setting all properties.
function Kdc_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function distanciaPos1_Callback(~, ~, handles)

distanciaMinima = 8;
distanciaMaxima = 84;
distancia = round(str2double(get(handles.distanciaPos1,'String')));

if distancia<distanciaMinima 
    distancia = distanciaMinima;
elseif distancia>distanciaMaxima
        distancia = distanciaMaxima;
end

set(handles.distanciaPos1,'String',distancia);


% --- Executes during object creation, after setting all properties.
function distanciaPos1_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function distanciaPos2_Callback(~, ~, handles)

distanciaMinima = 8;
distanciaMaxima = 84;
distancia = round(str2double(get(handles.distanciaPos2,'String')));

if distancia<distanciaMinima 
    distancia = distanciaMinima;
elseif distancia>distanciaMaxima
        distancia = distanciaMaxima;
end

set(handles.distanciaPos2,'String',distancia);


% --- Executes during object creation, after setting all properties.
function distanciaPos2_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function distanciaPos3_Callback(~, ~, handles)

distanciaMinima = 8;
distanciaMaxima = 84;
distancia = round(str2double(get(handles.distanciaPos3,'String')));

if distancia<distanciaMinima 
    distancia = distanciaMinima;
elseif distancia>distanciaMaxima
        distancia = distanciaMaxima;
end

set(handles.distanciaPos3,'String',distancia);


% --- Executes during object creation, after setting all properties.
function distanciaPos3_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function distanciaPos4_Callback(~,~,handles)

distanciaMinima = 8;
distanciaMaxima = 84;
distancia = round(str2double(get(handles.distanciaPos4,'String')));

if distancia<distanciaMinima 
    distancia = distanciaMinima;
elseif distancia>distanciaMaxima
        distancia = distanciaMaxima;
end

set(handles.distanciaPos4,'String',distancia);


% --- Executes during object creation, after setting all properties.
function distanciaPos4_CreateFcn(hObject,~,~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function distancia = definicaoDistanciaPorPosicoes(posicao,handles)

switch posicao
    case 'Posição 1'
        distancia = str2double(get(handles.distanciaPos1,'String'));
    case 'Posição 2'
        distancia = str2double(get(handles.distanciaPos2,'String'));
    case 'Posição 3'
        distancia = str2double(get(handles.distanciaPos3,'String'));
    case 'Posição 4'
        distancia = str2double(get(handles.distanciaPos4,'String'));
end

function sequencia = definicaoSequenciaTemporizacaoComandoManual(handles)

sequencia = zeros(1,4);
posicoes = cellstr(get(handles.posicoes,'String'));

for i=1:4
    [k,~] = listdlg('PromptString',sprintf('Selecione a posição relativa ao %dº movimento',i),...
                    'SelectionMode','single',...
                    'ListString',posicoes,...
                    'ListSize',[240 60]);
    posicao = posicoes{k};
    sequencia(i) = definicaoDistanciaPorPosicoes(posicao,handles);
end

% --- Executes on button press in btnLigaManual.
function btnLigaManual_Callback(~, ~, handles)

isTemporizado = get(handles.btnTemporizacao,'Value');
if(isTemporizado)
    handles.enableTemporizacao = 1;
    handles.sequenciaTemporizacao = definicaoSequenciaTemporizacaoComandoManual(handles);
    guidata(handles.output,handles);
end

habilitaLigarManual = ligarTemporizacao(handles);
if(habilitaLigarManual)
    envioDoPacote(handles);
end


function [] = temporizacaoTimerCallback(~,~,guiHandle)

if ~isempty(guiHandle)
  handles = guidata(guiHandle);
  if ~isempty(handles)
      posicaoAnterior = handles.posicaoTemporizacao;
          
      if(posicaoAnterior == 4)
          posicao = 1;
      else
          posicao = posicaoAnterior + 1;
      end

      handles.distanciaPacote = handles.sequenciaTemporizacao(posicao);

      posicaoAnterior = posicao;
      handles.posicaoTemporizacao = posicaoAnterior;
      guidata(handles.output,handles);

      envioDoPacote(handles);
          
  end
end


function [] = envioDoPacote(handles)

distancia = num2str(handles.distanciaPacote - 4);   %O -4 é para considerar um offset devido à estrutura
                                                    %física que reflete os pulsos ultrassônicos
kpl = get(handles.Kpl,'String');
kpc = get(handles.Kpc,'String');
kdc = get(handles.Kdc,'String');

pacote = strcat('<',distancia,';',kpl,';',kpc,';',kdc,':'); %Montagem do pacote
sum = 0;
for i = 1:length(pacote)            %Soma dos valores do pacote
    if ((pacote(i) ~= '<') && (pacote(i) ~= ';') && (pacote(i) ~= ':') && (pacote(i) ~= '.'))
        sum = sum + pacote(i);
    end
end

sum = dec2bin(sum);
sum = bin2dec(sum((length(sum)-7):length(sum)));    %Soma truncada de 8 bits
checksum = (255 - sum) + 1;      %Checksum: complemento de 2

pacoteComChecksum = strcat(pacote,num2str(checksum),'>');

global serial_port
fprintf(serial_port,'%s',pacoteComChecksum);

stop(handles.temporizacaoTimer);


% --- Executes on button press in isLigado.
function isLigado_Callback(~, ~, handles)

isLigado = get(handles.btnLigaManual,'Value');

if isLigado == 1
    ledValue = 1;
else
    ledValue = 0;
end

set(handles.isLigado,'Value',ledValue);


% --- Executes on selection change in posicoes.
function posicoes_Callback(hObject,~,~)

if ~isempty(hObject)
  handles = guidata(hObject);
  if ~isempty(handles)
      
      contents = cellstr(get(handles.posicoes,'String'));
      posicao = contents{get(handles.posicoes,'Value')};
      
      handles.distanciaPacote = definicaoDistanciaPorPosicoes(posicao,handles);
      
      guidata(handles.output,handles);
      
  end
end

% --- Executes during object creation, after setting all properties.
function posicoes_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btnTemporizacao.
function btnTemporizacao_Callback(~, ~, handles)

btnTemporizacao = get(handles.btnTemporizacao,'Value');

if btnTemporizacao == 1
    ledValue = 1;
else
    ledValue = 0;
    stop(handles.temporizacaoTimer);
    handles.enableTemporizacao = 0;
end

set(handles.isTemporizado,'Value',ledValue);

guidata(handles.output,handles);


% --- Executes on button press in isTemporizado.
%Código duplicado para impedir que usuário acabe setando por si mesmo o
%valor do Led enquanto o programa roda
function isTemporizado_Callback(~, ~, handles)

btnTemporizado = get(handles.btnTemporizacao,'Value'); 

if btnTemporizado == 1
    ledValue = 1;
else
    ledValue = 0;
end

set(handles.isTemporizado,'Value',ledValue);


function valorTemporizacao_Callback(~, ~, handles)

isTemporizado = get(handles.btnTemporizacao,'Value');
parado = handles.parado;

if(isTemporizado && parado)
    stop(handles.temporizacaoTimer);
    handles.temporizacaoTimer.StartDelay = str2double(get(handles.valorTemporizacao,'String'));
    start(handles.temporizacaoTimer);
end


% --- Executes during object creation, after setting all properties.
function valorTemporizacao_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function txtPos_CreateFcn(~, ~, ~)


% --- Executes on selection change in selecionadorComandos.
function selecionadorComandos_Callback(~, ~, handles)

contents = cellstr(get(handles.selecionadorComandos,'String'));
tipoDeComando = contents{get(handles.selecionadorComandos,'Value')};

if strcmp(tipoDeComando,'Comando manual')
    set(handles.btnLigaManual,'Enable','on');
    set(handles.btnLigaManual,'Visible','on');
    set(handles.txtPos,'Visible','on');
    set(handles.posicoes,'Enable','on');
    set(handles.posicoes,'Visible','on');
    set(handles.txtPos1,'Visible','on');
    set(handles.txtPos2,'Visible','on');
    set(handles.txtPos3,'Visible','on');
    set(handles.txtPos4,'Visible','on');
    set(handles.distanciaPos1,'Visible','on');
    set(handles.distanciaPos2,'Visible','on');
    set(handles.distanciaPos3,'Visible','on');
    set(handles.distanciaPos4,'Visible','on');
    set(handles.btnFalarComandoPorVoz,'Enable','off');
    set(handles.btnFalarComandoPorVoz,'Visible','off');
elseif strcmp(tipoDeComando,'Comando por voz')
    set(handles.btnLigaManual,'Enable','off');
    set(handles.btnLigaManual,'Visible','off');
    set(handles.txtPos,'Visible','off');
    set(handles.posicoes,'Enable','off');
    set(handles.posicoes,'Visible','off');
    set(handles.txtPos1,'Visible','off');
    set(handles.txtPos2,'Visible','off');
    set(handles.txtPos3,'Visible','off');
    set(handles.txtPos4,'Visible','off');
    set(handles.distanciaPos1,'Visible','off');
    set(handles.distanciaPos2,'Visible','off');
    set(handles.distanciaPos3,'Visible','off');
    set(handles.distanciaPos4,'Visible','off');
    set(handles.btnFalarComandoPorVoz,'Enable','on');
    set(handles.btnFalarComandoPorVoz,'Visible','on');
end


% --- Executes during object creation, after setting all properties.
function selecionadorComandos_CreateFcn(hObject, ~, ~)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function distancia = definicaoDistanciaPelaCor(cor)

switch cor
    case 'vermelho'
        distancia = 10;
    case 'verde'
        distancia = 35;
    case 'azul'
        distancia = 55;
    case 'amarelo'
        distancia = 75;
end

function sequencia = definicaoSequenciaTemporizacaoComandoDeVoz(recObj)

sequencia = zeros(1,4);

for i=1:4
    %uiwait(msgbox(sprintf('Após pressionar o botão OK, diga o nome da cor relativa à %dª posição',i),...,
        %'Gravação de Voz','modal'));
    cor = gravacaoEClassificacao(recObj);
    sequencia(i) = definicaoDistanciaPelaCor(cor);
end

% --- Executes on button press in btnFalarComandoPorVoz.
function btnFalarComandoPorVoz_Callback(~, ~, handles)

global recObj;

isTemporizado = get(handles.btnTemporizacao,'Value');
if(isTemporizado)
    handles.enableTemporizacao = 1;
    handles.sequenciaTemporizacao = definicaoSequenciaTemporizacaoComandoDeVoz(recObj);
    guidata(handles.output,handles);
end

habilitaLigarManual = ligarTemporizacao(handles);
if(habilitaLigarManual)
    
    uiwait(msgbox('Após pressionar o botão OK, diga o nome da cor relativa à posição desejada',...,
        'Gravação de Voz','modal'));
    cor = gravacaoEClassificacao(recObj);
    handles.distanciaPacote = definicaoDistanciaPelaCor(cor);
    guidata(handles.output,handles);
    envioDoPacote(handles);
end


% --- Executes on button press in btnSair.
function btnSair_Callback(~, ~, handles)

stop(handles.plotterTimer);

global serial_port;
fclose(serial_port);
delete(serial_port);
clear serial_port;

close(handles.figure1);


% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(~, ~, ~)
