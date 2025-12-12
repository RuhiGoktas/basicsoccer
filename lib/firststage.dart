import 'package:flutter/material.dart';
import 'playerselection.dart';


class Team {
  final String name;
  final String flag; // emoji flag for now (no assets needed)
  final String group;

  const Team({required this.name, required this.flag, required this.group});
}

class PickCountryWelcomePage extends StatefulWidget {
  const PickCountryWelcomePage({super.key});

  @override
  State<PickCountryWelcomePage> createState() => _PickCountryWelcomePageState();
}

class _PickCountryWelcomePageState extends State<PickCountryWelcomePage> {
  Team? selected;

  // NOTE: Some labels in the image are tiny; I used best-effort names.
  // You can adjust the list anytime.
  final List<Team> teams = const [
    // GROUP A (override: Ireland)
    Team(name: "Mexico", flag: "🇲🇽", group: "A"),
    Team(name: "South Africa", flag: "🇿🇦", group: "A"),
    Team(name: "Korea Republic", flag: "🇰🇷", group: "A"),
    Team(name: "Ireland", flag: "🇮🇪", group: "A"),

    // GROUP B (override: Italy)
    Team(name: "Canada", flag: "🇨🇦", group: "B"),
    Team(name: "Italy", flag: "🇮🇹", group: "B"),
    Team(name: "Qatar", flag: "🇶🇦", group: "B"),
    Team(name: "Switzerland", flag: "🇨🇭", group: "B"),

    // GROUP C
    Team(name: "Brazil", flag: "🇧🇷", group: "C"),
    Team(name: "Morocco", flag: "🇲🇦", group: "C"),
    Team(name: "Haiti", flag: "🇭🇹", group: "C"),
    Team(name: "Scotland", flag: "🏴", group: "C"),

    // GROUP D (override: Turkey)
    Team(name: "USA", flag: "🇺🇸", group: "D"),
    Team(name: "Paraguay", flag: "🇵🇾", group: "D"),
    Team(name: "Australia", flag: "🇦🇺", group: "D"),
    Team(name: "Turkey", flag: "🇹🇷", group: "D"),

    // GROUP E
    Team(name: "Germany", flag: "🇩🇪", group: "E"),
    Team(name: "Curaçao", flag: "🇨🇼", group: "E"),
    Team(name: "Côte d’Ivoire", flag: "🇨🇮", group: "E"),
    Team(name: "Ecuador", flag: "🇪🇨", group: "E"),

    // GROUP F (override: Poland)
    Team(name: "Netherlands", flag: "🇳🇱", group: "F"),
    Team(name: "Japan", flag: "🇯🇵", group: "F"),
    Team(name: "Tunisia", flag: "🇹🇳", group: "F"),
    Team(name: "Poland", flag: "🇵🇱", group: "F"),

    // GROUP G
    Team(name: "Belgium", flag: "🇧🇪", group: "G"),
    Team(name: "Egypt", flag: "🇪🇬", group: "G"),
    Team(name: "Iran", flag: "🇮🇷", group: "G"),
    Team(name: "New Zealand", flag: "🇳🇿", group: "G"),

    // GROUP H
    Team(name: "Spain", flag: "🇪🇸", group: "H"),
    Team(name: "Cabo Verde", flag: "🇨🇻", group: "H"),
    Team(name: "Saudi Arabia", flag: "🇸🇦", group: "H"),
    Team(name: "Uruguay", flag: "🇺🇾", group: "H"),

    // GROUP I
    Team(name: "France", flag: "🇫🇷", group: "I"),
    Team(name: "Senegal", flag: "🇸🇳", group: "I"),
    Team(name: "Bolivia", flag: "🇧🇴", group: "I"),
    Team(name: "Norway", flag: "🇳🇴", group: "I"),

    // GROUP J
    Team(name: "Argentina", flag: "🇦🇷", group: "J"),
    Team(name: "Algeria", flag: "🇩🇿", group: "J"),
    Team(name: "Austria", flag: "🇦🇹", group: "J"),
    Team(name: "Jordan", flag: "🇯🇴", group: "J"),

    // GROUP K
    Team(name: "Portugal", flag: "🇵🇹", group: "K"),
    Team(name: "Uzbekistan", flag: "🇺🇿", group: "K"),
    Team(name: "Colombia", flag: "🇨🇴", group: "K"),
    Team(name: "Congo DR", flag: "🇨🇩", group: "K"),

    // GROUP L
    Team(name: "England", flag: "🏴", group: "L"),
    Team(name: "Croatia", flag: "🇭🇷", group: "L"),
    Team(name: "Ghana", flag: "🇬🇭", group: "L"),
    Team(name: "Panama", flag: "🇵🇦", group: "L"),
  ];

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Team>>{};
    for (final t in teams) {
      groups.putIfAbsent(t.group, () => []).add(t);
    }
    final orderedGroups = List<String>.generate(12, (i) => String.fromCharCode("A".codeUnitAt(0) + i));

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("World Cup 2026 — Pick Your Country"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _HeroHeader(selectedName: selected?.name),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: orderedGroups.length,
                itemBuilder: (context, index) {
                  final g = orderedGroups[index];
                  final list = groups[g] ?? const <Team>[];

                  return _GroupCard(
                    group: g,
                    teams: list,
                    selected: selected,
                    onPick: (t) {
                      setState(() => selected = t);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('You picked "${t.name}"'),
                          duration: const Duration(milliseconds: 900),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
				onPressed: selected == null
					? null
					: () {
						Navigator.push(
						  context,
						  MaterialPageRoute(
							builder: (_) => PlayerSelectionPage(teamName: selected!.name),
						  ),
						);
					  },

                  child: Text(selected == null ? "Select a country to continue" : "Continue as ${selected!.name}"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String? selectedName;
  const _HeroHeader({required this.selectedName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12261A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Choose your team",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            selectedName == null
                ? "Tap a country below. We’ll build the tournament around your pick."
                : "Locked in: $selectedName ✅",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String group;
  final List<Team> teams;
  final Team? selected;
  final ValueChanged<Team> onPick;

  const _GroupCard({
    required this.group,
    required this.teams,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF12261A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Group $group",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: teams.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3.2,
            ),
            itemBuilder: (context, i) {
              final t = teams[i];
              final isSelected = selected?.name == t.name && selected?.group == t.group;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onPick(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isSelected ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color: isSelected ? Colors.white.withOpacity(0.60) : Colors.white.withOpacity(0.10),
                      width: isSelected ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(t.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
