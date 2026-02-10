# Research @ UIUC's Gritton Lab

**MATLAB pipeline for analyzing behavioral performance in optogenetic laser tasks.**

This tool automates the batch processing of LabView data files, distinguishing between Laser and Non-Laser trials to calculate performance metrics (accuracy, omissions, reaction time) and aggregating results into a master Excel file for statistical analysis.

## 📌 Overview

Quantifying behavioral changes during optogenetic manipulation is critical for understanding neural circuit function. This pipeline processes raw behavioral data files to compare subject performance across **Laser** (stimulated) and **Non-Laser** (control) conditions.

It provides a **turnkey workflow** for:
* Parsing raw LabView output files.
* Calculating key behavioral metrics (Hit Rate, Reaction Latency, Omission Rate).
* Preserving manual metadata (e.g., fiber angle, laser power) during batch updates.

## Features

✅ **Intelligent Batch Processing** – Recursively searches directories to process hundreds of data files automatically.
✅ **Laser vs. Non-Laser Logic** – Automatically separates trials based on sound/trial type (Control: Types 1/2 vs. Laser: Types 3/4).
✅ **Smart Data Merging** – Updates calculated metrics in the output Excel file while *preserving* manually entered columns (e.g., Angle, Power).
✅ **Feature Extraction** – Computes Accuracy (%), Omission Rates, and First-Lick Latency (Reaction Time).
✅ **Metadata Parsing** – Extracts Subject IDs and Dates directly from filenames for consistent record-keeping.

## File Descriptions

* **`Batch_Processing.m`** – The main execution script. It manages the directory search, loads existing data to prevent overwriting manual entries, loops through all found files, and saves the consolidated results to `Batch_Analysis_Results.xlsx`.
* **`Function_LaserAnalysis.m`** – The core analysis engine. It takes a single file path as input, reads the raw trial data (timestamps, lick triggers, sound types), and computes specific performance metrics for that session.
* **`Batch_Analysis_Results.xlsx`** – (Generated Output) The final report containing paired Laser/Non-Laser statistics for every processed subject and date.

## 🚀 Getting Started

### Prerequisites

* MATLAB R2020b or later.
* Statistics and Machine Learning Toolbox (recommended for advanced stats, though core logic is base MATLAB).

### Installation

1.  Clone this repository:
    ```bash
    git clone [https://github.com/yourusername/Optogenetic-Behavior-Analysis.git](https://github.com/yourusername/Optogenetic-Behavior-Analysis.git)
    cd Optogenetic-Behavior-Analysis
    ```
2.  **Organize Data**: Ensure your raw LabView data files are located in a folder named `labview_copy` (or modify the `targetFolderName` variable in `Batch_Processing.m`).

### Usage

1.  Open **`Batch_Processing.m`** in MATLAB.
2.
