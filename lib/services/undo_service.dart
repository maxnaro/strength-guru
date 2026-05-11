import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

abstract class UndoAction {
  final String message;
  UndoAction(this.message);

  Future<void> undo(WidgetRef ref);
}

class SwapDaysAction extends UndoAction {
  final String mesoId;
  final int dayA;
  final int dayB;

  SwapDaysAction({
    required this.mesoId,
    required this.dayA,
    required this.dayB,
  }) : super('Days swapped');

  @override
  Future<void> undo(WidgetRef ref) async {
    final db = ref.read(dbProvider);
    await db.swapDays(mesoId, dayA, dayB);
  }
}

class UndoNotifier extends StateNotifier<UndoAction?> {
  UndoNotifier() : super(null);

  void push(UndoAction action) {
    state = action;
  }

  void clear() {
    state = null;
  }

  Future<void> undo(WidgetRef ref) async {
    final action = state;
    if (action != null) {
      state = null;
      await action.undo(ref);
    }
  }
}
