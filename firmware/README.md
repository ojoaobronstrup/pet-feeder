# ESP32 e LED

O protótipo usa um ESP32 Dev Module com LED externo. Desconecte o USB antes de montar o circuito. Ligue `GPIO23` a um resistor de 220–330 Ω, a outra ponta do resistor ao ânodo do LED (perna longa) e o cátodo (perna curta) a `GND`. Use o USB para alimentar e programar a placa.

1. Copie `include/secrets.example.h` para `include/secrets.h`. Se o arquivo já existir, preserve as credenciais Wi-Fi e acrescente as definições `FEEDER_API_URL` e `FEEDER_DEVICE_KEY`. O arquivo local é ignorado pelo Git.
2. Preencha o Wi-Fi de 2,4 GHz. Configure `FEEDER_API_URL` com o IP do computador que roda a API, por exemplo `http://192.168.1.10:5087`, sem barra final. Preencha `FEEDER_DEVICE_KEY` com o mesmo valor de `Device__ApiKey` na API. Use a mesma rede local para o ESP32 e o computador.
3. Nesta pasta, execute `pio run` para compilar e `pio run --target upload` para gravar. `pio device monitor` acompanha a conexão a 115200 baud.
4. Ao ver `API conectada.`, acione e desative o alimentador no aplicativo e confira o LED. Agende alguns minutos à frente, feche o aplicativo e mantenha a API e o ESP32 ligados. No horário salvo, o LED deve acender e apagar automaticamente depois de cerca de 10 segundos.

O LED começa apagado. A placa envia à API o estado aplicado em cada consulta e apaga o LED se ficar cerca de 15 segundos sem resposta válida. O HTTP entre a API e o ESP32 é destinado à rede local de bancada.
