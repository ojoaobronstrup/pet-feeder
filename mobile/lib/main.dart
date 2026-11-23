import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

String apiUrl = 'http://10.0.2.2:5087';
String googleClientId = '';
const feederName = 'Alimentador';
const canvas = Color(0xff05070a),
    surface = Color(0xff10141b),
    mutedSurface = Color(0xff1a2029),
    border = Color(0xff29313d),
    muted = Color(0xff8d98a6),
    accent = Color(0xff5b9dff),
    ice = Color(0xfff5f7fa),
    statusSuccess = Color(0xff48cfa0),
    statusWarning = Color(0xfff0b45b),
    statusDanger = Color(0xffef6666);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final env = await rootBundle.loadString('.env');
    for (final line in env.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final separator = trimmed.indexOf('=');
      if (separator <= 0) continue;
      final key = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      if (key == 'API_URL' && value.isNotEmpty) apiUrl = value;
      if (key == 'GOOGLE_SERVER_CLIENT_ID') googleClientId = value;
    }
  } on FlutterError {
    // Mantém os padrões para permitir abrir a tela e informar configuração ausente.
  }
  runApp(const PetFeederApp());
}

class AuthException implements Exception {
  const AuthException();
}

class PetFeederApp extends StatelessWidget {
  const PetFeederApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Pet Feeder',
    locale: const Locale('pt', 'BR'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('pt', 'BR')],
    theme: ThemeData.dark().copyWith(
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? accent : muted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.dark(
        primary: ice,
        surface: surface,
        onPrimary: canvas,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'Inter Tight',
        bodyColor: ice,
        displayColor: ice,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    home: const Home(),
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRect(
        child: SizedBox(
          width: 43,
          height: 40,
          child: OverflowBox(
            minWidth: 110,
            maxWidth: 110,
            minHeight: 60,
            maxHeight: 60,
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix([
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                -0.333,
                -0.333,
                -0.333,
                0,
                255,
              ]),
              child: Image(
                image: AssetImage('assets/images/logo.png'),
                semanticLabel: 'Qnis',
              ),
            ),
          ),
        ),
      ),
      SizedBox(width: 10),
      Text(
        'PET FEEDER',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: accent,
        ),
      ),
    ],
  );
}

