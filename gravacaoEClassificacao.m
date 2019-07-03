function [cor,corVal] = gravacaoEClassificacao(recObj)

    %Gravação de áudio, extração de MFCCs e classificação
    close all, pause on;
    Fs = get(recObj,'SampleRate');

    %% Gravação do áudio

    disp('Após pressionar a tecla Enter, diga o nome da cor relativo à posição desejada');
    pause;
    disp('Gravação iniciada.');
    recordblocking(recObj, 3);
    disp('Gravação finalizada.');
    audio = getaudiodata(recObj);
    
    %% Extração de MFCCs
    
    mfcc = extracaoMFCC(audio,Fs);
    
    %% Classificação
    
    load('net');
    cores = net(mfcc);
    outCores = {'vermelho';'verde';'azul';'amarelo'};
    [val,i] = max(cores);
    cor = outCores(i);
    corVal = val;
    
end