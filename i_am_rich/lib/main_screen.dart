import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'notes/notes_list_screen.dart';
import 'workout/screens/workout_home_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView(
      // Page 0: Workout (swipe right from Home)
      // Page 1: Home (initial)
      // Page 2: Notes (swipe left from Home)
      controller: PageController(initialPage: 1),
      physics: const ClampingScrollPhysics(),
      children: const [
        WorkoutHomeScreen(),
        HomeScreen(),
        NotesListScreen(),
      ],
    );
  }
}
