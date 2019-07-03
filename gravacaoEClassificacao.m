function [cor,corVal] = gravacaoEClassificacao(recObj)

    %Grava��o de �udio, extra��o de MFCCs e classifica��o
    close all, pause on;
    Fs = get(recObj,'SampleRate');

    %% Grava��o do �udio

    disp('Ap�s pressionar a tecla Enter, diga o nome da cor relativo � posi��o desejada');
    pause;
    disp('Grava��o iniciada.');
    recordblocking(recObj, 3);
    disp('Grava��o finalizada.');
    audio = getaudiodata(recObj);
    
    %% Extra��o de MFCCs
    
    mfcc = extracaoMFCC(audio,Fs);
    
    %% Classifica��o
    
    load('net');
    cores = net(mfcc);
    outCores = {'vermelho';'verde';'azul';'amarelo'};
    [val,i] = max(cores);
    cor = outCores(i);
    corVal = val;
    
end