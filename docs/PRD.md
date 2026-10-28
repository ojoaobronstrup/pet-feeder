# PRD — Alimentador de Pet

**Versão:** 1.0 — Draft inicial  
**Produto:** Aplicativo mobile para alimentador inteligente de pets  
**Plataformas:** iOS e Android  
**Identidade visual:** Cosmic Dark / SpaceX-inspired  
**Status:** Planejamento

---

## 1. Visão geral

O Alimentador de Pet é uma solução IoT composta por um dispositivo físico inteligente e um aplicativo mobile, permitindo que tutores monitorem e controlem a alimentação de seus animais remotamente.

O aplicativo deve oferecer uma experiência premium, minimalista e intuitiva, com identidade visual cósmica e escura, inspirada na linguagem estética da SpaceX.

A experiência deve priorizar três aspectos:

- **Conveniência:** alimentar e acompanhar o pet de qualquer lugar.
- **Confiabilidade:** transmitir informações claras sobre o estado do dispositivo e a execução das alimentações.
- **Simplicidade:** permitir acesso rápido às principais funções, sem navegação desnecessária.

## 2. Objetivos do produto

### Objetivos principais

1. Permitir o gerenciamento remoto de um ou vários alimentadores.
2. Possibilitar alimentações manuais e programadas.
3. Monitorar o estado físico e operacional dos dispositivos.
4. Disponibilizar vídeo ao vivo e comunicação por áudio com o pet.
5. Registrar o histórico de alimentações.
6. Permitir o compartilhamento seguro de alimentadores entre usuários.
7. Simplificar a configuração inicial de novos dispositivos.

### Público-alvo

Tutores de cães e gatos que desejam automatizar a alimentação de seus animais, especialmente pessoas que trabalham fora, viajam ou compartilham os cuidados do pet com familiares.

---

## 3. Design e identidade visual

### 3.1. Direção estética

O aplicativo deve apresentar uma identidade visual denominada **Cosmic Dark**, inspirada na estética tecnológica e minimalista da SpaceX, sem utilizar marcas, logotipos ou elementos proprietários da empresa.

Características:

- Interface predominantemente preta.
- Tipografia moderna, limpa e de alta legibilidade.
- Elementos geométricos simples e precisos.
- Espaçamentos generosos.
- Ícones minimalistas.
- Transições suaves e discretas.
- Animações com finalidade funcional.
- Destaques em branco, cinza e azul frio.
- Efeitos luminosos extremamente sutis.
- Ausência de elementos decorativos excessivos.

A sensação desejada é a de um painel de controle de tecnologia avançada, mas acessível ao consumidor.

### 3.2. Paleta de cores

| Elemento | Cor | Hexadecimal |
|---|---|---|
| Fundo principal | Preto espacial | `#05070A` |
| Superfície secundária | Grafite profundo | `#10141B` |
| Superfície elevada | Cinza espacial | `#1A2029` |
| Texto principal | Branco gelo | `#F5F7FA` |
| Texto secundário | Cinza lunar | `#8D98A6` |
| Destaque | Azul orbital | `#5B9DFF` |
| Sucesso | Verde suave | `#48CFA0` |
| Atenção | Âmbar | `#F0B45B` |
| Erro | Vermelho suave | `#EF6666` |

O azul orbital deve ser utilizado moderadamente, principalmente para representar ações ativas, conexões e controles selecionados.

### 3.3. Tipografia

Sugestão: Inter, com pesos Regular, Medium e Semibold.

Os indicadores numéricos devem possuir destaque visual, especialmente informações como bateria, nível de ração e quantidade dispensada.

### 3.4. Componentes

Botões principais com contraste elevado, cantos discretamente arredondados e feedback visual ao toque.

Cards com superfícies escuras, bordas finas e separação visual sutil.

Indicadores de progresso lineares ou circulares para bateria e nível de ração.

A interface deve respeitar as áreas seguras do iOS e Android e permitir acessibilidade por leitores de tela.

---

## 4. Autenticação e gerenciamento de conta