class AuthenticatedHeader extends StatelessWidget {
  const AuthenticatedHeader({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
    child: Row(
      children: [
        const Expanded(child: BrandHeader()),
        IconButton(
          tooltip: 'Sair',
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final signIn = GoogleSignIn(
    serverClientId: googleClientId.isEmpty ? null : googleClientId,
    scopes: ['email'],
  );
  GoogleSignInAccount? account;
  Map<String, dynamic>? feeder;
  List<dynamic> schedules = [];
  List<FeedingEvent>? history;
  bool historyUnavailable = false;
  int? loadingHistoryGeneration;
  String? error;
  bool busy = false;
  bool signingOut = false;
  bool validated = false;
  int? refreshingGeneration;
  int generation = 0;
  int stateRevision = 0;
  int tab = 0;
  Uint8List? avatar;
  Future<void> loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('test_feeder_avatar');
      if (value != null && mounted) {
        setState(() => avatar = base64Decode(value));
      }
    } catch (_) {
      /* A foto local pode ser selecionada novamente. */
    }
  }

  Future<void> chooseAvatar() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (image == null) return;
      if (await image.length() > 5 * 1024 * 1024) throw Exception();
      final bytes = await image.readAsBytes();
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('test_feeder_avatar', base64Encode(bytes))) {
        throw Exception();
      }
      if (mounted) setState(() => avatar = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar a imagem. Escolha uma imagem de até 5 MB.',
            ),
          ),
        );
      }
    }
  }

  Timer? timer;
  @override
  void initState() {
    super.initState();
    loadAvatar();
    if (googleClientId.isNotEmpty) restoreSession();
  }

  Future<void> restoreSession() async {
    try {
      final value = await signIn.signInSilently();
      if (mounted && value != null) {
        account = value;
        await refresh();
      }
    } catch (_) {
      /* User can sign in interactively. */
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    final token = (await account?.authentication)?.idToken;
    if (token == null) {
      throw Exception(
        'Não foi possível obter a identidade Google. Confira a configuração OAuth.',
      );
    }
    final uri = Uri.parse('$apiUrl$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final http.Response response;
    if (method == 'PUT') {
      response = await http
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
    } else if (method == 'POST') {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
    } else if (method == 'DELETE') {
      response = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
    } else {
      response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 10));
    }
    if (response.statusCode == 401) throw const AuthException();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message =
          'Não foi possível concluir a solicitação (${response.statusCode}).';
      try {
        message =
            (jsonDecode(response.body) as Map<String, dynamic>)['error']
                as String? ??
            message;
      } catch (_) {}
      throw Exception(message);
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<void> refresh() async {
    final currentGeneration = generation;
    if (refreshingGeneration == currentGeneration || account == null) return;
    refreshingGeneration = currentGeneration;
    final currentRevision = stateRevision;
    try {
      final f = await request('/api/feeder') as Map<String, dynamic>;
      final s = await request('/api/feeder/schedules') as List<dynamic>;
      if (!mounted ||
          generation != currentGeneration ||
          stateRevision != currentRevision) {
        return;
      }
      setState(() {
        validated = true;
        feeder = f;
        schedules = s;
        error = null;
      });
      if (timer == null) {
        unawaited(refreshHistory());
        timer = Timer.periodic(const Duration(seconds: 4), (_) {
          unawaited(refresh());
          if (tab == 0 || tab == 1) unawaited(refreshHistory());
        });
      }
    } on AuthException {
      await expireSession(currentGeneration);
    } catch (_) {
      if (mounted && generation == currentGeneration) {
        setState(() {
          feeder = null;
          error = 'Sem conexão com a API. Confira a rede e a configuração.';
        });
      }
    } finally {
      if (refreshingGeneration == currentGeneration) {
        refreshingGeneration = null;
      }
    }
  }

  Future<void> refreshHistory() async {
    final currentGeneration = generation;
    if (!validated || loadingHistoryGeneration == currentGeneration) return;
    setState(() => loadingHistoryGeneration = currentGeneration);
    try {
      final entries = await request('/api/feeder/history') as List<dynamic>;
      final events = entries
          .map((entry) => FeedingEvent.fromJson(entry as Map<String, dynamic>))
          .toList();
      if (!mounted || generation != currentGeneration) return;
      setState(() {
        history = events;
        historyUnavailable = false;
      });
    } on AuthException {
      await expireSession(currentGeneration);
    } catch (_) {
      if (mounted && generation == currentGeneration) {
        setState(() => historyUnavailable = true);
      }
    } finally {
      if (mounted && generation == currentGeneration) {
        setState(() => loadingHistoryGeneration = null);
      }
    }
  }

  Future<void> expireSession(int currentGeneration) async {
    if (!mounted || generation != currentGeneration) return;
    timer?.cancel();
    timer = null;
    generation++;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      validated = false;
      tab = 0;
      account = null;
      feeder = null;
      schedules = [];
      history = null;
      historyUnavailable = false;
      loadingHistoryGeneration = null;
      error = 'Conta não autorizada ou sessão expirada. Entre novamente com a conta configurada.';
    });
    try {
      await signIn.signOut();
    } catch (_) {
      // A sessão local da aplicação já foi encerrada.
    }
  }

  Future<void> login() async {
    if (googleClientId.isEmpty) {
      setState(
        () => error = 'Configure GOOGLE_SERVER_CLIENT_ID no arquivo mobile/.env e reinicie o app com flutter run.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await signIn.signIn();
      if (mounted && value != null) {
        setState(() => account = value);
        await refresh();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Não foi possível entrar com Google. Confira a configuração OAuth e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    if (signingOut) return;
    signingOut = true;
    timer?.cancel();
    timer = null;
    generation++;
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() {
        account = null;
        validated = false;
        tab = 0;
        feeder = null;
        schedules = [];
        history = null;
        historyUnavailable = false;
        loadingHistoryGeneration = null;
        error = null;
        busy = true;
      });
    }
    try {
      await signIn.signOut();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Não foi possível concluir a saída do Google. Tente entrar novamente.',
        );
      }
    } finally {
      signingOut = false;
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(Future<void> Function() operation) async {
    final currentGeneration = generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
      if (generation == currentGeneration) await refresh();
    } on AuthException {
      if (generation == currentGeneration) await refresh();
    } catch (e) {
      if (mounted && generation == currentGeneration) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && generation == currentGeneration) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> schedule() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    final date = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!date.isAfter(DateTime.now())) {
      setState(() => error = 'Escolha uma data e horário futuros.');
      return;
    }
    await action(() async {
      await request(
        '/api/feeder/schedules',
        method: 'POST',
        body: {'scheduledAt': date.toUtc().toIso8601String()},
      );
    });
  }

  String scheduleStatus(String status) => switch (status) {
    'pending' => 'Agendada',
    'dispatched' => 'Aguardando confirmação',
    'executed' => 'Confirmada pelo dispositivo',
    'missed' => 'Sem confirmação',
    'cancelled' => 'Cancelada',
    _ => status,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: !validated
              ? loginView()
              : Column(
                  children: [
                    AuthenticatedHeader(onLogout: logout),
                    Expanded(child: deviceView()),
                  ],
                ),
        ),
      ),
    ),
  );
  Widget loginView() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: BrandHeader(),
              ),
              AspectRatio(
                aspectRatio: 390 / 266,
                child: Image.asset(
                  'assets/images/pet_hd.png',
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cuidado que está sempre por perto.',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Entre para acompanhar e controlar seu alimentador.',
                      style: TextStyle(fontSize: 15, height: 1.5, color: muted),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error != null) errorText(),
                    FilledButton.icon(
                      onPressed: busy ? null : login,
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      label: const Text('Continuar com Google'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget errorText() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(error!, style: const TextStyle(color: statusDanger)),
  );
  Widget avatarButton() => IconButton(
    tooltip: 'Alterar foto do alimentador',
    onPressed: chooseAvatar,
    iconSize: 56,
    icon: CircleAvatar(
      radius: 28,
      backgroundColor: mutedSurface,
      backgroundImage: avatar == null ? null : MemoryImage(avatar!),
      child: avatar == null
          ? const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.pets, color: muted),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(Icons.add_a_photo, color: accent, size: 16),
                ),
              ],
            )
          : null,
    ),
  );

  Widget deviceView() => Column(
    children: [
      Expanded(
        child: switch (tab) {
          0 => dashboard(),
          1 => FeedingHistoryView(
            events: history,
            loading: loadingHistoryGeneration == generation,
            unavailable: historyUnavailable,
            onRefresh: refreshHistory,
          ),
          2 => schedulesView(),
          _ => settingsView(),
        },
      ),
      NavigationBar(
        height: 80,
        backgroundColor: surface,
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
          if (value == 0 || value == 1) unawaited(refreshHistory());
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Rotinas'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Ajustes',
          ),
        ],
      ),
    ],
  );

  Future<void> confirmFeeding() async {
    final currentGeneration = generation;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Despejar alimento'),
        content: const Text('Enviar o comando de dispensação ao alimentador?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || generation != currentGeneration) {
      return;
    }
    await action(() async {
      final result = await request('/api/feeder/feed', method: 'POST');
      if (mounted &&
          generation == currentGeneration &&
          result is Map<String, dynamic>) {
        stateRevision++;
        setState(() => feeder = result);
      }
    });
    if (mounted && generation == currentGeneration) await refreshHistory();
  }

  Widget dashboard() {
    final online = feeder?['online'] == true;
    final active = feeder?['active'] == true;
    final awaitingConfirmation =
        online && feeder?['desiredActive'] == true && !active;
    final lastSeen = DateTime.tryParse(feeder?['lastSeenAt'] as String? ?? '');
    final lastConfirmation = history
        ?.where((event) => event.status == 'confirmed' && event.active)
        .firstOrNull;
    final nextSchedule = schedules
        .where((item) => item['status'] == 'pending')
        .map((item) => DateTime.parse(item['scheduledAt'] as String))
        .fold<DateTime?>(
          null,
          (next, at) => next == null || at.isBefore(next) ? at : next,
        );
    return RefreshIndicator(
      onRefresh: () async {
        await refresh();
        await refreshHistory();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const FeederPageHeading(label: 'DISPOSITIVO', title: feederName),
          const SizedBox(height: 8),
          Text(
            feeder == null
                ? 'Conexão indisponível'
                : online
                ? '● Online'
                : '● Offline',
            style: TextStyle(
              color: online ? statusSuccess : statusWarning,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!online && lastSeen != null) ...[
            const SizedBox(height: 4),
            Text(
              'Última conexão em ${formatDate(lastSeen)}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          if (error != null) errorText(),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 250 ||
                  MediaQuery.textScalerOf(context).scale(14) > 22) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _UnavailableMetric(label: 'Bateria'),
                    SizedBox(height: 12),
                    _UnavailableMetric(label: 'Ração'),
                  ],
                );
              }
              return const Row(
                children: [
                  Expanded(child: _UnavailableMetric(label: 'Bateria')),
                  SizedBox(width: 12),
                  Expanded(child: _UnavailableMetric(label: 'Ração')),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          const FeederSectionLabel('ÚLTIMA ATIVIDADE'),
          const SizedBox(height: 12),
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lastConfirmation != null
                      ? formatDate(lastConfirmation.occurredAt)
                      : historyUnavailable
                      ? 'Histórico indisponível'
                      : history == null
                      ? 'Consultando o histórico…'
                      : 'Nenhum comando confirmado',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (lastConfirmation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${lastConfirmation.originLabel} · Comando confirmado',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  if (historyUnavailable)
                    const Text(
                      'Histórico desatualizado',
                      style: TextStyle(color: statusWarning, fontSize: 12),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: online && !active && !awaitingConfirmation && !busy
                ? confirmFeeding
                : null,
            child: const Text('Despejar alimento'),
          ),
          if (!online || awaitingConfirmation || active) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                !online
                    ? 'O alimentador precisa estar conectado para dispensar.'
                    : awaitingConfirmation
                    ? 'Aguardando confirmação do dispositivo.'
                    : 'Comando confirmado pelo dispositivo.',
                style: TextStyle(
                  color: !online
                      ? muted
                      : awaitingConfirmation
                      ? accent
                      : statusSuccess,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          const FeederSectionLabel('PRÓXIMA ROTINA'),
          const SizedBox(height: 12),
          Text(
            nextSchedule == null
                ? 'Nenhuma rotina agendada'
                : formatDate(nextSchedule),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget schedulesView() => RefreshIndicator(
    onRefresh: refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const FeederPageHeading(
          label: 'AUTOMAÇÃO',
          title: 'Rotinas',
          description: 'Alimentações programadas.',
        ),
        const SizedBox(height: 24),
        if (error != null) errorText(),
        if (schedules.isEmpty)
          card(
            const Text(
              'Nenhuma rotina agendada.',
              style: TextStyle(color: muted),
            ),
          ),
        for (final item in schedules)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: card(
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDate(
                            DateTime.parse(item['scheduledAt'] as String),
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scheduleStatus(item['status'] as String),
                          style: TextStyle(
                            color: switch (item['status']) {
                              'pending' || 'dispatched' => accent,
                              'executed' => statusSuccess,
                              'missed' => statusWarning,
                              _ => muted,
                            },
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item['status'] == 'pending')
                    IconButton(
                      tooltip: 'Cancelar rotina',
                      onPressed: busy
                          ? null
                          : () => action(() async {
                              await request(
                                '/api/feeder/schedules/${item['id']}',
                                method: 'DELETE',
                              );
                            }),
                      icon: const Icon(Icons.close, color: muted),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy ? null : schedule,
          icon: const Icon(Icons.add),
          label: const Text('Criar rotina'),
        ),
      ],
    ),
  );

  Widget settingsView() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const FeederPageHeading(
        label: 'DISPOSITIVO',
        title: 'Configurações',
        description: feederName,
      ),
      const SizedBox(height: 24),
      card(
        Row(
          children: [
            const Expanded(
              child: Text(
                'Foto do alimentador',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            avatarButton(),
          ],
        ),
      ),
    ],
  );
}

Widget card(Widget child) => Material(
  color: surface,
  shape: RoundedRectangleBorder(
    side: const BorderSide(color: border),
    borderRadius: BorderRadius.circular(14),
  ),
  clipBehavior: Clip.antiAlias,
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);

String formatDate(DateTime value, {bool includeSeconds = false}) {
  final local = value.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  final time = '${pad(local.hour)}:${pad(local.minute)}';
  final seconds = includeSeconds ? ':${pad(local.second)}' : '';
  return '${pad(local.day)}/${pad(local.month)}/${local.year} às $time$seconds';
}

class FeederPageHeading extends StatelessWidget {
  const FeederPageHeading({
    super.key,
    required this.label,
    required this.title,
    this.description,
  });

  final String label;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FeederSectionLabel(label, color: accent),
      const SizedBox(height: 8),
      Semantics(
        header: true,
        child: Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
      ),
      if (description != null) ...[
        const SizedBox(height: 8),
        Text(description!, style: const TextStyle(color: muted, fontSize: 14)),
      ],
    ],
  );
}

class FeederSectionLabel extends StatelessWidget {
  const FeederSectionLabel(this.label, {super.key, this.color = muted});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
  );
}

class _UnavailableMetric extends StatelessWidget {
  const _UnavailableMetric({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FeederSectionLabel(label.toUpperCase()),
        const SizedBox(height: 12),
        const ExcludeSemantics(
          child: Text(
            '—',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Leitura indisponível',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class FeedingEvent {
  FeedingEvent.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      occurredAt = DateTime.parse(json['occurredAt'] as String).toLocal(),
      scheduledAt = DateTime.tryParse(json['scheduledAt'] as String? ?? '')
          ?.toLocal(),
      origin = json['origin'] as String,
      active = json['active'] as bool,
      status = json['status'] as String;

  final String id;
  final DateTime occurredAt;
  final DateTime? scheduledAt;
  final String origin;
  final bool active;
  final String status;

  String get originLabel => switch (origin) {
    'scheduled' => 'Programada',
    'manual' => 'Manual',
    _ => 'Origem indisponível',
  };

  String get statusLabel => switch (status) {
    'requested' when origin == 'scheduled' => 'Rotina criada',
    'requested' => 'Comando solicitado',
    'dispatched' => 'Comando preparado para envio',
    'confirmed' => 'Comando confirmado',
    'missed' => 'Sem confirmação',
    'cancelled' => 'Cancelado',
    _ => 'Resultado indisponível',
  };

  Color get statusColor => switch (status) {
    'requested' || 'dispatched' => accent,
    'confirmed' => statusSuccess,
    'missed' => statusWarning,
    _ => muted,
  };
}

class FeedingHistoryView extends StatefulWidget {
  const FeedingHistoryView({
    super.key,
    required this.events,
    required this.loading,
    required this.unavailable,
    required this.onRefresh,
  });

  final List<FeedingEvent>? events;
  final bool loading;
  final bool unavailable;
  final Future<void> Function() onRefresh;

  @override
  State<FeedingHistoryView> createState() => _FeedingHistoryViewState();
}

class _FeedingHistoryViewState extends State<FeedingHistoryView> {
  String period = '';
  String origin = '';
  String status = '';

  List<FeedingEvent> filteredEntries() {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = switch (period) {
      'today' => today,
      'week' => DateTime(today.year, today.month, today.day - 6),
      'month' => DateTime(today.year, today.month, today.day - 29),
      _ => null,
    };
    return [
      for (final event in widget.events ?? const <FeedingEvent>[])
        if ((start == null || !event.occurredAt.isBefore(start)) &&
            (origin.isEmpty || event.origin == origin) &&
            (status.isEmpty || event.status == status))
          event,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = filteredEntries();
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: accent,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: 1 + entries.length,
        itemBuilder: (context, index) {
          if (index > 0) {
            final event = entries[index - 1];
            final newDay =
                index == 1 ||
                !DateUtils.isSameDay(
                  entries[index - 2].occurredAt,
                  event.occurredAt,
                );
            return Column(
              key: ValueKey(event.id),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (newDay) ...[
                  const SizedBox(height: 12),
                  FeederSectionLabel(historyDayLabel(event.occurredAt)),
                ],
                eventRow(event),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FeederPageHeading(
                label: 'ATIVIDADE',
                title: 'Histórico',
                description: feederName,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  filter(
                    title: 'Período',
                    value: period,
                    options: const {
                      '': 'Todos os dias',
                      'today': 'Hoje',
                      'week': 'Últimos 7 dias',
                      'month': 'Últimos 30 dias',
                    },
                    onSelected: (value) => setState(() => period = value),
                  ),
                  filter(
                    title: 'Origem',
                    value: origin,
                    options: const {
                      '': 'Todas as origens',
                      'manual': 'Manual',
                      'scheduled': 'Programada',
                    },
                    onSelected: (value) => setState(() => origin = value),
                  ),
                  filter(
                    title: 'Resultado',
                    value: status,
                    options: const {
                      '': 'Todos os resultados',
                      'requested': 'Solicitado',
                      'dispatched': 'Preparado para envio',
                      'confirmed': 'Confirmado',
                      'missed': 'Sem confirmação',
                      'cancelled': 'Cancelado',
                    },
                    onSelected: (value) => setState(() => status = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.unavailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.events?.isNotEmpty == true
                                ? 'Histórico desatualizado. Não foi possível buscar novos eventos.'
                                : 'Não foi possível carregar o histórico.',
                            style: const TextStyle(color: statusWarning),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.loading ? null : widget.onRefresh,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (widget.events == null)
                card(
                  Row(
                    children: [
                      const ExcludeSemantics(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            color: accent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: const Text('Carregando histórico…'),
                        ),
                      ),
                    ],
                  ),
                )
              else if (entries.isEmpty)
                card(
                  Text(
                    widget.events!.isEmpty
                        ? 'Nenhum evento registrado.'
                        : 'Nenhum evento para os filtros selecionados.',
                    style: const TextStyle(color: muted),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String historyDayLabel(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (DateUtils.isSameDay(date, now)) return 'HOJE';
    if (DateUtils.isSameDay(date, yesterday)) return 'ONTEM';
    return MaterialLocalizations.of(context).formatCompactDate(date);
  }

  Widget filter({
    required String title,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onSelected,
  }) {
    final selected = value.isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: 'Filtrar por ${title.toLowerCase()}',
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options.entries)
          PopupMenuItem(value: option.key, child: Text(option.value)),
      ],
      child: Semantics(
        selected: selected,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accent : mutedSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected ? options[value]! : title,
                style: TextStyle(
                  color: selected ? canvas : ice,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: selected ? canvas : ice,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget eventRow(FeedingEvent event) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(event.occurredAt),
      alwaysUse24HourFormat: true,
    );
    final scheduledAt = event.scheduledAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '$time · ${event.originLabel}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: scheduledAt == null
              ? null
              : Text(
                  'Agendada para ${formatDate(scheduledAt)}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: () => showEventDetails(event),
        ),
        const Divider(height: 1, color: border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            event.statusLabel,
            style: TextStyle(
              color: event.statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void showEventDetails(FeedingEvent event) {
    final scheduledAt = event.scheduledAt;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Detalhes do evento',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(event.statusLabel, style: TextStyle(color: event.statusColor)),
            const SizedBox(height: 16),
            Text('Origem: ${event.originLabel}'),
            const SizedBox(height: 8),
            Text(
              'Registrado em ${formatDate(event.occurredAt, includeSeconds: true)}',
            ),
            if (scheduledAt != null) ...[
              const SizedBox(height: 8),
              Text('Agendado para ${formatDate(scheduledAt)}'),
            ],
          ],
        ),
      ),
    );
  }
}
