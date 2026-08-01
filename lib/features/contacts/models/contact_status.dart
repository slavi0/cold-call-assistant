/// Represents where a contact stands in the sales pipeline.
///
/// Having status on the model (rather than computed from call history)
/// lets salespeople manually override it and lets the UI filter contacts
/// without loading every call record.
enum ContactStatus {
  /// Freshly imported, not yet called.
  newContact,

  /// At least one call was attempted or completed.
  contacted,

  /// A follow-up has been scheduled or is needed.
  followUp,

  /// The prospect became a client.
  converted,

  /// The prospect explicitly declined or is permanently disqualified.
  rejected,
}