### RF-001 — Autenticação social

O aplicativo deve oferecer exclusivamente autenticação por provedores OAuth/OIDC:

- Continuar com Google.
- Continuar com Apple.

Não será necessário implementar autenticação por e-mail e senha.

O backend deverá validar a identidade informada pelos provedores e gerenciar sessões próprias da aplicação.

### RF-002 — Persistência de sessão

A sessão deverá permanecer ativa entre aberturas do aplicativo, enquanto válida.

O aplicativo deve renovar as credenciais de sessão de forma segura, quando aplicável.

### RF-003 — Perfil do usuário

O usuário poderá consultar e editar os seguintes campos:

- Nome de exibição.
- Foto de perfil.
- Idioma e preferências de notificações.
- Configurações de conta.

O e-mail associado ao provedor deve ser apresentado quando disponibilizado pelo serviço de autenticação.

### RF-004 — Encerramento de sessão

O usuário poderá encerrar sua sessão a qualquer momento.

O sistema também deverá permitir solicitar a exclusão da conta, respeitando regras de retenção e propriedade dos dispositivos.

---

## 5. Navegação após autenticação

A navegação inicial depende diretamente da quantidade de alimentadores vinculados à conta.

### RF-005 — Conta sem alimentadores

Quando não existir nenhum alimentador vinculado:

- Exibir uma tela vazia intencional, com composição centralizada.
- Apresentar uma mensagem curta e objetiva.
- Destacar um botão principal para configurar o primeiro alimentador.
- Evitar cards e informações sem utilidade nessa situação.

**Exemplo de conteúdo:**

Título: Seu espaço começa aqui.

Descrição: Conecte seu primeiro alimentador e acompanhe seu pet de qualquer lugar.

Botão: **Configurar alimentador**

### RF-006 — Conta com um alimentador

Quando existir exatamente um alimentador vinculado, o aplicativo deverá abrir diretamente o dashboard desse dispositivo.

O usuário não deverá ser obrigado a passar por uma tela de seleção.

### RF-007 — Conta com múltiplos alimentadores

Quando existirem dois ou mais alimentadores, exibir uma tela de seleção com cards individuais, contendo:

- Nome do alimentador.
- Nome do pet associado.
- Status de conectividade.
- Nível de bateria.
- Nível de ração.
- Acesso ao dashboard.

Deve ser possível adicionar novos alimentadores nessa tela.

O usuário poderá alternar entre os dispositivos sem precisar encerrar a sessão.

---

## 6. Dashboard do alimentador

O dashboard constitui a interface principal do aplicativo e deve apresentar rapidamente as informações mais relevantes do dispositivo.

### RF-008 — Identificação do dispositivo

Exibir:

- Nome configurado para o alimentador.
- Nome do pet.
- Estado de conexão.
- Última sincronização.

O nome do dispositivo e do pet poderá ser alterado pelo proprietário ou por um usuário com permissão adequada.

### RF-009 — Monitoramento da bateria

Apresentar a porcentagem estimada de bateria, de 0% a 100%, acompanhada de representação visual.

Estados:

- Normal.
- Bateria baixa.
- Bateria crítica.
- Carregando, quando suportado pelo hardware.
- Informação indisponível.

Abaixo de um limite configurado, o aplicativo deverá informar que a bateria precisa de atenção.

### RF-010 — Nível de ração

O dashboard deverá mostrar a porcentagem estimada de alimento disponível no reservatório.

A interface deverá diferenciar:

- Reservatório cheio.
- Nível intermediário.
- Nível baixo.
- Reservatório vazio.
- Leitura indisponível.

A precisão dependerá do sensor e da calibração disponibilizados pelo hardware.

### RF-011 — Estado operacional

Exibir se o dispositivo está:

- Online e disponível.
- Offline.
- Dispensando alimento.
- Em configuração.
- Com erro operacional.

O estado operacional deverá ser distinto do estado de alimentação elétrica.

### RF-012 — Última alimentação

Mostrar data, horário e quantidade dispensada na última alimentação concluída e confirmada pelo dispositivo.

