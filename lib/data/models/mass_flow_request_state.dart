class MassFlowRequestState {
  DateTime _requestedDate;
  DateTime _committedDate;

  MassFlowRequestState(DateTime initialDate)
    : _requestedDate = initialDate,
      _committedDate = initialDate;

  DateTime get requestedDate => _requestedDate;
  DateTime get committedDate => _committedDate;

  void request(DateTime date) {
    _requestedDate = date;
  }

  void commit(DateTime date) {
    _committedDate = date;
  }
}
