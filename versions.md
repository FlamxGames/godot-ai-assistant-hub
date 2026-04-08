**Version history**
--------------------

**1.8.3**
* Added reasoning level support for Ollama (help wanted to add it to other LLM Providers!)
* "Make floating" option (by right-click to the plugin tab) is now enabled in Godot 4.6 without need to do any manual code changes (closes #64).
* Thinking content is now obtained when it comes separate to the agent response and displayed accordingly to the user settings (Project Settings > General > Plugins > AI Assistant Hub > Thinking Target).
* Reworked error/debugging handling, a new option exists now to ease debugging (Project Settings > General > Plugins > AI Assistant Hub > Debug Mode). This supports logging to a log file that skips keys automatically.
* System message is no longer lost in saved chats (closes #75).
* Added anonymous (counting) usage stats to understand better what versions and APIs most people use.

**1.8.2**
* New entry in settings to disable/enable chat sounds (Project Settings > General > Plugins > AI Assistant Hub > Audio Hints).

**1.8.1**
* When you select an assistant tab, the chat text box is now focused automatically.
* Added commented code in ai_hub_plugin.gd under _enter_tree() and _exit_tree(), in Godot 4.6 you can uncomment this to enable making the plugin screen floating by right-clicking its tab.
* Fixed bugs in code placement when replacing the selection. Also improved code placement in general removing extra lines around it.
* Fixed bug that caused freeze when editing an assistant resource in Linux.

**1.8.0**
* xAI API support

--------------------

**1.7.3**
* Bug fix in Jan API, now it displays the field to input the API key.
* Bug fix in OllamaTurbo, OpenRouter, and OpenWebUI, now the headers get refreshed when the API key changes.

**1.7.2**
* Bug fix in Jan API.
* Allow to rearrange chat tabs.

**1.7.1**
* The plugin checks for the latest version and shows a upgrade button if there is a newer version.

**1.7.0**
* Ollama Turbo support

--------------------

**1.6.3**
* Support chat save.
* Fixed code formatting.
* Reload chat when edited.

**1.6.2**
* New project setting to skip the initial greeting.

**1.6.1**
* Right click assistant types to edit or delete.

**1.6.0**
* Major refactor to ease adding new LLM providers.
* Moved API keys to user settings and removed multiple project settings no longer needed.
* Now the assistants keep the full context of the LLM they are using instead of depending on the LLM selected in AI Hub tab as before.

--------------------

**1.5.0**
* Button to create assistants, you don't need to navigate the right path and create a resource anymore
* Bug fix for Google Gemini API

--------------------

**1.4.0**
* Support for OpenWebUI
* Button to cancel the last prompt (force the assistant to stop thinking)
* Auto-scroll to bottom moved to settings

--------------------

**1.3.0**
* Google Gemini support
* Migrated project settings to a path specific for this plugin

--------------------

**1.2.0**
* JanAPI support

--------------------

**1.1.0**
* OpenRouter support

--------------------

**1.0.0**
* First version, Ollama support only