Quando não houver histórico, apresentar uma mensagem informativa, sem dados fictícios.

### RF-013 — Alimentação manual

Disponibilizar uma ação principal **Dispensar ração**.

O usuário poderá selecionar a quantidade desejada, expressa em gramas ou porções calibradas.

Antes do comando, o sistema poderá solicitar confirmação para prevenir acionamentos acidentais.

Durante a execução, apresentar estados de envio, processamento, sucesso ou falha.

O aplicativo não deverá considerar um despejo concluído apenas porque o comando foi enviado.

### RF-014 — Alimentação programada

Permitir a criação de rotinas automáticas contendo:

- Horário.
- Dias da semana.
- Quantidade de ração.
- Estado ativo ou inativo.

O usuário poderá editar, pausar e excluir programações.

O sistema deverá prevenir agendamentos duplicados acidentais e sinalizar possíveis conflitos.

A programação deve continuar funcionando quando o celular estiver fechado, conforme a capacidade do dispositivo.

---

## 7. Câmera e comunicação por áudio

### RF-015 — Visualização ao vivo

Disponibilizar uma tela para visualizar a transmissão da câmera integrada ao alimentador.

A interface deverá possuir:

- Área de vídeo em destaque.
- Indicador de conexão.
- Estado de carregamento.
- Informação de indisponibilidade.
- Opção para ampliar o vídeo.
- Controles de áudio.

O sistema deverá restringir o acesso à transmissão a contas autorizadas.

### RF-016 — Microfone

Permitir que o usuário utilize o microfone do smartphone para transmitir sua voz pelo alto-falante do alimentador, quando o hardware oferecer esse recurso.

A interface deverá apresentar um controle claro de ativação e desativação, com indicador visível durante a transmissão.

O acesso ao microfone dependerá da permissão concedida pelo sistema operacional.

### RF-017 — Áudio ambiente

Permitir ouvir o áudio captado pelo microfone do alimentador, quando disponível.

O áudio deverá poder ser silenciado independentemente do vídeo.

### RF-018 — Erros de transmissão

Quando a conexão falhar, o aplicativo deverá apresentar uma mensagem objetiva e oferecer a possibilidade de tentar novamente.

A indisponibilidade da câmera não deverá impedir o acesso às demais funcionalidades que continuarem operacionais.

---

## 8. Histórico de alimentações

### RF-019 — Consulta ao histórico

Disponibilizar uma tela contendo todos os eventos de alimentação associados ao dispositivo.

Cada registro deverá apresentar:

- Data e horário.
- Quantidade solicitada.
- Quantidade efetivamente dispensada, quando mensurável.
- Origem do evento.
- Resultado da operação.

Origens possíveis:

- Alimentação manual.
- Alimentação programada.
- Alimentação iniciada localmente no dispositivo.

Resultados possíveis:

- Concluída.
- Parcialmente concluída.
- Falhou.
- Cancelada.

### RF-020 — Filtros

Permitir filtrar os eventos por intervalo de datas, origem e resultado.

### RF-021 — Detalhes do evento

Ao selecionar uma alimentação, apresentar os detalhes relevantes, incluindo horário de início, término, usuário responsável (quando aplicável) e eventuais erros.

Um registro confirmado não deverá ser alterado silenciosamente.

---

## 9. Configuração de novos alimentadores

### RF-022 — Início do pareamento

A partir da ação **Configurar alimentador**, iniciar um fluxo guiado.

Etapas propostas:

1. Preparar e ligar o alimentador.
2. Identificar o dispositivo pelo método de pareamento disponibilizado pelo hardware.
3. Configurar a conexão Wi-Fi.
4. Vincular o dispositivo à conta autenticada.
5. Definir nome do alimentador e do pet.
6. Validar a comunicação.
7. Apresentar o dashboard.

O método de descoberta poderá utilizar Bluetooth Low Energy, rede temporária ou outro recurso definido na arquitetura de hardware.

### RF-023 — Segurança do vínculo

