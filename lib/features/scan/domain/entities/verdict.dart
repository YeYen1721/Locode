enum Verdict {
  safe,        // Green — URL appears legitimate
  suspicious,  // Amber — some risk indicators found
  danger,      // Red — high-confidence phishing indicators
  error,       // Gray — analysis could not complete
  loading,     // Loading state
}
