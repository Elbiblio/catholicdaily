import 'package:catholic_daily/data/models/mass_flow_request_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reloads target the newest request before it is committed', () {
    final dateA = DateTime(2026, 8, 10);
    final dateB = DateTime(2026, 8, 15);
    final state = MassFlowRequestState(dateA);

    state.request(dateB);

    expect(state.requestedDate, dateB);
    expect(state.committedDate, dateA);

    state.commit(dateB);

    expect(state.committedDate, dateB);
  });
}
