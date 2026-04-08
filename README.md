**Godot AI Assistant Hub**
<img src="https://github.com/FlamxGames/godot-ai-assistant-hub/blob/main/logo.png" width="50px">
==========================
**Latest version: 1.8.3**
<sub>([What's new?](#whats-new-in-the-latest-version))</sub>
<sub>([Upgrading to a newer version](#upgrading-to-a-newer-version))</sub>

A Flexible Godot Plugin for AI Assistants
-----------------------------------------

Embed AI assistants in Godot with the ability to read and write code in Godot's Code Editor.

This plugin does not run LLM models directly, but acts as an interface between Godot and your local LLM. There are plenty of options to run LLMs locally. Thanks to the community this tool supports the following:

* [Ollama](https://ollama.com/)*
* Google Gemini
* Jan
* Ollama Turbo
* OpenRouter
* OpenWebUI
* xAI

**Ollama** is officially supported, while the other LLM providers are maintained by community contributions. Regardless, the plugin delivers the same functionality for all of them.

If you use other LLM tools not listed here, you could easily extend this plugin to work with them if they have a REST API. This plugin was designed to be API agnostic. See the videos for more information on this.

Tutorial Playlist
-----------------------------------------

[Click here to go to the tutorial playlist](https://www.youtube.com/playlist?list=PL2PLLTlAI2ogvgcY8mG-QsMI1dDUDPyF2)

First Video 👇

[![YouTube Video](http://i.ytimg.com/vi/3PDKJYp-upU/hqdefault.jpg)](https://www.youtube.com/watch?v=3PDKJYp-upU&list=PL2PLLTlAI2ogvgcY8mG-QsMI1dDUDPyF2&index=1)

**Key Features**
---------------

#### ✍️ Assistants can write code or documentation directly in Godot's Code Editor.
#### 👀 Assistants can read the code you highlight for quick interactions.
#### 🪄 Save reusable prompts to ask your assistant to act with a single button.
#### 🤖 Create your own assistant types and quick prompts without coding.
#### 💬 Have multiple chat sessions with different types of assistants simultaneously.
#### ⏪ Edit the conversation history in case your assistant gets confused by some of your prompts.
#### 💻 Call LLMs locally or remotely.

**System Requirements**
-----------------------

The system requirements to run local LLMs depend on the models you use and the speed you expect. Of course, if you use the plugin to run remote models (Gemini, xAI, etc.), then you don't need to worry about this (just about the bills).

**Tested in versions**

* Godot 4.3 to 4.6

Tested in stable versions only.

**Getting Started**
--------------------
This section assumes you have installed [Ollama](https://ollama.com/) and installed at least one model. If you are not sure about the models to download, read section "Not sure what models to use?".

### ▶️ If you are feeling like not reading much
Just install it and follow the hints it gives you in Godot itself.

### ▶️ If you want to understand it better
There are 2 main concepts for this addon, familiarize yourself with them, both are Godot [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html):

#### A) AI assistant type (AIAssistantResource). 🤖
This is the setup for an assistant, it describes what the assistant does, what LLM model to use, and what Quick Prompts it can use.

Think of it as a template for creating assistants. For example, you can have an assistant that helps with coding, and one that helps with writing. In that case, you would have 2 assistant types, and you can summon as many coders or writers you need.

#### B) Quick Prompt (AIQuickPromptResource). 🪄
Allows to send a prompt in the chat by clicking a button instead of writing it every time. It adds the ability to insert the assistant's answer in the Godot's Code Editor.
The following keywords are used to allow the prompt to pull data from the Code Editor or from the chat prompt.
* Use `{CODE}` to insert the code currently selected in the editor.
* Use `{CHAT}` to include the current content of the text prompt.

**Note**: Most models already tag their code properly, but not all of them. In order for the plugin to identify what code to use from the assistant's response, you may need to give explicit instructions in their description, for example:

    Any code you write you mark it properly, for example:
    ```gdscript
    var x:String = "abc"
    ```

## Setup steps
In general this is what you need to do:

0. If running your LLMs locally, install Ollama or some other LLM supported and download at least one model.
1. Download this addon from [here](https://github.com/FlamxGames/godot-ai-assistant-hub/archive/refs/heads/main.zip), unzip it, and copy the folder ai_assistant_hub into your addons folder `res://addons/ai_assistant_hub/`. (You may see errors, those should go away after next step.)
2. Reload your project: **Project > Reload Current Project** (this will reload the whole project, so make sure to save before doing this).
3. Enable the plugin in your project settings (**Project > Project Settings... > Plugins**), you should see a new tab `AI Hub` in the bottom panel.
4. Select an LLM provider, by default Ollama is selected.
5. You should see a list of models you have installed. Click one and use the "New assistant type" button.
6. Fill up the data for your assistant.
7. After saving, you should see a new button for your assistant type.
8. Your assistant type will open in the Inspector panel, there you can optionally configure an icon and Quick Prompts for your assistant type, the later would allow it to interact with the code editor.
9. Click the assistant type button to start a chat with a new assistant of this type.

### Configuring Quick Prompts and icon ###
1. Right-click the button for your assistant type, there you can select Edit or Delete.
2. Select Edit.
3. In the *Type Icon* property select an image to display in the assistant button. (The addon has some icons under `res://addons/ai_assistant_hub/graphics/icons`, you can use those by using a *New AtlasTexture* in this property, loading the icons file in the *Atlas* property of the AtlasTexture, then clicking *Edit Region* to select the icon you want.)
4. If you click the property *Quick Prompts* you will see an empty array, click *Add Element*, then in the empty slot select *New AIQuickPromptResource*.
5. Click the new resource to open its properties in the editor.
6. You will see a few properties:
    * **Action Name**. This name will be displayed in the Quick Prompt button.
    * **Action Prompt**. This is what this prompt will send to the chat. There are two keywords:
        * Use `{CODE}` to insert the code currently selected in the editor.
        * Use `{CHAT}` to include the current content of the text prompt.
    * **Icon**. The icon to display in the Quick Prompt button.
    * **Respose Target**. Where should the bot's answer go in Godot's editor.
    * **Code Placement**. Only relevant when the Response Target is the Code Editor.
    * **Format Response as Comment**. Only relevant when the Response Target is the Code Editor. Useful when the prompt is used to create inline code documentation.
7. Once done start a new chat to see the Quick Prompt.

Experiment and build the right type of assistants for your workflow.

### Not sure what models to use?

I found it is not a good idea to give advice here, as models change all the time. What I suggest you to do is to search “Best coding local LLM models in (current year) that fit (insert your setup here).”
For example, “Best coding local LLM models in 2026 that fit 8 GB of VRAM.”

The rule of thumb I follow is to check the output speed by chatting with it. If it is slow, the model is not being loaded onto my GPU; it is using RAM/CPU. You probably only want to do that if the results the model produces are remarkably better, or simply if you don’t have a GPU capable of loading any models.

**What's new in the latest version**
-----------------------
**1.8.3**
* Added reasoning level support for Ollama (help wanted to add it to other LLM Providers!)
* Thinking content is now obtained when it comes separate to the agent response and displayed accordingly to the user settings (Project Settings > General > Plugins > AI Assistant Hub > Thinking Target).
* Reworked error/debugging handling, a new option exists now to ease debugging (Project Settings > General > Plugins > AI Assistant Hub > Debug Mode). This supports logging to a log file that skips keys automatically.
* System message is no longer lost in saved chats (issue #75).
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

[Full version history](versions.md)

**Upgrading to a newer version**
-----------------------
If you had the plugin installed and want to upgrade to the latest version, follow these steps:

***Download > Disable current > Install new > Reload project > Enable***

1. Download the latest version [here](https://github.com/FlamxGames/godot-ai-assistant-hub/archive/refs/heads/main.zip) and unzip it.
2. **Disable** the plugin from **Project > Project Settings... > Plugins**.
3. Pull the **ai_assistant_hub** folder from the new version into your addons folder (don't delete the previous one so you don't lose your assistants). You may see errors in Godot's output tab, that is fine.
4. Ensure Godot loads into memory the new version: **Project > Reload Current Project** (this will reload the whole project, so make sure to save before doing this).
5. **Enable** the plugin. You should not see any errors in the output tab, but in some cases you may see some message confirming the migration of old settings.

**Leave a contribution**
-----------------------
If you like this project check the following page for ideas about how to support it: https://github.com/FlamxGames/godot-ai-assistant-hub/blob/main/support.md

**Who is developing this**
----------
Hi, I'm Forest, I created this addon for my personal use and decided to share it, hope you find it useful.

I'm a solo game developer that sometimes ends up building game dev tools. This a hobby project I may keep improving from time to time. Right now I'm planning to improve it on a need-basis, so there is no formal roadmap. However I welcome ideas in the Discussions section.

**License**
----------
This project is licensed under the MIT license.
