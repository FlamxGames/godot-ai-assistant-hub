**Godot AI Assistant Hub**
<img src="https://github.com/FlamxGames/godot-ai-assistant-hub/blob/main/logo.png" width="50px">
==========================
**Latest version: 2.0.0**
<sub>([What's new?](#whats-new-in-the-latest-version))</sub>
<sub>([Upgrading to a newer version](#upgrading-to-a-newer-version))</sub>

A Flexible Godot Plugin for AI Assistants
-----------------------------------------

Embed AI assistants in Godot to help you code, edit scenes, and more.

- Designed for **developers who still want to drive their game's creative and development processes**, but want AI help to augment their capacity.
- Designed for local LLMs first, but capable of using remote options.
- With a unique take on LLMs centered around the idea of having different assistant types for different tasks.

This plugin does not run LLM models directly, but acts as an interface between Godot and your LLM provider. There are plenty of options to run LLMs locally. Thanks to the community, this tool supports the following:

* [Ollama](https://ollama.com/)*
* Google Gemini
* Jan
* Ollama Turbo
* OpenRouter
* OpenWebUI
* xAI

**Ollama** is supported by the maintainer, and sometimes ahead in features (more on that [below](#features-by-llm-provider)).

Before reviewing the available features, you need to understand there are *two main workflows*:

|                     | Tools 🚀 (do many things)                         | Quick Prompts 🪓 (coding only)  |
|---------------------|---------------------------------------------------|---------------------------------|
| **Example request** | *"Make a new enemy that chases the player"*       | *"Complete code marked with #CODE_HERE#"* |
| Pros                | Much more capabilities + multi‑step tasks         | Reliable with less powerful models    |
| Cons                | Risk of mistakes when using tools (you can undo)  | Requires user to manually select code |
| Scope               | Assistants decide how to edit code and scenes     | Targeted code edits only        |
| Model requirement   | Models with tooling capabilities                  | Works with any model            |
| Workflow            | Auto tool selection, dynamic                      | Manual code‑block selection     |
| Required setup      | More prompt tuning, define tools access           | Rigid prompt design using keywords |

<sub>⚠️ *Quick Prompts* can be used in combination with tools as well for other things.</sub>

## Available Tools
| Category | Tool | Introduced in Version | Last Update |
|----------|------|-----------------------|-------------|
| **Code** | Create Script | 2.0.0 | 2.0.0 |
| | Append Code | 2.0.0 | 2.0.0 |
| | Replace Code | 2.0.0 | 2.0.0 |
| | Delete Code | 2.0.0 | 2.0.0 |
| | Show Code | 2.0.0 | 2.0.0 |
| **Scene** | Create Scene | 2.0.0 | 2.0.0 |
| | Add Node From Class | 2.0.0 | 2.0.0 |
| | Add Node From Scene | 2.0.0 | 2.0.0 |
| | Delete Node | 2.0.0 | 2.0.0 |
| | Edit Node Groups | 2.0.0 | 2.0.0 |
| | Edit Node Properties | 2.0.0 | 2.0.0 |
| | Edit Node Signals | 2.0.0 | 2.0.0 |
| | Get Node Groups | 2.0.0 | 2.0.0 |
| | Get Node Properties | 2.0.0 | 2.0.0 |
| | Get Node Signals | 2.0.0 | 2.0.0 |
| | Scan Scene Node Tree | 2.0.0 | 2.0.0 |
| | Show Scene Node | 2.0.0 | 2.0.0 |
| **Resource** | Create External Resource | 2.0.0 | 2.0.0 |
| | Edit Resource Properties | 2.0.0 | 2.0.0 |
| | Get Resource Properties | 2.0.0 | 2.0.0 |
| **File** | Read File | 2.0.0 | 2.0.0 |
| | Create Text File | 2.0.0 | 2.0.0 |
| | Scan Directory | 2.0.0 | 2.0.0 |
| | Create Directory | 2.0.0 | 2.0.0 |
| **Project** | List Global Groups | 2.0.0 | 2.0.0 |
| | Manage Global Groups | 2.0.0 | 2.0.0 |
| **General** | Save All | 2.0.0 | 2.0.0 |
| | Undo | 2.0.0 | 2.0.0 |

### Tools Permissions and Security
Assistants can have three levels of tool access: **Allow, Ask, and Hide.**  

- **Allow** – Grants the assistant permission to use the tool at all times. This setting is applied by default to read‑only tools.  
- **Ask** – Adds an approval step, allowing you to review what the assistant is doing and either accept or provide feedback. This is the default for tools that have write access.  
- **Hide** – Makes the tool unavailable to the assistant. It also reduces the amount of information the LLM must process (so you want to hide any tools you consider unnecessary).

In addition many tools have options to define what files the assistants can read or edit, hide node properties from the assistants, or even ban keywords in the generated code.

**Each assistant type can have access to a different set of tools**, this allows you to have, for example, assistant types tuned to only work in a specific scene, with tool access restricted to that scene only.

#### 💡 Quick Prompts and Tools Access
Quick Prompts can be configured to have specific code access. So, for example, you could hide the Create Scene tool, and make it available only through a Quick Prompt.

Using this you can have a very fine-grained access setup.

## Other Features
- **Godot context** - When tools are enabled, the assistants can know what scene and script you are editing, so you can simply ask things like "What does this code do?".
- **Multiple assistants** - Have multiple chat sessions with different types of assistants simultaneously.
- **Conversation editor** - Edit the conversation history in case your assistant gets confused by some of your prompts, or you want to delete something that is using too much context.
- **IP configuration** - Even for local LLMs, you can connect to a local computer and call remotely. This can be useful, for example, if you are a team but have only 1 powerful computer to run LLMs.

## Features by LLM provider
Use the table below to see what features are currently available.

Missing features in LLM providers different to Ollama may be added by the community:

| LLM Provider | Chat | Tools | Quick Prompts | Reasoning Levels | Context usage indicator | Set Context Length |
| :----------- | :---: | :---: | :----------: | :--------------: | :---------------------: | :----------------: |
| Ollama        | ✅   | ✅    | ✅           | ✅                | ✅                      | ✅                 |
| Google Gemini | ✅   |       | ✅           |                   |                          |                    |
| Jan           | ✅   |       | ✅           |                   |                          |                    |
| Ollama Turbo  | ✅   |       | ✅           |                   |                          |                    |
| OpenRouter    | ✅   |       | ✅           |                   |                          |                    |
| OpenWebUI     | ✅   |       | ✅           |                   |                          |                    |
| xAI           | ✅   |       | ✅           |                   |                          |                    |

This plugin was designed to be API agnostic and could be extended to support other LLM providers.

The only reason Ollama was selected as the "officially maintained" LLM provider is because its relative popularity, easy installation, and ease of use for non-advanced users. This could change in the future (but not planned as of now).

V2 Tutorial
-----------------------------------------
[![YouTube Video](http://i.ytimg.com/vi/lLTO_fFqa6Q/hqdefault.jpg)](https://youtu.be/lLTO_fFqa6Q)

### V1 Tutorial Playlist (outdated)
**These videos are for version 1.0.0, they are missing all the tools-related features. But may still be helpful if you are looking to learn about Quick Prompts and the basics of this plugin.**

[Click here to go to the tutorial playlist](https://www.youtube.com/playlist?list=PL2PLLTlAI2ogvgcY8mG-QsMI1dDUDPyF2)

Compatible Godot Versions
-----------------------
Supported in Godot 4.3 to 4.7. Tested in stable versions only.
After version 2.0 I will test only in 4.7, but it will probably work in previous versions.

Setup steps
--------------------
In general this is what you need to do:

0. If running your LLMs locally, install [Ollama](https://ollama.com/) or some other supported LLM provider, and download at least one model.
1. Download this addon from [here](https://github.com/FlamxGames/godot-ai-assistant-hub/archive/refs/heads/main.zip), unzip it, and copy the folder ai_assistant_hub into your addons folder `res://addons/ai_assistant_hub/`. (You may see errors, those should go away after next step.)
2. Reload your project: **Project > Reload Current Project** (this will reload the whole project, so make sure to save before doing this).
3. Enable the plugin in your project settings (**Project > Project Settings... > Plugins**), you should see a new tab `AI Hub` in the bottom panel.
4. Select an LLM provider, by default Ollama is selected.
5. You should see a list of models you have installed. Clicking them will check its capabilities. If the model can use Tools you will see a hammer icon at the left side of the "New assistant type" button.
6. Click the "New assistant type" button to use that model. A new window will open.
  - 6.1. Fill up the data requested in the window. Icon is optional.
  - 6.2. Click "Set tools access" if present. Hide whatever tools are not required. Using all tools can use too much context for some computers.
  - 6.3. Configure Quick Prompts if you want. They allow you to send a prompt in the chat by clicking a button instead of writing it every time.
7. After saving, you should see a new button for your assistant type.
8. Click the assistant type button to start a chat with a new assistant of this type. Or right click it to edit it or delete it.

### Configuring Quick Prompts for Coding
If you cannot use Tools for coding, you can still use Quick Prompts for that, but it requires some additional configuration.

Quick Prompts add the ability to insert the assistant's answer in the Godot's Code Editor, even if the assistant is not really aware of it.
The following keywords are used to allow the prompt to pull data from the Code Editor or from the chat prompt.
* Use `{CODE}` to insert the code currently selected in the editor.
* Use `{CHAT}` to include the current content of the text prompt.

**Note**: Most models already tag their code properly, but not all of them. In order for the plugin to identify what code to use from the assistant's response, you may need to give explicit instructions in their description, for example:

	Any code you write, mark it properly, for example:
	```gdscript
	var x:String = "abc"
	```

**Step-by-step process:**
1. Find your assistant, it should be .tres file under "res://addons/ai_assistant_hub/assistants/".
2. Double-click it to open it in the Inspector.
3. Locate property *Quick Prompts* and click it.
4. If you are creating a new Quick Prompt for this, click *Add Element* and then in the empty slot select *New AIQuickPromptResource*.
5. Click the entry to expand it and see its properties.
6. You will see a few properties:
	* **Action Name**. This name will be displayed in the Quick Prompt button.
	* **Action Prompt**. This is what this prompt will send to the chat. There are two keywords:
		* Use `{CODE}` to insert the code currently selected in the editor.
		* Use `{CHAT}` to include the current content of the text prompt.
	* **Icon**. The icon to display in the Quick Prompt button.
	* **Limit Tool Access**. This is irrelevant if the model you are using cannot use tools.
	* **Tool Access**. This is irrelevant if the model you are using cannot use tools.
	* **Response Target**. Where should the bot's answer go in Godot's editor. In most cases you want to set this to "Only Code To Code Editor".
	* **Code Placement**. Select your preference about how the tool should place the code generated by the assistant.
	* **Format Response as Comment**. Useful when the prompt is used to create inline code documentation.
7. Once done start a new chat to see the Quick Prompt.

Experiment and build the right type of assistants for your workflow.

### Not sure what models to use?

I found it is not a good idea to give advice here, as models change all the time. My suggestion is to search “Best coding local LLM models in (current year) that fit (insert your setup here).”
For example, “Best coding local LLM models in 2026 that fit 8 GB of VRAM.”

The rule of thumb I follow is to check the output speed by chatting with it. If it is slow, the model is not being loaded onto my GPU; it is using RAM/CPU. You probably only want to do that if the results the model produces are remarkably better, or simply if you don’t have a GPU capable of loading any models.

What's new in the latest version
-----------------------
**2.0.0**
* Tools support (Ollama).
* Context usage indicator (Ollama).
* Set context length (Ollama).
* Editing assistants definition propagates to existing chats.
* Configure icon and Quick Prompts from the assistant editor itself (no need to edit the resource manually anymore).

[Full version history](versions.md)

Upgrading to a newer version
-----------------------
If you had the plugin installed and want to upgrade to the latest version, follow these steps:

***Download > Disable current > Install new > Reload project > Enable***

1. Download the latest version [here](https://github.com/FlamxGames/godot-ai-assistant-hub/archive/refs/heads/main.zip) and unzip it.
2. **Disable** the plugin from **Project > Project Settings... > Plugins**.
3. Pull the **ai_assistant_hub** folder from the new version into your addons folder (don't delete the previous one so you don't lose your assistants). You may see errors in Godot's output tab, that is fine.
4. Ensure Godot loads into memory the new version: **Project > Reload Current Project** (this will reload the whole project, so make sure to save before doing this).
5. **Enable** the plugin. You should not see any errors in the output tab, but in some cases you may see some message confirming the migration of old settings.

Contribute
-----------------------------
Hi, I'm Forest, I'm a solo game developer that sometimes ends up building game dev tools.

I created this addon for my personal use, and decided to share it as open source. Hope you find it useful.

If you like this project check the following page for ideas about how to support it: https://github.com/FlamxGames/godot-ai-assistant-hub/blob/main/support.md

License
----------
This project is licensed under the MIT license.
