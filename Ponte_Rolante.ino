// ======================================================================
// Descrição: Controle da ponte rolante didática e comunicação serial 
// com a interface. Código para ser embarcado ao microcontrolador. Deve 
// ser utilizado em conjunto com o programa da interface gráfica do 
// usuário (Ponte_Rolante.m)
// Hardware: Arduino MEGA 2560
//
// Autor: Christofer Galdino Bernardo
// Instituição: Instituto Federal do Espírito Santo
// Data: 03/07/2019
//
// Em caso de dúvidas, consultar o documento "CONTROLE ANTIBALANÇO DA 
// CARGA PARA UMA PONTE ROLANTE DIDÁTICA ACIONADA COM USO DE COMANDOS 
// DE VOZ.pdf"
//
// Este código pode ser utilizado livremente conquanto que se faça 
// referência ao autor
// ======================================================================

#include <Fuzzy.h>
#include <FuzzyComposition.h>
#include <FuzzyInput.h>
#include <FuzzyIO.h>
#include <FuzzyOutput.h>
#include <FuzzyRule.h>
#include <FuzzyRuleAntecedent.h>
#include <FuzzyRuleConsequent.h>
#include <FuzzySet.h>
#include <Ultrasonic.h>

#define pinCarga A2
#define pinPWM2 2 //IN3
#define pinPWM1 3 //IN4
#define pinTrig 4 
#define pinEcho 5 

// Variáveis movimento lateral
int setpointLateral = 30, leiturasLateral[2], distancia;
double erroNormalizado = 0.00, velocidadeNormalizada = 0.00, kpl = 1, previousKpl = kpl; // kpl = 4.0;

// Variáveis balanço da carga
int setpointCarga = 469, lastCarga = setpointCarga, wrongCarga = setpointCarga, maxRange = setpointCarga + 10, minRange = setpointCarga - 10; 
double kpc = 0, kdc = 0, lastError = 1.0, P = 0.00, D = 0.00, error = 0.00; // kpc = 10.0, kdc = 0.0 
long lastProcess = 0, sampling;

// Variáveis da comunicação
int i = 0;
double valores[5] = {0};
char checksum = 0;
boolean stopChecksum = false, decimalValue = false;

// Variáveis comuns
double controle = 0.00, PWM = 0.00;
int n = 0, k = 0;
short movementFlag; // 1 - ligado; 0 - parado na posição

Ultrasonic ultrasonic(pinTrig, pinEcho);

// Instanciando um objeto da biblioteca Fuzzy
Fuzzy* fuzzy = new Fuzzy();

void inicializaFiltro (int vetor[], int valor) {  
  	
  	for (int i = 0; i < sizeof(vetor); i++) {
    	vetor[i] = valor;
  	}

}

int filtro (int vetor[], int novo) {    // Filtro média móvel
  	
  	for (int i = 0; i < (sizeof(vetor) - 1); i++) {
    	vetor[i] = vetor[i + 1];
  	}

  	vetor[(sizeof(vetor) - 1)] = novo;
  	long int somatorio = 0;

  	for (int i = 0; i < sizeof(vetor); i++) {
    	somatorio = somatorio + vetor[i];
  	}
  	somatorio = somatorio/sizeof(vetor);
  	
  	return somatorio;

}

