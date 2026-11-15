/// The case shown by custom letter keys, shared by name entry and guided exercises.
public enum KeyboardCapitalization {
    public static func name(after prefix: String) -> Bool {
        guard let last = prefix.last else { return true }
        return last.isWhitespace || last == "-"
    }

    /// Match the actual target, including lowercase missing letters and proper names.
    public static func target(_ text: String, at index: Int) -> Bool {
        guard index >= 0 else { return false }
        return text.dropFirst(index).first?.isUppercase ?? false
    }
}