Um dispositivo deverá possuir identidade própria e comprovação de posse para o primeiro vínculo.

O sistema não deverá permitir que terceiros reivindiquem dispositivos pertencentes a outras contas sem autorização ou procedimento explícito de transferência.

### RF-024 — Falhas na configuração

Cada etapa deverá possuir feedback de sucesso, progresso e erro.

Deverá existir uma forma de repetir etapas quando ocorrerem problemas de conexão ou configuração.

---

## 10. Compartilhamento de alimentadores

### RF-025 — Gerenciamento de membros

O proprietário poderá compartilhar um alimentador com outras contas existentes ou convidar pessoas que ainda não utilizam o aplicativo.

Um alimentador poderá ter vários usuários autorizados, mas somente um proprietário principal na primeira versão.

### RF-026 — Convites

O sistema poderá enviar convites por link seguro ou e-mail.

O convite deverá:

- Identificar o alimentador compartilhado.
- Exigir autenticação do destinatário.
- Possuir prazo de validade.
- Ser invalidado após o uso.
- Permitir revogação pelo proprietário.

O compartilhamento deverá ser confirmado explicitamente pelo destinatário.

### RF-027 — Permissões

O aplicativo deverá oferecer inicialmente dois papéis:

| Funcionalidade | Proprietário | Convidado |
|---|---|---|
| Visualizar dashboard | Sim | Sim |
| Ver câmera e ouvir áudio | Sim | Sim |
| Falar pelo microfone | Sim | Sim |
| Dispensar ração | Sim | Sim |
| Consultar histórico | Sim | Sim |
| Gerenciar programações | Sim | Não |
| Alterar Wi-Fi e configurações críticas | Sim | Não |
| Convidar/remover usuários | Sim | Não |
| Remover ou transferir dispositivo | Sim | Não |

O proprietário poderá revogar o acesso a qualquer momento.

Permissões mais granulares poderão ser disponibilizadas em versões futuras.

---

## 11. Notificações

### RF-028 — Alertas operacionais

O aplicativo deverá suportar notificações para eventos como:

- Bateria baixa.
- Ração em nível baixo.
- Alimentação concluída.
- Falha ao dispensar ração.
- Alimentador offline por período relevante.
- Dispositivo novamente online.
- Convite de compartilhamento recebido.

O usuário poderá configurar as categorias de notificações que deseja receber.

Alertas críticos deverão possuir prioridade diferenciada, respeitando as permissões do sistema operacional.

---

## 12. Estrutura de navegação

### 12.1. Fluxo principal

**Splash Screen → Autenticação → Verificação dos alimentadores**

- 0 alimentadores → Empty State → Configuração.
- 1 alimentador → Dashboard diretamente.
- 2 ou mais alimentadores → Seleção → Dashboard.

### 12.2. Navegação do dispositivo

O dashboard deverá disponibilizar acesso às áreas:

- **Início:** status, indicadores e alimentação manual.
- **Câmera:** vídeo ao vivo e áudio.
- **Histórico:** registro de alimentações.
- **Programação:** gerenciamento de horários.
- **Configurações:** informações, compartilhamento e administração do dispositivo.

A navegação poderá utilizar uma barra inferior para as seções mais frequentes e uma área de configurações secundária.

---

## 13. Diretrizes de UX

### 13.1. Clareza

As informações críticas deverão ser compreendidas sem necessidade de interpretação de gráficos complexos.

Indicadores visuais deverão sempre possuir rótulos ou descrições.

### 13.2. Feedback

Toda ação remota deverá apresentar seu estado real.

A interface deverá diferenciar claramente comando enviado, comando recebido e execução concluída.

### 13.3. Estados vazios

Telas sem dados deverão possuir textos contextualizados e, quando aplicável, ações úteis.

### 13.4. Funcionamento offline

Quando o smartphone estiver sem internet ou o dispositivo ficar inacessível, apresentar informações armazenadas com indicação de quando foram atualizadas.

Não apresentar dados antigos como se fossem leituras em tempo real.

