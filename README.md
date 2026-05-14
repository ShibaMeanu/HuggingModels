# 🤗 Hugging Models

Ever found a shiny new model on Hugging Face, got super excited, downloaded it, and then watched your GPU cry as it immediately ran out of memory? Yeah, me too. 

That's why I built this.

**Hugging Models** is a lightweight, native macOS menu bar app that lets you search Hugging Face, explore trending models, and instantly calculate the estimated VRAM required to run them *before* you nuke your system. 

<p align="center">
  <img src="HuggingModels/AppIcon.icns" width="128" alt="Hugging Models Icon">
</p>

## ✨ Features

* **🔍 Direct Hub Search:** Search Hugging Face models right from your menu bar. 
* **⚡️ Trending Indicators:** See what's hot right now. We pull the exact same momentum signals Hugging Face uses to highlight trending models.
* **📊 Metrics at a Glance:** Instantly view downloads and community likes for any model.
* **🧠 Smart Auto-Detection:** Automatically pulls architectural configs (layers, heads, dimensions) and guesses the parameter count if it's in the model name.
* **📦 GGUF Support:** Detects GGUF variants and allows you to select specific quantization files to see precise memory requirements.
* **🧮 KV Cache Math:** It doesn't just calculate weight size; it estimates the KV cache overhead based on your desired context length and batch size.

## 🛠️ How to Build

If you want to compile this yourself, you'll need a Mac and Swift (Xcode command line tools are fine).

1. Clone the repo.
2. Open your terminal and navigate to the `HuggingModels` directory.
3. Run the magical `make` command:
```bash
make all
```
4. Find your shiny new `HuggingModels.app` inside the `build/` folder.
5. (Optional) Run `make run` to build and immediately launch the app.
6. (Optional) Run `make install` to copy the app to your `/Applications` folder.

## 🤝 Architecture

It's a clean, standard SwiftUI MVVM architecture. If you want to poke around, start at `ViewModel.swift` (the brains) or `ContentView.swift` (the beauty). Check out [ARCHITECTURE.md](ARCHITECTURE.md) for the fancy Mermaid diagrams.

## 📝 License

This project is licensed under the [Apache License 2.0](LICENSE). Do whatever you want with it, just don't blame me if your GPU still catches fire.
