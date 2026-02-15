import 'dart:convert';
import 'dart:math';
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

    // Ορισμός κατηγορίας για το κουμπί "Done" στο iOS
    final DarwinNotificationCategory taskCategory = DarwinNotificationCategory(
      'task_actions',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain('done_action', 'Mark as Done',
            options: {DarwinNotificationActionOption.foreground}),
      ],
    );

    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [taskCategory],
    );

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _notifications.initialize(
      InitializationSettings(iOS: iosSettings, android: androidSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationAction(response);
      },
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
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'task_actions',
        ),
      ),
      payload: id.toString(),
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

  static void _handleNotificationAction(NotificationResponse response) async {
    if (response.actionId == 'done_action') {
      final prefs = await SharedPreferences.getInstance();
      final String? tasksString = prefs.getString('tasks');

      if (tasksString != null) {
        List<dynamic> rawTasks = jsonDecode(tasksString);
        List<Map<String, dynamic>> tasks =
            List<Map<String, dynamic>>.from(rawTasks);

        int? taskId = int.tryParse(response.payload ?? '');
        if (taskId != null) {
          for (var task in tasks) {
            if (task['id'] == taskId) {
              task['isDone'] = true;
            }
          }
          await prefs.setString('tasks', jsonEncode(tasks));
        }
      }
    }
  }
}

// -----------------------------------------------------------------------------
// 2. DATA & QUOTES
// -----------------------------------------------------------------------------

const List<String> kQuotes = [
  "We suffer more often in imagination than in reality. -Seneca",
  "Wealth is the slave of a wise man. The master of a fool. -Seneca",
  "Difficulties strengthen the mind, as labor does the body. -Seneca",
  "Luck is what happens when preparation meets opportunity. -Seneca",
  "All cruelty springs from weakness. -Seneca",
  "He who is brave is free. -Seneca",
  "No man was ever wise by chance. -Seneca",
  "Associate with people who are likely to improve you. -Seneca",
  "Waste no more time arguing about what a good man should be. Be one. -Marcus Aurelius",
  "The happiness of your life depends upon the quality of your thoughts. -Marcus Aurelius",
  "Everything we hear is an opinion, not a fact. -Marcus Aurelius",
  "You have power over your mind - not outside events. -Marcus Aurelius",
  "The best revenge is to be unlike him who performed the injury. -Marcus Aurelius",
  "It is not death that a man should fear, but never beginning to live. -Marcus Aurelius",
  "Very little is needed to make a happy life; it is all within yourself. -Marcus Aurelius",
  "First say to yourself what you would be; and then do what you have to do. -Epictetus",
  "It's not what happens to you, but how you react to it that matters. -Epictetus",
  "If you want to improve, be content to be thought foolish and stupid. -Epictetus",
  "No man is free who is not master of himself. -Epictetus",
  "Keep your silence unless you have something better than silence to say. -Epictetus",
  "The greater the difficulty, the more glory in surmounting it. -Epictetus",
  "Freedom is won by disregarding things that lie beyond our control. -Epictetus",
  "Knowing yourself is the beginning of all wisdom. -Aristotle",
  "We are what we repeatedly do. Excellence, then, is a habit. -Aristotle",
  "The unexamined life is not worth living. -Socrates",
  "Be as you wish to seem. -Socrates",
  "He who has a why to live can bear almost any how. -Nietzsche",
  "The soul becomes dyed with the color of its thoughts. -Marcus Aurelius",
  "If it is not right do not do it; if it is not true do not say it. -Marcus Aurelius",
  "Begin at once to live, and count each separate day as a separate life. -Seneca",
  "Self-control is strength. Right thought is mastery. Calmness is power. -James Allen",
  "Act as if what you do makes a difference. It does. -William James",
  "Small is the number of those who see with their own eyes. -Albert Einstein",
  "He who is discontented with what he has, would not be contented with what he would like to have. -Socrates",
  "The mind that is anxious about future events is miserable. -Seneca",
  "External things are not my problem. My response to them is. -Epictetus",
  "How long are you going to wait before you demand the best for yourself? -Epictetus",
  "Don't explain your philosophy. Embody it. -Epictetus",
  "Curb your desire—don't set your heart on so many things and you will get what you need. -Epictetus",
  "If someone is able to show me that what I think or do is not right, I will happily change. -Marcus Aurelius",
  "It is not that we have a short time to live, but that we waste a lot of it. -Seneca",
  "Life is long if you know how to use it. -Seneca",
  "While we are postponing, life speeds by. -Seneca",
  "The tranquilized mind is the best of all gifts. -Seneca",
  "You live as if you were destined to live forever. -Seneca",
  "Life, if well lived, is long enough. -Seneca",
  "The greatest remedy for anger is delay. -Seneca",
  "Look within. Within is the fountain of good, and it will ever bubble up. -Marcus Aurelius",
  "Think of yourself as dead. You have lived your life. Now, take what's left and live it properly. -Marcus Aurelius",
  "The object of life is not to be on the side of the majority, but to escape finding oneself in the ranks of the insane. -Marcus Aurelius",
  "Reject your sense of injury and the injury itself disappears. -Marcus Aurelius",
  "What stands in the way becomes the way. -Marcus Aurelius",
  "Everything is ephemeral—both what remembers and what is remembered. -Marcus Aurelius",
  "Circumstances don't make the man, they only reveal him to himself. -Epictetus",
  "You are a little soul carrying around a corpse. -Epictetus",
  "Only the educated are free. -Epictetus",
  "Wealth consists not in having great possessions, but in having few wants. -Epictetus",
  "Nature hath given men one tongue but two ears, that we may hear twice as much as we speak. -Epictetus",
  "He is a wise man who does not grieve for the things which he has not, but rejoices for those which he has. -Epictetus",
  "Control your perceptions. Direct your actions properly. Willingly accept what's outside your control. -Marcus Aurelius"
];

// -----------------------------------------------------------------------------
// 3. MAIN APP UI
// -----------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

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

    setState(() {
      _currentQuote = kQuotes[Random().nextInt(kQuotes.length)];
    });

    final String? tasksString = prefs.getString('tasks');
    List<Map<String, dynamic>> loadedTasks = [];
    if (tasksString != null) {
      loadedTasks = List<Map<String, dynamic>>.from(jsonDecode(tasksString));
    }

    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String? lastOpenDate = prefs.getString('last_open_date');

    if (lastOpenDate != null && lastOpenDate != today) {
      loadedTasks =
          loadedTasks.where((task) => task['isDone'] == false).toList();
      await prefs.setString('tasks', jsonEncode(loadedTasks));
    }

    await prefs.setString('last_open_date', today);

    setState(() {
      _tasks = loadedTasks;
    });

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
    await prefs.setString('tasks', jsonEncode(_tasks));
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
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
              primary: Colors.black, onSurface: Colors.black),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quote_time', '${picked.hour}:${picked.minute}');
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
                        color: Colors.black),
                  ).animate().fadeIn(duration: 800.ms).moveY(begin: 20, end: 0),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
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
                                    color: Colors.black.withValues(alpha: 0.03),
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
                    hintText: "What needs doing?", border: InputBorder.none),
                onChanged: (val) => newTitle = val,
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
                            Text(selectedTime!.format(context),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
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
                          color: Colors.black, shape: BoxShape.circle),
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
