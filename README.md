**Godot AI Assistant Hub**
<img src="https://github.com/FlamxGames/godot-ai-assistant-hub/blob/main/logo.png" width="50px">
==========================
**Latest version: 1.7.0**
<sub>([What's new?](#whats-new-in-the-latest-version))</sub>
<sub>([Upgrading to a newer version](#upgrading-to-a-newer-version))</sub>

A Flexible Godot Plugin for AI Assistants
-----------------------------------------

Embed AI assistants in Godot with the ability to read and write code in Godot's Code Editor.

It leverages [Ollama](https://ollama.com/) as an LLM provider, an open-source tool to run models locally for free. If you're not familiar with Ollama, I found it to be extremely simple to use; you should give it a try!

If you use ChatGPT, Gemini, or similar tools with a REST API, you could easily extend this addon to work with them—it was designed to be API agnostic. See the videos for more information on this.

[Click here to go to the tutorial playlist](https://www.youtube.com/playlist?list=PL2PLLTlAI2ogvgcY8mG-QsMI1dDUDPyF2)

Thanks to contributors, additionally to **Ollama**, the following APIs are already supported:
* Google Gemini
* Ollama Turbo
* OpenRouter
* Jan
* OpenWebUI

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

It depends on the models you use and the speed you expect. Of course, if you extend the plugin to run hosted models (ChatGPT, Gemini, etc.), then you don't need to worry about this (just about the bills).

**Tested in versions**

* Godot 4.4
* Godot 4.3

If you test it in other versions, let me know in the discussions section so I can add it here.


**Getting Started**
--------------------
This section assumes you have installed [Ollama](https://ollama.com/) and installed at least one model. If you are not sure about the models to download, read section "Not sure what models to use?".

### ▶️ If you are feeling like not reading much
Just install it and follow the hints it gives you in Godot itself.

### ▶️ If you want to understand it better
There are 2 main concepts for this addon, familiarize yourself with them, both are Godot [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html):

#### A) AI assistant type (AIAssistantResource). 🤖
This is the setup for an assistant, it describes what the assistant does, what LLM model to use, and what Quick Prompts it can use.

<Insert an image>

Think of it as a template for creating assistants. For example, you can have an assistant that helps with coding, and one that helps with writing. In that case, you would have 2 assistant types, and you can summon as many coders or writers you need.

#### B) Quick Prompt (AIQuickPromptResource). 🪄
Allows to send a prompt in the chat by clicking a button instead of writing it every time. It adds the ability to insert the assistant's answer in the Godot's Code Editor.
The following keywords are used to allow the prompt to pull data from the Code Editor or from the chat prompt.
* Use `{CODE}` to insert the code currently selected in the editor.
* Use `{CHAT}` to include the current content of the text prompt.

<Insert an image>

## Setup steps
In general this is what you need to do:

0. Install Ollama or some other LLM supported and download a model.
1. Download this addon and copy the folder ai_assistant_hub into your addons folder (`res://addons/ai_assistant_hub/`).
2. Enable the plugin in your project settings (**Project > Project Settings... > Plugins**), you should see a new tab `AI Hub` in the bottom panel.
3. Select an LLM provider, by default Ollama is selected.
4. You should see a list of models you have installed. Click one and use the "New assistant type" button.
5. Fill up the data for your assistant.
6. After saving, you should see a new button for your assistant type.
7. Your assistant type will open in the Inspector panel, there you can optionally confirgure an icon and Quick Prompts for your assistant type, the later would allow it to interact with the code editor.
8. Click the assistant type button to start a chat with a new assistant of this type.

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

Some popular models that work fine in low-end computers at the time I wrote this (Oct 2024) are:
* **llama3.2:** Fast and efficient, but may have occasional accuracy issues.
* **granite-code:** Ideal for coding on lower-end machines.
* **mistral:** Excellent for writing tasks.
* **deepseek-coder-v2:** Powerful coding model (requires at least 8GB of VRAM).

⚠️ If you don't agree with these suggestions or have an updated list of recommendations, leave a comment in the Discussions page with your suggestions.

If you have a powerful PC, just keep increasing the level of the model. You will see many models have versions like 1.5B, 3B, 7B, 30B, 77B, these mean billions of parameters. You can consider 1.5B for very low-end machines, and 77B for very powerful ones. If you are not sure, just try them out, they are easy to delete as well.

**What's new in the latest version**
-----------------------
* Ollama Turbo support

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
This project is licensed under the MIT license. Enjoy!