### 13.5. Segurança operacional

A interface deverá evitar acionamentos acidentais e comandos simultâneos incompatíveis.

A aplicação deverá respeitar as limitações e mecanismos de proteção implementados no próprio alimentador.

---

## 14. Requisitos não funcionais

### RNF-001 — Plataformas

O aplicativo deverá funcionar nas versões de iOS e Android oficialmente suportadas pelo framework escolhido.

### RNF-002 — Desempenho

O dashboard deverá priorizar carregamento rápido, utilizando cache local para informações não sensíveis e atualizando os estados quando houver conectividade.

### RNF-003 — Segurança

- Comunicação com backend por HTTPS/TLS.
- Tokens de sessão armazenados em mecanismos seguros do sistema operacional.
- Autorização validada no servidor para todas as operações.
- Segregação de dados por usuário e dispositivo.
- Proteção de credenciais de rede.
- Transmissão de vídeo e áudio com controle de acesso.
- Auditoria de ações relevantes, como compartilhamentos e comandos de alimentação.

### RNF-004 — Privacidade

O aplicativo deverá tratar dados pessoais de acordo com a LGPD e disponibilizar informações transparentes sobre coleta, armazenamento e uso dos dados.

A câmera e o microfone não deverão ser utilizados sem autorização apropriada.

O MVP não exige gravação contínua de vídeo nem armazenamento de áudio na nuvem.

### RNF-005 — Confiabilidade

Comandos de alimentação deverão utilizar identificadores únicos para prevenir execuções duplicadas causadas por novas tentativas de envio.

O dispositivo deverá fornecer confirmações e estados de execução quando tecnicamente possível.

### RNF-006 — Escalabilidade

A arquitetura deverá permitir múltiplos dispositivos por conta e múltiplas contas autorizadas para um mesmo dispositivo.

---

## 15. Arquitetura técnica proposta

### Aplicativo

**React Native + Expo + TypeScript**, com componentes reutilizáveis e estrutura modular por funcionalidade.

### Backend

API responsável por:

- Identidade e sessões.
- Gerenciamento de contas.
- Registro e propriedade de dispositivos.
- Compartilhamentos e autorizações.
- Agendamentos e configurações.
- Armazenamento de eventos.
- Comandos remotos.
- Notificações.

### Dispositivo IoT

O firmware deverá controlar:

- Motor de dispensação.
- Conectividade.
- Monitoramento da bateria.
- Leitura do nível de ração.
- Execução das programações.
- Confirmação de eventos.
- Integração com câmera e áudio, quando suportados.

### Comunicação

Sugestão inicial:

- HTTPS para operações administrativas e consulta.
- MQTT sobre TLS para telemetria e comandos IoT.
- WebRTC ou solução equivalente para comunicação de vídeo e áudio em tempo real.

A escolha definitiva deverá considerar as capacidades do microcontrolador, disponibilidade de memória, custo do hardware e infraestrutura necessária.

---

## 16. Escopo de desenvolvimento

### MVP — Primeira versão

Funcionalidades essenciais:

- Autenticação Google e Apple.
- Persistência de sessão.
- Listagem e seleção de alimentadores.
- Entrada direta quando houver um único dispositivo.
- Tela vazia com configuração destacada.
- Configuração e vinculação de dispositivos.
- Dashboard de monitoramento.
- Alimentação manual.
- Programação de alimentações.
- Histórico de eventos.
- Compartilhamento básico entre contas.
- Tratamento de dispositivos offline.
- Notificações essenciais.

### Versão 1.1 — Monitoramento audiovisual

- Câmera ao vivo.
- Áudio ambiente.
- Comunicação por voz.
- Melhorias na experiência de conectividade.
- Diagnósticos adicionais do dispositivo.

### Versão 1.2 — Recursos avançados

- Relatórios de consumo de ração.
- Gráficos por dia, semana e mês.
- Múltiplos perfis de pets.
- Permissões personalizadas.
- Calibração avançada de porções.
- Atualização remota de firmware.
- Melhorias na automação de horários.

