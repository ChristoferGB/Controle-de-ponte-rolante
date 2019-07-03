function mfcc = extracaoMFCC(audio,fs)

    % Caracter�sticas
    windowLength = 0.025;
    windowStep = 0.01;
    audioLength = length(audio)/fs;
    numberSamples = floor(fs * windowLength);
    overlapSamples = floor(fs * (windowLength - windowStep));
    preemph = 0.97;

    %Remo��o dos blocos com energia menor que 1% da m�xima (sil�ncio)
    yNormInit = (audio*0.5)/max(abs(audio));    %Dados normalizados (-1 a 1)
    yBlk = reshape(yNormInit,[fs*windowLength,audioLength/windowLength]);     %Organizando o �udio em blocos
    E = sum(yBlk(:,:).^2);                      %C�lculo da energia de cada bloco
    Emax = max(E);                              %Energia m�xima
    n = [];
    for k=1:length(E)                           %Verifica quais blocos tem menos que 1% de Emax
        if E(k)<0.01*Emax
            n = [n k];
        end
    end
    yBlk(:,n) = [];                             %Remove os blocos com menos de 1% de Emax
    y = yBlk(:);

    yNorm = y/max(abs(y));                      %Dados normalizados (-1 a 1)
    yNorm = filter([1 -preemph], 1, yNorm);     %Pre-�nfase
    yFrames = buffer(yNorm,numberSamples,overlapSamples,'nodelay'); %Frames de 25ms e overlap de 15ms
    h = hamming(size(yFrames,1));               %Janela de Hamming
    yHammed = yFrames.*repmat(h(:),[1,size(yFrames,2)]);            %Sinal janelado
    nFFT = 512;
    yFFT = abs(fft(yHammed(:,:),nFFT/2 + 1));   %FFT e espectro de magnitude
    powerSpec = 1/nFFT * yFFT.^2;               %Espectro de pot�ncia

    %Constru��o do Mel filterbank
    filterLength = nFFT/2+1;                    %Comprimento de cada filtro
    numberFilters = 26;                         %N�mero de filtros
    hz2mel = @(hz)(1127*log(1+hz/700));         %Hertz para mel warping function
    mel2hz = @(mel)(700*exp(mel/1127)-700);     %Mel para Hertz warping function
    H1 = trifbank(numberFilters, filterLength, [0 fs/2], fs, hz2mel, mel2hz ); %Mel filterbank

    yFiltered = H1*powerSpec;                   %Filtragem do espectro de pot�ncia
    yFiltered(yFiltered == 0) = eps;            %Substitui��o dos valores nulos para evitar erros na hora do log
    yLog = log10(yFiltered);                    %Aplica��o do logaritmo
    features = dct(yLog);                       %DCT
    features = features(2:14,:);                %Treze primeiros coeficientes
    mfcc = mean(features,2);
    plot(1:length(mfcc),mfcc);

end