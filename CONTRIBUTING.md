## 🚀 Contributing Guidelines

Thank you for your interest in contributing to this project.

This document provides clear guidance on what is expected from contributors and what you can expect from the review process. It isn’t long or very strict, so please don’t skip it.

---

### 1️⃣  Godot version

- The minimum supported Godot version is **4.3 stable**.
- Use this version when making changes to the plugin: <https://godotengine.org/download/archive/4.3-stable/>
- **Why?**
  - Newer versions introduce changes that 4.3 struggles to handle, whereas 4.3 files still work fine in newer Godot versions.
  - If your change depends on newer capabilities, let me know in the PR comments.

---

### 2️⃣  Feature value vs maintenance

Before adding a feature, ask yourself:

1. Does it solve a need many users have?
2. Could it break easily or require significant maintenance?

If unsure, open an issue first to discuss it.

---

### 3️⃣  UI changes

I try to be very careful when modifying the UI, and I may be a bit picky about it.

Consider this guideline for UI changes:

| Situation | What to do |
|-----------|------------|
| Reorganizing the UI (new text box, button, icon) | **Open an issue first** – explain why the change is needed and how it affects the layout. |
| Minor tweaks (new option in a menu, typo fix) | No issue/discussion needed |

---

### 4️⃣  Test your changes

- Before opening a pull‑request (PR), run basic tests with your changes.
- When adding a new LLM provider API, have at least a brief conversation with one assistant and verify that it can read and write to the code editor using Quick Prompts.
- Depending on what you changed, verify that no related functionality broke.

---

### 5️⃣  Coding style (GDScript)

- Try to adhere to the style used in other files.  
- Try to follow the existing architecture (use existing files as guidelines).  
- Use an underscore at the beginning of names for private methods and properties (e.g., `_models_url`, `_create_save_file`).  
- Prefer readability over cleverness.  
  - Descriptive, concise variable names are preferred; short one‑letter names for loop indices are acceptable, but in general discouraged.
- Use strong typing whenever possible, e.g. declare as `var your_variable := "hello"` or `var your_variable: String = "hello"`, instead of `var your_variable = "hello"`.

---

### 6️⃣  Big changes

If your PR involves:

- A significant re‑architecture of the add‑on, **or**
- Complex logic that may be hard to maintain

Open an issue **before** you start coding so we can discuss it.

---

### 7️⃣  PR descriptions

- Do not generate long AI‑written descriptions (you didn't see that coming, did you? 😉).
- Keep it short, straight to the point, and focus on *what* changed and *why*.

---

### 8️⃣  Licensing

All contributions are automatically licensed under MIT, matching the project’s license.

---

### 9️⃣  What to expect from me (the maintainer)

1. I regularly check new issues, PRs, and discussions. I try to reply or ackowledge I've read them, but sometimes it may take days (in rare cases even weeks! 😓).
2. I will perform a code review and may request changes.
3. I may make modifications at my discretion.
4. I’ll update the version number in the relevant files as part of the merge process.

---

### That’s it! Ready to contribute?

1. Fork the repo.  
2. Create a branch (any name is fine).  
3. Make your changes.  
4. Test them thoroughly.  
5. Open a PR and stay tuned!
