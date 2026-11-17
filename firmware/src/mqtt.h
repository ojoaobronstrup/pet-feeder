#pragma once
#include <Arduino.h>

// Conecta ao broker e assina o tópico.
void mqttBegin();

// Chamar a cada iteração do loop(). Retorna a mensagem recebida,
// ou uma String vazia se não chegou nada.
String mqttLoop();