A câmera e o áudio continuam sendo requisitos do produto completo, mas podem ser entregues após o MVP para reduzir o investimento inicial.

---

## 17. Critérios de aceitação

### Autenticação

**Dado** um usuário não autenticado, **quando** selecionar Google ou Apple e concluir o processo, **então** deverá acessar sua conta sem precisar criar uma senha no aplicativo.

### Nenhum alimentador

**Dado** um usuário autenticado sem dispositivos, **quando** acessar o aplicativo, **então** deverá visualizar uma tela centralizada com a ação Configurar alimentador em destaque.

### Um alimentador

**Dado** um usuário com exatamente um alimentador vinculado, **quando** entrar no aplicativo, **então** deverá acessar diretamente o dashboard desse alimentador.

### Múltiplos alimentadores

**Dado** um usuário com vários dispositivos, **quando** entrar no aplicativo, **então** deverá visualizar a lista de alimentadores e conseguir selecionar qualquer dispositivo autorizado.

### Alimentação manual

**Dado** um alimentador online e operacional, **quando** o usuário solicitar uma porção, **então** o aplicativo deverá acompanhar a execução e registrar o resultado confirmado.

### Dispositivo offline

**Dado** um dispositivo sem comunicação, **quando** o usuário abrir seu dashboard, **então** o aplicativo deverá informar o estado offline e não apresentar telemetria antiga como atual.

### Compartilhamento

**Dado** um proprietário autenticado, **quando** convidar outra conta e esta aceitar, **então** o convidado deverá visualizar o alimentador respeitando as permissões atribuídas.

### Acesso à câmera

**Dado** um usuário autorizado e um dispositivo audiovisual disponível, **quando** abrir a seção Câmera, **então** deverá conseguir visualizar a transmissão e utilizar os recursos de áudio permitidos.

---

## 18. Indicadores de sucesso

As métricas iniciais do produto deverão incluir:

- Percentual de usuários que concluem a configuração do primeiro alimentador.
- Tempo médio de configuração.
- Percentual de comandos de alimentação concluídos.
- Taxa de falhas de comunicação.
- Frequência de uso do aplicativo.
- Número de dispositivos por conta.
- Quantidade de alimentadores compartilhados.
- Taxa de sucesso das programações automáticas.
- Tempo necessário para estabelecer uma transmissão de vídeo.

Metas quantitativas deverão ser estabelecidas após a validação dos primeiros protótipos.

---

## 19. Dependências e decisões pendentes

As seguintes decisões deverão ser validadas antes da implementação definitiva:

1. **Hardware da câmera:** o ESP32 escolhido será capaz de suportar câmera e áudio ou será utilizado um módulo dedicado?
2. **Medição de ração:** como será medida a quantidade disponível e a quantidade realmente dispensada?
3. **Alimentação elétrica:** o dispositivo utilizará bateria recarregável, fonte externa ou ambos?
4. **Provisionamento:** será utilizado Bluetooth, Wi-Fi temporário ou outro método de pareamento?
5. **Operação offline:** os agendamentos serão armazenados e executados localmente pelo dispositivo?
6. **Infraestrutura audiovisual:** qual tecnologia oferecerá o equilíbrio adequado entre latência, custo e compatibilidade?
7. **Compartilhamento:** os convidados poderão gerenciar programações ou somente realizar alimentações manuais?
8. **Limites de segurança:** quais limites de porção e frequência serão impostos para evitar alimentação excessiva?
9. **Identidade comercial:** qual será o nome definitivo do produto e seus elementos próprios de marca?

---

## 20. Princípio orientador do produto

**Tecnologia avançada. Experiência simples. Cuidado constante.**

O aplicativo deve transmitir controle, precisão e confiabilidade, permitindo que o usuário acompanhe e alimente seu pet com o mínimo de esforço.

A estética cósmica deve reforçar a identidade do produto sem prejudicar a usabilidade. A prioridade é construir uma solução confiável, visualmente sofisticada e preparada para evolução comercial.