void montaFuncoesDePertinenciaFuzzy (Fuzzy* fuzzy, float Kpl) {

    // Distância se dará pela diferença entre a distância do setpoint e a atual distância do carro da ponte
	// Com isso, distância mínima = 0 e distância máxima = 76cm (80 - 4)

	// Criando o FuzzyInput distancia
    FuzzyInput* distancia = new FuzzyInput(1);  // Como parametro seu ID

    // Criando os FuzzySet que compoem o FuzzyInput distancia
    FuzzySet* longeNegativo = new FuzzySet(-1,-1,-1/Kpl,0);     // Distancia grande 
    distancia->addFuzzySet(longeNegativo);                      // Adicionando o FuzzySet longeNegativo em distancia
    FuzzySet* perto = new FuzzySet(-1/Kpl,0,0,1/Kpl);           // Distancia segura
    distancia->addFuzzySet(perto);                              // Adicionando o FuzzySet perto em distancia
    FuzzySet* longePositivo = new FuzzySet(0,1/Kpl,1,1);        // Distancia grande
    distancia->addFuzzySet(longePositivo);                      // Adicionando o FuzzySet longePositivo em distancia

    fuzzy->addFuzzyInput(distancia); // Adicionando o FuzzyInput no objeto Fuzzy

    // Criando o FuzzyOutput velocidadee
    FuzzyOutput* velocidade = new FuzzyOutput(1);// Como parametro seu ID

    // Criando os FuzzySet que compoem o FuzzyOutput velocidadee
    FuzzySet* rapidoDireita = new FuzzySet(-2,-1,-1,0);     // Velocidade alta para a direita: Inicia em 55 por conta do tempo morto do motor
    velocidade->addFuzzySet(rapidoDireita);                 // Adicionando o FuzzySet rapidoDireita em velocidade
    FuzzySet* zero = new FuzzySet(-1,0,0,1);                // Velocidade baixa
    velocidade->addFuzzySet(zero);                          // Adicionando o FuzzySet zero em velocidade
    FuzzySet* rapidoEsquerda = new FuzzySet(0,1,1,2);       // Velocidade alta para a esquerda
    velocidade->addFuzzySet(rapidoEsquerda);                // Adicionando o FuzzySet rapidoEsquerda em velocidade

    fuzzy->addFuzzyOutput(velocidade); // Adicionando o FuzzyOutput no objeto Fuzzy

    // Montando as regras Fuzzy
    // FuzzyRule "SE distancia = longePositivo ENTAO velocidade = rapidoDireita"
    FuzzyRuleAntecedent* ifDistanciaLongePositivo = new FuzzyRuleAntecedent();      // Instanciando um Antecedente para a expressão
    ifDistanciaLongePositivo->joinSingle(longePositivo);                            // Adicionando o FuzzySet correspondente ao objeto Antecedente
    FuzzyRuleConsequent* thenVelocidadeRapidoDireita = new FuzzyRuleConsequent();   // Instancinado um Consequente para a expressão
    thenVelocidadeRapidoDireita->addOutput(rapidoDireita);                          // Adicionando o FuzzySet correspondente ao objeto Consequente
    // Instanciando um objeto FuzzyRule
    FuzzyRule* fuzzyRule01 = new FuzzyRule(1, ifDistanciaLongePositivo, thenVelocidadeRapidoDireita); // Passando o Antecedente e o Consequente da expressão

    fuzzy->addFuzzyRule(fuzzyRule01); // Adicionando o FuzzyRule ao objeto Fuzzy

    // FuzzyRule "SE distancia = perto ENTAO velocidade = zero"
    FuzzyRuleAntecedent* ifDistanciaPerto = new FuzzyRuleAntecedent();      // Instanciando um Antecedente para a expressão
    ifDistanciaPerto->joinSingle(perto);                                    // Adicionando o FuzzySet correspondente ao objeto Antecedente
    FuzzyRuleConsequent* thenVelocidadeZero = new FuzzyRuleConsequent();    // Instancinado um Consequente para a expressão
    thenVelocidadeZero->addOutput(zero);                                    // Adicionando o FuzzySet correspondente ao objeto Consequente
    // Instanciando um objeto FuzzyRule
    FuzzyRule* fuzzyRule02 = new FuzzyRule(2, ifDistanciaPerto, thenVelocidadeZero); // Passando o Antecedente e o Consequente da expressão

    fuzzy->addFuzzyRule(fuzzyRule02); // Adicionando o FuzzyRule ao objeto Fuzzy

    // FuzzyRule "SE distancia = longeNegativo ENTAO velocidade = rapidoEsquerda"
    FuzzyRuleAntecedent* ifDistanciaLongeNegativo = new FuzzyRuleAntecedent();      // Instanciando um Antecedente para a expressão
    ifDistanciaLongeNegativo->joinSingle(longeNegativo);                            // Adicionando o FuzzySet correspondente ao objeto Antecedente
    FuzzyRuleConsequent* thenVelocidadeRapidoEsquerda = new FuzzyRuleConsequent();  // Instancinado um Consequente para a expressão
    thenVelocidadeRapidoEsquerda->addOutput(rapidoEsquerda);                        // Adicionando o FuzzySet correspondente ao objeto Consequente
    // Instanciando um objeto FuzzyRule
    FuzzyRule* fuzzyRule03 = new FuzzyRule(3, ifDistanciaLongeNegativo, thenVelocidadeRapidoEsquerda); // Passando o Antecedente e o Consequente da expressão

    fuzzy->addFuzzyRule(fuzzyRule03); // Adicionando o FuzzyRule ao objeto Fuzzy

}

