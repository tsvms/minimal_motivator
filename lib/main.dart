import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// -----------------------------------------------------------------------------
// 1. SERVICES (NOTIFICATION & STORAGE)
// -----------------------------------------------------------------------------

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    // Χρειαζόμαστε και το Android initialization για να μην κρασάρει,
    // ακόμα κι αν στοχεύουμε iOS.
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _notifications.initialize(
      const InitializationSettings(iOS: iosSettings, android: androidSettings),
    );
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required DateTime scheduledTime,
  }) async {
    await _notifications.zonedSchedule(
      id,
      'Reminder',
      title,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleDailyQuote(TimeOfDay time, String quote) async {
    final now = DateTime.now();
    var scheduledDate =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      999,
      'Daily Insight',
      quote,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) async => await _notifications.cancel(id);
}

// -----------------------------------------------------------------------------
// 2. DATA & QUOTES
// -----------------------------------------------------------------------------

const List<String> kQuotes = [
  "Simplicity is the ultimate sophistication.",
  "Do less, but better.",
  "Focus on what matters.",
  "Edit your life frequently.",
  "Silence is a source of great strength.",
  "Act as if what you do makes a difference.",
  "Dream big and dare to fail.",
  "It always seems impossible until it's done.",
  "Don't count the days, make the days count.",
  "Everything you can imagine is real."
];

// -----------------------------------------------------------------------------
// 3. MAIN APP UI
// -----------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  // Κάνει τη status bar (πάνω μέρος κινητού) διάφανη για full screen look
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const MinimalApp());
}

class MinimalApp extends StatelessWidget {
  const MinimalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        textSelectionTheme:
            const TextSelectionThemeData(cursorColor: Colors.black),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _tasks = [];
  String _currentQuote = "";
  TimeOfDay? _quoteTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Quote
    setState(() {
      _currentQuote = kQuotes[Random().nextInt(kQuotes.length)];
    });

    // Load Tasks
    final String? tasksString = prefs.getString('tasks');
    if (tasksString != null) {
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(jsonDecode(tasksString));
      });
    }

    // Load Quote Time
    final String? timeString = prefs.getString('quote_time');
    if (timeString != null) {
      final parts = timeString.split(':');
      setState(() {
        _quoteTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('tasks', jsonEncode(_tasks));
  }

  void _addTask(String title, TimeOfDay? time) {
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    setState(() {
      _tasks.add({
        'id': id,
        'title': title,
        'time': time != null ? '${time.hour}:${time.minute}' : null,
        'isDone': false,
      });
    });
    _saveTasks();

    if (time != null) {
      final now = DateTime.now();
      var scheduledDate =
          DateTime(now.year, now.month, now.day, time.hour, time.minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      NotificationService.scheduleNotification(
          id: id, title: title, scheduledTime: scheduledDate);
    }
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index]['isDone'] = !_tasks[index]['isDone'];
    });
    _saveTasks();

    // Αν ολοκληρωθεί, περιμένουμε λίγο και το σβήνουμε ή το αφήνουμε;
    // Εδώ το αφήνουμε για να φαίνεται η πρόοδος.
  }

  void _deleteTask(int index) {
    NotificationService.cancel(_tasks[index]['id']);
    setState(() {
      _tasks.removeAt(index);
    });
    _saveTasks();
  }

  Future<void> _setQuoteTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _quoteTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
                primary: Colors.black, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('quote_time', '${picked.hour}:${picked.minute}');
      setState(() => _quoteTime = picked);

      NotificationService.scheduleDailyQuote(picked, _currentQuote);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context),
        backgroundColor: Colors.black,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(CupertinoIcons.add, color: Colors.white),
      ).animate().scale(delay: 500.ms, duration: 300.ms),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER & QUOTE ---
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE').format(DateTime.now()).toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                            color: Colors.grey[400]),
                      ),
                      GestureDetector(
                        onTap: _setQuoteTime,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _quoteTime != null
                                ? Colors.black
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.bell,
                                  size: 14,
                                  color: _quoteTime != null
                                      ? Colors.white
                                      : Colors.black),
                              const SizedBox(width: 6),
                              Text(
                                _quoteTime != null
                                    ? _quoteTime!.format(context)
                                    : "Set Time",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _quoteTime != null
                                        ? Colors.white
                                        : Colors.black),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _currentQuote,
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      height: 1.2,
                      color: Colors.black,
                    ),
                  ).animate().fadeIn(duration: 800.ms).moveY(begin: 20, end: 0),
                ],
              ),
            ),

            // --- TASKS LIST ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50], // Πολύ απαλό γκρι για διαχωρισμό
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: _tasks.isEmpty
                    ? Center(
                        child: Text(
                          "No tasks.\nEnjoy the silence.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: Colors.grey[300], fontSize: 16),
                        ).animate().fadeIn(delay: 300.ms),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                            top: 30, left: 20, right: 20, bottom: 100),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return Dismissible(
                            key: Key(task['id'].toString()),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _deleteTask(index),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(CupertinoIcons.trash,
                                  color: Colors.red),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleTask(index),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: task['isDone']
                                            ? Colors.black
                                            : Colors.transparent,
                                        border: Border.all(
                                            color: Colors.black, width: 1.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: task['isDone']
                                          ? const Icon(Icons.check,
                                              size: 16, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          opacity: task['isDone'] ? 0.3 : 1.0,
                                          child: Text(
                                            task['title'],
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              decoration: task['isDone']
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        if (task['time'] != null &&
                                            !task['isDone'])
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              "Reminder at ${task['time']}",
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[400]),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(delay: (100 * index).ms)
                              .slideX(begin: 0.2);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    String newTitle = "";
    TimeOfDay? selectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 40,
              top: 40,
              left: 30,
              right: 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("NEW FOCUS",
                  style: GoogleFonts.inter(
                      fontSize: 12, letterSpacing: 2, color: Colors.grey)),
              TextField(
                autofocus: true,
                style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  hintText: "What needs doing?",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.black26),
                ),
                onChanged: (val) => newTitle = val,
                onSubmitted: (_) {
                  if (newTitle.isNotEmpty) {
                    _addTask(newTitle, selectedTime);
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) => Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: Colors.black, onSurface: Colors.black),
                          ),
                          child: child!,
                        ),
                      );
                      setSheetState(() => selectedTime = t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selectedTime != null
                            ? Colors.black
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.alarm,
                              size: 16,
                              color: selectedTime != null
                                  ? Colors.white
                                  : Colors.black),
                          if (selectedTime != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              selectedTime!.format(context),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (newTitle.isNotEmpty) {
                        _addTask(newTitle, selectedTime);
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.arrow_upward, color: Colors.white),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
