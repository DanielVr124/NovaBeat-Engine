# Building NovaBeat Engine

NovaBeat currently uses the official Friday Night Funkin' v0.8.6 source tree vendored under `upstream/Funkin/`. Its two required upstream asset repositories are pinned as Git submodules.

## Supported build targets

- **Windows desktop:** release executable.
- **Android mobile:** debug APK, suitable for installation/testing after the user obtains the build output from an authorized private build environment.

Android's upstream v0.8.6 project configuration currently targets landscape orientation. A successful Android compile does not mean NovaBeat's separate portrait-and-landscape UI requirement is complete.

## Clone the repository

Use recursive submodule checkout so the exact pinned `assets` and `art` revisions are available:

```bash
git clone --recurse-submodules https://github.com/DanielVr124/NovaBeat-Engine.git
cd NovaBeat-Engine
```

For an existing clone:

```bash
git submodule update --init --recursive
```

## Common Haxe setup

Use **Haxe 4.3.7** and Git. From `upstream/Funkin/`, install the same patched Haxe library manager used by the upstream build setup:

```bash
haxelib fixrepo --global
haxelib --global install haxelib 4.1.0
haxelib --global set haxelib 4.1.0
haxelib --global remove haxelib git
haxelib --global remove hmm
haxelib --global git haxelib https://github.com/FunkinCrew/haxelib.git funkin-patches --skip-dependencies
haxelib --global git hmm https://github.com/FunkinCrew/hmm funkin-patches
haxelib --never newrepo
haxelib --global run hmm install -q
```

If either `remove` command reports that the library is not installed, it is safe to continue.

Compile the pinned HXCPP support tools before the platform build:

```bash
cd .haxelib/hxcpp/git/tools/hxcpp
haxe compile.hxml
cd ../../../../..
```

## Windows desktop

Install Visual Studio 2022 Build Tools with the **Desktop development with C++** workload, including MSVC v143 and a Windows 10/11 SDK.

From `upstream/Funkin/`, run:

```bash
haxelib run lime build windows -v -release -DGITHUB_BUILD
```

Expected output:

```text
export/release/windows/bin/Funkin.exe
```

## Android mobile

Install **JDK 17** and Android command-line tools. Install the exact SDK/NDK versions used by this source baseline:

```bash
sdkmanager --install \
  "platform-tools" \
  "platforms;android-29" \
  "platforms;android-35" \
  "build-tools;35.0.0" \
  "ndk;29.0.13113456"
```

Set the Android toolchain paths before building:

- `ANDROID_HOME` and `ANDROID_SDK` to the Android SDK directory.
- `ANDROID_NDK_HOME`, `ANDROID_NDK_ROOT`, and `ANDROID_NDK` to its `ndk/29.0.13113456` directory.
- `JAVA_HOME` to the JDK 17 installation.

Then, from `upstream/Funkin/`, register the toolchain paths with Lime and build:

```bash
haxelib run lime config ANDROID_SDK "$ANDROID_HOME"
haxelib run lime config ANDROID_NDK_ROOT "$ANDROID_NDK_HOME"
haxelib run lime config JAVA_HOME "$JAVA_HOME"
haxelib run lime config ANDROID_SETUP true
haxelib run lime build android -v -debug -DGITHUB_BUILD
```

The debug build does not need a release keystore. Lime writes the APK beneath the Android export directory under `export/`.

## Automated build checks

GitHub Actions workflow [NovaBeat platform build checks](https://github.com/DanielVr124/NovaBeat-Engine/actions/workflows/novabeat-platform-builds.yml) builds Windows and Android independently on pushes to `main`, pull requests, and manual runs. Each job verifies the expected executable/APK exists and records its SHA-256 in the workflow summary.

The workflow intentionally does **not** upload or publish EXE/APK binaries. The upstream `assets` and `art` repositories contain proprietary material whose licenses prohibit public redistribution by anyone other than the copyright owner. Keep any personally produced build private and follow those licenses.

## What a green build means

A green Windows job means the v0.8.6 game source compiled into a Windows executable. A green Android job means the v0.8.6 game source compiled into an Android debug APK. Neither result alone verifies runtime behavior on every PC or phone, and neither completes NovaBeat's planned Mod Manager, gameplay extensions, or Android portrait/landscape adaptation.

## Run the checks manually

Open the repository's **Actions** tab, select **NovaBeat platform build checks**, and choose **Run workflow** to start both platform builds on demand.
