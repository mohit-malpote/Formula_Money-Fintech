import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_screen.dart';
import 'firebase_service.dart';
import 'dart:convert';
const String _rawApiKey = String.fromEnvironment(
  'API_KEY',
  defaultValue: String.fromEnvironment('GEMINI_API_KEY'),
);

const String geminiModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-3.8-flash',
);

String get globalApiKey {
  String key = _rawApiKey.trim();
  if ((key.startsWith('"') && key.endsWith('"')) ||
      (key.startsWith("'") && key.endsWith("'"))) {
    key = key.substring(1, key.length - 1).trim();
  }
  if (key.isEmpty || key == 'YOUR_GEMINI_API_KEY_HERE' || key == 'YOUR_KEY_HERE') {
    return '';
  }
  return key;
}

void main() async {
  print("DEBUG API KEY CONFIGURED: ${globalApiKey.isNotEmpty ? "YES (${globalApiKey.substring(0, globalApiKey.length > 6 ? 6 : globalApiKey.length)}...)" : "NO (EMPTY)"}");
  // 1. Tell Flutter to wait for the engine to boot
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Start your connection to Firebase using the json file
  await Firebase.initializeApp();
  
  runApp( MaterialApp(
    home: AuthScreen(), // Your new starting point
  ));
} 

// 1. FULL DATA MODEL
class UserProfile {
  String username = "";
  double salary = 0;
  int age = 0;
  String address = "";
  int experience = 0;
  double currentAssets = 0;
  double monthlyEMI = 0;
  double dailyGroceries = 0;
  String travelMode = "";
  String guiltyPleasure = "";
  double guiltyCost = 0;
  String longTermDream = "";
  double dreamCost = 0; 
}