void comunicacao (int *setpointLateral, double *kpl, double *kpc, double *kdc) {  // Rotina de comunicação serial com a interface
  
    double checksumEnviado = 0;
    boolean comunicationFinished = false;
    static boolean recvInProgress = false;

    while(Serial.available() > 0){
      
        char byteRead = Serial.read();
        double valueRead = (double) byteRead - 48;  // Conversão de ASCII para int

        if (recvInProgress == true) {
            
            if (valueRead != 14) {      // ASCII para ">" = 62 - 48 = 14
                
                if(valueRead != 11 && valueRead != 10 && valueRead != -2) {    	// ASCII para ";" = 59 - 48 = 11
                                    					                        // ASCII para ":" = 58 - 48 = 10
            																	// ASCII para "." = 46 - 48 = -2
          
                    // Como o Arduino recebe um dígito por vez na porta serial, 
                    // é preciso ajustar os valores recebidos para se tornarem 
                    // igual ao número enviado
                    
                    if (!decimalValue) {			// Verifica se o valor a ser lido é decimal ou não, e ajusta o recebimento de acordo
                        valores[i] *= 10; 
                        valores[i] += valueRead;
                    } else {
                        valueRead /= 10;
                        valores[i] += valueRead;
                    }

                    if (!stopChecksum) {      		// Para de somar o checksum do recebedor a partir do início do checksum enviado
                        checksum += byteRead;
                    }

                } else {
                    
                    if (valueRead == -2) {			// Caso tenha chegado no caractere '.', indicando um valor decimal
                        decimalValue = true;
                    } else {

                        if (valueRead == 10) {		// Caso tenha chegado no caractere de separação ':', dando início ao checksum enviado
                            stopChecksum = true;
                        }

                        i += 1;
                        decimalValue = false;

                    }
                }

            } else {
                recvInProgress = false;
                stopChecksum = false;
                comunicationFinished = true;
                i = 0;
            }

        } else if (valueRead == 12) {               // ASCCI para "<" = 60 - 48 = 12
            recvInProgress = true;
        }

    }

    if (comunicationFinished) {

        checksumEnviado = valores[4];

        if (byte(checksum + checksumEnviado) == 0) {    // Se a soma dos checksums for nula, não houve erro na comunicação

            *setpointLateral = valores[0];
            *kpl = valores[1];
            *kpc = valores[2];
            *kdc = valores[3];

        } else {
            Serial.println(1111);               // Código de erro de leitura serial   
        }

        memset(valores, 0, sizeof(valores));    // Reseta o vetor de valores
        checksum = 0;
    }

  
}

void acionaPlaca (double valorControle) {       // Acionnamento do drive ponte-H do motor do carro da ponte rolante

    double PWM;

	if (valorControle > 0) {

      	if (valorControle > 255) {
        	valorControle = 255;
      	}

      	PWM = (0.784) * valorControle + 55;
      	analogWrite(pinPWM2, 0);
      	analogWrite(pinPWM1, PWM);

    } else if (valorControle < 0) {

      	valorControle = -valorControle;
      	if (valorControle > 255) {
        	valorControle = 255;
      	}

      	PWM = (0.784) * valorControle + 55;
      	analogWrite(pinPWM1, 0);
      	analogWrite(pinPWM2, PWM);

    } else if (valorControle == 0) {
      	
      	PWM = 0;

      	analogWrite(pinPWM1, 0);
      	analogWrite(pinPWM2, 0);

    }

}

void setup() {
    Serial.begin(9600);
    sampling = millis();
    inicializaFiltro(leiturasLateral, 81);
    montaFuncoesDePertinenciaFuzzy(fuzzy,kpl);
}

void loop() {

    comunicacao(&setpointLateral,&kpl,&kpc,&kdc);

    int carga = analogRead(pinCarga);

    if (abs(carga - lastCarga) >= 17) {            // Filtragem e correção do valor lido (valores espúrios)
       	wrongCarga = carga;
       	carga = lastCarga;
       	n += 1;
    } else {
        n = 0;
    }
    if (n >= 3) {
     	carga = wrongCarga;
    }

	if (carga > maxRange || carga < minRange) {    // Controle antibalanço da carga
		
		float dt = (millis() - lastProcess) / 1000.0; 

	  	error = setpointCarga - carga;
	  	P = kpc * error;
      	D = (lastCarga - carga) * kdc / dt;

	  	controle = P + D;

	} else {                                       // Controle fuzzy dos movimentos laterais do carro

		if ((millis() - sampling) >= 10 ) {        // Temporização necessária para bom funcionamento do ultrassom

			sampling = millis();

			long microsec = ultrasonic.timing();
	    	int readDistance = ultrasonic.convert(microsec, Ultrasonic::CM);
	    	distancia = filtro(leiturasLateral, readDistance);

	    	double erroLido = setpointLateral - distancia;
	    	erroNormalizado = erroLido/76;

	    	if (kpl != previousKpl) {              // Caso o ganho tenha sido alterado pelo usuário na interface

          		fuzzy = NULL;
          		fuzzy = new Fuzzy();
          		montaFuncoesDePertinenciaFuzzy(fuzzy,kpl);
          
	    	}
  
	    	fuzzy->setInput(1,erroNormalizado);

	  		fuzzy->fuzzify();
	  
	  		float velocidadeSaida = fuzzy->defuzzify(1);
        	velocidadeNormalizada = velocidadeSaida*255; 	
        
        	previousKpl = kpl;
	  		controle = roundf(velocidadeNormalizada*100)/100;

	    	if ((distancia <= 5 && controle > 0) || (distancia >= 78 && controle < 0)) {
	      		controle = 0;
	    	}

	    }

	}

	lastProcess = millis();
	lastCarga = carga;

    acionaPlaca(controle);

    if(controle == 0 && distancia == setpointLateral) {     // Caso o carro tenha chegado no seu destino
        movementFlag = 0;
    } else {                                                // Caso contrário
        movementFlag = 1; 
    }

//    if(carga > 600) {
//        movementFlag = 0;
//    } else {
//        movementFlag = 1; 
//    }

    Serial.println((10*carga) + movementFlag);              // Envia para a interface via comunicação serial

//    Serial.print('<');
//    Serial.print(carga);
//    Serial.print(movementFlag);
//    Serial.println('>');

}
