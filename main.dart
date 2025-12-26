import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('habitBox');
  runApp(const HabitTrackerApp());
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Habit Tracker',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HabitTrackerPage(),
    );
  }
}

class HabitTrackerPage extends StatefulWidget {
  const HabitTrackerPage({super.key});

  @override
  State<HabitTrackerPage> createState() => _HabitTrackerPageState();
}

class _HabitTrackerPageState extends State<HabitTrackerPage> {
  List<String> habits = ['Workout', 'Read', 'Meditate'];
  late List<List<bool>> habitData;

  late DateTime selectedMonth;
  late int daysInMonth;
  bool isCurrentMonth = true;

  int selectedTab = 0;
  int selectedHabitIndex = 0;

  Box get box => Hive.box('habitBox');

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime.now();
    daysInMonth = getDaysInMonth(selectedMonth);
    habitData = List.generate(
      habits.length,
      (_) => List.generate(daysInMonth, (_) => false),
    );
    loadData();
  }

  int getDaysInMonth(DateTime date) {
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1)).day;
  }

  String get monthKey =>
      '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

  void saveData() {
    box.put(monthKey, {
      'habits': habits,
      'data': habitData,
    });
  }

  void loadData() {
    final saved = box.get(monthKey);
    if (saved != null) {
      habits = List<String>.from(saved['habits']);
      habitData = List<List<bool>>.from(
        saved['data'].map((e) => List<bool>.from(e)),
      );
    }
  }

  void changeMonth(DateTime newMonth) {
    setState(() {
      selectedMonth = newMonth;
      isCurrentMonth = newMonth.year == DateTime.now().year &&
          newMonth.month == DateTime.now().month;
      daysInMonth = getDaysInMonth(selectedMonth);
      habitData = List.generate(
        habits.length,
        (_) => List.generate(daysInMonth, (_) => false),
      );
      loadData();
    });
  }

  int calculateStreak(int habitIndex) {
    if (!isCurrentMonth) return 0;
    int streak = 0;
    for (int i = daysInMonth - 1; i >= 0; i--) {
      if (habitData[habitIndex][i]) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  double monthCompletion(DateTime month) {
    final key =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final saved = box.get(key);
    if (saved == null) return 0;

    List<List<bool>> data = List<List<bool>>.from(
      saved['data'].map((e) => List<bool>.from(e)),
    );

    int total = data.length * data[0].length;
    int done = data.expand((e) => e).where((e) => e).length;
    return done / total;
  }

  List<FlSpot> habitSpots(int index) {
    List<FlSpot> spots = [];
    int done = 0;
    for (int i = 0; i < daysInMonth; i++) {
      if (habitData[index][i]) done++;
      spots.add(FlSpot(i.toDouble(), (done / (i + 1)) * 10));
    }
    return spots;
  }

  void addHabit() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Habit'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Habit name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                habits.add(controller.text);
                habitData.add(
                    List.generate(daysInMonth, (_) => false));
                saveData();
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget tableView() {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            itemCount: habits.length,
            onReorder: (o, n) {
              setState(() {
                if (n > o) n--;
                final h = habits.removeAt(o);
                final d = habitData.removeAt(o);
                habits.insert(n, h);
                habitData.insert(n, d);
                saveData();
              });
            },
            itemBuilder: (_, i) => ListTile(
              key: ValueKey(habits[i]),
              title: Text(habits[i]),
              leading: const Icon(Icons.drag_handle),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    habits.removeAt(i);
                    habitData.removeAt(i);
                    saveData();
                  });
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: FloatingActionButton(
            onPressed: addHabit,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget calendarView() {
    return Column(
      children: [
        DropdownButton<int>(
          value: selectedHabitIndex,
          items: List.generate(
            habits.length,
            (i) => DropdownMenuItem(
              value: i,
              child: Text(habits[i]),
            ),
          ),
          onChanged: (v) =>
              setState(() => selectedHabitIndex = v!),
        ),
        Text(
          '🔥 Streak: ${calculateStreak(selectedHabitIndex)} days',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: GridView.builder(
            itemCount: daysInMonth,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (_, i) {
              bool done = habitData[selectedHabitIndex][i];
              return GestureDetector(
                onTap: isCurrentMonth
                    ? () {
                        setState(() {
                          habitData[selectedHabitIndex][i] = !done;
                          saveData();
                        });
                      }
                    : null,
                child: Card(
                  color: done ? Colors.green : Colors.grey[300],
                  child: Center(child: Text('${i + 1}')),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget graphView() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 10,
          titlesData: FlTitlesData(show: false),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: List.generate(
            habits.length,
            (i) => LineChartBarData(
              spots: habitSpots(i),
              isCurved: true,
              barWidth: 2,
              color:
                  Colors.primaries[i % Colors.primaries.length],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double curr = monthCompletion(selectedMonth);
    double prev = monthCompletion(
        DateTime(selectedMonth.year, selectedMonth.month - 1));

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedMonth,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              changeMonth(DateTime(picked.year, picked.month));
            }
          },
          child:
              Text(DateFormat('MMMM yyyy').format(selectedMonth)),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Text(
            curr >= prev
                ? '⬆ Improved ${(curr - prev) * 100}%'
                : '⬇ Dropped ${(prev - curr) * 100}%',
          ),
          Expanded(
            child: IndexedStack(
              index: selectedTab,
              children: [
                tableView(),
                calendarView(),
                graphView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab,
        onTap: (i) => setState(() => selectedTab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.list), label: 'Table'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: 'Calendar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: 'Graph'),
        ],
      ),
    );
  }
}