class SmartSalaryApp extends StatelessWidget {
  const SmartSalaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const SurveyScreen(),
    );
  }
}

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final UserProfile _profile = UserProfile();
  bool _isGenerating = false;

  // AI GOAL GENERATION
  Future<void> _generateGoals() async {
    if (globalApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Error: Gemini API key is missing in this build. Please run with --dart-define=API_KEY=your_key or install the Release APK from GitHub Releases."),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 6),
      ));
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final model = GenerativeModel(
        model: geminiModel,
        apiKey: globalApiKey,
      );

      final prompt = """
      User Profile: ${_profile.username}, Age: ${_profile.age}.
      Finances: Salary ₹${_profile.salary}, Assets: ₹${_profile.currentAssets}, EMIs: ₹${_profile.monthlyEMI}.
      Daily Expenses: Groceries ₹${_profile.dailyGroceries}, Travel: ${_profile.travelMode}.
      Guilty Pleasure: '${_profile.guiltyPleasure}' (₹${_profile.guiltyCost}/day).
      Long Term Dream: ${_profile.longTermDream} (Cost: ₹${_profile.dreamCost}).

      Task: Generate exactly 6 daily goals for a gamified finance app.
      - 5 [Normal] goals.
      - 1 [Guilty] goal (avoiding ${_profile.guiltyPleasure}).
      Format: 1. [Normal]... 6. [Guilty]...
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      setState(() => _isGenerating = false);
      
      if (response.text != null) {
        _showGoalDialog(response.text!);
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // AI Analysis for Suggestion Change
  Future<void> _analyzeSuggestedGoal(String userSuggestion) async {
    if (globalApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Error: Gemini API key is missing in this build."),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ));
      return;
    }

    setState(() => _isGenerating = true);
    
    final model = GenerativeModel(
      model: geminiModel,
      apiKey: globalApiKey,
    );

    final prompt = """
    User Profile: Salary ₹${_profile.salary}, EMIs ₹${_profile.monthlyEMI}.
    User suggests this daily financial goal: '$userSuggestion'.
    Is this reasonable? Start response with 'REASONABLE: YES' or 'REASONABLE: NO' and explain why in 1 sentence.
    """;

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      setState(() => _isGenerating = false);
      _showReasonabilityFeedback(userSuggestion, response.text ?? "No feedback.");
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Analysis failed: $e")));
    }
  }

  void _showReasonabilityFeedback(String suggestion, String feedback) {
    bool isReasonable = feedback.contains("YES");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isReasonable ? "Goal Approved" : "AI Warning"),
        content: Text(feedback),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Try Another")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
               context, 
               MaterialPageRoute(
                 builder: (context) => MainNavigationContainer(
                   profile: _profile, 
                   initialGoals: suggestion,
        ),
      ),
    );
            },
            child: Text(isReasonable ? "Add Goal" : "Change Regardless"),
          ),
        ],
      ),
    );
  }

  void _showSuggestInputChange() {
    TextEditingController suggestionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Suggest New Goal"),
        content: TextField(controller: suggestionController, decoration: const InputDecoration(hintText: "e.g., Save ₹20 on travel")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () { Navigator.pop(context); _analyzeSuggestedGoal(suggestionController.text); }, child: const Text("Analyze")),
        ],
      ),
    );
  }

  void _showGoalDialog(String goals) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("Goal Confirmation"),
        content: SingleChildScrollView(child: Text(goals)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showSuggestInputChange(); // Opens the input for changes
            }, 
            child: const Text("Suggest Change"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
               context, 
               MaterialPageRoute(
                 builder: (context) => MainNavigationContainer(
                   profile: _profile, 
                   initialGoals: goals, // or 'suggestion' depending on which function you're in
        ),
      ),
    );
  },
            child: const Text("Confirm & Start Game"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Survey")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSectionTitle("Basic Info"),
            _buildField("Username", (v) => _profile.username = v),
            _buildField("Age", (v) => _profile.age = int.tryParse(v) ?? 0, numeric: true),
            _buildField("Address", (v) => _profile.address = v),
            _buildField("Work Experience (Years)", (v) => _profile.experience = int.tryParse(v) ?? 0, numeric: true),
            _buildSectionTitle("Finances"),
            _buildField("Monthly Salary", (v) => _profile.salary = double.tryParse(v) ?? 0, numeric: true),
            _buildField("Current Assets", (v) => _profile.currentAssets = double.tryParse(v) ?? 0, numeric: true),
            _buildField("Monthly EMIs", (v) => _profile.monthlyEMI = double.tryParse(v) ?? 0, numeric: true),
            _buildField("Daily Groceries", (v) => _profile.dailyGroceries = double.tryParse(v) ?? 0, numeric: true),
            _buildSectionTitle("Lifestyle & Dreams"),
            _buildField("Travel Mode", (v) => _profile.travelMode = v),
            _buildField("Guilty Pleasure", (v) => _profile.guiltyPleasure = v),
            _buildField("Cost of Pleasure", (v) => _profile.guiltyCost = double.tryParse(v) ?? 0, numeric: true),
            _buildField("Long Term Dream", (v) => _profile.longTermDream = v),
            _buildField("Estimated Dream Cost", (v) => _profile.dreamCost = double.tryParse(v) ?? 0, numeric: true),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateGoals,
                child: _isGenerating ? const CircularProgressIndicator() : const Text("Set Goals & Generate Report"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))),
    );
  }

  Widget _buildField(String label, Function(String) onChanged, {bool numeric = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(keyboardType: numeric ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), onChanged: onChanged));
  }
}

class HomePage extends StatefulWidget {
  final UserProfile profile;
  final String initialGoals;
  final ValueChanged<int> onExpChanged;

  const HomePage({
    super.key,
    required this.profile,
    required this.initialGoals,
    required this.onExpChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _exp = 0;
  int _currentDay = 1; 
  List<bool> _goalCompletion = []; // Changed to empty to be dynamic
  List<String> _currentGoalTexts = []; 
  bool _isAIThinking = false;

  @override
  void initState() {
    super.initState();
    _parseGoals(widget.initialGoals);
  }

  // New helper to parse text and reset the checkbox list length
  void _parseGoals(String goalText) {
    setState(() {
      _currentGoalTexts = goalText
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      // FIX: Re-generate the list to exactly match the AI's output length
      _goalCompletion = List.generate(_currentGoalTexts.length, (index) => false);
    });
  }

  String get _rank {
    if (_exp >= 500) return "Absolute Genius";
    if (_exp >= 300) return "Professional";
    if (_exp >= 150) return "Intermediate";
    return "Rookie";
  }

  void _updateExp(int index, bool? value) async {
    setState(() {
      _goalCompletion[index] = value ?? false;
      int points = (index == _currentGoalTexts.length - 1) ? 50 : 10;
      _exp += (value == true) ? points : -points;
    });

    // 🚀 Syncing with the cloud leaderboard
    await FirebaseService().updateUserExp(_exp); 
    widget.onExpChanged(_exp); 
  }

  Future<void> _refreshDailyGoals() async {
    if (globalApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gemini API key is not configured in this build."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isAIThinking = true);
    
    final model = GenerativeModel(
      model: geminiModel,
      apiKey: globalApiKey,
    );

    final prompt = """
      User Profile: Salary ₹${widget.profile.salary}, Goal: ${widget.profile.longTermDream}.
      Current Game Day: $_currentDay of 30.
      Task: Generate exactly 5 NEW [Normal] daily financial tasks. 
      The 6th goal MUST remain exactly: Avoid ${widget.profile.guiltyPleasure}.
      
      Return ONLY a numbered list of 6 items. No intro text.
    """;

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      if (response.text != null) {
        _parseGoals(response.text!); // This fixes the RangeError
      }
      setState(() => _isAIThinking = false);
    } catch (e) {
      setState(() => _isAIThinking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Refresh Failed: $e")));
      }
    }
  }

  void _nextDay() {
    setState(() {
      if (_currentDay < 30) {
        _currentDay++;
      } else {
        _currentDay = 1; 
      }
    });
    _refreshDailyGoals(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
         backgroundColor: Colors.grey[1000],
         title: const Text("Formula Money"),
       actions: [
           TextButton(
             onPressed: () {
        // Add your logic here to show the change GP goal dialog
          },
      child: const Text("Edit GP", style: TextStyle(color: Colors.white)),
       ),
     ],
   ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. EXP & RANK BOX
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Rank: $_rank", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("$_exp EXP", style: const TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  LinearProgressIndicator(
                    value: (_exp % 150) / 150, 
                    backgroundColor: Colors.white24,
                    color: Colors.amber,
                    minHeight: 10,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Today's Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (_isAIThinking) const Text("AI Refreshing...", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),

            // 2. DYNAMIC CHECKBOX LIST
            ...List.generate(_currentGoalTexts.length, (index) {
              // Highlight the last goal as the Guilty Pleasure
              bool isGuilty = index == _currentGoalTexts.length - 1;
              return Card(
                color: isGuilty ? Colors.red[50] : Colors.white,
                child: CheckboxListTile(
                  title: Text(_currentGoalTexts[index]),
                  subtitle: Text(isGuilty ? "Monthly Challenge - 50 EXP" : "Daily Goal - 10 EXP"),
                  value: _goalCompletion[index],
                  activeColor: Colors.red,
                  onChanged: (val) => _updateExp(index, val),
                ),
              );
            }),
            
            const SizedBox(height: 25),
            SizedBox(
               width: double.infinity,
               child: ElevatedButton.icon(
                 onPressed: _nextDay, // Uses the existing function from your screenshot
                 icon: const Icon(Icons.arrow_forward),
                 label: const Text("Next Day"),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.red, // Matching your new theme
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }
}
class MainNavigationContainer extends StatefulWidget {
  final UserProfile profile;
  final String initialGoals;
  const MainNavigationContainer({super.key, required this.profile, required this.initialGoals});

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}


class AiBotTab extends StatefulWidget {
  final UserProfile profile;
  const AiBotTab({super.key, required this.profile});

  @override
  State<AiBotTab> createState() => _AiBotTabState();
}

class _AiBotTabState extends State<AiBotTab> {
  final TextEditingController _queryController = TextEditingController();
  final List<Map<String, String>> _messages = []; // To track the conversation
  bool _isTyping = false;

  Future<void> _askAi() async {
    if (_queryController.text.isEmpty) return;

    if (globalApiKey.isEmpty) {
      setState(() {
        _messages.add({"role": "user", "content": _queryController.text});
        _messages.add({
          "role": "bot",
          "content": "Gemini API key is not configured in this build. Please run with --dart-define=API_KEY=... or install the Release APK from GitHub."
        });
        _queryController.clear();
      });
      return;
    }

    final userMessage = _queryController.text;
    setState(() {
      _messages.add({"role": "user", "content": userMessage});
      _isTyping = true;
      _queryController.clear();
    });

    final model = GenerativeModel(
      model: geminiModel,
      apiKey: globalApiKey,
    );

    // Context-heavy prompt to ensure the AI remembers the user's specific details
    final prompt = """
      System: You are the SmartSalary Personal Finance Architect. 
      User Profile: ${widget.profile.username}, Age ${widget.profile.age}, Salary ₹${widget.profile.salary}. 
      Goal: ${widget.profile.longTermDream} (Cost: ₹${widget.profile.dreamCost}).
      Location: ${widget.profile.address}.
      
      Instruction: Provide brief, precise, and highly personalized financial advice. 
      Avoid long meaningless paragraphs. Focus on actionable steps.
      
      User Question: $userMessage
    """;

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      setState(() {
        _messages.add({"role": "bot", "content": response.text ?? "I encountered an error. Please try again."});
        _isTyping = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "content": "Connection error. Check your API key or internet."});
        _isTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Financial Architect"), centerTitle: true),
      body: Column(
        children: [
          // 1. Chat Message Area
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isUser = msg["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.red : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      msg["content"]!,
                      style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (_isTyping) const LinearProgressIndicator(minHeight: 2),

          // 2. Input Bar
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: "Ask about your ₹${widget.profile.dreamCost} goal...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _askAi,
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LeaderboardTab extends StatelessWidget {
  final int userExp;
  final String userName;

  const LeaderboardTab({super.key, required this.userExp, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Global Leaderboard")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // 1. Connect to the real cloud stream
        stream: FirebaseService().getLeaderboardStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Use cloud data or fallback to empty list
          List<Map<String, dynamic>> players = snapshot.data ?? [];

          // 2. Map Firebase fields to match your design
          // We convert 'username' and 'totalExp' to 'name' and 'exp'
          List<Map<String, dynamic>> formattedPlayers = players.map((p) {
            String name = p['username'] ?? "Unknown";
            // Highlight current user based on username matching
            if (name == userName) name = "$userName (You)";
            return {
              "name": name,
              "exp": p['totalExp'] ?? 0,
            };
          }).toList();

          // 3. Keep your existing Sorting & Ranking Logic
          formattedPlayers.sort((a, b) => b['exp'].compareTo(a['exp']));

          int userIndex = formattedPlayers.indexWhere((p) => p['name'].contains("(You)"));
          
          // Safety check: if user isn't in top 20 list yet
          double percentile = (userIndex == -1) ? 0 : (1 - (userIndex / formattedPlayers.length)) * 100;

          String dynamicRank;
          if (percentile >= 98) {
            dynamicRank = "Absolute Genius";
          } else if (percentile >= 80) {
            dynamicRank = "Professional";
          } else if (percentile >= 45) {
            dynamicRank = "Intermediate";
          } else {
            dynamicRank = "Rookie";
          }

          return Column(
            children: [
              // Your exact Percentile Header design
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.red,
                child: Column(
                  children: [
                    Text("You are in the top ${(100 - percentile).toStringAsFixed(1)}% of users!", 
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 5),
                    Text(dynamicRank, 
                      style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  itemCount: formattedPlayers.length,
                  itemBuilder: (context, index) {
                    final player = formattedPlayers[index];
                    bool isUser = index == userIndex;
                    return ListTile(
                      leading: Text("#${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      title: Text(player['name']),
                      trailing: Text("${player['exp']} EXP"),
                      tileColor: isUser ? Colors.amber[50] : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _selectedIndex = 0;
  int _currentTotalExp = 0; // Tracks your points for the Leaderboard

  // Function to handle adding new investments manually
  void _showAddInvestmentDialog() {
    TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Investment"),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Enter amount (INR)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                double amount = double.tryParse(amountController.text) ?? 0;
                // Directly updates the profile assets
                widget.profile.currentAssets += amount;
              });
              Navigator.pop(context);
            }, 
            child: const Text("Update Portfolio")
          ),
        ],
      ),
    );
  }

  // Function for the 'Rad Button' high-risk alert
  void _showRadOpportunity() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 10), Text("Rad Alert!")],
        ),
        content: Text("High Risk Opportunity: Based on your age (${widget.profile.age}), aggressive growth assets like Small-cap funds or Crypto are options. Analyze now?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Not Today")),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Analyze Risk")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      HomePage(
        profile: widget.profile,
        initialGoals: widget.initialGoals,
        onExpChanged: (newExp) {
          setState(() => _currentTotalExp = newExp);
        },
      ),
      AiBotTab(profile: widget.profile),
      LeaderboardTab(
        userExp: _currentTotalExp,
        userName: widget.profile.username,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("SmartSalary"),
        centerTitle: true,
        backgroundColor: Colors.red[50],
      ),
      // NEW: Added the Drawer (Side Menu)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.red),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_circle, size: 50, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(widget.profile.username, style: const TextStyle(color: Colors.white, fontSize: 18)),
                  Text("Rank: Rookie", style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bolt, color: Colors.orange),
              title: const Text('Rad Button (High Risk)'),
              onTap: () {
                Navigator.pop(context); // Close Drawer
                _showRadOpportunity();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_chart, color: Colors.green),
              title: const Text('Add Investment'),
              onTap: () {
                Navigator.pop(context); // Close Drawer
                _showAddInvestmentDialog();
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'AI Bot'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Leaders'),
        ],
      ),
    );
  }
}